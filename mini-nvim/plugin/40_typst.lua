-- Typst preview. No autocmd and no debounce here on purpose: `typst watch`
-- already recompiles on change, and `tdf` reloads the PDF on its own. This
-- only has to start the pair and put the viewer in a kitty split.

vim.api.nvim_create_user_command('TypstPreview', function()
    local src = vim.api.nvim_buf_get_name(0)
    if not src:match('%.typ$') then
        vim.notify('TypstPreview: not a .typ buffer', vim.log.levels.WARN)
        return
    end

    local pdf = (src:gsub('%.typ$', '.pdf'))
    vim.system({ 'typst', 'watch', src, pdf })
    vim.system({
        'kitten', '@', 'launch', '--location=vsplit', '--keep-focus',
        'tdf', pdf,
    }, {}, function(res)
        if res.code ~= 0 then
            vim.schedule(function()
                vim.notify('TypstPreview: ' .. res.stderr, vim.log.levels.ERROR)
            end)
        end
    end)
end, { desc = 'typst watch + tdf in a kitty split' })
