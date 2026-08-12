# Compatibility

## Supported environment

v0.1.1 supports:

- Zsh 5.2 and later;
- Spaceship Prompt v4 through the `spaceship::section::v4` interface; the audited test dependency is v4.21.0;
- macOS and Linux; release CI covers Ubuntu 24.04, macOS 15, and a built Zsh 5.2 compatibility lane; and
- the stable Supabase CLI local layouts represented by the v2.72.7 and v2.113.0 fixtures.

The section does not invoke the CLI at prompt time. Fixture versions therefore validate the on-disk contract, not an executable dependency or a claim that every CLI command is supported.

## Stable layout contract

The supported layout is:

```text
<project-root>/supabase/config.toml
<project-root>/supabase/.temp/project-ref
```

The ref must be exactly 20 lowercase ASCII letters. `config.toml` is a project-boundary marker; it is not automatically treated as the live hosted identity source. See [data sources](data-sources.md).

The optional `supabase/.branches/_current_branch` input is a local database-branch file, not hosted branch state. It is disabled by default and, when enabled, is rendered only with a live ref as `local-db:<name>`.

## Fail-closed policy

An unsupported, malformed, unreadable, oversized, symlinked, or ambiguous **identity-critical** root/config/live-ref layout is not a compatibility fallback. It renders no segment. This is a security property: a terminal prompt must not turn arbitrary filesystem bytes into trusted context. The local-db branch is optional decoration: an unsafe branch file is omitted while an independently valid live ref remains visible.

v0.1.1 intentionally does not support:

- `.supabase/project.json`, which belongs to the alpha next/V3 shell rather than
  the stable CLI contract;
- hosted-branch inference from the local database branch file;
- automatic config remote selection or top-level `project_id` fallback;
- remote API or CLI enrichment during a prompt render;
- historical project identity caches, arbitrary prompt templates, ref truncation, or branch-only output.

## Future adapters

A `.supabase/project.json` adapter is deferred. It can be considered only as an explicit opt-in after Supabase publishes a stable, documented contract and this project can give it the same bounded parsing, symlink protections, fail-closed behavior, and test coverage as the current stable layout. Until then, do not create a symlink or compatibility shim to make the section consume it.

An adapter for stable CLI telemetry metadata at
`supabase/.temp/linked-project.json` is not part of v0.1.1 and is a deliberate
v0.2/first-external-beta no-go. Although recent stable versions write the file,
it is an undocumented, best-effort name snapshot with no freshness timestamp
rather than identity authority. Reconsider it only after Supabase publishes a
stable documented metadata contract and the project records a new product
decision. See the [primary-source research report](research/supabase-cli-project-names.md)
and [#5](https://github.com/junyoung2015/spaceship-supabase/issues/5).

## Report a compatibility issue

For a non-security compatibility problem, first run the local `spaceship_supabase_doctor` command and consult [troubleshooting](troubleshooting.md). Then open a GitHub issue using the relevant public template with sanitized, minimal reproduction details. Do not attach credentials, access tokens, full local paths, or private configuration files.
