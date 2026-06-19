-- LSP wiring. Servers are defined one file each under lsp/ (native
-- Neovim 0.11+ format: the table is merged into vim.lsp.config[<name>]).
-- Only servers whose binary is on PATH get enabled: a missing tool means
-- no LSP for that language, everything else keeps working (regex
-- highlighting, mini.nvim modules).

-- Ansible buffers are plain 'yaml' to Neovim: refine the filetype so
-- ansible-language-server (filetypes = yaml.ansible) attaches instead
-- of yamlls (filetype matching is exact, the two never overlap).
vim.filetype.add({
    pattern = {
        ['.*/playbooks/.*%.ya?ml'] = 'yaml.ansible',
        ['.*/roles/.*/tasks/.*%.ya?ml'] = 'yaml.ansible',
        ['.*/roles/.*/handlers/.*%.ya?ml'] = 'yaml.ansible',
        ['.*/roles/.*/defaults/.*%.ya?ml'] = 'yaml.ansible',
        ['.*/roles/.*/meta/.*%.ya?ml'] = 'yaml.ansible',
        ['.*/group_vars/.*%.ya?ml'] = 'yaml.ansible',
        ['.*/host_vars/.*%.ya?ml'] = 'yaml.ansible',
        ['.*playbook%.ya?ml'] = 'yaml.ansible',
    },
})

local servers = {
    'lua_ls', 'ruff', 'basedpyright', 'gopls', 'clangd',
    'bashls', 'yamlls', 'ansiblels', 'dockerls', 'marksman',
}

for _, name in ipairs(servers) do
    local cfg = vim.lsp.config[name]
    local exe = cfg and type(cfg.cmd) == 'table' and cfg.cmd[1] or nil
    if exe ~= nil and vim.fn.executable(exe) == 1 then
        vim.lsp.enable(name)
    end
end

vim.diagnostic.config({
    severity_sort = true,
    virtual_text = true,
    float = { border = 'rounded', source = true },
})

-- Buffer-local keymaps on attach. grn (rename), grr (references),
-- gri (implementation), gra (code action), K (hover) and <C-s>
-- (signature, insert mode) are Neovim defaults already.
vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('UserLsp', {}),
    callback = function(ev)
        local map = function(lhs, rhs, desc)
            vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, desc = desc })
        end
        map('gd', vim.lsp.buf.definition, 'Go to definition')
        map('<Leader>lf', function() require('walcark.format').format() end, 'Format buffer')
    end,
})
