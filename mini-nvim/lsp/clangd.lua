-- Diagnostics, completion and formatting; reads compile_commands.json
-- and .clang-format from the project.
return {
    cmd = { 'clangd' },
    filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
    root_markers = {
        'compile_commands.json', 'compile_flags.txt', '.clang-format', '.git',
    },
}
