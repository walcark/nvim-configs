-- vim-suda: read and write root files through sudo while nvim keeps running
-- as the user, with this config. Smart edit: a file the user cannot write
-- opens through suda, so a plain :w asks for the sudo password.
vim.g.suda_smart_edit = 1
