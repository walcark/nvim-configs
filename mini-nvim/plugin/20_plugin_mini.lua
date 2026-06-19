-- Contains all imports and configuration of mini.nvim pluggins.
-- Currently used pluggins:
--      mini.files
--      mini.hues
--      mini.snippets
--      mini.completion
--      mini.pairs
--      mini.icons
--      mini.pick


-- File navigation
require('mini.files').setup()
vim.keymap.set('n', '<leader>e', MiniFiles.open, {desc = 'Explorer'})

require('mini.hues').setup({
    background = '#1a1b2e',
    foreground = '#c0caf5',
    n_hues = 8,
    saturation = 'high',
})

require('mini.snippets').setup({
    snippets = {
        require('mini.snippets').gen_loader.from_file(
            vim.fn.stdpath('config') .. '/snippets/global.json'
        ),
    },
})

-- Two-stage autocompletion: LSP first (with completion item docs and
-- automatic signature help), buffer words as fallback. Set up after
-- mini.snippets so snippet candidates integrate into the menu.
vim.opt.completeopt = { 'menuone', 'noinsert' }
require('mini.completion').setup()

require('mini.pairs').setup()

require('mini.icons').setup()

require('mini.pick').setup()
vim.keymap.set('n', '<leader>ff', MiniPick.builtin.files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', MiniPick.builtin.grep_live, { desc = 'Grep' })
vim.keymap.set('n', '<leader>fb', MiniPick.builtin.buffers, { desc = 'Buffers' })
vim.keymap.set('n', '<leader>fh', MiniPick.builtin.help, { desc = 'Help' })


