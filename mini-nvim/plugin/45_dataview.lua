-- Data files (netCDF, HDF, GeoTIFF, GRIB, GeoPackage...) open as a summary,
-- with the first variable drawn by matplotlib in a kitty split beside it.
--
-- One Python process per nvim (python/dataview.py, env pixi `xarray`) keeps the
-- files open, so moving along a dimension costs a render (~0.3 s), not a
-- reopen. It writes a PNG of the split's size, in the terminal's colours; the
-- split (bin/dataview-viewer) shows it with `kitten icat`, told by
-- `send-text` like the tdf of the markdown preview.
--
-- The first lines of the buffer show what is drawn and the keys:
--   <CR>       draw the variable under the cursor
--   l h        next / previous slice along the active dimension (] [ too,
--              a count works: 5l)
--   <Tab>      next dimension to move along (<S-Tab>: previous)
--   r          robust colour range (2-98 %) on or off
--   c          next colour map
--   R          draw again (after resizing the split)
--   o          interactive matplotlib window: zoom, pan, a slider per dimension
--   q          close

local config = vim.fn.stdpath('config')
local script = config .. '/python/dataview.py'
local viewer = config .. '/bin/dataview-viewer'
-- The env of the dotfiles extra `data`: xarray and its readers.
local python = (vim.env.PIXI_HOME or (vim.env.HOME .. '/.pixi')) .. '/envs/xarray/bin/python'
local patterns = {
    '*.nc', '*.nc4', '*.cdf', '*.h5', '*.he5', '*.hdf5', '*.hdf', '*.hdf4',
    '*.tif', '*.tiff', '*.jp2', '*.vrt',
    '*.grib', '*.grib2', '*.grb', '*.grb2',
    '*.gpkg', '*.shp', '*.fgb', '*.geojson',
}
local cmaps = { 'viridis', 'RdBu_r', 'magma', 'cividis', 'terrain', 'gray' }
local keys_line = '  l h slice   <Tab> dimension   <CR> variable   c colours   r robust   '
    .. 'o window   R redraw   q close'
local header_size = 3 -- state, keys, rule
local title = 'dataview-' .. vim.fn.getpid()
local tmp = vim.fn.tempname()
local ns = vim.api.nvim_create_namespace('dataview')

local server       -- the vim.system handle of dataview.py
local pending = {} -- request id -> callback
local next_id = 0
local partial = '' -- stdout not yet ended by a newline
local view_open = false
local colors = {}  -- bg, fg of kitty, asked once
local states = {}  -- buf -> { path, body, at, var, index, free, dim, robust, cmap, busy, again }
local shown = 0    -- PNG counter

local function notify(msg, level)
    vim.schedule(function() vim.notify('dataview: ' .. msg, level or vim.log.levels.ERROR) end)
end

local function request(req, callback)
    if not server then
        vim.fn.mkdir(tmp, 'p')
        server = vim.system({ python, '-I', script, 'serve' }, {
            stdin = true,
            stdout = function(_, data)
                if not data then return end
                partial = partial .. data
                while true do
                    local line, rest = partial:match('^(.-)\n(.*)$')
                    if not line then break end
                    partial = rest
                    local ok, res = pcall(vim.json.decode, line)
                    local cb = ok and pending[res.id]
                    if cb then
                        pending[res.id] = nil
                        vim.schedule(function() cb(res) end)
                    end
                end
            end,
        }, function(res)
            server = nil
            if res.code ~= 0 and res.signal == 0 then notify('the Python side stopped (' .. res.code .. ')') end
        end)
    end
    next_id = next_id + 1
    req.id = next_id
    pending[next_id] = callback
    server:write(vim.json.encode(req) .. '\n')
end

-- The split's size in pixels, as the viewer wrote it, a little smaller for
-- kitty's padding.
local function view_size()
    local f = io.open(tmp .. '/size', 'r')
    if not f then return 900, 700 end
    local w, h = f:read('*a'):match('(%d+)x(%d+)')
    f:close()
    if not w then return 900, 700 end
    return tonumber(w) - 8, tonumber(h) - 8
end

