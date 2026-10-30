-- Markdown preview in a kitty split, rendered like a document: pandoc turns
-- the note into Typst, `typst watch` compiles it, tdf shows the PDF and
-- reloads it on its own (the same pair as :TypstPreview). Formulas, tables,
-- images and code all render; Mermaid does not (that needs a browser).
--
-- It follows typing: ~300 ms after the last change the buffer is written to a
-- private temp copy, never to your file. Measured on a 300-line note: pandoc
-- 0.07 s + typst 0.2 s, so the page updates about half a second after you stop.
--
-- The preview follows the cursor: the page holding the block under the cursor
-- is shown. pandoc reads the note with `+sourcepos`, a filter puts an
-- invisible marker before each block (pandoc/sourcepos.lua), and `typst eval`
-- gives the line -> page table. That is a second pandoc pass, run beside the
-- one that feeds the page: the markers cost pandoc 0.19 s against 0.08 s
-- (measured), and the text must not wait for them. Both passes use the same
-- reader, so the pages match. tdf is driven like a user would,
-- its "go to page" keys sent through kitty.
--
-- :MarkdownPreview [style] toggles it for the current buffer; with a style
-- while it runs, it switches style instead. The style comes from, in order:
-- that argument, `style: <name>` in the note's front matter, `default`. It is
-- read again at every render, so editing the front matter restyles live.
-- Styles live in styles/ (see styles/README.md). Leaving the buffer or nvim
-- stops the preview and closes the split.

local filter = vim.fn.stdpath('config') .. '/pandoc/abs-images.lua'
local sourcepos = vim.fn.stdpath('config') .. '/pandoc/sourcepos.lua'
local follow_delay = 150 -- ms of cursor rest before turning the page
local styles = vim.fn.stdpath('config') .. '/styles'
local delay = 300 -- ms of quiet before re-rendering
local a4 = 210 / 297 -- width / height of an A4 page
local fallback_bias = 40 -- percent of the width for the preview if measuring fails

-- Width of the preview, in percent of this kitty window, so that its height
-- holds exactly one A4 page. kitty reports sizes in cells only, and a cell's
-- shape depends on the font, so the pixel size is asked to the terminal
-- (TIOCGWINSZ on /dev/tty, which kitty fills in pixels).
local function a4_bias()
    local ok, bias = pcall(function()
        local ffi = require('ffi')
        pcall(ffi.cdef, [[
            struct mdp_winsize { unsigned short row, col, xpixel, ypixel; };
            int open(const char *path, int flags);
            int close(int fd);
            int ioctl(int fd, unsigned long request, ...);
        ]])
        local fd = ffi.C.open('/dev/tty', 0)
        if fd < 0 then return nil end
        local ws = ffi.new('struct mdp_winsize')
        local rc = ffi.C.ioctl(fd, 0x5413, ws) -- TIOCGWINSZ
        ffi.C.close(fd)
        if rc ~= 0 or ws.xpixel == 0 or ws.ypixel == 0 then return nil end
        return math.floor(100 * ws.ypixel * a4 / ws.xpixel + 0.5)
    end)
    if not ok or not bias then return fallback_bias end
    return math.max(20, math.min(70, bias))
end
local previews = {} -- buf -> { dir, timer, watch, title, group, style }

local function style_names()
    return vim.tbl_map(function(f) return vim.fn.fnamemodify(f, ':t:r') end,
        vim.fn.glob(styles .. '/*.yaml', false, true))
end

-- `style:` in the YAML front matter, if the note has one.
local function front_matter_style(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, 50, false)
    if lines[1] ~= '---' then return nil end
    for i = 2, #lines do
        if lines[i] == '---' or lines[i] == '...' then return nil end
        local name = lines[i]:match('^style:%s*["\']?([%w_-]+)')
        if name then return name end
    end
end

-- The style file to use, falling back to default (with a warning once per
-- unknown name) rather than breaking the preview.
local warned = {}
local function style_file(buf, override)
    local name = override or front_matter_style(buf) or 'default'
    local file = styles .. '/' .. name .. '.yaml'
    if vim.fn.filereadable(file) == 1 then return file end
    if not warned[name] then
        warned[name] = true
        vim.notify('MarkdownPreview: no style "' .. name .. '", using default', vim.log.levels.WARN)
    end
    return styles .. '/default.yaml'
end

local function notify(msg, level)
    vim.schedule(function() vim.notify('MarkdownPreview: ' .. msg, level or vim.log.levels.ERROR) end)
end

local function stop(buf)
    local p = previews[buf]
    if not p then return end
    previews[buf] = nil
    for _, t in ipairs({ p.timer, p.cursor_timer }) do
        t:stop()
        t:close()
    end
    if p.watch then p.watch:kill('sigterm') end
    vim.system({ 'kitten', '@', 'close-window', '--match', 'title:' .. p.title })
    pcall(vim.api.nvim_del_augroup_by_id, p.group)
    vim.fn.delete(p.dir, 'rf')
