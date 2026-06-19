-- Format: LSP if available, otherwise an external binary. Binaries read the
-- project's own config (.stylua.toml, mdformat); nothing configured in Neovim.
-- Cross-cutting policy, deliberately kept out of the lsp/ server files.
local M = {}

-- External formatters, for filetypes with no LSP formatter (lua_ls and
-- marksman do not format).
local binary = {
    lua = { 'stylua', '-' },       -- stdin -> stdout
    markdown = { 'mdformat', '-' },
}

-- Filetypes where we also run the LSP organize-imports before formatting.
local organize_imports = { python = true }

local function run_binary(buf, cmd)
    if vim.fn.executable(cmd[1]) ~= 1 then return end
    local input = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    local res = vim.system(cmd, { stdin = input }):wait()
    if res.code ~= 0 or not res.stdout then
        vim.notify(('format: %s failed'):format(cmd[1]), vim.log.levels.WARN)
        return
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split((res.stdout:gsub('\n$', '')), '\n'))
end

function M.format(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local ft = vim.bo[buf].filetype

    -- 1. organize imports (ruff code action: source.organizeImports)
    if organize_imports[ft] then
        vim.lsp.buf.code_action({
            context = { only = { 'source.organizeImports' }, diagnostics = {} },
            apply = true,
        })
    end

    -- 2. LSP formatter if any attached client provides one
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
        if c:supports_method('textDocument/formatting') then
            vim.lsp.buf.format({ bufnr = buf })
            return
        end
    end

    -- 3. fall back to an external binary
    if binary[ft] then run_binary(buf, binary[ft]) end
end

function M.setup()
    vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('UserFormat', {}),
        callback = function(ev) M.format(ev.buf) end,
    })
end

return M
