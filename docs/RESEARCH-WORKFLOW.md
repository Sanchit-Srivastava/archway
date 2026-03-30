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
├── .zk/
│   ├── config.toml        # zk configuration
│   └── templates/         # note templates (daily, paper, meeting, research)
├── .git/                  # git repo for cross-machine sync
├── entries/               # all notes (flat, categorized by frontmatter category)
├── references/            # Zotero BibTeX auto-export target
├── topics/                # auto-generated per-topic pages (by zk-index)
├── index.md               # entry point (Neovim navigation, with frontmatter)
└── README.md              # auto-generated index (recent notes + category sections)
```

### Second machine

Just clone the repo. The config and templates are tracked by git:

```bash
git clone git@github.com:you/notes.git ~/notes
```

`zk-init` detects a cloned repo (has a remote **and** a fully configured
`.zk/config.toml` with alias definitions) and exits without touching anything.
If the repo is empty (freshly created on GitHub), `zk-init` will populate it
with the config, templates, and directory structure.

### README index (`zk-index`)

The `README.md` in `~/notes` is auto-generated with standard markdown links so
notes are clickable on GitHub. Run after adding notes:

```bash
zk-index              # regenerate README.md
zk-index --dry-run    # preview without writing
```

The generated README groups notes by frontmatter `category` field (papers,
journal, ideas, meetings) and shows a topic directory built from `tags`. It is
designed to be regenerated, not hand-edited.

Workflow:

```bash
zk new --title "My note"   # write some notes...
zk-index                   # rebuild the index
cd ~/notes && git add -A && git commit -m "sync" && git push
```

### Note types

All notes live in `entries/` (flat directory). Note type is determined by the
template, which sets the `category` field in YAML frontmatter. Tags are used
separately for content/topic classification.

| Command | Template | Filename pattern |
|---------|----------|-----------------|
| `zk journal` | daily.md | `YYYY-MM-DD` |
| `zk paper "title"` | paper-summary.md | `slug-title` |
| `zk meeting "title"` | meeting-notes.md | `YYYY-MM-DD-slug-title` |
| `zk idea "title"` | research-note.md | `slug-title` |
| `zk new --dir entries --title "title"` | research-note.md | `slug-title` |

### Neovim integration (zk-nvim)

The zk LSP auto-attaches to any markdown file inside `~/notes/`. Provides
link completion, goto-definition, backlinks, and dead-link diagnostics.

| Keybind | Action |
|---------|--------|
| `<leader>zn` | New note (prompts for title) |
| `<leader>zj` | New journal entry (today) |
| `<leader>zp` | New paper summary |
| `<leader>zm` | New meeting notes |
| `<leader>zI` | New idea |
| `<leader>zf` | Find notes (sorted by modified) |
| `<leader>zt` | Browse tags |
| `<leader>zl` | List outgoing links |
| `<leader>zB` | List backlinks |
| `<leader>zs` | Search notes by content |
| `v` `<leader>zn` | Create note from selection (visual mode) |

### Zotero integration (zotcite)

Zotcite reads Zotero's SQLite database directly -- no `.bib` export step
required. Changes made in Zotero are immediately available in Neovim. Better
BibTeX citation keys are used for compatibility with collaborative workflows.

Zotero must be installed and its database accessible at the default path
(`~/.zotero/zotero/*/zotero.sqlite`). The `sqlite3` CLI tool is required.

#### Required Zotero plugins

The repo cannot automate Zotero plugin installation -- these must be installed
manually inside Zotero via **Tools > Add-ons > gear icon > Install Add-on From
File** (select the downloaded `.xpi`, then restart Zotero). Run `just check
zotero` and `just check zotero-mcp` to verify installation.

**1. Better BibTeX for Zotero** --
<https://retorque.re/zotero-better-bibtex/installation/>

Download the latest `.xpi` from the link above. Better BibTeX provides the
JSON-RPC endpoint (`localhost:23119`) used by `zotero-search`, `doi2bib`, and
the zotcite Neovim plugin. Without it these tools will not function.

**2. Zotero MCP Plugin** --
<https://github.com/cookjohn/zotero-mcp/releases>

Download the latest `zotero-mcp-plugin-*.xpi` from the releases page. This
plugin embeds an MCP server inside Zotero (`localhost:23120/mcp`) that gives
OpenCode direct access to search, read, and annotate your library. After
installation, enable the server in Zotero: **Preferences > Zotero MCP Plugin >
Enable Server** (default port 23120).

**Completion** -- type `@` in a markdown file to get citekey suggestions via
zotcite's built-in LSP. In LaTeX files, `\cite{` triggers completion. Use
`<C-X><C-B>` in insert mode for a telescope picker.

**Reference inspection** -- place cursor on a citekey in normal mode:

| Mode | Keybind | Action |
|------|---------|--------|
| normal | `<leader>zi` | Reference info (author, year, title) |
| normal | `<leader>za` | All reference fields |
| normal | `<leader>zb` | Insert abstract into buffer |
| normal | `<leader>zo` | Open PDF attachment |
| normal | `<leader>zv` | View compiled document (PDF/HTML) |

**Annotation extraction** -- pull highlights and notes from Zotero:

| Command | Action |
|---------|--------|
| `:Zseek [pattern]` | Fuzzy-search references (telescope) |
| `:Zannotations [key]` | Extract all Zotero annotations for a reference |
| `:Zselectannotations [key]` | Selectively import annotations (telescope) |
| `:Znote [key]` | Extract Zotero notes for a reference |
| `:Zpdfnote [key]` | Extract annotations from external PDF viewer |

**Auto bib management** -- zotcite automatically writes the bib file listed in
the document's YAML `bibliography:` field on save. This replaces the need for
Better BibTeX auto-export for per-document bibliographies.

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

Notes launcher with search and creation, opening in a persistent tmux session:

1. Pick action: **Search notes** or **Add note**
2. **Search notes** — live content search (ripgrep + fzf) across all notes in
   `entries/`. Type to filter by content; select a match to open it in Neovim
   at the matching line.
3. **Add note** — pick note type (journal / paper / idea / meeting / note),
   enter a title (journal skips this step), and the note is created in
   `entries/` with the appropriate template, opening in Neovim.

Both paths use a persistent tmux session called `notes` (working directory
`~/notes`). If a Ghostty window is already attached to the session, it is
reused; otherwise a new terminal is opened.

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
| `Mod+G` | `quick-note` | Search or create research note |
| `Mod+Alt+T` | `translate-clip` | Translate clipboard |
| `Mod+Alt+C` | `today-schedule` | Today's schedule |

### Neovim (`<leader>z` prefix)

**zk-nvim** (note management -- global, all buffers):

| Keybind | Action |
|---------|--------|
| `<leader>zn` | New note (prompts for title) |
| `<leader>zj` | New journal entry (today) |
| `<leader>zp` | New paper summary |
| `<leader>zm` | New meeting notes |
| `<leader>zI` | New idea |
| `<leader>zf` | Find notes (sorted by modified) |
| `<leader>zt` | Browse tags |
| `<leader>zl` | List outgoing links |
| `<leader>zB` | List backlinks |
| `<leader>zs` | Search notes by content |
| `v` `<leader>zn` | Create note from selection |

**zotcite** (Zotero references -- buffer-local in markdown/tex/quarto):

| Keybind | Mode | Action |
|---------|------|--------|
| `@` | insert | Citekey completion (LSP, markdown) |
| `\cite{` | insert | Citekey completion (LSP, LaTeX) |
| `<C-X><C-B>` | insert | Citation picker (telescope) |
| `<leader>zi` | normal | Reference info (author, year, title) |
| `<leader>za` | normal | All reference fields |
| `<leader>zb` | normal | Insert abstract into buffer |
| `<leader>zo` | normal | Open PDF attachment |
| `<leader>zv` | normal | View compiled document (PDF/HTML) |

**zotcite commands:**

| Command | Action |
|---------|--------|
| `:Zseek [pattern]` | Fuzzy-search references (telescope) |
| `:Zannotations [key]` | Extract Zotero annotations for a reference |
| `:Zselectannotations [key]` | Selectively import annotations (telescope) |
| `:Znote [key]` | Extract Zotero notes for a reference |
| `:Zpdfnote [key]` | Extract external PDF annotations |
| `:Zodt2md file.odt` | Convert ODT with Zotero citations to markdown |
| `:Zinfo` | Show zotcite internal state (for debugging) |
| `:Zconfig` | Show current zotcite configuration |

---

## Files

| File | Purpose |
|------|---------|
| `dots/nvim/lua/plugins/zk.lua` | zk-nvim plugin config and keybinds |
| `dots/nvim/lua/plugins/writing.lua` | zotcite + ltex-ls-plus config |
| `dots/lazygit/config.yml` | Lazygit delta pager config |
| `dots/vale/.vale.ini` | Vale prose linter config |
| `dots/bin/arxiv-search` | arXiv launcher script |
| `dots/bin/doi2bib` | DOI/arXiv to BibTeX script |
| `dots/bin/zotero-search` | Zotero search script |
| `dots/bin/quick-note` | Quick note launcher script |
| `dots/bin/today-schedule` | Calendar popup script |
| `dots/bin/translate-clip` | Translation script |
| `dots/bin/zk-init` | One-time notebook initializer |
| `dots/bin/zk-index` | Regenerate README.md and index.md (groups by category, indexes topics) |

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
