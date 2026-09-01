# Roadmap

`spaceship-supabase` exists to answer a safety-critical question before a
developer runs a Supabase command:

> Which linked Supabase target am I operating against right now?

The prompt is a decision aid, not an authorization boundary. It cannot stop a
bad deployment by itself, but it can make a target mismatch visible before a
developer updates the wrong environment. It reflects supported local link state;
an explicit command target such as `--project-ref`, selected credentials, or
another command-specific override can still direct an operation elsewhere.

## North star

Make Supabase target context continuously trustworthy: the exact linked
identity is always visible, human context is added only with reviewable
provenance or an explicit user-owned label, and prompt rendering has no hidden
CLI, network, credential, parser-process, cache, or write side effects.

The long-term product may distinguish top-level projects, hosted branch
environments, and stronger user-owned risk markers. Each layer earns its place
independently. A milestone is complete when its narrower promise is useful and
truthful; it does not wait for every possible enrichment source merely because
that source fits the north star.

## Current status

- Current stable release: `v0.1.1`.
- Historical beta.1 result: `v0.2.0-beta.1` is an immutable, rejected,
  unpublished tag. Its tag release gate failed before GitHub publication, so it
  must not be installed, retagged, or republished.
- Published private-dogfood prerelease: `v0.2.0-beta.2`. It remains immutable,
  but its current-style explicit-sync path is superseded after dogfood found a
  fail-closed envelope incompatibility.
