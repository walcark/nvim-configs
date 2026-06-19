-- Format : LSP si dispo, sinon binaire. Les binaires lisent la config du
-- projet (.stylua.toml, mdformat) ; aucun reglage cote Neovim.
-- Politique transversale, volontairement separee des fiches serveur lsp/.
local M = {}

-- Formateurs externes, pour les filetypes sans formatter LSP (lua_ls et
-- marksman ne formatent pas).
local binary = {
    lua = { 'stylua', '-' },       -- stdin -> stdout
    markdown = { 'mdformat', '-' },
}

-- Filetypes ou on lance aussi l'organize-imports LSP avant le format.
local organize_imports = { python = true }

local function run_binary(buf, cmd)
    if vim.fn.executable(cmd[1]) ~= 1 then return end
    local input = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    local res = vim.system(cmd, { stdin = input }):wait()
    if res.code ~= 0 or not res.stdout then
        vim.notify(('format: %s a echoue'):format(cmd[1]), vim.log.levels.WARN)
        return
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split((res.stdout:gsub('\n$', '')), '\n'))
end

function M.format(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local ft = vim.bo[buf].filetype

    -- 1. organize imports (code action ruff : source.organizeImports)
    if organize_imports[ft] then
        vim.lsp.buf.code_action({
            context = { only = { 'source.organizeImports' }, diagnostics = {} },
            apply = true,
        })
    end

    -- 2. formatter LSP si un client en fournit un
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
        if c:supports_method('textDocument/formatting') then
            vim.lsp.buf.format({ bufnr = buf })
            return
        end
    end

    -- 3. repli binaire
    if binary[ft] then run_binary(buf, binary[ft]) end
end

function M.setup()
    vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('UserFormat', {}),
        callback = function(ev) M.format(ev.buf) end,
    })
end

return M
