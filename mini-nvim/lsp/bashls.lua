-- Drives shellcheck (lint) and shfmt (format) when present on PATH.
return {
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'bash', 'sh' },
    root_markers = { '.git' },
}
