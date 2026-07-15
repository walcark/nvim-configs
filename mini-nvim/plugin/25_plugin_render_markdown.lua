-- In-buffer markdown rendering (headings, bullets, checkboxes, tables).
-- Relies on the treesitter markdown parser bundled with Neovim >= 0.10
-- and on mini.icons (set up in 20_plugin_mini.lua) for file icons.
require('render-markdown').setup({
  -- No Nerd Font is installed, so the default checkbox glyphs (U+F0131 / U+F0C52)
  -- resolve to random fallback fonts (the unchecked one lands on a Tibetan font,
  -- hence the CJK-looking glyph). These Unicode ballot boxes both resolve to
  -- Adwaita Mono here, so they stay consistent in weight and monospace width.
  checkbox = {
    unchecked = { icon = '☐ ' },
    checked = { icon = '☒ ' },
  },
})
