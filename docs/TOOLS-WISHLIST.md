# Tools Wishlist

A curated list of CLI tools, TUIs, launcher workflows, and configuration improvements
to implement incrementally. Organized by category with installation commands and
implementation details.

---

## Table of Contents

- [A. Packages to Add](#a-packages-to-add)
- [B. Git Enhancements](#b-git-enhancements)
- [C. Calendar and Task Sync](#c-calendar-and-task-sync)
- [D. Writing Quality in Neovim](#d-writing-quality-in-neovim)
- [E. Research Notes Workflow (zk)](#e-research-notes-workflow-zk)
- [F. Custom Launcher Workflows (fuzzel)](#f-custom-launcher-workflows-fuzzel)
- [G. TUI Tools to Explore](#g-tui-tools-to-explore)
- [H. AI Research Tools (deferred)](#h-ai-research-tools-deferred)

---

## A. Packages to Add

### Official repos (pkgs.pacman.txt)

```
# CLI Tools
fuzzel                  # Wayland-native dmenu replacement (backbone for launcher workflows)
glow                    # Terminal Markdown renderer
pdfgrep                 # Grep across PDF contents
translate-shell         # CLI translation (provides `trans` command)
zk                      # CLI Zettelkasten / markdown wiki tool

# Git Enhancements
git-delta               # Syntax-highlighted git pager
difftastic              # Structural diff tool (understands code semantics)

# Calendar / Task Sync
vdirsyncer              # CalDAV/CardDAV sync daemon
python-todoman          # Terminal todo list (uses CalDAV data from vdirsyncer)
```

### AUR (pkgs.aur.txt)

```
# Writing Quality
ltex-ls-plus-bin        # Grammar/spell-checking LSP for LaTeX and Markdown
vale-bin                # Prose linter for academic writing

# System
pacseek                 # TUI for browsing/installing Arch + AUR packages
```

---

## B. Git Enhancements

### git-delta

Syntax-highlighted, side-by-side git diffs. Drop-in replacement for the default pager.

**Install**: `sudo pacman -S git-delta`

**Configure** (add to `dots/git/.gitconfig`):

```gitconfig
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    side-by-side = true
    line-numbers = true
    syntax-theme = Catppuccin-mocha   # or whatever matches your theme

[merge]
    conflictstyle = zdiff3
```

### difftastic

Structural diffs that understand language syntax. A moved function shows as moved,
not as a deletion + addition.

**Install**: `sudo pacman -S difftastic`

**Configure** (add alias to `dots/git/.gitconfig`):

```gitconfig
[alias]
    dft = "!f() { GIT_EXTERNAL_DIFF=difft git diff $@; }; f"
    dftl = "!f() { GIT_EXTERNAL_DIFF=difft git log -p --ext-diff $@; }; f"
```

Usage: `git dft`, `git dftl`, or `GIT_EXTERNAL_DIFF=difft git show HEAD`.

---

## C. Calendar and Task Sync

Syncs Google Calendar to your terminal via CalDAV. The chain:

```
Google Calendar <--CalDAV--> vdirsyncer <--local files--> khal (calendar TUI)
                                                      \-> todoman (todo TUI)
```

Your phone's native calendar app syncs with the same Google Calendar, so everything
stays in sync across devices.

### Step 1: vdirsyncer config

**Install**: `sudo pacman -S vdirsyncer`

Create `dots/vdirsyncer/config` (symlink to `~/.config/vdirsyncer/config`):

```ini
[general]
status_path = "~/.local/share/vdirsyncer/status/"

[pair google_calendar]
a = "google_calendar_local"
b = "google_calendar_remote"
collections = ["from a", "from b"]
metadata = ["color"]

[storage google_calendar_local]
type = "filesystem"
path = "~/.local/share/calendars/"
fileext = ".ics"

[storage google_calendar_remote]
type = "google_calendar"
# Follow vdirsyncer docs for OAuth2 setup:
# https://vdirsyncer.pimutils.org/en/stable/config.html#google
token_file = "~/.local/share/vdirsyncer/google_token"
client_id = "YOUR_CLIENT_ID"
client_secret = "YOUR_CLIENT_SECRET"
```

**First run**:
```bash
vdirsyncer discover google_calendar
vdirsyncer sync google_calendar
```

### Step 2: khal config

khal is already installed. Create/update `dots/khal/config`
(symlink to `~/.config/khal/config`):

```ini
[calendars]

[[google]]
path = ~/.local/share/calendars/*
type = discover

[locale]
timeformat = %H:%M
dateformat = %Y-%m-%d
longdateformat = %Y-%m-%d
datetimeformat = %Y-%m-%d %H:%M
longdatetimeformat = %Y-%m-%d %H:%M

[default]
default_calendar = your-calendar-name
highlight_event_days = true
```

### Step 3: todoman config

**Install**: `sudo pacman -S python-todoman`

Create `dots/todoman/config.py` (symlink to `~/.config/todoman/config.py`):

```python
path = "~/.local/share/calendars/*"
date_format = "%Y-%m-%d"
time_format = "%H:%M"
default_list = "your-calendar-name"
```

Usage: `todo list`, `todo new "Write abstract"`, `todo done 1`.

### Step 4: systemd timer for auto-sync

Create `dots/systemd/user/vdirsyncer-sync.service`:

```ini
[Unit]
Description=Sync CalDAV via vdirsyncer

[Service]
Type=oneshot
ExecStart=/usr/bin/vdirsyncer sync
```

Create `dots/systemd/user/vdirsyncer-sync.timer`:

```ini
[Unit]
Description=Sync CalDAV every 15 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
```

Enable: `systemctl --user enable --now vdirsyncer-sync.timer`

---

## D. Writing Quality in Neovim

### ltex-ls-plus (grammar/spell checking LSP)

Grammar and spell checking for LaTeX and Markdown directly in Neovim, powered by
LanguageTool. Shows red squiggles under grammar mistakes with quick-fix suggestions.

**Install**: `yay -S ltex-ls-plus-bin`

**Neovim config** (add to your LSP setup, e.g. `dots/nvim/lua/plugins/writing.lua`):

```lua
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ltex_plus = {
          filetypes = { "tex", "latex", "markdown", "bib" },
          settings = {
            ltex = {
              language = "en-US",
              -- Add technical terms that aren't real errors:
              dictionary = {
                ["en-US"] = {
                  "Hamiltonian", "eigenstates", "qubit", "ansatz",
                  "bosonic", "fermionic", "Hermitian", "unitary",
                  -- add your field-specific terms here
                },
              },
              -- Disable rules that conflict with academic writing:
              disabledRules = {
                ["en-US"] = { "MORFOLOGIK_RULE_EN_US" }, -- less aggressive spell check
              },
            },
          },
        },
      },
    },
  },
}
```

### vale (prose linter)

Configurable prose linter. Enforces writing style rules (no passive voice, no weasel
words, etc.).

**Install**: `yay -S vale-bin`

Create `dots/vale/.vale.ini` (symlink to `~/.vale.ini`):

```ini
StylesPath = ~/.local/share/vale/styles
MinAlertLevel = suggestion

[*.{tex,md}]
BasedOnStyles = Vale
```

Download default styles:
```bash
vale sync  # after creating config
```

Usage: `vale paper.tex` or integrate with nvim-lint in Neovim.

---

## E. Research Notes Workflow (zk)

A flat-file markdown wiki for research notes, synced across machines via git.

### Why zk

- Plain `.md` files with YAML frontmatter -- no proprietary format, future-proof
- CLI tool: `zk new`, `zk list`, `zk edit` -- composable with scripts and launchers
- Neovim LSP via `zk-nvim`: link completion, goto-definition, backlinks
- Templates for different note types
- Already in pacman: `sudo pacman -S zk`

### Directory structure

```
~/notes/
├── .zk/
│   └── config.toml           # zk configuration
├── .git/                      # git repo for cross-machine sync
├── templates/
│   ├── paper-summary.md
│   ├── meeting-notes.md
│   ├── research-note.md
│   └── daily.md
├── journal/                   # daily notes
├── papers/                    # paper summaries (linked to Zotero via citekey)
├── ideas/                     # research ideas
├── meetings/                  # meeting notes
├── references/
│   └── library.bib            # Zotero Better BibTeX auto-export
└── index.md                   # entry point / dashboard
```

### zk configuration

Create `~/notes/.zk/config.toml`:

```toml
[note]
filename = "{{slug title}}"
extension = "md"
template = "research-note.md"
id-charset = "alphanum"
id-length = 4
id-case = "lower"

[group.journal]
paths = ["journal"]
[group.journal.note]
filename = "{{format-date now '%Y-%m-%d'}}"
template = "daily.md"

[group.papers]
paths = ["papers"]
[group.papers.note]
filename = "{{slug title}}"
template = "paper-summary.md"

[group.meetings]
paths = ["meetings"]
[group.meetings.note]
filename = "{{format-date now '%Y-%m-%d'}}-{{slug title}}"
template = "meeting-notes.md"

[group.ideas]
paths = ["ideas"]
[group.ideas.note]
filename = "{{slug title}}"
template = "research-note.md"

[tool]
editor = "nvim"
pager = "less -FRX"
fzf-preview = "bat -p --color always {-1}"

[format.markdown]
link-format = "markdown"
hashtags = true
colon-tags = true

[lsp]
diagnostics.dead-link = "error"

[lsp.completion]
note-label = "{{title}}"
note-filter-text = "{{title}} {{path}}"
note-detail = "{{filename}}"

[alias]
journal = 'zk new --group journal "$@"'
paper = 'zk new --group papers --title "$@"'
meeting = 'zk new --group meetings --title "$@"'
idea = 'zk new --group ideas --title "$@"'
recent = 'zk list --sort modified --limit 20'
```

### Templates

**templates/daily.md**:

```markdown
---
date: {{format-date now "%Y-%m-%d"}}
tags: [journal]
---

# {{format-date now "%A, %B %d, %Y"}}

## Plan

-

## Notes

-

## End of day

-
```

**templates/paper-summary.md**:

```markdown
---
title: {{title}}
date: {{format-date now "%Y-%m-%d"}}
tags: [paper]
citekey:
arxiv:
authors:
---

# {{title}}

## Key Results

-

## Methods

-

## Relevance to My Work

-

## Questions / Follow-ups

-
```

**templates/meeting-notes.md**:

```markdown
---
title: {{title}}
date: {{format-date now "%Y-%m-%d"}}
tags: [meeting]
attendees:
---

# {{title}}

## Discussion

-

## Action Items

- [ ]
```

**templates/research-note.md**:

```markdown
---
title: {{title}}
date: {{format-date now "%Y-%m-%d"}}
tags: []
---

# {{title}}


```

### Neovim integration (zk-nvim)

Add to your Neovim plugin config (e.g. `dots/nvim/lua/plugins/zk.lua`):

```lua
return {
  {
    "zk-org/zk-nvim",
    config = function()
      require("zk").setup({
        picker = "telescope",  -- or "fzf_lua"
        lsp = {
          config = {
            cmd = { "zk", "lsp" },
            name = "zk",
          },
          auto_attach = {
            enabled = true,
            filetypes = { "markdown" },
          },
        },
      })

      local opts = { noremap = true, silent = false }

      -- Create notes
      vim.keymap.set("n", "<leader>zn", "<Cmd>ZkNew { title = vim.fn.input('Title: ') }<CR>", opts)
      vim.keymap.set("n", "<leader>zj", "<Cmd>ZkNew { group = 'journal' }<CR>", opts)
      vim.keymap.set("n", "<leader>zp", "<Cmd>ZkNew { group = 'papers', title = vim.fn.input('Paper: ') }<CR>", opts)
      vim.keymap.set("n", "<leader>zm", "<Cmd>ZkNew { group = 'meetings', title = vim.fn.input('Meeting: ') }<CR>", opts)

      -- Search / navigate
      vim.keymap.set("n", "<leader>zf", "<Cmd>ZkNotes { sort = { 'modified' } }<CR>", opts)
      vim.keymap.set("n", "<leader>zt", "<Cmd>ZkTags<CR>", opts)
      vim.keymap.set("n", "<leader>zl", "<Cmd>ZkLinks<CR>", opts)
      vim.keymap.set("n", "<leader>zb", "<Cmd>ZkBacklinks<CR>", opts)
      vim.keymap.set("v", "<leader>zn", ":'<,'>ZkNewFromTitleSelection<CR>", opts)

      -- Search by content (grep)
      vim.keymap.set("n", "<leader>zs", "<Cmd>ZkNotes { match = { vim.fn.input('Search: ') } }<CR>", opts)
    end,
  },
}
```

### Zotero integration

Set up Better BibTeX auto-export to keep `~/notes/references/library.bib` in sync:

1. In Zotero: Edit > Settings > Better BibTeX > Automatic Export
2. Add export: collection = "My Library", format = "Better BibTeX", path = `~/notes/references/library.bib`
3. Set to auto-export on change

Paper summary notes reference the citekey in frontmatter, creating a bridge between
your notes and your reference manager.

### Cross-machine sync

Add a git remote and sync manually or with a hook:

```bash
# Manual
cd ~/notes && git add -A && git commit -m "sync $(date +%Y-%m-%d)" && git push

# Auto-commit on save (add to a post-save hook or cron)
# Or use a systemd timer similar to the vdirsyncer one
```

---

## F. Custom Launcher Workflows (fuzzel)

Shell scripts in `dots/bin/`, triggered by niri keybinds. All use **fuzzel** as the
Wayland-native fuzzy picker.

**Install**: `sudo pacman -S fuzzel`

### Available keybinds (confirmed free)

| Keybind | Proposed use |
|---------|-------------|
| `Mod+A` | arXiv Search |
| `Mod+B` | DOI/arXiv → BibTeX |
| `Mod+P` | Zotero Paper Search |
| `Mod+G` | Quick Research Note (zk) |
| `Mod+Alt+T` | Translate Clipboard |
| `Mod+Alt+C` | Today's Schedule |

### 1. Zotero Paper Search (`Mod+P`)

Search your Zotero library, pick a paper, open its PDF in Zathura. Uses the Better
BibTeX JSON-RPC API (runs at `localhost:23119` when Zotero is open).

Create `dots/bin/zotero-search`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ZOTERO_RPC="http://127.0.0.1:23119/better-bibtex/json-rpc"

bbt_rpc() {
    local method="$1" params="$2"
    curl -s "$ZOTERO_RPC" \
        -X POST -H "Content-Type: application/json" -H "Accept: application/json" \
        --data-binary "{\"jsonrpc\": \"2.0\", \"method\": \"$method\", \"params\": $params}"
}

# Get search query from user
query=$(echo "" | fuzzel --dmenu --prompt="Zotero: " --width=60)
[ -z "$query" ] && exit 0

# Search via BBT JSON-RPC
results=$(bbt_rpc "item.search" "[\"$query\"]")

# Parse results into "citekey | title | authors" for fuzzel
entries=$(echo "$results" | jq -r '.result[] |
    "\(.citekey) | \(.title // "Untitled") | \(.creators // [] | map(.lastName // .name) | join(", "))"' 2>/dev/null)

[ -z "$entries" ] && notify-send "Zotero" "No results for: $query" -t 3000 && exit 0

# Let user pick
selected=$(echo "$entries" | fuzzel --dmenu --prompt="Open: " --width=80 --lines=15)
[ -z "$selected" ] && exit 0

# Extract citekey
citekey=$(echo "$selected" | cut -d'|' -f1 | tr -d ' ')

# Get PDF path via attachments
pdf_path=$(bbt_rpc "item.attachments" "[\"$citekey\"]" | jq -r '.result[0].path // empty' 2>/dev/null)

if [ -n "$pdf_path" ] && [ -f "$pdf_path" ]; then
    zathura "$pdf_path" &
else
    # Fallback: open in browser
    notify-send "Zotero" "No local PDF, opening in browser" -t 2000
    xdg-open "https://scholar.google.com/scholar?q=${query// /+}"
fi
```

### 2. DOI/arXiv → BibTeX (`Mod+B`)

Copy a DOI or arXiv ID, press the keybind, get a BibTeX entry on your clipboard.
Tries Zotero first (if running), falls back to Crossref/arXiv APIs.

Create `dots/bin/doi2bib`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ZOTERO_RPC="http://127.0.0.1:23119/better-bibtex/json-rpc"

# Get identifier from clipboard or prompt
id=$(wl-paste 2>/dev/null | tr -d '[:space:]')

if [[ ! "$id" =~ ^10\. ]] && [[ ! "$id" =~ ^[0-9]{4}\.[0-9]+ ]] && [[ ! "$id" =~ ^https://doi.org/ ]]; then
    id=$(echo "" | fuzzel --dmenu --prompt="DOI or arXiv ID: " --width=50)
fi
[ -z "$id" ] && exit 0

# Normalize DOI
id="${id#https://doi.org/}"
id="${id#doi:}"

# Try Zotero first (if running and has the item)
if curl -s --max-time 1 "$ZOTERO_RPC" >/dev/null 2>&1; then
    bib=$(curl -s "$ZOTERO_RPC" \
        -X POST -H "Content-Type: application/json" -H "Accept: application/json" \
        --data-binary "{\"jsonrpc\": \"2.0\", \"method\": \"item.search\", \"params\": [\"$id\"]}" \
        | jq -r '.result[0].citekey // empty' 2>/dev/null)
    if [ -n "$bib" ]; then
        result=$(curl -s "$ZOTERO_RPC" \
            -X POST -H "Content-Type: application/json" -H "Accept: application/json" \
            --data-binary "{\"jsonrpc\": \"2.0\", \"method\": \"item.export\", \"params\": [[\"$bib\"], \"Better BibTeX\"]}" \
            | jq -r '.result // empty' 2>/dev/null)
        if [ -n "$result" ]; then
            echo "$result" | wl-copy
            notify-send "BibTeX (Zotero)" "Entry copied to clipboard" -t 3000
            exit 0
        fi
    fi
fi

# Fallback: arXiv ID
if [[ "$id" =~ ^[0-9]{4}\.[0-9]+ ]]; then
    bib=$(curl -sL "https://arxiv.org/bibtex/${id}" 2>/dev/null)
    if echo "$bib" | grep -q '@'; then
        echo "$bib" | wl-copy
        notify-send "BibTeX (arXiv)" "Entry copied to clipboard" -t 3000
        exit 0
    fi
fi

# Fallback: Crossref DOI
bib=$(curl -sL -H "Accept: application/x-bibtex" "https://doi.org/${id}" 2>/dev/null)
if echo "$bib" | grep -q '@'; then
    echo "$bib" | wl-copy
    notify-send "BibTeX (Crossref)" "Entry copied to clipboard" -t 3000
else
    notify-send "BibTeX Error" "Could not resolve: $id" -t 5000
fi
```

### 3. arXiv Search (`Mod+A`)

Search arXiv directly from a launcher, pick a paper, open in browser.

Create `dots/bin/arxiv-search`:

```bash
#!/usr/bin/env bash
set -euo pipefail

query=$(echo "" | fuzzel --dmenu --prompt="arXiv: " --width=60)
[ -z "$query" ] && exit 0

encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$query'''))")
results=$(curl -s "http://export.arxiv.org/api/query?search_query=all:${encoded}&start=0&max_results=15&sortBy=relevance")

entries=$(echo "$results" | python3 -c "
import sys, xml.etree.ElementTree as ET
root = ET.fromstring(sys.stdin.read())
ns = {'a': 'http://www.w3.org/2005/Atom'}
for e in root.findall('a:entry', ns):
    title = ' '.join(e.find('a:title', ns).text.split())
    aid = e.find('a:id', ns).text.split('/')[-1]
    authors = ', '.join(
        a.find('a:name', ns).text
        for a in e.findall('a:author', ns)[:3]
    )
    if len(e.findall('a:author', ns)) > 3:
        authors += ' et al.'
    print(f'{aid} | {title} | {authors}')
")

[ -z "$entries" ] && notify-send "arXiv" "No results for: $query" -t 3000 && exit 0

selected=$(echo "$entries" | fuzzel --dmenu --prompt="Open: " --width=80 --lines=15)
[ -z "$selected" ] && exit 0

arxiv_id=$(echo "$selected" | cut -d'|' -f1 | tr -d ' ')
xdg-open "https://arxiv.org/abs/${arxiv_id}"
```

### 4. Quick Research Note (`Mod+G`)

Create a new zk note from a fuzzel prompt. Picks a note group, asks for title,
opens in Neovim in a new terminal window.

Create `dots/bin/quick-note`:

```bash
#!/usr/bin/env bash
set -euo pipefail

NOTES_DIR="$HOME/notes"

# Pick note type
group=$(printf "journal\npaper\nidea\nmeeting\nnote" | \
    fuzzel --dmenu --prompt="Type: " --width=30)
[ -z "$group" ] && exit 0

if [ "$group" = "journal" ]; then
    # Journal notes don't need a title
    ghostty -e zk new --working-dir "$NOTES_DIR" --group journal &
elif [ "$group" = "note" ]; then
    title=$(echo "" | fuzzel --dmenu --prompt="Title: " --width=50)
    [ -z "$title" ] && exit 0
    ghostty -e zk new --working-dir "$NOTES_DIR" --title "$title" &
else
    title=$(echo "" | fuzzel --dmenu --prompt="Title: " --width=50)
    [ -z "$title" ] && exit 0
    ghostty -e zk new --working-dir "$NOTES_DIR" --group "$group" --title "$title" &
fi
```

### 5. Today's Schedule (`Mod+Alt+C`)

Shows today's khal events in a fuzzel popup.

Create `dots/bin/today-schedule`:

```bash
#!/usr/bin/env bash
set -euo pipefail

entries=$(khal list today today \
    --format "{start-time}-{end-time}  {title}  ({location})" 2>/dev/null)

if [ -z "$entries" ]; then
    notify-send "Schedule" "Nothing scheduled today" -t 3000
else
    echo "$entries" | fuzzel --dmenu \
        --prompt="Today ($(date +%a)): " --width=60 --lines=10
fi
```

### 6. Translate Clipboard (`Mod+Alt+T`)

Translate selected/copied text to English.

Create `dots/bin/translate-clip`:

```bash
#!/usr/bin/env bash
set -euo pipefail

text=$(wl-paste 2>/dev/null)
[ -z "$text" ] && exit 0

result=$(trans -b -t en "$text" 2>/dev/null)

if [ -n "$result" ]; then
    echo -n "$result" | wl-copy
    notify-send "Translation" "$result" -t 5000
else
    notify-send "Translation failed" "Could not translate selection" -t 3000
fi
```

### Niri keybinds

Add to `dots/niri/dms/binds.kdl`:

```kdl
Mod+A           { spawn "arxiv-search"; }
Mod+B           { spawn "doi2bib"; }
Mod+P           { spawn "zotero-search"; }
Mod+G           { spawn "quick-note"; }
Mod+Alt+T       { spawn "translate-clip"; }
Mod+Alt+C       { spawn "today-schedule"; }
```

---

## G. TUI Tools to Explore

Tools to try out and potentially add to the package lists. Grouped by category.

### Network Monitoring

| Tool | Package | Description |
|------|---------|-------------|
| **bandwhich** | `pacman -S bandwhich` | Real-time network bandwidth per process |
| **trippy** | `pacman -S trippy` | Traceroute + ping TUI with live charts |
| **gping** | `pacman -S gping` | Ping with a real-time graph |
| **sniffnet** | `pacman -S sniffnet` | Network traffic monitor with alerts |

### Data / Science

| Tool | Package | Description |
|------|---------|-------------|
| **visidata** | `pacman -S visidata` | Spreadsheet TUI for CSV, JSON, SQLite, HDF5. Useful for simulation data |

### Log Viewing

| Tool | Package | Description |
|------|---------|-------------|
| **lnav** | `pacman -S lnav` | Advanced log viewer with SQL queries and auto-format detection |

### Disk / Storage

| Tool | Package | Description |
|------|---------|-------------|
| **ncdu** | `pacman -S ncdu` | Classic ncurses disk usage analyzer |
| **gdu** | `pacman -S gdu` | Faster alternative to ncdu (parallel scanning) |

### API / HTTP Testing

| Tool | Package | Description |
|------|---------|-------------|
| **posting** | `yay -S posting` | Modern TUI HTTP client (like Postman in the terminal) |

### Music

| Tool | Package | Description |
|------|---------|-------------|
| **spotify-player** | `pacman -S spotify-player` | Terminal Spotify client with full feature parity |
| **ncspot** | `pacman -S ncspot` | Lightweight terminal Spotify client |

### Social / News

| Tool | Package | Description |
|------|---------|-------------|
| **circumflex** | `yay -S circumflex` | Hacker News reader TUI |

### Chat

| Tool | Package | Description |
|------|---------|-------------|
| **gomuks** | `pacman -S gomuks` | Matrix chat TUI (if your department uses Matrix) |
| **iamb** | `yay -S iamb` | Matrix client with Vim keybindings |

### System Administration

| Tool | Package | Description |
|------|---------|-------------|
| **pacseek** | `yay -S pacseek` | TUI for browsing and installing Arch + AUR packages |
| **kmon** | `pacman -S kmon` | Kernel module manager TUI |
| **hwatch** | `pacman -S hwatch` | Modern `watch` replacement with diff highlighting and history |

### Presentation / Documents

| Tool | Package | Description |
|------|---------|-------------|
| **slides** | `yay -S slides` | Terminal presentations from Markdown files |

### Markdown

| Tool | Package | Description |
|------|---------|-------------|
| **glow** | `pacman -S glow` | Beautiful Markdown rendering in the terminal |

### JSON / Data

| Tool | Package | Description |
|------|---------|-------------|
| **fx** | `pacman -S fx` | Interactive JSON viewer with jq-like queries |

### Niche / Fun

| Tool | Package | Description |
|------|---------|-------------|
| **mapscii** | `yay -S mapscii` | ASCII world map in the terminal |
| **cbonsai** | `yay -S cbonsai` | Grow bonsai trees in your terminal |

---

## H. AI Research Tools (deferred)

These are deferred for now but worth revisiting:

| Tool | Install | Description |
|------|---------|-------------|
| **llm** (Simon Willison) | `uv tool install llm` | Swiss army knife for LLM interaction from terminal. Pipe papers, summarize, ask questions |
| **fabric** (Daniel Miessler) | `uv tool install fabric-ai` | Curated AI prompt patterns: `summarize_paper`, `extract_wisdom`, `create_flashcards` |
| **paper-qa** | `uv tool install paper-qa` | RAG for scientific papers. Point at a PDF directory, ask questions, get cited answers |

Example workflow with llm:
```bash
curl -s https://arxiv.org/pdf/2301.12345 | llm "summarize the key results of this paper"
```

---

## Implementation Checklist

- [ ] Add packages to `infra/pkgs.pacman.txt` and `infra/pkgs.aur.txt`
- [ ] Configure git-delta in `dots/git/.gitconfig`
- [ ] Set up vdirsyncer config template in `dots/vdirsyncer/config`
- [ ] Configure khal in `dots/khal/config`
- [ ] Set up todoman in `dots/todoman/config.py`
- [ ] Create vdirsyncer systemd timer in `dots/systemd/user/`
- [ ] Add ltex-ls-plus to Neovim LSP config
- [ ] Set up vale config in `dots/vale/.vale.ini`
- [ ] Initialize `~/notes/` repo with zk config and templates
- [ ] Add zk-nvim plugin to Neovim config
- [ ] Install fuzzel and create launcher scripts in `dots/bin/`
- [ ] Add niri keybinds in `dots/niri/dms/binds.kdl`
- [ ] Wire new dotfile directories into `infra/dotfiles.sh`
- [ ] Try out TUI tools from section G and add favorites to package lists
