"""Render data files for nvim: a summary, then one 2D slice at a time as PNG.

Run by plugin/45_dataview.lua with the Python of the pixi env ``xarray``
(the dotfiles extra ``data``).

``serve`` reads one JSON request per line on stdin and answers one JSON line
on stdout, with the same ``id``. Files stay open between requests, so moving
along a dimension costs a render, not a reopen.

``window`` opens an interactive matplotlib window (zoom, pan, one slider per
free dimension), for what a still image in the terminal cannot do.

Two models cover every format: a grid (xarray, for netCDF, HDF5, GRIB and
GDAL rasters) and a table of geometries (geopandas, for vector files).
"""

from __future__ import annotations

import json
import os
import sys
import warnings
import traceback
from pathlib import Path
from typing import Any

import numpy as np

RASTER = {".tif", ".tiff", ".jp2", ".vrt", ".img", ".asc"}
HDF4 = {".hdf", ".hdf4", ".h4"}
GRIB = {".grib", ".grib2", ".grb", ".grb2"}
VECTOR = {".gpkg", ".shp", ".geojson", ".json", ".fgb", ".kml", ".gml"}
MAX_PIXELS = 1200  # per axis, after striding: enough for a terminal split
MAX_FEATURES = 200_000
Y_NAMES = ("y", "lat", "latitude", "nav_lat", "rlat", "row", "rows", "south_north")
X_NAMES = ("x", "lon", "longitude", "nav_lon", "rlon", "col", "cols", "west_east")


def open_grid(path: Path) -> Any:
    """Open a gridded file as an xarray Dataset, lazily.

    Parameters
    ----------
    path : Path
        The file.

    Returns
    -------
    xarray.Dataset
        Its variables, nothing loaded yet.
    """
    import xarray as xr

    ext = path.suffix.lower()
    if ext in RASTER:
        return xr.open_dataset(path, engine="rasterio")
    if ext in GRIB:
        return xr.open_dataset(path, engine="cfgrib", backend_kwargs={"indexpath": ""})
    try:
        return xr.open_dataset(path)
    except Exception:
        return xr.open_dataset(path, engine="h5netcdf", phony_dims="sort")


def spatial_dims(dims: tuple[str, ...]) -> tuple[str | None, str | None]:
    """Pick the y and x dimensions of a variable.

    Parameters
    ----------
    dims : tuple of str
        Its dimensions.

    Returns
    -------
    tuple
        The y and x names, by usual names first, else the last two.
    """
    low = {str(d).lower(): d for d in dims}
    y = next((low[n] for n in Y_NAMES if n in low), None)
    x = next((low[n] for n in X_NAMES if n in low), None)
    if y and x:
        return y, x
    if len(dims) >= 2:
        return dims[-2], dims[-1]
    return None, dims[-1] if dims else None


def human(n: float) -> str:
    """Format a size in bytes.

    Parameters
    ----------
    n : float
        The size.

    Returns
    -------
    str
        Like ``12.3 MB``.
    """
    for unit in ("B", "kB", "MB", "GB"):
        if n < 1000:
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1000
    return f"{n:.1f} TB"