-- The theme's colours, so that the figure looks like part of the terminal.
local function ask_colors()
    local res = vim.system({ 'kitten', '@', 'get-colors' }):wait()
    for _, line in ipairs(vim.split(res.stdout or '', '\n')) do
        local key, value = line:match('^(%w+)%s+(#%x+)')
        if key == 'background' or key == 'foreground' then colors[key] = value end
    end
end

local function open_view(then_)
    if not colors.background then ask_colors() end
    vim.system({
        'kitten', '@', 'launch', '--location=vsplit', '--keep-focus', '--bias', '55',
        '--title', title, viewer, tmp .. '/size',
    }, {}, function(res)
        if res.code ~= 0 then
            notify('no kitty split (' .. vim.trim(res.stderr) .. '): run nvim in kitty')
            return
        end
        view_open = true
        -- Wait for the viewer to write its size, at most a second.
        local tries = 0
        local timer = vim.uv.new_timer()
        timer:start(50, 50, vim.schedule_wrap(function()
            tries = tries + 1
            if vim.uv.fs_stat(tmp .. '/size') or tries > 20 then
                timer:stop()
                timer:close()
                then_()
            end
        end))
    end)
end

local function close_view()
    if view_open then
        vim.system({ 'kitten', '@', 'close-window', '--match', 'title:' .. title })
        view_open = false
    end
end

local function show(png)
    vim.system({ 'kitten', '@', 'send-text', '--match', 'title:' .. title, png .. '\r' }, {}, function(res)
        if res.code ~= 0 then view_open = false end -- closed by hand: reopened next time
    end)
end

-- What is drawn, as the first line: the variable, each dimension with its
-- position, the active one in brackets.
local function state_line(st)
    if not st.var then return '' end
    local parts = { '▶ ' .. st.var }
    for k, d in ipairs(st.free or {}) do
        if d.size > 1 then
            local pos = ('%s %d/%d'):format(d.name, (st.index[d.name] or 0) + 1, d.size)
            table.insert(parts, k == st.dim and ('[' .. pos .. ']') or pos)
        end
    end
    table.insert(parts, cmaps[st.cmap] .. (st.robust and ', robust' or ''))
    return table.concat(parts, '   ')
end

-- Header and summary, the drawn variable highlighted.
local function render(buf)
    local st = states[buf]
    if not (st and vim.api.nvim_buf_is_valid(buf)) then return end
    local lines = { state_line(st), keys_line, string.rep('─', 78) }
    vim.list_extend(lines, st.body)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { line_hl_group = 'Title' })
    vim.api.nvim_buf_set_extmark(buf, ns, 1, 0, { line_hl_group = 'Comment' })
    vim.api.nvim_buf_set_extmark(buf, ns, 2, 0, { line_hl_group = 'NonText' })
    for row, name in pairs(st.at or {}) do
        if name == st.var then
            vim.api.nvim_buf_set_extmark(buf, ns, tonumber(row) + header_size, 0, { line_hl_group = 'Visual' })
        end
    end
end

