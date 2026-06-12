# Keymaps — modules mini.nvim & LSP

Mappings par défaut (vérifiés dans la doc de mini.nvim v0.17) + nos mappings persos.
`<leader>` = Espace.

## Nos mappings (plugin/20_mini.lua)

| Touche | Action |
|---|---|
| `<leader>e` | Explorateur de fichiers (mini.files) |
| `<leader>ff` | Chercher un fichier (mini.pick) |
| `<leader>fg` | Grep live dans le projet |
| `<leader>fb` | Buffers ouverts |
| `<leader>fh` | Chercher dans l'aide (doc mini incluse, hors-ligne) |

## LSP (natifs Neovim ≥ 0.11, actifs dès qu'un serveur tourne)

| Touche | Action |
|---|---|
| `gd` | Aller à la définition (cross-fichiers) |
| `grr` | Lister les références |
| `grn` | Renommer le symbole |
| `gra` | Code actions |
| `gri` | Aller à l'implémentation |
| `K` | Doc du symbole sous le curseur (hover) |
| `<C-s>` (insert) | Signature de la fonction (auto avec mini.completion) |
| `[d` / `]d` | Diagnostic précédent / suivant |

## mini.files — l'explorateur s'édite comme un buffer

Créer/renommer/supprimer = éditer le texte, puis `=` pour appliquer.

| Touche | Action |
|---|---|
| `l` / `L` | Entrer (dossier/fichier) / + fermer l'explorateur |
| `h` / `H` | Remonter / + plier |
| `=` | **Synchroniser** (applique créations, renommages, suppressions) |
| `<BS>` | Réinitialiser la vue |
| `@` | Révéler le cwd |
| `g?` | Aide |
| `q` | Fermer |

## mini.pick — dans le picker

| Touche | Action |
|---|---|
| `<C-n>` / `<C-p>` | Item suivant / précédent |
| `<CR>` | Choisir |
| `<C-s>` / `<C-v>` / `<C-t>` | Ouvrir en split / vsplit / onglet |
| `<Tab>` | Toggle preview |
| `<S-Tab>` | Toggle infos |
| `<C-x>` / `<C-a>` | Marquer item / tout marquer |
| `<M-CR>` | Ouvrir les items marqués (→ quickfix) |
| `<C-Space>` | Raffiner : re-filtrer les résultats courants |
| `<Esc>` | Fermer |

## mini.completion (insert)

Le menu s'ouvre automatiquement ; touches natives de complétion Vim.

| Touche | Action |
|---|---|
| `<C-n>` / `<C-p>` | Naviguer dans le menu |
| `<C-y>` | Accepter |
| `<C-e>` | Annuler le menu |
| `<C-f>` / `<C-b>` | Scroller la doc / signature affichée |

## mini.snippets (insert)

| Touche | Action |
|---|---|
| `<C-j>` | Déplier le snippet au curseur |
| `<C-l>` / `<C-h>` | Tabstop suivant / précédent (pendant la session) |
| `<C-c>` | Arrêter la session |

## mini.diff — hunks Git dans le buffer

| Touche | Action |
|---|---|
| `gh{motion}` / visuel + `gh` | Stage le hunk (apply) |
| `gH{motion}` / visuel + `gH` | Reset le hunk |
| `ghgh` | Stage le hunk courant (opérateur + textobject) |
| `[h` / `]h` | Hunk précédent / suivant (`[H`/`]H` premier/dernier) |
| — | `:lua MiniDiff.toggle_overlay()` : voir le diff inline |

## mini.git

Pas de mapping par défaut : la commande `:Git` (blame, log, diff, commit...).
Mapping conseillé : `<leader>gs` → `MiniGit.show_at_cursor()` (contextuel :
historique de la ligne, détail d'un commit dans un log...).

## mini.surround — quotes, brackets, tags

`{c}` = caractère cible : `)`, `]`, `"`, `'`, `` ` ``, `t` (tag), `f` (appel de fonction)...

| Touche | Action | Exemple |
|---|---|---|
| `sa{motion}{c}` | Ajouter | `saiw"` → mot entre `"` |
| `sd{c}` | Supprimer | `sd"` → enlève les `"` |
| `sr{c}{c}` | Remplacer | `sr"'` → `"` devient `'` |
| `sf` / `sF` | Trouver à droite / gauche | |

## mini.ai — text-objects étendus

S'utilisent après un opérateur (`d`, `c`, `y`, `v`) : `a` = autour, `i` = intérieur.

| Objet | Cible | Exemple |
|---|---|---|
| `a)` `i)` `a"` ... | Brackets/quotes, multi-lignes | `ci"` |
| `af` / `if` | Appel de fonction | `daf` supprime `f(x, y)` |
| `aa` / `ia` | Argument | `cia` change un argument |
| `an` / `al` + objet | Occurrence suivante / précédente | `cin)` : prochain `(...)` |
| `g[` / `g]` + objet | Aller au bord de l'objet | |

## mini.clue

Pas de mapping : après `<leader>`, `g`, `s`, `[`, `'`, `"`, `<C-w>`...,
une fenêtre liste automatiquement les suites possibles. C'est la doc vivante
de tous les mappings ci-dessus.
