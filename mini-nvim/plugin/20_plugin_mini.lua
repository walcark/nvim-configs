-- Contains all imports and configuration of mini.nvim pluggins.
-- Currently used pluggins:
--      mini.files
--      mini.snippets
--      mini.completion
--      mini.pairs
--      mini.icons
--      mini.pick


-- Recently visited files
require('mini.visits').setup()
vim.keymap.set('n', '<leader>fv', MiniVisits.select_path, { desc = 'Visited paths' })

-- File navigation
require('mini.files').setup({
    windows = {
        preview = true,
        width_focus = 30,
        width_nofocus = 20,
        width_preview = 70,
    },
    options = {
        use_as_default_explorer = true,
    }
})

-- Open the current file's directory, not the cwd
local files_toggle = function()
    if not MiniFiles.close() then
        MiniFiles.open(vim.api.nvim_buf_get_name(0), true)
    end
end
vim.keymap.set('n', '<leader>e', files_toggle, { desc = 'Explorer' })

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