class Grid:
    """A gridded file, its summary and its slices."""

    kind = "grid"

    def __init__(self, path: Path) -> None:
        self.path = path
        self.ds = open_grid(path)

    def variables(self) -> list[dict[str, Any]]:
        """List the plottable variables, the largest first.

        Returns
        -------
        list of dict
            Name, dims and shape of each variable.
        """
        out = [
            {"name": str(n), "dims": [str(d) for d in v.dims], "shape": list(v.shape)}
            for n, v in self.ds.data_vars.items()
            if v.ndim >= 1 and np.issubdtype(v.dtype, np.number)
        ]
        return sorted(out, key=lambda v: -int(np.prod(v["shape"])))

    def summary(self) -> tuple[list[str], dict[int, str]]:
        """Describe the file.

        Returns
        -------
        tuple
            The lines, and the variable named on each line (0-based).
        """
        ds, lines, at = self.ds, [], {}
        dims = ", ".join(f"{k}={v}" for k, v in ds.sizes.items())
        lines += [f"Dimensions   {dims}", "", "Variables"]
        for name, v in ds.data_vars.items():
            at[len(lines)] = str(name)
            label = v.attrs.get("long_name") or v.attrs.get("standard_name") or ""
            units = v.attrs.get("units", "")
            lines.append(
                f"  {name!s:<20} ({', '.join(map(str, v.dims))})  {v.dtype}"
                + (f"  {label}" if label else "")
                + (f" [{units}]" if units else "")
            )
        lines += ["", "Coordinates"]
        for name, c in ds.coords.items():
            rng = ""
            if c.ndim == 1 and c.size:
                rng = f"  {str(c.values[0])[:19]} .. {str(c.values[-1])[:19]}"
            lines.append(f"  {name!s:<20} ({', '.join(map(str, c.dims))})  {c.dtype}{rng}")
        crs = next((c.attrs["crs_wkt"] for c in ds.coords.values() if "crs_wkt" in c.attrs), None)
        if crs:
            lines += ["", f"CRS          {crs[:100]}"]
        if ds.attrs:
            lines += ["", "Attributes"]
            for k, val in list(ds.attrs.items())[:20]:
                lines.append(f"  {k:<20} {str(val).replace(chr(10), ' ')[:100]}")
        return lines, at

    def free_dims(self, var: str) -> list[dict[str, Any]]:
        """List the dimensions of a variable that are not drawn.

        Parameters
        ----------
        var : str
            The variable.

        Returns
        -------
        list of dict
            Name and size of each, in order.
        """
        da = self.ds[var]
        y, x = spatial_dims(da.dims)
        return [{"name": str(d), "size": int(da.sizes[d])} for d in da.dims if d not in (y, x)]

    def plot(self, ax: Any, var: str, index: dict[str, int], robust: bool, cmap: str) -> str:
        """Draw one slice of a variable.

        Parameters
        ----------
        ax : matplotlib.axes.Axes
            Where to draw.
        var : str
            The variable.
        index : dict
            Position along each free dimension.
        robust : bool
            Colour range from the 2nd to the 98th percentile.
        cmap : str
            The colour map.

        Returns
        -------
        str
            The title: variable, units, and where the slice is.
        """
        da = self.ds[var]
        y, x = spatial_dims(da.dims)
        where = []
        for d in [d for d in da.dims if d not in (y, x)]:
            size = da.sizes[d]
            i = min(max(int(index.get(str(d), 0)), 0), size - 1)
            da = da.isel({d: i})
            value = str(da.coords[d].values) if d in da.coords else str(i)
            value = value.removesuffix("T00:00:00.000000000")[:19]  # a date alone
            if size > 1:
                where.append(f"{d}={value} ({i + 1}/{size})")
        steps = {d: max(1, -(-da.sizes[d] // MAX_PIXELS)) for d in (y, x) if d}
        da = da.isel({d: slice(None, None, s) for d, s in steps.items()}).load()
        units = da.attrs.get("units", "")
        if da.ndim == 1:
            da.plot(ax=ax, linewidth=1.2)
        else:
            mesh = da.plot(ax=ax, x=x, y=y, robust=robust, cmap=cmap, add_colorbar=False)
            # A map keeps its proportions: square pixels, or degrees as degrees.
            names = {str(x).lower(), str(y).lower()}
            if names <= set(X_NAMES) | set(Y_NAMES):
                ax.set_aspect("equal", adjustable="box")
            # Metres in full, five ticks at most: no "1e6" offset, no crowding.
            from matplotlib.ticker import MaxNLocator

            for axis in (ax.xaxis, ax.yaxis):
                axis.set_major_locator(MaxNLocator(5))
            ax.ticklabel_format(useOffset=False, style="plain")
            # In axes coordinates, so that it is exactly as tall as the map.
            bar = ax.figure.colorbar(mesh, cax=ax.inset_axes((1.02, 0, 0.025, 1)))
            bar.outline.set_linewidth(0.4)
            label = da.attrs.get("long_name") or da.attrs.get("standard_name") or ""
            if label:
                bar.set_label(label)
        ax.set_title("")
        stride = max(steps.values(), default=1)
        return (
            var
            + (f" [{units}]" if units else "")
            + ("   " + "   ".join(where) if where else "")
            + (f"   (1 pixel in {stride})" if stride > 1 else "")
        )


class Hdf4(Grid):
    """An HDF4 file (MODIS and the like), read through GDAL subdatasets.

    A MODIS product holds hundreds of them: the summary comes from GDAL's
    descriptions, and a subdataset is opened only when it is drawn.
    """

    def __init__(self, path: Path) -> None:
        import rasterio
        import xarray as xr

        self.path = path
        with rasterio.open(path) as src:
            tags = src.tags(ns="SUBDATASETS")
            attrs = src.tags()
        self.subs: dict[str, tuple[str, str]] = {}  # name -> (GDAL name, description)
        for key, gdal_name in tags.items():
            if key.endswith("_NAME"):
                name = gdal_name.rsplit(":", 1)[-1].strip('"').replace(" ", "_")
                self.subs[name] = (gdal_name, tags.get(key[:-5] + "_DESC", ""))
        self.attrs = attrs
        self.ds = xr.Dataset()  # filled as subdatasets are drawn

    def open_sub(self, var: str) -> None:
        """Load one subdataset into ``ds``, scaled and masked.

        Parameters
        ----------
        var : str
            Its name.
        """
        import rioxarray

        if var not in self.ds:
            da = rioxarray.open_rasterio(self.subs[var][0], mask_and_scale=True)
            self.ds[var] = da.rename({d: f"{var}_{d}" for d in da.dims if d == "band"})

    def variables(self) -> list[dict[str, Any]]:
        """List the subdatasets, in file order.

        Returns
        -------
        list of dict
            Their names, without dims (unknown until opened).
        """
        return [{"name": n, "dims": [], "shape": []} for n in self.subs]

    def summary(self) -> tuple[list[str], dict[int, str]]:
        """Describe the file from GDAL's metadata, opening nothing.

        Returns
        -------
        tuple
            The lines, and the subdataset named on each line (0-based).
        """
        lines, at = [f"Subdatasets  {len(self.subs)}", "", "Variables"], {}
        for name, (_, desc) in self.subs.items():
            at[len(lines)] = name
            lines.append(f"  {name:<40} {desc.split(']')[0].lstrip('[')}")
        if self.attrs:
            lines += ["", "Attributes"]
            for k, val in list(self.attrs.items())[:20]:
                lines.append(f"  {k:<20} {str(val).replace(chr(10), ' ')[:100]}")
        return lines, at

    def free_dims(self, var: str) -> list[dict[str, Any]]:
        """Open the subdataset, then list its free dimensions.

        Parameters
        ----------
        var : str
            The subdataset.

        Returns
        -------
        list of dict
            Name and size of each.
        """
        self.open_sub(var)
        return super().free_dims(var)

    def plot(self, ax: Any, var: str, index: dict[str, int], robust: bool, cmap: str) -> str:
        """Open the subdataset, then draw it like any grid.

        Parameters
        ----------
        ax : matplotlib.axes.Axes
            Where to draw.
        var : str
            The subdataset.
        index : dict
            Position along each free dimension.
        robust : bool
            Colour range from the 2nd to the 98th percentile.
        cmap : str
            The colour map.

        Returns
        -------
        str
            The title.
        """
        self.open_sub(var)
        return super().plot(ax, var, index, robust, cmap)


class Vector:
    """A vector file: its layers, attributes and geometries."""

    kind = "vector"

    def __init__(self, path: Path) -> None:
        import pyogrio

        self.path = path
        self.layers = [str(name) for name, _ in pyogrio.list_layers(path)]
        self.layer = self.layers[0]
        self.info = pyogrio.read_info(path, layer=self.layer)
        self.gdf = pyogrio.read_dataframe(path, layer=self.layer, max_features=MAX_FEATURES)

    def variables(self) -> list[dict[str, Any]]:
        """List what can colour the map: the geometry alone, then each column.

        Returns
        -------
        list of dict
            ``geometry`` then each column.
        """
        cols = [str(c) for c in self.gdf.columns if c != self.gdf.geometry.name]
        return [{"name": c, "dims": [], "shape": []} for c in ["geometry", *cols]]

    def summary(self) -> tuple[list[str], dict[int, str]]:
        """Describe the layer.

        Returns
        -------
        tuple
            The lines, and the attribute named on each line (0-based).
        """
        info, gdf, at = self.info, self.gdf, {}
        count = int(info["features"])
        lines = [
            f"Layers       {', '.join(self.layers)}",
            f"Features     {count}" + (f" (first {MAX_FEATURES} read)" if count > MAX_FEATURES else ""),
            f"Geometry     {info.get('geometry_type')}",
            f"CRS          {info.get('crs')}",
            f"Bounds       {', '.join(f'{b:.4g}' for b in gdf.total_bounds)}",
            "",
            "Attributes",
        ]
        at[len(lines)] = "geometry"
        lines.append(f"  {'geometry':<20} {info.get('geometry_type')}")
        for c in gdf.columns:
            if c == gdf.geometry.name:
                continue
            at[len(lines)] = str(c)
            sample = gdf[c].dropna().head(3).astype(str).str.slice(0, 20).tolist()
            lines.append(f"  {c!s:<20} {str(gdf[c].dtype):<10} {', '.join(sample)}")
        return lines, at

    def free_dims(self, var: str) -> list[dict[str, Any]]:
        """Vectors have no dimension to move along.

        Parameters
        ----------
        var : str
            Unused.

        Returns
        -------
        list
            Empty.
        """
        return []

    def plot(self, ax: Any, var: str, index: dict[str, int], robust: bool, cmap: str) -> str:
        """Draw the geometries, coloured by an attribute.

        Parameters
        ----------
        ax : matplotlib.axes.Axes
            Where to draw.
        var : str
            ``geometry``, or the attribute giving the colour.
        index : dict
            Unused.
        robust : bool
            Unused.
        cmap : str
            The colour map.

        Returns
        -------
        str
            The title.
        """
        if var == "geometry":
            self.gdf.plot(ax=ax, linewidth=0.5, edgecolor="0.3")
        else:
            self.gdf.plot(ax=ax, column=var, cmap=cmap, legend=True, linewidth=0.3)
        return f"{self.layer}   {var}"


def style(bg: str, fg: str) -> None:
    """Make figures quiet and in the terminal's colours.

    Parameters
    ----------
    bg : str
        Background colour, like ``#1e1e2e``.
    fg : str
        Text colour.
    """
    import matplotlib as mpl

    mpl.rcParams.update({
        "figure.facecolor": bg,
        "savefig.facecolor": bg,
        "axes.facecolor": bg,
        "axes.edgecolor": fg,
        "axes.labelcolor": fg,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.linewidth": 0.6,
        "text.color": fg,
        "xtick.color": fg,
        "ytick.color": fg,
        "xtick.major.width": 0.6,
        "ytick.major.width": 0.6,
        "font.size": 9,
        "axes.labelsize": 9,
        "figure.titlesize": 10,
        "image.interpolation": "nearest",
    })


def load(path: Path) -> Grid | Vector:
    """Open a file with the model that fits its extension.

    Parameters
    ----------
    path : Path
        The file.

    Returns
    -------
    Grid or Vector
        The opened file.
    """
    ext = path.suffix.lower()
    if ext in VECTOR:
        return Vector(path)
    return Hdf4(path) if ext in HDF4 else Grid(path)


class Server:
    """Answer the requests of nvim, keeping files open."""

    def __init__(self) -> None:
        self.files: dict[str, Grid | Vector] = {}

    def get(self, path: str) -> Grid | Vector:
        """Return an opened file, opening it on first use.

        Parameters
        ----------
        path : str
            The file.

        Returns
        -------
        Grid or Vector
            The opened file.
        """
        if path not in self.files:
            self.files[path] = load(Path(path))
        return self.files[path]

    def open(self, req: dict[str, Any]) -> dict[str, Any]:
        """Summarise a file.

        Parameters
        ----------
        req : dict
            ``path``.

        Returns
        -------
        dict
            The summary lines, the variable of each line (0-based), the
            plottable variables.
        """
        path = Path(req["path"])
        f = self.get(req["path"])
        lines, at = f.summary()
        head = [f"{path.name}   {f.kind}, {human(path.stat().st_size)}", ""]
        return {
            "lines": head + lines,
            "at": {str(k + len(head)): v for k, v in at.items()},
            "variables": f.variables(),
        }

    def plot(self, req: dict[str, Any]) -> dict[str, Any]:
        """Render one slice to a PNG of the viewer's size.

        Parameters
        ----------
        req : dict
            ``path``, ``var``, ``index``, ``robust``, ``cmap``, ``out``,
            ``width`` and ``height`` in pixels.

        Returns
        -------
        dict
            The PNG, its title, and the free dimensions of the variable.
        """
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        f = self.get(req["path"])
        style(req.get("bg") or "#ffffff", req.get("fg") or "#222222")
        dpi = 100
        width = max(int(req.get("width") or 800), 300)
        height = max(int(req.get("height") or 600), 200)
        fig, ax = plt.subplots(figsize=(width / dpi, height / dpi), dpi=dpi, layout="constrained")
        fig.get_layout_engine().set(w_pad=0.15, h_pad=0.15)
        try:
            title = f.plot(ax, req["var"], req.get("index") or {}, req.get("robust", True), req["cmap"])
            fig.suptitle(title, x=0.02, ha="left")
            fig.savefig(req["out"])
        finally:
            plt.close(fig)
        return {"png": req["out"], "title": title, "free": f.free_dims(req["var"])}

    def close(self, req: dict[str, Any]) -> dict[str, Any]:
        """Forget a file.

        Parameters
        ----------
        req : dict
            ``path``.

        Returns
        -------
        dict
            Empty.
        """
        f = self.files.pop(req["path"], None)
        if isinstance(f, Grid):
            f.ds.close()
        return {}

    def run(self) -> None:
        """Serve until stdin closes."""
        for line in sys.stdin:
            req = json.loads(line)
            try:
                res = getattr(self, req["cmd"])(req)
            except Exception as exc:
                res = {"error": f"{type(exc).__name__}: {exc}", "trace": traceback.format_exc()}
            res["id"] = req.get("id")
            sys.stdout.write(json.dumps(res, default=str) + "\n")
            sys.stdout.flush()
        # GDAL handles still open make the interpreter's shutdown slow and
        # noisy; nothing is left to flush.
        os._exit(0)


def window(path: str, var: str, index: dict[str, int], cmap: str) -> None:
    """Show a variable in an interactive window, a slider per free dimension.

    Parameters
    ----------
    path : str
        The file.
    var : str
        The variable.
    index : dict
        Where the sliders start.
    cmap : str
        The colour map.
    """
    import matplotlib.pyplot as plt
    from matplotlib.widgets import Slider

    f = load(Path(path))
    free = f.free_dims(var)
    state = {k: int(v) for k, v in index.items()}
    fig = plt.figure(figsize=(10, 7))
    n = len(free)
    top, bottom = fig.subfigures(2, 1, height_ratios=[1, 0.06 * n + 1e-3])

    def draw() -> None:
        top.clear()
        ax = top.add_subplot()
        ax.set_title(f.plot(ax, var, state, True, cmap), fontsize=9)
        fig.canvas.draw_idle()

    sliders = []
    for k, d in enumerate(free):
        sax = bottom.add_axes((0.15, (n - 1 - k + 0.2) / max(n, 1), 0.7, 0.6 / max(n, 1)))
        s = Slider(sax, d["name"], 0, d["size"] - 1, valinit=state.get(d["name"], 0), valstep=1)
        s.on_changed(lambda v, name=d["name"]: (state.__setitem__(name, int(v)), draw()))
        sliders.append(s)
    draw()
    plt.show()


def main() -> None:
    """Dispatch ``serve`` or ``window``."""
    warnings.simplefilter("ignore")  # stderr is not shown: keep it quiet
    if sys.argv[1:2] == ["serve"]:
        Server().run()
    elif sys.argv[1:2] == ["window"] and len(sys.argv) == 6:
        window(sys.argv[2], sys.argv[3], json.loads(sys.argv[4]), sys.argv[5])
    else:
        sys.exit("usage: dataview.py serve | window <path> <var> <index json> <cmap>")


if __name__ == "__main__":
    main()
