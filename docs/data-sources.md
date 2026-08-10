# Data sources and precedence

`spaceship-supabase` uses a small, fail-closed local data contract. It does not call the Supabase CLI, a network service, package runtime, or credential provider while rendering a prompt.

## Stable CLI layout

The supported layout is the stable Supabase CLI layout exercised by the included v2.72.7 and v2.113.0 fixtures:

```text
<project-root>/supabase/config.toml
<project-root>/supabase/.temp/project-ref
```

`config.toml` establishes a project boundary. A valid `project-ref` is the live linked hosted-project reference. It must contain exactly 20 lowercase ASCII letters, with no surrounding spaces, extra lines, or other bytes.

The resolver rejects unsafe or unexpected identity-critical layouts rather than guessing. In particular, the selected root, `supabase/`, `config.toml`, `.temp/`, and `project-ref` must be regular, non-symlinked entries that remain beneath the selected root. Input files are size-bounded before parsing.

## Root selection

The section resolves a root in this order:

1. If `SUPABASE_WORKDIR` is set, resolve it relative to `$PWD` when it is not absolute, canonicalize it, and inspect that directory only. If it is invalid, unsafe, or not a supported project root, render nothing.
2. Otherwise, walk upward from `$PWD` through at most 32 ancestors and choose the nearest safe directory containing `supabase/config.toml`.
3. Once a nearer project boundary is found, do not continue upward to inherit a parent project's identity.

This makes nested projects and monorepos deterministic. A `SUPABASE_WORKDIR` override does not silently fall back to an ancestor or the current directory.

## Identity precedence

After selecting a safe root, the section applies the following identity rules:

| Order | Source | Result |
| --- | --- | --- |
| 1 | `supabase/.temp/project-ref` | A valid live reference is rendered and always takes priority. |
| 2 | `project_id` in the explicitly selected `[remotes.<name>]` block | Used only when no valid live reference exists, and rendered with `· configured:<name>`. |
| 3 | Anything else | No segment. |

No label, prior prompt result, current directory cache, or missing-state fallback can replace this order. The prompt rereads local state on every render, so a successful `supabase link`, source repair, or local database-branch change is reflected on the next prompt without changing directories.

## Config mapping is not live link state

`SPACESHIP_SUPABASE_CONFIG_REMOTE` opts in to a single local mapping. For example:

```toml
[remotes.staging]
project_id = "abcdefghijklmnopqrst"
```

```zsh
SPACESHIP_SUPABASE_CONFIG_REMOTE="staging"
```

If and only if live `project-ref` state is absent or invalid, the output is:

```text
🔷 abcdefghijklmnopqrst · configured:staging
```

The marker matters: it says the reference is a configured mapping, not a current CLI link. The parser reads only the named remote block line by line using Zsh; it does not source TOML, inspect `env(...)`, or interpret unrelated fields.

The top-level `project_id` in `config.toml` is a local workspace identifier and is never treated as a hosted project reference. The selector itself is validated before use, so neither automatic remote discovery nor arbitrary TOML path traversal is supported.

## Local database branch

The optional `supabase/.branches/_current_branch` input is local database state from the CLI's deprecated local database branch command. When `SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH=true`, a valid value is displayed only with a live `project-ref`; it never decorates a configured fallback:

```text
🔷 abcdefghijklmnopqrst (local-db:feature/refactor-42)
```

It does not select a project and must not be read as a hosted Supabase Branch. It is ignored by default and never shown as `ref@branch`.

The branch is optional decoration, not identity. If its directory or file is absent, malformed, unreadable, oversized, or symlinked, the section omits only the `local-db:<name>` marker. A separately validated live reference remains visible.

## Unsupported layout

`.supabase/project.json` belongs to Supabase's unreleased next-shell work, not the stable v0.1.0 CLI contract. It is intentionally unsupported for this release. A future opt-in adapter may be considered only after it is part of a stable, documented CLI contract and has equivalent safety coverage.
