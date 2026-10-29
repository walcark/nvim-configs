-- Markdown preview in a kitty split, rendered like a document: pandoc turns
-- the note into Typst, `typst watch` compiles it, tdf shows the PDF and
-- reloads it on its own (the same pair as :TypstPreview). Formulas, tables,
-- images and code all render; Mermaid does not (that needs a browser).
--
-- It follows typing: ~300 ms after the last change the buffer is written to a
-- private temp copy, never to your file. Measured on a 300-line note: pandoc
-- 0.07 s + typst 0.2 s, so the page updates about half a second after you stop.
--
-- :MarkdownPreview toggles it for the current buffer. Leaving the buffer or
-- nvim stops it and closes the split.

local filter = vim.fn.stdpath('config') .. '/pandoc/abs-images.lua'
local delay = 300 -- ms of quiet before re-rendering
local previews = {} -- buf -> { dir, timer, watch, title, group }

local function notify(msg, level)
    vim.schedule(function() vim.notify('MarkdownPreview: ' .. msg, level or vim.log.levels.ERROR) end)
end

local function stop(buf)
    local p = previews[buf]
    if not p then return end
    previews[buf] = nil
    p.timer:stop()
    p.timer:close()
    if p.watch then p.watch:kill('sigterm') end
    vim.system({ 'kitten', '@', 'close-window', '--match', 'title:' .. p.title })
    pcall(vim.api.nvim_del_augroup_by_id, p.group)
    vim.fn.delete(p.dir, 'rf')
end

local function start(buf)
    local src = vim.api.nvim_buf_get_name(buf)
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local md, typ, pdf = dir .. '/note.md', dir .. '/note.typ', dir .. '/note.pdf'
    local env = { MDPREVIEW_DIR = vim.fn.fnamemodify(src ~= '' and src or vim.fn.getcwd(), ':p:h') }

    -- Buffer -> temp .md -> .typ. typst watch picks the .typ up from there.
    local function render(wait)
        vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), md)
        local job = vim.system(
            { 'pandoc', md, '-s', '-t', 'typst', '--lua-filter', filter, '-o', typ },
            { env = env },
            function(res) if res.code ~= 0 then notify(res.stderr) end end
        )
        if wait then job:wait() end
    end

    render(true)
    -- One full compile first: tdf needs the PDF to exist when it starts.
    local first = vim.system({ 'typst', 'compile', '--root', '/', typ, pdf }):wait()
    if first.code ~= 0 then
        notify(first.stderr)
        vim.fn.delete(dir, 'rf')
        return
    end

    local p = {
        dir = dir,
        timer = vim.uv.new_timer(),
        title = 'mdpreview-' .. buf,
        group = vim.api.nvim_create_augroup('mdpreview_' .. buf, { clear = true }),
    }
    previews[buf] = p
    -- --root /: images may live anywhere, made absolute by the filter.
    p.watch = vim.system({ 'typst', 'watch', '--root', '/', typ, pdf })
    vim.system({
        'kitten', '@', 'launch', '--location=vsplit', '--keep-focus',
        '--title', p.title, 'tdf', pdf,
    }, {}, function(res) if res.code ~= 0 then notify(res.stderr) end end)

    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufWritePost' }, {
        group = p.group,
        buffer = buf,
        callback = function()
            p.timer:stop()
            p.timer:start(delay, 0, vim.schedule_wrap(function()
                if previews[buf] then render(false) end
            end))
        end,
    })
    vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
        group = p.group,
        buffer = buf,
        callback = function() stop(buf) end,
    })
end

vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
        for buf in pairs(previews) do stop(buf) end
    end,
})

vim.api.nvim_create_user_command('MarkdownPreview', function()
    local buf = vim.api.nvim_get_current_buf()
    if previews[buf] then
        stop(buf)
    elseif vim.bo[buf].filetype ~= 'markdown' then
        vim.notify('MarkdownPreview: not a markdown buffer', vim.log.levels.WARN)
    else
        start(buf)
    end
end, { desc = 'toggle a live pandoc + typst + tdf preview in a kitty split' })
