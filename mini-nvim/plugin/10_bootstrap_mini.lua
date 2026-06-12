-- Generate help tags for mini.nvim if not present
local doc_path = vim.fn.stdpath('config') .. '/pack/plugins/start/mini.nvim/doc'
if vim.fn.filereadable(doc_path .. '/tags') == 0 then
    vim.cmd('helptags ' .. doc_path)
end
