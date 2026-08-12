# Configuration

`spaceship-supabase` has a deliberately small configuration surface. Its identity display is always a full, validated 20-character project reference. There are no arbitrary templates, prefix/truncation settings, project-name-only modes, branch-only modes, or automatic remote lookups.

Put settings in `.zshrc`, preferably before your prompt is first drawn. All prompt rendering remains local and read-only.

## Settings

| Setting | Default | Accepted value | Effect |
| --- | --- | --- | --- |
| `SPACESHIP_SUPABASE_SHOW` | `true` | `true` or `false` | Enables or disables the section. `false` performs no normal resolution and renders nothing. |
| `SPACESHIP_SUPABASE_ASYNC` | `true` | `true` or `false` | Spaceship section scheduling preference. The section's own data path remains local and synchronous-safe. |
| `SPACESHIP_SUPABASE_COLOR` | `cyan` | A Spaceship v4 color value | Color supplied to `spaceship::section::v4`. |
| `SPACESHIP_SUPABASE_SYMBOL` | `"🔷 "` | User-owned text | Symbol placed before the validated section value. |
| `SPACESHIP_SUPABASE_PREFIX` | `""` | User-owned text | Prefix supplied to Spaceship. |
| `SPACESHIP_SUPABASE_SUFFIX` | `"$SPACESHIP_PROMPT_DEFAULT_SUFFIX"` | User-owned text | Suffix supplied to Spaceship. |
| `SPACESHIP_SUPABASE_FORMAT` | `ref` | `ref` or `label+ref` | Chooses the bare full reference or a safe local label followed by the full reference. |
| `SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH` | `false` | `true` or `false` | When enabled, appends a validated `local-db:<name>` marker from the local database-branch file to a live ref only. |
| `SPACESHIP_SUPABASE_CONFIG_REMOTE` | empty | A remote selector matching `[A-Za-z0-9][A-Za-z0-9._-]{0,63}` | Explicitly selects one `[remotes.<name>]` mapping as a non-authoritative fallback. |
| `SPACESHIP_SUPABASE_USE_LABELS` | `true` | `true` or `false` | Enables reading a valid local label for `label+ref` output. It never changes identity selection. |
| `SPACESHIP_SUPABASE_LABEL_FILE` | `${XDG_STATE_HOME:-$HOME/.local/state}/spaceship-supabase/labels.tsv` | An absolute owner-controlled local path | Location of the manual label store. It is read during rendering only when labels are enabled; writes happen only through explicit helpers. |
| `SPACESHIP_SUPABASE_DEBUG` | `false` | `true` or `false` | Enables fixed, redacted diagnostic codes. It never prints raw paths, source lines, labels, or file contents. |

`SUPABASE_WORKDIR` is an upstream Supabase work-directory override that the section honors. When it is set, it is resolved relative to the current directory if necessary and is the **only** directory inspected. An invalid or unsafe override renders no segment; it never falls back to the current directory.

An unsupported `SPACESHIP_SUPABASE_FORMAT` is fail-closed: it renders no segment. With debug enabled it may emit the fixed `UNSUPPORTED_FORMAT` diagnostic code, never an interpolated value.

## Supported formats

The default is the truthful live-reference display:

```zsh
SPACESHIP_SUPABASE_FORMAT="ref"
```

```text
🔷 abcdefghijklmnopqrst
```

The only alternative retains the exact reference and adds a local safe label:

```zsh
SPACESHIP_SUPABASE_FORMAT="label+ref"
```

```text
🔷 Production (abcdefghijklmnopqrst)
```

The label is optional: if it is absent, invalid, disabled, or unavailable, the resolved full reference remains the identity-bearing value. See [labels](labels.md).

## Local database-branch marker

The stable CLI's `supabase/.branches/_current_branch` represents a local database branch. It is not evidence of a hosted Supabase Branch. It is ignored by default.

```zsh
SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH=true
```

Only a value matching `[A-Za-z0-9][A-Za-z0-9._/-]{0,127}` is displayed, and only when a live `project-ref` is active:

```text
🔷 abcdefghijklmnopqrst (local-db:feature/refactor-42)
```

The section never uses `ref@branch` and does not offer a branch-only format.
If the optional local-db branch file is absent, malformed, unreadable, oversized, or symlinked, the marker is omitted. A separately validated live reference remains visible.

## Explicit config mapping

Set a selector only when you consciously want to use one local mapping as a fallback:

```zsh
SPACESHIP_SUPABASE_CONFIG_REMOTE="staging"
```

The resolver reads only `project_id` inside the matching `[remotes.staging]` block, and only accepts it when it is exactly 20 lowercase letters. If a valid live `project-ref` exists, it always wins. If it does not, a valid mapping is visibly marked:

```text
🔷 abcdefghijklmnopqrst · configured:staging
```

`config.toml` is never sourced or evaluated. Top-level `project_id` and all unrelated TOML values are ignored. See [data sources](data-sources.md).

## Labels

Labels are manual decorations stored locally by ref. Enable their display and set one explicitly:

```zsh
SPACESHIP_SUPABASE_USE_LABELS=true
SPACESHIP_SUPABASE_FORMAT="label+ref"
spaceship_supabase_label set "Production"
```

The label must be printable ASCII, at most 64 characters, and must not contain `%`, tabs, newlines, or control characters. It is never used as a project target, cache entry, or fallback identity. See [labels](labels.md) for command behavior and local-state protections.

## Removed alpha options

v0.1.1 intentionally retains the v0.1 configuration reset. The following alpha-era options are not public API and must not be relied on:

- source toggles such as `SPACESHIP_SUPABASE_USE_PROJECT_REF` and `SPACESHIP_SUPABASE_USE_CONFIG_TOML`;
- cache controls such as `SPACESHIP_SUPABASE_USE_CACHE`, `SPACESHIP_SUPABASE_CACHE_FILE`, and `SPACESHIP_SUPABASE_CACHE_TTL`;
- ref prefixing or truncation settings;
- raw error symbols or colors; and
- arbitrary format, project-name-only, or branch-only settings.

The reset removes stale context and prompt-injection-prone output paths rather than preserving an untagged alpha contract.
