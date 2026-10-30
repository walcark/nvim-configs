# Previews: next steps (decided 2026-10-30, not started)

1. Turn `:Preview` into a table: filetype -> converter, viewer (tdf for PDF,
   kitty image, text), cursor sync when paginated. Stop, kitty split and
   cursor following written once.
2. Python figures in kitty (a matplotlib backend for kitty: `plt.show()` in
   the split, over ssh too).
3. Data files preview (`.nc`, `.hdf`, `.csv`: ncdump -h, h5dump, an xarray
   summary); also the preview of the `data` picker in the dotfiles.
4. LaTeX: `latexmk -pvc` -> tdf, exact cursor sync with SyncTeX.
5. Diagrams: PlantUML (installed), maybe Excalidraw if workable.
6. Typst cursor sync, at section level.
7. marimo: `marimo edit --watch` next to nvim (see the note on marimo).
