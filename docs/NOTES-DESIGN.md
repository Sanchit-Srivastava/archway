# Notes System Redesign

> **Status: Proposed.** This document describes the intended replacement for
> the current notes workflow. It is a design record, not documentation of
> functionality that has already been implemented.

## Goals

The notes repository will hold long-lived and important material, including
PhD research, quick observations, paper notes, meeting records, references,
and follow-up actions. It must remain understandable and usable for years even
if the surrounding tools change.

The system should provide:

- immediate, reliable note capture without mandatory metadata entry;
- filenames that are unique, chronological, and searchable by note kind;
- plain Markdown files that remain useful without `zk` or an editor plugin;
- the same canonical creation workflow on Linux and macOS;
- optional integrations for niri, KDE, terminals, and Neovim;
- simple Git-based synchronization and migration; and
- room for later validation or publishing without requiring either now.

The design should not turn either Archway or the notes repository into a
custom note-taking application.

## Design principles

### The notes repository is canonical

Anything that defines the notebook belongs in the notes repository:

- filename and metadata conventions;
- templates;
- creation and validation commands;
- `.zk/config.toml` and `zk` aliases;
- migration utilities; and
- documentation of the stored format.

Cloning that repository should be enough to recover the notebook's structure
and behavior. Archway may install tools and provide convenient entry points,
but it must not contain another implementation of the format.

### Capture first, classify later

A note must be creatable without a final title, tags, references, attendees,
or polished metadata. The creator should generate every value needed for a
valid and collision-free file. Optional fields can be completed while editing
or during later review.

### Prefer explicit, repairable automation

Creation-time automation should be limited to facts the computer knows:

- a stable ID;
- creation time;
- initial note kind;
- a safe filename and slug; and
- minimal valid frontmatter.

Checks and generated output should initially be invoked explicitly. A broken
indexer or validator must never prevent an urgent meeting note from being
saved or committed.

### Plain files are the durable interface

`zk`, `rg`, `fzf`, Neovim, and future publishing tools are consumers of the
Markdown files. None of them should define the only usable interface to the
notes. Ordinary filesystem search, GitHub, Finder, and Dolphin should still be
useful.

## File organization

Keep one flat directory initially:

```text
notes/
├── .zk/
│   └── config.toml
├── bin/
│   └── new-note
├── entries/
├── templates/
│   └── note.md
├── AGENTS.md
├── Justfile
└── README.md
```

Do not introduce directories per topic or note kind until the flat collection
causes a demonstrated problem. Tags and filename prefixes already provide two
ways to filter it, while a flat directory makes links, moves, and searches
simple.

## Filename convention

Use:

```text
kind_YYYY-MM-DD_HHMMSS_slug.md
```

Examples:

```text
note_2026-08-03_143522_bell-inequality-question.md
meeting_2026-08-04_100000_supervisor-meeting.md
paper_2026-08-05_091415_device-independent-qkd.md
journal_2026-08-06_083000_daily-note.md
```

The underscore separates structural fields. Dates and slugs use hyphens for
readability. Including seconds makes collisions unlikely even when notes are
created on more than one machine.

The initial kinds should remain deliberately small:

- `note` for ordinary research notes and uncategorized capture;
- `meeting` for discussions and meeting records;
- `paper` for notes centered on a publication; and
- `journal` for chronological personal or research logs.

Use `kind`, rather than `category`, for this stable creation-time distinction.
Tags describe subject matter and can change freely. A semantic `category`
field should only be introduced later if tags and kinds prove insufficient.

Do not automatically rename existing files when metadata changes. Stable
paths make links, Git history, and external references easier to maintain.

If no title is supplied, the creator should use `untitled` in the filename and
an editable heading such as `Untitled note`. A blank title must never be an
error.

## Common note format

Begin with one general template:

```markdown
---
id: 20260803T143522
created: 2026-08-03T14:35:22-04:00
kind: note
tags: []
---

# Bell inequality question

## Notes


## References


## Actions

- [ ]
```

The creator supplies `id`, `created`, `kind`, and the heading. Tags are an
empty valid list. The remaining sections are prompts, not requirements.

The timestamp ID is intentionally simple and readable. A UUID is unnecessary
unless real collision problems appear. The ID should remain unchanged if the
file is renamed.

Specialized metadata is added only when it is useful. For example:

```yaml
attendees:
  - Supervisor
```

or:

```yaml
citekey: bell1964
doi: 10.example/example
```

Avoid placing every possible specialized field in the common template. Empty
frontmatter creates visual noise and makes capture feel like form filling.

## Canonical creation command

The notes repository should provide one implementation, tentatively:

```bash
just new
just new meeting
just new paper "Device-independent QKD"
just new note "Bell inequality question"
```

