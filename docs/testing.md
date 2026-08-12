# Testing

## Canonical runner

`tests/run.zsh` is the only supported local and CI entrypoint. It starts maintained first-party suites in isolated `zsh -f` processes with a fresh temporary `ZDOTDIR` so user shell configuration cannot affect a result.

Run the standard release suite with the system Zsh:

```sh
ZSH_BIN="$(command -v zsh)" tests/run.zsh
```

Run it with a specific interpreter:

```sh
ZSH_BIN=/path/to/zsh tests/run.zsh
```

Add the performance suite explicitly:

```sh
ZSH_BIN=/path/to/zsh tests/run.zsh --performance
```

The runner uses the tracked, audited test dependencies. It must not download a dependency, initialize a user shell profile, or rely on an ignored local Supabase project.

## Behavior matrix

The suite verifies behavior rather than xtrace-derived coverage percentages. Critical cases include:

- valid stable v2.72.7 and v2.113.0 layouts render the full reference;
- config-only state is silent unless an explicit valid remote selector is configured;
- live state outranks configured mappings and labels;
- malformed, multi-line, oversized, unreadable, or symlinked identity-critical input is silent, while unsafe optional local-db state is omitted without hiding a separately valid live ref;
- nearest-boundary selection, nested boundaries, and strict `SUPABASE_WORKDIR` behavior;
- fresh same-directory rereads after a local `project-ref` or local DB-branch change;
- local DB branch state is ignored by default and unambiguously labeled when enabled;
- dangerous `%`, ESC/CSI/OSC, whitespace, Unicode/control, and symlink payloads never reach actual Spaceship v4 rendered prompt bytes;
- the documented idempotent registration guard adds exactly one `supabase` section before `char`, and a real vendored Spaceship v4 compose path renders the section after registration;
- labels cannot revive an identity and their helper commands preserve privacy, permissions, and atomic update behavior; and
- prompt rendering makes no writes, network calls, Supabase CLI calls, Python/Node/jq calls, or credential reads.

For the v0.2 beta synced-project slice, the maintained integration suite also
uses a controlled fake `supabase` executable **only** in explicit-helper tests.
It covers the v2.72.7 JSON array and current `projects` envelope, exact-ref
matching, default confirmation and `--yes`, manual-label independence and
precedence, redacted error paths, malformed/oversized streaming output, child
cleanup, ref recheck before write, owner-only atomic state, and no-live-ref
short-circuiting. It proves that unsafe state and fake-CLI payloads cannot
reach actual Spaceship v4 rendering.

The suite also checks every documented default and supported option. It deliberately does not impose a numeric xtrace coverage threshold: explicit critical failure-path cases are the release gate.

## Fixtures

Fixtures are flat, synthetic, and tracked. Tests materialize the relevant runtime paths under a temporary directory. They use fake all-letter references only and must not contain:

- a real project reference, project configuration, token, environment file, or user path;
- a captured local `supabase/` tree;
- a symlink that points outside the temporary test root; or
- a dependency on a developer's ignored state.

The repository ignores root-local `/supabase/` and `/.supabase/` state without ignoring the tracked test fixture inputs.

## Performance policy

The optional benchmark builds a valid live stable-layout fixture and performs
five independent batches of 100 renders for both the ref-only baseline and an
enabled `label+ref` plus matching `synced:project` decoration. On Linux, each
scenario must keep a median P99 below 5 ms and a maximum P99 below 15 ms.
macOS reports samples without enforcing those timing thresholds. CI publishes
the samples in its summary.

The direct live path is intentionally cache-free and contains no external process invocation. If a benchmark regresses, investigate filesystem safety checks and renderer integration before introducing stale render caching.

## Vendored dependencies

The repository vendors audited copies of Spaceship Prompt and shunit2 for deterministic tests. Their upstream locations, immutable revisions, licenses, and update procedure are recorded in [`tests/vendor/DEPENDENCIES.md`](../tests/vendor/DEPENDENCIES.md). Updating a vendor is a deliberate reviewable change: record the new immutable revision, validate license and integrity, rerun the entire suite, and update compatibility documentation if its tested surface changes.