-- Draw the current state. A request already running absorbs the next ones:
-- holding l draws the last slice asked for, not every one in between.
local function draw(buf)
    local st = states[buf]
    if not st or not st.var then return end
    if st.busy then
        st.again = true
        return
    end
    local function go()
        st.busy = true
        local w, h = view_size()
        shown = shown + 1
        local out = ('%s/plot-%d.png'):format(tmp, shown)
        request({
            cmd = 'plot', path = st.path, var = st.var, index = st.index,
            robust = st.robust, cmap = cmaps[st.cmap], out = out, width = w, height = h,
            bg = colors.background, fg = colors.foreground,
        }, function(res)
            st.busy = false
            if res.error then
                notify(res.error)
            else
                st.free = res.free
                st.dim = math.min(st.dim, math.max(#st.free, 1))
                show(res.png)
                local old = ('%s/plot-%d.png'):format(tmp, shown - 2)
                vim.defer_fn(function() vim.fn.delete(old) end, 1000)
                render(buf)
            end
            if st.again then
                st.again = false
                draw(buf)
            end
        end)
    end
    if view_open then go() else open_view(vim.schedule_wrap(go)) end
end

local function step(buf, delta)
    local st = states[buf]
    local d = st and st.free and st.free[st.dim]
    if not d then return end
    st.index[d.name] = math.max(0, math.min(d.size - 1, (st.index[d.name] or 0) + delta))
    render(buf) -- the position shows at once, the image follows
    draw(buf)
end

-- The next dimension worth moving along (size > 1).
local function cycle(buf, delta)
    local st = states[buf]
    local n = st and st.free and #st.free or 0
    for _ = 1, n do
        st.dim = (st.dim - 1 + delta) % n + 1
        if st.free[st.dim].size > 1 then break end
    end
    render(buf)
end

local function keymaps(buf)
    local function map(lhs, fn, desc)
        vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, desc = 'dataview: ' .. desc })
    end
    local st = states[buf]
    -- mini.clue puts its own ] and [ in every buffer: not in this one.
    vim.b[buf].miniclue_disable = true
    if _G.MiniClue then pcall(MiniClue.disable_buf_triggers, buf) end
    map('<CR>', function()
        local name = st.at[tostring(vim.api.nvim_win_get_cursor(0)[1] - 1 - header_size)]
        if name then
            st.var = name
            st.dim = 1
            draw(buf)
        end
    end, 'draw the variable under the cursor')
    for _, k in ipairs({ { 'l', 'h' }, { ']', '[' } }) do
        map(k[1], function() step(buf, vim.v.count1) end, 'next slice')
        map(k[2], function() step(buf, -vim.v.count1) end, 'previous slice')
    end
    map('<Tab>', function() cycle(buf, 1) end, 'next dimension')
    map('<S-Tab>', function() cycle(buf, -1) end, 'previous dimension')
    map('r', function() st.robust = not st.robust; render(buf); draw(buf) end, 'robust range')
    map('c', function() st.cmap = st.cmap % #cmaps + 1; render(buf); draw(buf) end, 'next colour map')
    map('R', function() draw(buf) end, 'redraw')
    map('o', function()
        vim.system({ python, '-I', script, 'window', st.path, st.var, vim.json.encode(st.index), cmaps[st.cmap] },
            { detach = true })
    end, 'interactive window')
    map('q', function() vim.cmd('bwipeout') end, 'close')
end

local group = vim.api.nvim_create_augroup('dataview', { clear = true })

vim.api.nvim_create_autocmd('BufReadCmd', {
    group = group,
    pattern = patterns,
    callback = function(args)
        local buf = args.buf
        local path = vim.fn.fnamemodify(args.file, ':p')
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].swapfile = false
        vim.bo[buf].filetype = 'dataview'
        states[buf] = {
            path = path, body = {}, at = {}, index = {}, free = {}, dim = 1, robust = true, cmap = 1,
        }
        if vim.fn.executable(python) == 0 then
            states[buf].body = {
                'No Python with xarray: enable the dotfiles extra `data`:',
                '  dot extra add data',
            }
            render(buf)
            return
        end
        states[buf].body = { 'reading ' .. path .. ' ...' }
        render(buf)
        keymaps(buf)
        request({ cmd = 'open', path = path }, function(res)
            local st = states[buf]
            if not (st and vim.api.nvim_buf_is_valid(buf)) then return end
            if res.error then
                st.body = vim.split(res.error .. '\n\n' .. (res.trace or ''), '\n')
                render(buf)
                return
            end
            st.body = res.lines
            st.at = res.at
            st.var = res.variables[1] and res.variables[1].name
            render(buf)
            if vim.api.nvim_get_current_buf() == buf then
                vim.api.nvim_win_set_cursor(0, { math.min(header_size + 1, vim.api.nvim_buf_line_count(buf)), 0 })
                draw(buf)
            end
        end)
    end,
})

-- Back to a data buffer: show its own variable again.
vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = patterns,
    callback = function(args)
        local st = states[args.buf]
        if st and st.var then draw(args.buf) end
    end,
})

vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    pattern = patterns,
    callback = function(args)
        local st = states[args.buf]
        if not st then return end
        states[args.buf] = nil
        if server then request({ cmd = 'close', path = st.path }, function() end) end
        if next(states) == nil then close_view() end
    end,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
        close_view()
        if server then server:kill('sigterm') end
        vim.fn.delete(tmp, 'rf')
    end,
})
