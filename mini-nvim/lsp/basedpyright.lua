-- Types, completion, navigation. Lint/format/imports are ruff's job.
-- See: https://docs.basedpyright.com/v1.21.0/configuration/language-server-settings/
-- See: https://docs.basedpyright.com/v1.21.0/configuration/config-files/

return {
    cmd = { 'basedpyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = {
        'pyproject.toml',
        'pyrightconfig.json',
        'setup.py',
        'requirements.txt',
        '.git',
    },

    -- Point basedpyright at the pixi env interpreter so imports resolve in neovim
    before_init = function(_, config)
        local env = vim.env.CONDA_PREFIX or vim.env.VIRTUAL_ENV
        local py
        if env then
            py = env .. '/bin/python' -- launched from pixi shell
        elseif config.root_dir then
            py = config.root_dir .. '/.pixi/envs/default/bin/python'
        end
        if py and vim.uv.fs_stat(py) then
            config.settings.python = config.settings.python or {}
            config.settings.python.pythonPath = py
        end
    end,

    settings = {
        basedpyright = {
            disableOrganizeImports = true, -- ruff owns import sorting
            reportAny = false,
            reportExplicitAny = false,
            reportUnknownVariableType = false,
            enableTypeIgnoreComments = false,   -- force usage of `# pyright: ignore[]` over `type: ignore[]`
            reportUnreachable = 'warning',
            analysis = {
                typeCheckingMode = 'standard',
            },
        },
    },
}
