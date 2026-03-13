# Research Workflow

> **Status: Experimental** -- These features are newly added and may change as
> the workflow is tested and refined on actual hardware.

Research-oriented tools for note-taking, paper management, and academic writing,
integrated into the Neovim + terminal workflow.

---

## Table of Contents

- [zk Notes](#zk-notes)
- [Git Enhancements](#git-enhancements)
- [Writing Quality](#writing-quality)
- [Launcher Workflows](#launcher-workflows)
- [Keybind Reference](#keybind-reference)

---

## zk Notes

A flat-file Zettelkasten for research notes, powered by
[zk](https://github.com/zk-org/zk). Notes are plain markdown with YAML
frontmatter, synced across machines via git.

### First-time setup

```bash
zk-init          # creates ~/notes with config, templates, and git repo
```

This creates:

```
~/notes/
├── .zk/config.toml       # zk configuration
├── .git/                  # git repo for cross-machine sync
├── templates/             # note templates (daily, paper, meeting, research)
├── journal/               # daily notes
├── papers/                # paper summaries
├── ideas/                 # research ideas
├── meetings/              # meeting notes
├── references/            # Zotero BibTeX auto-export target
├── index.md               # entry point (wiki-links, for Neovim navigation)
└── README.md              # GitHub-friendly index with clickable links
```

### Second machine

Just clone the repo. The config and templates are tracked by git:

```bash
git clone git@github.com:you/notes.git ~/notes
```

`zk-init` detects a cloned repo (has a remote **and** `.zk/config.toml`) and
exits without touching anything. If the repo is empty (freshly created on
GitHub), `zk-init` will populate it with the config, templates, and directory
structure.

### README index (`zk-index`)

The `README.md` in `~/notes` is auto-generated with standard markdown links so
notes are clickable on GitHub. Run after adding notes:

```bash
zk-index              # regenerate README.md
zk-index --dry-run    # preview without writing
```

The generated README groups notes by section (papers, journal, ideas, meetings)
and extracts titles from YAML frontmatter. It is designed to be regenerated, not
hand-edited.

Workflow:

```bash
zk new --title "My note"   # write some notes...
zk-index                   # rebuild the index
cd ~/notes && git add -A && git commit -m "sync" && git push
```

### Note types

| Command | Template | Filename pattern |
|---------|----------|-----------------|
| `zk journal` | daily.md | `YYYY-MM-DD` |
| `zk paper "title"` | paper-summary.md | `slug-title` |
| `zk meeting "title"` | meeting-notes.md | `YYYY-MM-DD-slug-title` |
| `zk idea "title"` | research-note.md | `slug-title` |
| `zk new --title "title"` | research-note.md | `slug-title` |

### Neovim integration (zk-nvim)

The zk LSP auto-attaches to any markdown file inside `~/notes/`. Provides
`[[wiki-link]]` completion, goto-definition, backlinks, and dead-link diagnostics.

| Keybind | Action |
|---------|--------|
| `<leader>zn` | New note (prompts for title) |
| `<leader>zj` | New journal entry (today) |
| `<leader>zp` | New paper summary |
| `<leader>zm` | New meeting notes |
| `<leader>zi` | New idea |
| `<leader>zf` | Find notes (sorted by modified) |
| `<leader>zt` | Browse tags |
| `<leader>zl` | List outgoing links |
| `<leader>zb` | List backlinks |
| `<leader>zs` | Search notes by content |
| `v` `<leader>zn` | Create note from selection (visual mode) |

### Zotero integration

Set up Better BibTeX auto-export to keep `~/notes/references/library.bib` in sync:

1. In Zotero: Edit > Settings > Better BibTeX > Automatic Export
2. Add export: collection = "My Library", format = "Better BibTeX",
   path = `~/notes/references/library.bib`
3. Set to auto-export on change

Paper summary notes reference the citekey in frontmatter, creating a bridge
between your notes and your reference manager.

### Cross-machine sync

```bash
cd ~/notes && git add -A && git commit -m "sync $(date +%Y-%m-%d)" && git push
```

### Publishing (future)

The notes are compatible with static site generators like
[Quartz](https://quartz.jzhao.xyz/) or Hugo. A pipeline like
`~/notes/ -> git push -> GitHub Actions -> Quartz -> GitHub Pages` would produce
a navigable wiki with backlinks and a graph view from the same markdown files.

---

## Git Enhancements

### git-delta

Syntax-highlighted diffs with line numbers. Configured as the default pager in
`.gitconfig`, so `git diff`, `git log -p`, `git show`, etc. all use it
automatically.

Terminal `git diff` uses side-by-side mode. Lazygit uses a separate config
(`dots/lazygit/config.yml`) with line-numbers-only mode for better rendering in
narrow panes. Clickable line-number hyperlinks in lazygit open the file at that
line in your editor.

### difftastic

Structural diffs that understand language syntax. Available via aliases:

| Alias | Command |
|-------|---------|
| `git dft` | Structural diff (working tree) |
| `git dftl` | Structural diff in log view |

---

## Writing Quality

### ltex-ls-plus (grammar/spell checking LSP)

Grammar and spell checking for LaTeX and Markdown in Neovim, powered by
LanguageTool. Shows diagnostics under grammar mistakes with quick-fix suggestions.

- Filetypes: `tex`, `latex`, `markdown`, `bib`
- Pre-loaded dictionary with quantum computing terms (Hamiltonian, qubit,
  eigenstates, etc.)
- Config: `dots/nvim/lua/plugins/writing.lua`

### vale (prose linter)

Configurable prose linter for enforcing writing style rules.

- Config: `dots/vale/.vale.ini` (symlinked to `~/.vale.ini`)
- First-time setup: `vale sync` (downloads style rules)
- Usage: `vale paper.tex` or integrate with nvim-lint

---

## Launcher Workflows

Fuzzel-based launcher scripts, triggered by niri keybinds. All scripts live in
`dots/bin/` and are symlinked to `~/bin/`.

### arxiv-search (`Mod+A`)

Search arXiv directly from a launcher. Pick a result to open in browser.

### doi2bib (`Mod+B`)

Convert a DOI or arXiv ID (from clipboard) to a BibTeX entry. Resolution order:

1. Zotero (via Better BibTeX JSON-RPC, if running)
2. arXiv API
3. Crossref API

Result is copied to clipboard with a notification.

### zotero-search (`Mod+P`)

Search your Zotero library by keyword. Pick a paper to open its PDF in zathura.
Falls back to Google Scholar if no local PDF is attached.

Requires Zotero running with Better BibTeX installed.

### quick-note (`Mod+G`)

Create a new zk note from a fuzzel menu:

1. Pick note type (journal / paper / idea / meeting / note)
2. Enter title (journal skips this step)
3. Opens in Neovim in a new Ghostty window

### today-schedule (`Mod+Alt+C`)

Shows today's khal calendar events in a fuzzel popup.

### translate-clip (`Mod+Alt+T`)

Translates clipboard text to English using translate-shell. Result replaces
the clipboard and shows a notification.

---

## Keybind Reference

### Niri (compositor)

| Keybind | Script | Description |
|---------|--------|-------------|
| `Mod+A` | `arxiv-search` | Search arXiv |
| `Mod+B` | `doi2bib` | DOI/arXiv to BibTeX |
| `Mod+P` | `zotero-search` | Search Zotero library |
| `Mod+G` | `quick-note` | Create research note |
| `Mod+Alt+T` | `translate-clip` | Translate clipboard |
| `Mod+Alt+C` | `today-schedule` | Today's schedule |

### Neovim (`<leader>z` prefix)

See the [zk-nvim keybinds](#neovim-integration-zk-nvim) table above.

---

## Files

| File | Purpose |
|------|---------|
| `dots/nvim/lua/plugins/zk.lua` | zk-nvim plugin config and keybinds |
| `dots/nvim/lua/plugins/writing.lua` | ltex-ls-plus LSP config |
| `dots/lazygit/config.yml` | Lazygit delta pager config |
| `dots/vale/.vale.ini` | Vale prose linter config |
| `dots/bin/arxiv-search` | arXiv launcher script |
| `dots/bin/doi2bib` | DOI/arXiv to BibTeX script |
| `dots/bin/zotero-search` | Zotero search script |
| `dots/bin/quick-note` | Quick note launcher script |
| `dots/bin/today-schedule` | Calendar popup script |
| `dots/bin/translate-clip` | Translation script |
| `dots/bin/zk-init` | One-time notebook initializer |
| `dots/bin/zk-index` | Regenerate README.md with clickable note links |

## Packages added

### Official repos (`infra/pkgs.pacman.txt`)

- `difftastic` -- structural diffs
- `git-delta` -- syntax-highlighted git pager
- `python-todoman` -- terminal todo list (CalDAV)
- `translate-shell` -- CLI translation
- `vdirsyncer` -- CalDAV/CardDAV sync
- `zk` -- already present

### AUR (`infra/pkgs.aur.txt`)

- `ltex-ls-plus-bin` -- grammar/spell LSP
- `vale-bin` -- prose linter
