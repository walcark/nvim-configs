-- Colorscheme + highlight overrides. Presentation concern, kept separate
-- from mini (20_) and LSP (30_). Loaded early so other modules see the
-- theme already applied.

-- Personal overrides, on top of the theme. Registered via a ColorScheme
-- autocmd so they survive any colorscheme reload. Target mostly the
-- @lsp.type.* groups (semantic tokens): run :Inspect on a token to find
-- the group that colors it.
vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('UserColors', {}),
    callback = function()
        -- local set = vim.api.nvim_set_hl
        -- set(0, 'Comment', { italic = true })
        -- set(0, '@lsp.type.function', { bold = true })
    end,
})

-- catppuccin: built-in of Neovim 0.12 ($VIMRUNTIME/colors/).
-- pcall: degrade gracefully if the runtime does not ship it.
pcall(vim.cmd.colorscheme, 'catppuccin')
