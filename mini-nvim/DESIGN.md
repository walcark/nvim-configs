# Design — config Neovim minimale (mini.nvim)

## Objectifs

- Config la plus minimale possible, orientée DevOps.
- Un maximum de modules mini.nvim ; écrire soi-même les petits modules manquants.
- Support langage : Python, Go, Lua, Ansible, GitHub Actions, Docker, C++, Bash, Markdown.
- Intégration projet : les outils lisent la config du projet (`pyproject.toml`, `.clang-format`, `.stylua.toml`, `.ansible-lint`, `.editorconfig`...), pas Neovim.
- Fonctionnement hors-ligne : tout est vendorisé (submodules) ou fourni par des binaires système.

## Principes retenus

1. **Neovim 0.12 fait le gros du travail** : LSP natif (`lsp/*.lua` + `vim.lsp.enable()`),
   pas de nvim-lspconfig, conform.nvim ni nvim-lint.
2. **Pas de nvim-treesitter.** Coloration = syntaxe regex native (~600 langages)
   + semantic tokens LSP (gopls, clangd, basedpyright, lua_ls). Le parseur treesitter
   markdown est embarqué dans Neovim (requis par render-markdown.nvim).
   Si besoin futur (ex. YAML Ansible) : vendoriser le parseur seul.
3. **Navigation = LSP, pas treesitter** : `gd`, `grr`, `grn`, `K`, signature help
   (affichée automatiquement par mini.completion).
4. **Dépendances externes = 2 submodules** (mini.nvim, render-markdown.nvim)
   **+ binaires système**, avec dégradation propre si un binaire manque (`vim.fn.executable()`).

## Arborescence cible

```
init.lua                  -- options, leader
plugin/
  10_bootstrap.lua        -- helptags
  20_mini.lua             -- setup modules mini
  30_lsp.lua              -- vim.lsp.enable() + vim.diagnostic
  40_keymaps.lua          -- keymaps globaux
lsp/                      -- un fichier par serveur (format natif 0.11+)
lua/walcark/
  lint.lua                -- runner async → vim.diagnostic (hadolint, actionlint)
  format.lua              -- format : LSP si dispo, sinon binaire (stylua, mdformat)
  terminal.lua            -- terminal toggleable (+ preview glow)
after/ftplugin/           -- réglages par langage (indent, keywordprg, K → ansible-doc)
snippets/                 -- par langage
schemas/                  -- JSON schemas vendorisés (yamlls hors-ligne)
pack/plugins/start/       -- submodules : mini.nvim, render-markdown.nvim
```

## Modules mini.nvim

- **Actifs** : files, hues, snippets, pairs, icons, pick.
- **À ajouter** : completion (complétion + signature help), surround, ai, git, diff, misc
  (`setup_auto_root()` → cd racine projet), clue (découvrabilité keymaps), extra
  (pickers diagnostics/git), statusline, hipatterns (TODO/FIXME), notify, sessions,
  trailspace.
- Commentaire `gc` : natif depuis 0.10, pas de mini.comment.

## Support langage

| Langage | LSP | Format | Lint |
|---|---|---|---|
| Python | basedpyright + ruff | ruff (pyproject.toml) | ruff |
| Go | gopls | gopls | gopls |
| Lua | lua_ls | stylua (.stylua.toml) | lua_ls |
| C++ | clangd | clangd (.clang-format) | clangd |
| Bash | bashls | shfmt (.editorconfig) | shellcheck (via bashls) |
| Ansible | ansiblels | — | ansible-lint (via ansiblels) |
| GH Actions | yamlls (schéma vendorisé) | — | actionlint (via lint.lua) |
| Docker | dockerls | — | hadolint (via lint.lua) |
| Markdown | marksman (gd sur liens, rename headings) | mdformat | — |

Rendu Markdown : conceal natif (parseur embarqué) + render-markdown.nvim ;
preview complète avec `glow` dans un terminal flottant.

## Binaires à provisionner (bootstrap.sh à écrire)

`ruff`, `basedpyright`, `gopls`, `lua-language-server`, `stylua`, `clangd`,
`bash-language-server`, `shellcheck`, `shfmt`, `ansible-language-server`,
`ansible-lint`, `yaml-language-server`, `actionlint`, `docker-langserver`,
`hadolint`, `marksman`, `mdformat`, `glow`.

## Prochaines étapes

1. `30_lsp.lua` + fichiers `lsp/` (le cœur).
2. Modules mini supplémentaires dans `20_mini.lua`.
3. Modules persos `lint.lua` / `format.lua`.
4. Submodule render-markdown.nvim, schémas vendorisés, ftplugins, bootstrap.sh.
