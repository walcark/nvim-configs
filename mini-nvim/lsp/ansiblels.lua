-- Attaches to yaml.ansible buffers only (see filetype rules in
-- plugin/30_lsp.lua). Drives ansible-lint, which reads the project's
-- .ansible-lint configuration.
return {
    cmd = { 'ansible-language-server', '--stdio' },
    filetypes = { 'yaml.ansible' },
    root_markers = { 'ansible.cfg', '.ansible-lint', '.git' },
    settings = {
        ansible = {
            executionEnvironment = { enabled = false },
            validation = {
                enabled = true,
                lint = { enabled = true, path = 'ansible-lint' },
            },
        },
    },
}
