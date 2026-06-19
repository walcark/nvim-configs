return {
    cmd = { 'yaml-language-server', '--stdio' },
    filetypes = { 'yaml' },
    root_markers = { '.git' },
    settings = {
        redhat = { telemetry = { enabled = false } },
        yaml = {
            -- Explicit schemas only: no implicit schemastore.org catalog
            -- queries on every yaml file.
            schemaStore = { enable = false, url = '' },
            -- TODO(offline): vendor this schema under schemas/ in this
            -- repo and switch to a file:// URI for air-gapped machines.
            schemas = {
                ['https://json.schemastore.org/github-workflow.json'] =
                    '.github/workflows/*.{yml,yaml}',
            },
        },
    },
}