These commands should all delegate to `bin/new-note`. The script should:

1. accept an optional kind and title;
2. validate the kind, with `note` as the safe default;
3. generate the timestamp, stable ID, and portable slug;
4. render the common template into a unique path under `entries/`;
5. open the new file with `${EDITOR:-vi}` when interactive; and
6. print the created path for scripts and noninteractive use.

The implementation should use conservative shell features and avoid GNU-only
command flags so it works with the tools normally available on Linux and
macOS. It must quote titles safely and should use an exclusive-create or
equivalent check rather than overwriting an existing path.

Convenience recipes such as `just meeting` may exist, but they must remain
thin aliases to the same creator. They are not separate formats or templates.

## Search and navigation

Start with tools that query the source files directly:

- filename search for kinds and titles;
- `rg` for content search;
- `fzf` for interactive filtering and previews; and
- `zk` for links, backlinks, tags, and LSP support.

Do not begin by regenerating topic pages, `README.md`, or `index.md` on every
commit. Add generated indexes only if direct queries fail to serve a real use
case. If publishing later requires indexes, prefer generating them in CI or a
build directory rather than rewriting tracked files during normal commits.

## Validation and automation stages

### During capture

Only create a valid, uniquely named note. No network, index, citation, schema,
or Git operation should be required.

### During editing

The user may refine the title, add tags and references, add specialized
metadata, and turn rough actions into tasks. Editor integrations may assist
but must not alter the storage contract.

### Before committing

Initially, ordinary Git commands should always work. After the format has
settled, add an explicit command:

```bash
just check
```

Potential checks include duplicate IDs, malformed frontmatter, broken internal
links, and filenames outside the convention. Do not install these as mandatory
pre-commit hooks until they have proved fast, portable, and nearly infallible.

### In CI

CI may eventually run stricter checks or publishing builds. CI should report
format problems without making local capture dependent on external services.

## Ownership boundary with Archway

### Notes repository

The notes repository will own the common template, creator, schema, filename
rules, `.zk` configuration, aliases, checks, migration code, and notebook
documentation.

### Archway

Archway may own:

- package installation for `zk`, `fzf`, `ripgrep`, and `bat`;
- Neovim plugin configuration and machine-level keybindings;
- an optional Fuzzel menu under niri; and
- a terminal launcher suitable for the local desktop.

Archway launchers should call the repository interface, for example
`just --working-directory "$HOME/notes" new meeting`. They must not reproduce
the template, filename generation, or kind rules.

KDE and macOS must remain first-class environments. The canonical command must
work in a normal terminal; Niri and Fuzzel are optional presentation layers.

## Migration plan

Implement the new system before bulk-converting the stale repository:

1. Create the minimal repository layout.
2. Implement and manually test `bin/new-note` and `just new`.
3. Add the minimal `.zk/config.toml` without generated-index machinery.
4. Exercise capture on Linux, macOS, KDE, and niri where available.
5. Copy a small representative set of research, meeting, paper, and journal
   notes into the new format.
6. Adjust the schema only in response to observed friction.
7. Write a repeatable migration tool with dry-run and collision reporting.
8. Back up and migrate the full old repository.
9. Add `just check` after the stored format is stable.
10. Update Archway to delegate creation to the new repository and then remove
    Archway's legacy `zk-init`, template knowledge, and `zk-index` integration.

The migration must preserve original material and should record old paths or
identifiers when useful for traceability. It should never silently overwrite a
destination file.

## Deferred decisions

Do not decide these until the basic workflow has been used with real notes:

- whether a semantic `category` field is needed in addition to kind and tags;
- whether references should use citation keys, DOI fields, ordinary Markdown,
  or a combination;
- whether task aggregation outside individual notes is valuable;
- whether generated indexes or topic pages provide enough value to maintain;
- whether publishing through Quartz, Hugo, or another system is desirable;
- whether attachments belong in Git, Git LFS, Zotero, or external storage; and
- whether stricter validation belongs in CI or local hooks.

The default answer to each deferred feature is to omit it until repeated use
demonstrates its value.

## Archway changes after the notes repository exists

Do not extend the current Archway-owned templates or creation branches. Once
the new notes repository exposes its stable commands:

1. change `quick-note` creation actions to call the repository's `just new`;
2. keep or simplify `quick-note-search` as an optional desktop adapter;
3. update Neovim creation mappings to call the same repository interface;
4. remove `zk-init` from Archway;
5. remove the `zk-index` symlink setup from `infra/dotfiles.sh`; and
6. update `RESEARCH-WORKFLOW.md` from legacy behavior to the implemented
   portable workflow.

Until then, the current implementation remains available but should be treated
as temporary compatibility code rather than the source of the new design.