- Historical private-dogfood candidate: `v0.2.0-beta.3` is immutable and
  carries [#27](https://github.com/junyoung2015/spaceship-supabase/issues/27)'s
  narrow parser repair.
- Private-dogfood successor candidate: `v0.2.0-beta.4` retains beta.3's
  bounded sync scope and makes the host-owned default registration change that
  places the section before a present `line_sep`, leaving the identity on the
  first status/context line and the prompt character on the next in Spaceship's
  default two-line layout. It also makes `at ` the default section-level
  target/context prefix, with an explicitly empty prefix as the compact opt-out.
  The prefix does not establish live-link, environment, authorization, or
  freshness provenance. beta.4 may publish only as a reviewed annotated tag and is
  neither beta.4 dogfood authorization nor approval for external or
  phase-2-alpha invitations. The current two-person authorization in #15 is
  beta.3-only; beta.4 needs its own explicit decision after publication.
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
- Beta decision evidence template, currently unpopulated and not approval for
  an external beta merely because a private-dogfood prerelease exists:
  [`docs/beta/v0.2-beta-acceptance-report-template.md`](beta/v0.2-beta-acceptance-report-template.md).

The milestone has no calendar deadline. It closes when its outcome and safety
gates are met.

### Tracker-alignment gate for this CTO decision

This branch records the 2026-09-01 CTO scope decision, but a pull request does
not silently rewrite the live tracker. GitHub issues and milestones remain the
authoritative execution state. Until this PR is merged and the tracker is
synchronized, #9's current dependency on #13 and #13's current v0.2 milestone
assignment continue to block stable release preparation.

Immediately after merge—and before tagging beta.4—the release owner must update
#9's dependencies and acceptance criteria, move #13 out of the v0.2 milestone,
align the milestone description with the bounded stable outcome below, and
create or explicitly designate a beta.4 release issue that owns the exact
candidate scope, tag/publication gates, rollback accountability, and link to
this implementation PR. If those changes are not made, the narrower boundary
in this document is not operational authorization to tag or promote v0.2.

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
   came from their manual label, a configured mapping, or an explicit remote
   sync record. The telemetry snapshot is not a v0.2 source.
4. **Keep the prompt path local and read-only.** No CLI process, network call,
   credential lookup, external parser, or write may occur during rendering.
5. **Live identity wins.** Decoration must match the currently validated live
   ref and must disappear rather than select, replace, or resurrect identity.
6. **Fail closed.** Malformed, oversized, unreadable, symlinked, ambiguous, or
   injection-bearing state never reaches Spaceship prompt bytes.
7. **Stay fast.** Direct rendering retains the existing Ubuntu release budget:
   five 100-render batches, median P99 below 5 ms and maximum P99 below 15 ms.

## Now: v0.2.0 — trustworthy project target context

### Outcome

A developer switching among linked Supabase targets can recognize a top-level
project at a glance without losing the exact ref needed to verify it. A hosted
branch ref remains fully and truthfully supported as identity and can carry a
manual label, but v0.2 does not automatically discover or claim its hosted
branch name. This reduces the chance of running `db push`, deploying a
function, or performing another mutation against the wrong target without
overstating what the local evidence proves.

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

1. **Keep the vocabulary and provenance contract fixed.** The accepted
   [`v0.2 target-context contract`](design/v0.2-target-context-contract.md)
   defines `project name`, `manual label`, `configured mapping`, `hosted
   branch`, and `local database branch`; it also fixes the readable forms,
   privacy defaults, and decoration precedence. Feature work does not reopen
   those semantics without a new product decision.
2. **Keep the beta.1-defined enrichment narrow.** The `v0.2.0-beta.4`
   candidate retains [#6](https://github.com/junyoung2015/spaceship-supabase/issues/6):
   an explicit, user-confirmed top-level project sync that matches only the
   current valid live ref through a user-invoked Supabase CLI action and saves a
   separate provenance-aware `synced:project` decoration. It never overwrites a
   manual label and never runs from prompt rendering. beta.4 retains the
   narrowly bounded [#27](https://github.com/junyoung2015/spaceship-supabase/issues/27)
   repair for the fixed current CLI envelope, not a relaxation of source
   validation. beta.4 changes only presentation: the documented host-owned
   prompt placement and the default `at ` target/context prefix.
3. **Retain proof that the beta candidate cannot weaken the prompt.**
   [#7](https://github.com/junyoung2015/spaceship-supabase/issues/7) provides
   the fake-CLI boundary, separate-state, actual Spaceship v4 injection,
   cross-version, freshness, and performance tests. [#8](https://github.com/junyoung2015/spaceship-supabase/issues/8)
   promotes only implemented behavior into public reference docs.
4. **Keep prerelease publication reviewable before inviting anyone.**
   [#14](https://github.com/junyoung2015/spaceship-supabase/issues/14) provides
   the guarded annotated `v0.2.0-beta.N` prerelease path. beta.1 is rejected
   and unpublished; beta.2 is published but superseded for current-style sync;
   beta.3 is immutable; beta.4 is the sole successor candidate but has no
   dogfood authorization until an immutable prerelease exists and the release
   owner records an explicit beta.4 decision in #15.
   [#15](https://github.com/junyoung2015/spaceship-supabase/issues/15)
   provides the redacted go/extend/pause evidence structure; its working term
   “Dongtan report” remains undefined until the board supplies the audience,
   access, confidentiality, security-route, and approval decisions.
5. **Treat hosted-branch display as post-v0.2 discovery, not a stable-release
   dependency.** [#13](https://github.com/junyoung2015/spaceship-supabase/issues/13)
   remains a sound separately gated design. It requires a user-supplied parent
   ref and one exact remote branch-project-ref match; no local database branch,
   Git branch, config name, or project-name guess may masquerade as a hosted
   branch. It should move into delivery only after at least two independent
   users report recurring hosted-branch recognition pain that manual labels do
   not solve, and after a supported machine-readable branch-list contract is
   pinned. Until then, a manual label bound to the full branch ref is the
   supported recognition path.
6. **Keep the telemetry snapshot out of the beta.**
   [#5](https://github.com/junyoung2015/spaceship-supabase/issues/5) is a
   deliberate no-go for `linked-project.json` in v0.2 and the first external
   beta. The prompt continues to use manual labels and the explicit confirmed
   sync record instead.

### GitHub issue map

GitHub holds execution status; this map records stable scope and dependency
order without duplicating open/closed state in this document.

| Issue | Outcome | Depends on |
| --- | --- | --- |
| [#3 — CLI name and branch research](https://github.com/junyoung2015/spaceship-supabase/issues/3) | Verify stable local and explicit-refresh sources. | — |
| [#4 — target-context UX](https://github.com/junyoung2015/spaceship-supabase/issues/4) | Define truthful vocabulary, display, privacy, and precedence. | #3 |
| [#5 — linked project-name decoration spike](https://github.com/junyoung2015/spaceship-supabase/issues/5) | Closed no-go: do not consume undocumented telemetry state in v0.2 or the first external beta. | #3, #4 |
| [#6 — explicit top-level project sync](https://github.com/junyoung2015/spaceship-supabase/issues/6) | Implement the small v0.2 explicit `synced:project` path. | #3, #4 |
| [#7 — security and compatibility coverage](https://github.com/junyoung2015/spaceship-supabase/issues/7) | Prove the explicit sync path remains safe, compatible, fresh, and fast. | #6 |
| [#8 — provenance and migration docs](https://github.com/junyoung2015/spaceship-supabase/issues/8) | Publish the implemented v0.2 behavior, privacy, and troubleshooting guidance. | #4, #6, #7 |
| [#13 — hosted-branch sync](https://github.com/junyoung2015/spaceship-supabase/issues/13) | Post-v0.2 discovery for explicit hosted-branch decoration after demonstrated demand and an exact parent-scoped proof. | #6, #7 |
| [#14 — guarded prerelease publishing](https://github.com/junyoung2015/spaceship-supabase/issues/14) | Publish `v0.2.0-beta.N` through the full release gate without changing stable releases. | #6, #7, #8 |
| [#15 — redacted beta acceptance report](https://github.com/junyoung2015/spaceship-supabase/issues/15) | Prepare and later populate board-gated go/extend/pause evidence. | #6, #7, #8, #14 |
| [#19 — v0.2.0-beta.1 private dogfood prerelease](https://github.com/junyoung2015/spaceship-supabase/issues/19) | Historical rejected/unpublished beta.1 candidate; preserve its failed-gate evidence and do not retag or publish it. | #6–#8, #14 |
| [#25 — v0.2.0-beta.2 private dogfood prerelease](https://github.com/junyoung2015/spaceship-supabase/issues/25) | Cut the successor candidate with only merged release/test reliability fixes; no new customer feature or external-beta approval. | #6–#8, #14, #19 |
| [#27 — current CLI JSON envelope compatibility](https://github.com/junyoung2015/spaceship-supabase/issues/27) | Accept the stable `{ projects, message: "" }` explicit-sync envelope without weakening bounded validation. | #6, #7, #25 |
| [#29 — v0.2.0-beta.3 private dogfood prerelease](https://github.com/junyoung2015/spaceship-supabase/issues/29) | Historical beta.3 candidate carrying only #27's bounded current-CLI compatibility repair; beta.4 is its successor candidate with documented host-layout and `at ` prefix defaults and must receive its own immutable tag. | #6–#8, #14, #25, #27 |
| [#9 — v0.2.0 release](https://github.com/junyoung2015/spaceship-supabase/issues/9) | Dogfood beta.4, record the release decision, pass the release gate, tag, and publish the stable release. | #3, #4, #6–#8, #14, #15 |

### Release acceptance

`v0.2.0` is complete only when:

- this PR's post-merge tracker alignment is complete before beta.4 is tagged;
- a dedicated live beta.4 release issue owns the exact candidate, tag,
  publication, and rollback gates;
- a new user can identify the current project more easily than from the ref
  alone while the full ref remains visible;
- a manual user label has clear precedence over automatic decoration;
- every automatic name is bound to the currently validated ref;
- the top-level synced-project beta path has passed a tagged prerelease,
  redacted acceptance report, and the full release gate before broader beta
  invitations;
- source absence, mismatch, same-ref outdated-name behavior, unsafe paths,
  duplicate data, helper-output variants, and prompt-control payloads have
  explicit failure-path tests;
- v0.2 emits no automatic hosted-branch text; a linked branch ref remains
  visible in full and may use a manual label without implying remote freshness;
- prompt rendering remains local-only, read-only, network-free, CLI-free,
  credential-free, cache-free for identity, and within the release benchmark;
- doctor output reports source status without leaking raw untrusted state;
- supported Supabase CLI versions and unsupported layouts are documented; and
- README, configuration, data-source, labels, compatibility, troubleshooting,
  testing, AGENTS, and changelog documentation agree.

### Explicit non-goals

v0.2 does not promise:

- a network-fresh project name on every prompt;
- automatic hosted-branch discovery or `synced:hosted-branch` output;
- a hosted branch inferred from `supabase/.branches/_current_branch`;
- use of the undocumented `linked-project.json` telemetry snapshot in v0.2 or
  the first external beta;
- a name or branch that can replace the authoritative ref;
- arbitrary prompt templates, ref truncation, or name-only output;
- automatic background refresh, prompt-time persistence, or silent credential
  use;
- deployment blocking or confirmation prompts; or
- support for a non-stable CLI layout merely because source code exists for
  it.

## Next: v0.3 operating excellence

After v0.2 proves the target-context contract in daily use, v0.3 should make
the trustworthy behavior easier to install, update, recover, and support:

- provide a versioned installer/updater using immutable release assets and
  checksum verification, without a mutable unaudited `curl | sh` default;
- make upgrade and rollback instructions account for both the plugin tag and
  user-owned prompt-order configuration;
- improve doctor and helper UX from real support reports, with actionable
  redacted diagnostics for known installation and configuration failures; and
- automate compatibility evidence for supported Zsh, Spaceship, Supabase CLI,
  and common section load-order combinations.

An explicit protected-environment marker and [#13](https://github.com/junyoung2015/spaceship-supabase/issues/13)
remain candidates for later milestones, not promises for v0.3. Promote either
only after real user evidence, a reviewed product contract, and its own
failure-path and rollback proof.

## Twelve-month v1 direction

`v1.0.0` means the passive target-context layer is dependable as a maintained
tool, not merely feature-rich:

- no unresolved false-target, stale-identity resurrection, or prompt-injection
  incident exists in the supported release line;
- the full authoritative ref and provenance rules remain invariant across every
  supported decoration source;
- installation, exact-version update, and rollback are documented and proven
  on the supported macOS/Linux and Zsh/Spaceship matrix;
- prompt performance stays inside the five-batch budget of median P99 below
  5 ms and maximum P99 below 15 ms;
- doctor output identifies supported failure classes without exposing raw
  project state; and
- at least five independent exact-release install/update/rollback exercises,
  or the entire deliberately smaller invited cohort, complete successfully.

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
