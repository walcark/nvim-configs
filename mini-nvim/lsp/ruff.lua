-- Lint + format. Reads pyproject.toml / ruff.toml from the project root,
-- so per-project rules apply with zero editor configuration.
return {
    cmd = { 'ruff', 'server' },
    filetypes = { 'python' },
    root_markers = { 
        'pyproject.toml', 
        'ruff.toml', 
        '.ruff.toml', 
        '.git' 
    },

    -- basedpyright owns hover: avoid double documentation windows
    on_attach = function(client)
        client.server_capabilities.hoverProvider = false
    end,

    -- See: https://docs.astral.sh/ruff/editors/settings/ for config options
    settings = {
        configurationPreference = "filesystemFirst",
        lineLength = 79,
        organizeImports = true,
        showSyntaxErrors = true
    },
}
