# AGENTS.md

This file is the non-negotiable implementation contract for coding agents and contributors working on `spaceship-supabase`.

## Runtime constraints

- Support Zsh 5.2+.
- Use `spaceship::section::v4` for rendering.
- The prompt render path must be local-only, read-only, and fresh on every render.
- Do not call the Supabase CLI, network, Node, Python, jq, another external parser, or a credential provider during prompt rendering.
- Do not write label state, cache state, diagnostics, or any other file during prompt rendering.
- Do not add a per-directory or session value cache that can make a linked identity stale.

## Untrusted-state rules

- Treat project files, configuration, branch files, labels, paths, and environment-derived paths as untrusted input.
- Establish a safe root first. Honor `SUPABASE_WORKDIR` strictly; an invalid override renders nothing and must not fall back to `$PWD`.
- Resolve the nearest safe `supabase/config.toml` boundary within 32 ancestors. Do not cross a nearer boundary to use a parent identity.
- Reject symlinks at every expected component and require canonical targets to remain below the selected root.
- Bound files before parsing and validate accepted values exactly. Reject malformed, multi-line, control-bearing, oversized, unreadable, or ambiguous identity-critical input silently in normal operation. Unsafe optional local-db input must be omitted without suppressing an independently valid live ref.
- Never source TOML, evaluate it, inspect `env(...)`, or interpolate raw filesystem text into a prompt.
- Only filesystem-derived values that pass the documented strict allowlists may reach the renderer. Debug diagnostics use fixed codes and redact raw values and paths.

## Identity and output rules

- A valid live `supabase/.temp/project-ref` is authoritative and always wins.
- The only config fallback is an explicitly selected `[remotes.<name>].project_id`; it is non-authoritative and must render `configured:<name>` when used.
- Top-level `project_id` is not a hosted project reference.
- `supabase/.branches/_current_branch` is local database state, not a hosted Supabase Branch. It is opt-in and must render only as `local-db:<name>`, never `ref@branch`.
- Supported formats are exactly `ref` and `label+ref`; retain the full 20-character reference in either case.
- Do not add arbitrary templates, bare labels, branch-only output, ref prefixes, truncation, remote enrichment, or a `.supabase/project.json` adapter without an explicit product-contract review.

## Label-store rules

- Labels are user-owned decorations keyed by project ref, not project path.
- Only explicit `spaceship_supabase_label` helpers may create, update, or remove label state; use owner-only permissions and atomic writes.
- `set` and `clear` require a currently valid live ref.
- A label must never select, resurrect, replace, or out-rank a current identity.
- Ignore malformed, oversized, symlinked, insecure, or duplicate-ambiguous label files; do not repair them from the prompt path.
- `spaceship_supabase_doctor` is local and read-only; redact by default.
- A synced decoration is separate remote-derived state, not a manual label.
  Only the explicit `spaceship_supabase_sync project [--yes]` helper may create
  or replace it. It must prove a current live ref before CLI work, accept only
  the audited version-aware `projects list` JSON array/envelope forms, match
  the exact ref once, validate all text, preview/confirm by default, recheck
  the live ref immediately before an owner-only atomic write, and use fixed
  redacted errors. Never add a prompt-time sync, refresh, CLI call, telemetry
  snapshot reader, or hosted-branch inference without a new contract review.
- A synced decoration is display-only: it is opt-in, live-ref-only,
  `label+ref`-only, visibly marked `synced:project`, and subordinate to a
  matching manual label. It cannot decorate a configured mapping or restore an
  identity.

## Test and documentation gate

- Keep fixtures synthetic, flat, tracked, and free of real project state, credentials, user paths, or captured Supabase directories.
- Use `ZSH_BIN=/path/to/zsh tests/run.zsh` for every implementation change; run `--performance` for release-sensitive work.
- Preserve actual Spaceship v4 rendering coverage for prompt-injection cases.
- For explicit synced-project work, use fake CLI tests only outside prompt
  rendering and cover both supported output forms, no-write errors, bounded
  output/child cleanup, state permissions, exact-ref freshness, and the enabled
  decoration benchmark scenario.
- Update README, configuration, data-source, label, troubleshooting, compatibility, testing, changelog, and release metadata when a public behavior changes.
- Preserve historical planning artifacts with superseded notices; do not edit them to make invalid alpha assumptions look current.

## Planning and compatibility evidence

- `docs/roadmap.md` defines durable product direction. GitHub milestones and
  issues are the authoritative active backlog and progress state.
- The initial-plan and BMad phases are historical inputs, not executable
  requirements. Do not revive an archived story without a current GitHub issue
  that reconciles it with the released product contract.
- External compatibility claims require a primary-source report under
  `docs/research/`, pinned synthetic fixtures where applicable, and links from
  the implementing issue or pull request.
- A project name, user label, configured environment, hosted preview branch,
  and local database branch are separate concepts. Keep their provenance and
  precedence explicit in code, tests, diagnostics, and documentation.
- The accepted v0.2 vocabulary, exact display forms, privacy defaults, manual
  label precedence, and synced-decoration boundary live in
  `docs/design/v0.2-target-context-contract.md`. Synced decorations require a
  separate opt-in provenance store; they must not silently extend or overwrite
  the manual-label store.
