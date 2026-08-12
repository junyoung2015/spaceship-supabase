# Roadmap

`spaceship-supabase` exists to answer a safety-critical question before a
developer runs a Supabase command:

> Which hosted project and environment am I operating against right now?

The prompt is a decision aid, not an authorization boundary. It cannot stop a
bad deployment by itself, but it can make a target mismatch visible before a
developer updates the wrong environment. It reflects supported local link state;
an explicit command target such as `--project-ref`, selected credentials, or
another command-specific override can still direct an operation elsewhere.

## Current status

- Current stable release: `v0.1.1`.
- Active product milestone: [`v0.2.0`](https://github.com/junyoung2015/spaceship-supabase/milestone/1)
  — human-readable target context.
- Active work tracker: the GitHub Issues mapped below and assigned to that
  milestone.
- Shipped behavior: [`CHANGELOG.md`](../CHANGELOG.md).
- Completed first-release plan:
  [`docs/releases/v0.1.0-release-plan.md`](releases/v0.1.0-release-plan.md).
- Current source research:
  [`docs/research/supabase-cli-project-names.md`](research/supabase-cli-project-names.md).
- Accepted v0.2 product contract:
  [`docs/design/v0.2-target-context-contract.md`](design/v0.2-target-context-contract.md).

The milestone has no calendar deadline. It closes when its outcome and safety
gates are met.

## How planning evolved

The planning system changed as the project and its risks became clearer.

### 1. Initial-plan phase

The project started with six iterative initial plans and a final pre-BMad plan.
We refer to that phase as `docs/initial-plan`. In the private historical
workspace, the raw files remain under `docs/plan-before-bmm/` as
`initial-plan-01.md` through `initial-plan-06.md` and `final-plan.md`.
They are intentionally not part of the canonical release tree; this roadmap
preserves the durable history without publishing every exploratory draft.

Those plans found the core problem: a raw Supabase project ref is truthful but
hard to recognize, while a network request on every prompt would be unusably
slow. They also proposed caches, branch inference, and broad customization that
later proved too easy to make stale or misleading.

### 2. BMad planning and implementation phase

The project then used BMad for its product brief, PRD, architecture, epics,
stories, and implementation tracking. We refer to that phase as
`_bmad-implementation`; its private archived files are stored under
`_bmad-output/`.

BMad helped turn the idea into working code and captured useful reasoning. It
also preserved alpha assumptions that no longer match the stable Supabase CLI
or the released fail-closed contract. In particular, automatic config fallback,
hosted-branch inference from local database state, prompt identity caches, and
arbitrary output formats are superseded. The archive remains historical
evidence, not an executable backlog.

### 3. Stable-release re-audit

After returning from the six-month break, we re-audited the implementation,
Supabase CLI sources, tests, security boundary, documentation, and release
process. That work produced the stable v0.1 contract and exposed why the old
backlog should not simply resume. The completed
[`v0.1.0` release plan](releases/v0.1.0-release-plan.md) records that hardening
and public-release cutover.

### 4. GitHub Issues phase

From v0.2 onward:

- this roadmap records product direction and release outcomes;
- GitHub milestones and issues record active scope, dependencies, and status;
- research reports under `docs/research/` record external compatibility facts;
- pull requests carry implementation and verification evidence;
- `CHANGELOG.md` records shipped and unreleased changes; and
- initial-plan and BMad files remain frozen in the private archive.

An issue state is the authoritative progress state. Do not mirror issue status
back into the BMad sprint tracker; its `tracking_system: file-system` value is a
historical snapshot, not the current workflow.

| Question | Current source of truth |
| --- | --- |
| Why are we building this? | `docs/roadmap.md` |
| What are we doing now? | GitHub milestone and open issues |
| What is under review? | GitHub pull requests |
| What has shipped? | `CHANGELOG.md`, tags, and GitHub Releases |
| Why did an old design exist? | Frozen private initial-plan and BMad history |

## Product principles

Every roadmap item must preserve these rules:

1. **Show the authoritative ref.** A human name or environment is decoration;
   the complete validated 20-character ref remains visible.
2. **Never invent branch meaning.** Local database branches, hosted preview
   branches, configured environments, user labels, and project names are
   different concepts and must be labeled according to their actual source.
   `Production` and `Staging` are user/workflow vocabulary unless an explicit
   configured source says otherwise; a default branch alone proves neither.
3. **Make provenance reviewable.** A user must be able to learn whether a name
   came from their label, a matching local CLI snapshot, configured mapping, or
   an explicit refresh.
4. **Keep the prompt path local and read-only.** No CLI process, network call,
   credential lookup, external parser, or write may occur during rendering.
5. **Live identity wins.** Decoration must match the currently validated live
   ref and must disappear rather than select, replace, or resurrect identity.
6. **Fail closed.** Malformed, oversized, unreadable, symlinked, ambiguous, or
   injection-bearing state never reaches Spaceship prompt bytes.
7. **Stay fast.** Direct rendering retains the existing Ubuntu release budget:
   five 100-render batches, median P99 below 5 ms and maximum P99 below 15 ms.

## Now: v0.2.0 — human-readable target context

### Outcome

A developer switching among Supabase projects and environments can recognize
the current target at a glance without losing the exact ref needed to verify
it. This reduces the chance of running `db push`, deploying a function, or
performing another mutation against the wrong environment.

Today, a user can already assign a safe local label:

```zsh
SPACESHIP_SUPABASE_FORMAT="label+ref"
spaceship_supabase_label set "Production"
```

```text
🔷 Production (abcdefghijklmnopqrst)
```

v0.2 builds on that safe base. It does not replace it with an opaque automatic
name.

### Delivery sequence

1. **Lock the target-context vocabulary and provenance UX.** The accepted
   [`v0.2 target-context contract`](design/v0.2-target-context-contract.md)
   defines exactly what `project name`, `manual label`, `configured mapping`,
   `hosted branch`, and `local database branch` mean; it also freezes the
   smallest readable forms, privacy defaults, and decoration precedence before
   feature code begins.
2. **Make manual custom names first-class.** Improve discovery, examples, and
   diagnostics around the existing ref-keyed label workflow. This is the most
   dependable way to express operational vocabulary such as `Production` or
   `Customer staging` across every supported CLI layout.
3. **Add explicit project-name discovery.** A user-invoked helper may call
   authenticated Supabase CLI commands, require an exact live-ref match, show
   the proposed mapping, and atomically update a provenance-aware, user-owned
   decoration record. It must not overwrite a manual label; the manual label
   wins when both exist. The helper must never run automatically or from prompt
   rendering.
4. **Run a guarded local-snapshot adapter spike.** The stable CLI's
   `linked-project.json` is internal telemetry state, not a documented identity
   interface. It has no freshness timestamp and can retain old data. Ship an
   opt-in adapter only if a bounded Zsh-native parser and clear link-time
   provenance justify the complexity; require its embedded ref to exactly match
   the independently validated live `project-ref`. Otherwise record the no-go
   decision and keep the explicit-refresh/manual-label path.
5. **Treat hosted branch/environment display as research-gated.** An explicit
   refresh may map a branch ref to a hosted branch name only when a pinned
   stable CLI response identifies that exact ref. The first design should
   require or explicitly obtain the parent project ref rather than scanning an
   account silently. No local database branch, Git branch, config table name,
   or project-name guess may masquerade as a hosted branch.
6. **Ship the full trust and compatibility gate.** Add pinned synthetic
   fixtures, actual Spaceship v4 injection tests, freshness and mismatch tests,
   helper permission/atomicity tests, CLI/network call-boundary tests,
   cross-version CI, performance samples, and synchronized documentation.

### GitHub issue map

GitHub holds execution status; this map records stable scope and dependency
order without duplicating open/closed state in this document.

| Issue | Outcome | Depends on |
| --- | --- | --- |
| [#3 — CLI name and branch research](https://github.com/junyoung2015/spaceship-supabase/issues/3) | Verify stable local and explicit-refresh sources. | — |
| [#4 — target-context UX](https://github.com/junyoung2015/spaceship-supabase/issues/4) | Define truthful vocabulary, display, privacy, and precedence. | #3 |
| [#5 — linked project-name decoration spike](https://github.com/junyoung2015/spaceship-supabase/issues/5) | Decide whether guarded, ref-matched telemetry state is worth supporting. | #3, #4 |
| [#6 — explicit project/branch sync](https://github.com/junyoung2015/spaceship-supabase/issues/6) | Resolve exact remote context only on an explicit user action. | #3, #4 |
| [#7 — security and compatibility coverage](https://github.com/junyoung2015/spaceship-supabase/issues/7) | Prove enrichment remains safe, compatible, fresh, and fast. | #5, #6 |
| [#8 — provenance and migration docs](https://github.com/junyoung2015/spaceship-supabase/issues/8) | Publish complete behavior, privacy, and troubleshooting guidance. | #4–#6 |
| [#9 — v0.2.0 release](https://github.com/junyoung2015/spaceship-supabase/issues/9) | Dogfood, pass the release gate, tag, and publish. | #3–#8 |

### Release acceptance

`v0.2.0` is complete only when:

- a new user can identify the current project more easily than from the ref
  alone while the full ref remains visible;
- a manual user label has clear precedence over automatic decoration;
- every automatic name is bound to the currently validated ref;
- source absence, mismatch, same-ref outdated-name behavior, malformed JSON,
  unsafe paths, duplicate data, and prompt-control payloads have explicit
  failure-path tests;
- hosted branch/environment text is displayed only from a source whose exact
  semantics are verified and documented;
- prompt rendering remains local-only, read-only, network-free, CLI-free,
  credential-free, cache-free for identity, and within the release benchmark;
- doctor output reports source status without leaking raw untrusted state;
- supported Supabase CLI versions and unsupported layouts are documented; and
- README, configuration, data-source, labels, compatibility, troubleshooting,
  testing, AGENTS, and changelog documentation agree.

### Explicit non-goals

v0.2 does not promise:

- a network-fresh project name on every prompt;
- a hosted branch inferred from `supabase/.branches/_current_branch`;
- a name or branch that can replace the authoritative ref;
- arbitrary prompt templates, ref truncation, or name-only output;
- automatic background refresh, prompt-time persistence, or silent credential
  use;
- deployment blocking or confirmation prompts; or
- support for a non-stable CLI layout merely because source code exists for
  it.

## Next

After v0.2 proves target recognition in daily use:

- design a versioned installer/updater using immutable release assets and
  checksum verification, without a mutable unaudited `curl | sh` default;
- evaluate an explicit user-owned protected-environment marker, such as a
  stronger visual warning for a ref the user has labeled `Production`;
- improve doctor and helper UX from real support reports; and
- reassess supported CLI adapters whenever Supabase publishes a stable local
  metadata contract.

## Later

These remain research topics rather than commitments:

- authoritative live hosted-branch context without an explicit refresh;
- remote status or health decoration;
- integration with a documented future `.supabase/project.json` contract;
- cross-shell or non-Spaceship prompt support; and
- command interception or deployment guardrails beyond passive prompt context.

## GitHub workflow

- New work starts as a GitHub issue with a user-visible outcome, failure modes,
  acceptance criteria, and the `v0.2.0` milestone when applicable.
- Research claims link to primary sources and a report under `docs/research/`.
- Product-contract changes require an issue decision before implementation.
- Pull requests link or close their issue and include the canonical test command
  plus any security/performance evidence required by the change.
- Scope discovered during implementation becomes a linked issue instead of an
  unrecorded expansion.
- Closing the milestone requires every acceptance gate above, not merely closed
  issue counts.

The roadmap is intentionally outcome-oriented. GitHub contains the changing
execution details; this document changes only when product direction, milestone
scope, or a durable constraint changes.
