-- Markdown: gd on links, completion of cross-file references,
-- heading rename propagation.
return {
    cmd = { 'marksman', 'server' },
    filetypes = { 'markdown' },
    root_markers = { '.marksman.toml', '.git' },
}
