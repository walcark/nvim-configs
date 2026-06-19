-- Generate help tags for every vendored plugin (pack/plugins/start/*)
-- so :help works offline without any install step.
local start_dir = vim.fn.stdpath('config') .. '/pack/plugins/start'
for _, dir in ipairs(vim.fn.glob(start_dir .. '/*/doc', true, true)) do
    if vim.fn.filereadable(dir .. '/tags') == 0 then
        vim.cmd('helptags ' .. vim.fn.fnameescape(dir))
    end
end
