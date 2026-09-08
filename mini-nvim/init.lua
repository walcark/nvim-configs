-- Line numbering (relative)
vim.opt.number = true
vim.opt.relativenumber = true

-- Undo change after exiting a file
vim.opt.undofile = true

-- Better split options
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Change <leader> key to Space
vim.g.mapleader = " "

-- 4 spaces instead of tabstop + equal 4 space for indentation
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 0

vim.opt.clipboard = "unnamedplus"

-- netrw options
vim.g.netrw_liststyle = 3
vim.g.netrw_winsize = 20
vim.g.netrw_banner = 0
vim.keymap.set('n', '<leader>E', '<cmd>Lexplore<cr>', { desc = 'Sidebar tree' })