end

local function start(buf, override)
    local src = vim.api.nvim_buf_get_name(buf)
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local md, typ, pdf = dir .. '/note.md', dir .. '/note.typ', dir .. '/note.pdf'
    local map_typ = dir .. '/map.typ' -- the marked copy, for the table only
    local env = { MDPREVIEW_DIR = vim.fn.fnamemodify(src ~= '' and src or vim.fn.getcwd(), ':p:h') }

    -- Show the page of the block under the cursor: the last marker at or
    -- above the cursor line. Keys are sent only when the page changes.
    local function follow()
        local p = previews[buf]
        if not (p and p.map) or vim.api.nvim_get_current_buf() ~= buf then return end
        local row, page = vim.api.nvim_win_get_cursor(0)[1], nil
        for _, m in ipairs(p.map) do
            if m.line > row then break end
            page = m.page
        end
        if page and page ~= p.page then
            p.page = page
            vim.system({ 'kitten', '@', 'send-text', '--match', 'title:' .. p.title, 'g' .. page .. '\r' })
        end
    end

    -- The line -> page table, refreshed after each render. It compiles on its
    -- own, beside typst watch, so it never delays the page itself.
    local function refresh_map()
        vim.system({
            'typst', 'eval', 'query(<srcline>).map(it => it.value)', '--in', map_typ, '--root', '/',
        }, {}, function(res)
            if res.code ~= 0 then return end
            local ok, map = pcall(vim.json.decode, res.stdout)
            if not ok then return end
            table.sort(map, function(a, b) return a.line < b.line end)
            vim.schedule(function()
                if previews[buf] then
                    previews[buf].map = map
                    follow()
                end
            end)
        end)
    end

    -- Buffer -> temp .md -> .typ, which typst watch picks up; and, beside it,
    -- the marked copy for the line -> page table.
    local function render(wait)
        vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), md)
        local style = style_file(buf, previews[buf] and previews[buf].style or override)
        local base = { 'pandoc', md, '-s', '-t', 'typst', '--defaults=' .. style, '--lua-filter', filter }
        local job = vim.system(vim.list_extend({ unpack(base) }, { '-f', 'commonmark_x', '-o', typ }),
            { env = env }, function(res) if res.code ~= 0 then notify(res.stderr) end end)
        vim.system(vim.list_extend({ unpack(base) },
            { '-f', 'commonmark_x+sourcepos', '--lua-filter', sourcepos, '-o', map_typ }),
            { env = env }, function(res) if res.code == 0 then refresh_map() end end)
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
        cursor_timer = vim.uv.new_timer(),
        title = 'mdpreview-' .. buf,
        group = vim.api.nvim_create_augroup('mdpreview_' .. buf, { clear = true }),
        style = override,
        render = render,
    }
    previews[buf] = p
    refresh_map() -- the first render ran before the preview existed
    -- --root /: images may live anywhere, made absolute by the filter.
    p.watch = vim.system({ 'typst', 'watch', '--root', '/', typ, pdf })
    vim.system({
        'kitten', '@', 'launch', '--location=vsplit', '--keep-focus',
        '--bias', tostring(a4_bias()), '--title', p.title, 'tdf', '-f', pdf,
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
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = p.group,
        buffer = buf,
        callback = function()
            p.cursor_timer:stop()
            p.cursor_timer:start(follow_delay, 0, vim.schedule_wrap(follow))
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

local function markdown_preview(opts)
    local buf = vim.api.nvim_get_current_buf()
    local style = opts.args ~= '' and opts.args or nil
    local p = previews[buf]
    if p and style then
        p.style = style -- switch style, keep the split
        p.render(false)
    elseif p then
        stop(buf)
    elseif vim.bo[buf].filetype ~= 'markdown' then
        vim.notify('MarkdownPreview: not a markdown buffer', vim.log.levels.WARN)
    else
        start(buf, style)
    end
end

vim.api.nvim_create_user_command('MarkdownPreview', markdown_preview, {
    nargs = '?',
    complete = style_names,
    desc = 'toggle a live pandoc + typst + tdf preview in a kitty split',
})

-- One command for every previewable file: the type picks the previewer.
-- A Typst document chooses its look itself (#import), so the style argument
-- only means something for markdown.
vim.api.nvim_create_user_command('Preview', function(opts)
    local ft = vim.bo.filetype
    if ft == 'markdown' then
        markdown_preview(opts)
    elseif ft == 'typst' then
        if opts.args ~= '' then
            vim.notify('Preview: a Typst document sets its own style', vim.log.levels.WARN)
        end
        vim.cmd('TypstPreview')
    else
        vim.notify('Preview: nothing to preview for "' .. ft .. '"', vim.log.levels.WARN)
    end
end, { nargs = '?', complete = style_names, desc = 'preview this markdown or typst file' })
