# Labels and local state

Labels make a full project reference easier to recognize without turning a prompt into a remote metadata client. They are manual, local decorations. They never select, restore, or replace a Supabase project reference.

## What labels can do

With `SPACESHIP_SUPABASE_FORMAT="label+ref"`, a valid label decorates an identity that the renderer has resolved now:

```text
🔷 Production (abcdefghijklmnopqrst)
```

The exact reference remains visible. If live identity disappears, is malformed, or is unsafe, the label cannot make a segment appear. If a valid configured mapping is the active identity, its required `configured:<remote>` marker remains visible.

## Storage

By default, labels are enabled and stored at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/spaceship-supabase/labels.tsv
```

The store is a versioned TSV file keyed by project reference, not by project path. This means a label follows the same validated reference across local checkouts, while it does not preserve a historical target after all usable identity sources disappear.

Only explicit helper commands create or update the store. The prompt renderer never writes it. The implementation uses a private state directory and file, validates ownership and permissions before use, and updates via a temporary file and atomic rename. It ignores a malformed, oversized, symlinked, insecure, or duplicate-ambiguous store rather than attempting to repair it while drawing a prompt.

Do not hand-edit the file. Use the helpers so the invariants and permissions remain intact.

## Commands

All commands are local. None invokes the Supabase CLI or a network service.

### Set a label

```zsh
spaceship_supabase_label set "Production"
```

`set` requires a currently valid **live** `project-ref`; a configured mapping alone is not enough to create or update a label. The label must be at most 64 printable ASCII characters and may not contain `%`, tabs, newlines, or control characters.

### Clear the current label

```zsh
spaceship_supabase_label clear
```

`clear` also requires a currently valid live reference. It removes only that reference's label through the same safe update path.

### List stored labels

```zsh
spaceship_supabase_label list
```

`list` reports valid local entries from the secure store. It does not inspect project directories, contact Supabase, or create state. Since project references and labels can be sensitive contextual information, avoid copying the output into public reports unless necessary.

### Inspect local health

```zsh
spaceship_supabase_doctor
spaceship_supabase_doctor --verbose
```

`doctor` is read-only and local-only. Its normal output reports redacted root, source, and label-store status plus fixed remediation guidance. `--verbose` is an explicit request to show already-sanitized values, so use it thoughtfully when sharing logs. The command does not disclose raw config lines, arbitrary paths, label records, credentials, or malformed source data.

## Privacy model

A label is your own local annotation, not an authoritative Supabase name. Store only text you are comfortable having in a terminal prompt. Use `SPACESHIP_SUPABASE_USE_LABELS=false` to stop label reads without deleting local state, or `spaceship_supabase_label clear` while in a live linked project to remove its current label.
