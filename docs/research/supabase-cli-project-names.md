# Supabase CLI project names and branch identity research

- **Status:** research input for the `spaceship-supabase` v0.2 roadmap
- **Tracking:** [GitHub issue #3](https://github.com/junyoung2015/spaceship-supabase/issues/3)
- **Decision update:** [#5](https://github.com/junyoung2015/spaceship-supabase/issues/5) records a no-go for consuming `linked-project.json` in v0.2 and its first external beta. The explicit top-level project sync in [#6](https://github.com/junyoung2015/spaceship-supabase/issues/6) remains the only planned remote-derived beta.1 decoration source; hosted-branch sync is separately deferred to [#13](https://github.com/junyoung2015/spaceship-supabase/issues/13).
- **As of:** 2026-08-11
- **CLI snapshots inspected:** `v2.72.7`, locally installed `v2.111.0`, and latest stable `v2.113.0`
- **Primary-source policy:** this report uses only Supabase's official
  documentation and changelog, the official `supabase/cli` repository at pinned
  revisions, official GitHub release metadata, and local CLI `--help` output.

## Executive conclusion

The safest v0.2 product direction is to keep the current 20-letter project reference as the identity anchor and make human-readable text a strictly secondary decoration:

```text
Production (abcdefghijklmnopqrst)
```

The stable Supabase CLI contract still makes `supabase/.temp/project-ref` the checkout's local linked-project reference. That statement holds in the Go implementation shipped at `v2.72.7` and in both the current stable TypeScript legacy shell and its Go parity implementation at `v2.111.0` and `v2.113.0`. The ref is validated as exactly 20 lowercase letters in all three inspected versions. [`v2.72.7` path and pattern](https://github.com/supabase/cli/blob/v2.72.7/internal/utils/misc.go#L50-L79), [`v2.72.7` resolver](https://github.com/supabase/cli/blob/v2.72.7/internal/utils/flags/project_ref.go#L54-L75), [`v2.113.0` paths and pattern](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/utils/misc.go#L70-L99), [`v2.113.0` stable-shell resolver](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/config/legacy-project-ref.layer.ts#L81-L152)

Supabase project names are available, but no inspected stable local file is both authoritative and guaranteed fresh:

- `supabase projects list` returns Management API project records with human-readable names, but it requires authentication and a network request. It therefore belongs in an explicit user-run refresh or discovery helper, never prompt rendering. [`v2.113.0` projects-list side effects](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/SIDE_EFFECTS.md#L3-L36), [official CLI reference](https://supabase.com/docs/reference/cli/supabase-projects-list)
- `supabase/.temp/linked-project.json` contains a project ref and name in recent CLI versions, but it was introduced as PostHog telemetry metadata, is best-effort, is not overwritten by ordinary cache-fill runs, and may be absent for linked hosted branch projects. It is shipped local state, but it is not a documented identity contract. The resulting v0.2 decision is **not to consume it** in the prompt or first external beta. [`v2.87.0` telemetry schema](https://github.com/supabase/cli/blob/v2.87.0/internal/telemetry/project.go#L14-L49), [`v2.113.0` non-overwrite and best-effort rules](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/telemetry/legacy-linked-project-cache.layer.ts#L21-L35), [`v2.113.0` link side effects](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L16-L40)
- Project names are mutable through the Management API. A cached name can therefore become stale while the ref remains unchanged. [official Update a project API](https://supabase.com/docs/reference/api/v1-update-a-project), [`v2.113.0` generated update body](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/pkg/api/types.gen.go#L8927-L8930)
- `supabase/.branches/_current_branch` represents a **local database branch**. Hosted Supabase preview branches are Management API resources exposed by `supabase branches ...`; the two concepts must never be conflated. [`v2.113.0` local DB branch command](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/cmd/db.go#L40-L44), [`v2.113.0` hosted branch list](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/branches/list/list.go#L16-L81), [official Supabase Branching guide](https://supabase.com/docs/guides/deployment/branching)
- Since 2026-05-04, Supabase Branching without Git is the default and dashboard-created branches do not require a GitHub integration. A Git branch is therefore not a universal hosted-branch identity key. [official May 2026 announcement](https://supabase.com/blog/branching-without-git-is-now-the-default), [official May 2026 release update](https://github.com/supabase/supabase/releases/tag/v1.26.05)
- `.supabase/project.json` exists in the repository's next/V3 shell, but `v2.113.0` stable explicitly publishes the legacy shell, and the stable `link` command explicitly does not use that file. It is not a stable adapter target yet. [`v2.113.0` release-channel policy](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/README.md#L154-L181), [`v2.113.0` stable link side effects](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L1-L4)

**Recommended v0.2 outcome:** keep manual labels as the dependable, user-owned solution for recognizable environment names; research an opt-in, explicit refresh helper that fetches project names outside the prompt; retain the full ref in every rendering; and defer automatic hosted-branch naming until a branch ref can be matched exactly to a primary API response without guessing.

## How to read this report

The following labels are deliberate:

- **Verified fact** means the behavior is directly supported by a pinned source file, official documentation, an official release, or local CLI help.
- **Inference** means a consequence derived from verified behavior, but not promised by Supabase as a public contract.
- **Recommendation** is product guidance for `spaceship-supabase`; it is not a claim about the Supabase CLI.

The source inspection did not run authenticated Management API requests and did not read local Supabase credentials. Local checks were limited to the installed binary's version and help text:

```text
$ supabase --version
2.111.0

$ supabase projects list --help
List all Supabase projects the logged-in user can access.
...
supabase projects list --output-format json

$ supabase db branch --help
Manage local database branches.

$ supabase branches list --help
List all preview branches of a Supabase project.
```

The official GitHub latest-release response and release page identified `v2.113.0`, published 2026-08-08, as the latest stable version at the research date. [official latest-release API](https://api.github.com/repos/supabase/cli/releases/latest), [`v2.113.0` release](https://github.com/supabase/cli/releases/tag/v2.113.0)

A newer `v2.114.0-beta.8` existed at the cutoff, but GitHub marked it as a
prerelease and excluded it from the latest-stable endpoint. It was therefore
not treated as a stable compatibility contract. [`v2.114.0-beta.8` prerelease](https://github.com/supabase/cli/releases/tag/v2.114.0-beta.8)

## Compatibility matrix

| Concern | `v2.72.7` | local `v2.111.0` | latest stable `v2.113.0` | Product consequence |
|---|---|---|---|---|
| Stable shell | Go CLI | Stable legacy shell; TypeScript front end with Go parity/sidecar commands | Stable legacy shell; TypeScript front end with Go parity/sidecar commands | Test the old Go layout and current stable legacy shell semantics, not only repository `main` |
| Linked-ref file | `supabase/.temp/project-ref` | `supabase/.temp/project-ref` | `supabase/.temp/project-ref` | Safe cross-version identity anchor |
| Ref validation | `^[a-z]{20}$` | `^[a-z]{20}$` | `^[a-z]{20}$` | Continue exact validation; do not accept digits, uppercase, whitespace, or partial refs |
| `linked-project.json` | Absent in the inspected tag | Present under `supabase/.temp/`; telemetry/internal metadata | Present under `supabase/.temp/`; telemetry/internal metadata | Deliberate v0.2 and first-external-beta no-go; never identity |
| Project-name discovery | `supabase projects list --output json` returns project records plus `linked` | Local help supports `--output-format json`; legacy `--output json` remains available | `--output-format json` returns `{ "projects": [...] }`; legacy `--output json` returns the Go-compatible array | A refresh helper must version-detect or accept both JSON shapes |
| Local DB branches | Hidden/legacy `supabase db branch`; `_current_branch` | `supabase db branch`; `_current_branch` | `supabase db branch`; `_current_branch` | May render only as `local-db:<name>` when opted in |
| Hosted branches | `supabase branches ...` Management API commands | `supabase branches ...` Management API commands | `supabase branches ...` Management API commands | Requires explicit network-backed discovery; never infer from `_current_branch` |
| `.supabase/project.json` | Not used | Source may contain next-shell work, but local stable binary exposes legacy behavior | Next/V3 alpha-shell state; stable legacy `link` explicitly does not use it | Defer until a stable, documented contract exists |

Compatibility evidence: [`v2.72.7` ref definitions](https://github.com/supabase/cli/blob/v2.72.7/internal/utils/misc.go#L50-L79), [`v2.111.0` ref definitions](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/utils/misc.go#L70-L99), [`v2.113.0` ref definitions](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/utils/misc.go#L70-L99), [`v2.72.7` project-list output switch](https://github.com/supabase/cli/blob/v2.72.7/internal/projects/list/list.go#L16-L70), [`v2.113.0` stable project-list formats](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/list.handler.ts#L139-L178), [`v2.113.0` publishing model](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/README.md#L154-L181).

## 1. Authoritative linked-project reference

### 1.1 Path and validation

**Verified fact:** all three required versions define the linked-project file as:

```text
<project root>/supabase/.temp/project-ref
```

All three use the same exact project-ref regular expression, `^[a-z]{20}$`. The ref resolver trims the file contents and rejects a value that fails that pattern. [`v2.72.7` constants](https://github.com/supabase/cli/blob/v2.72.7/internal/utils/misc.go#L50-L79), [`v2.72.7` resolver](https://github.com/supabase/cli/blob/v2.72.7/internal/utils/flags/project_ref.go#L54-L75), [`v2.111.0` constants](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/utils/misc.go#L70-L99), [`v2.111.0` resolver](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/utils/flags/project_ref.go#L54-L75), [`v2.113.0` constants](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/utils/misc.go#L70-L99), [`v2.113.0` resolver](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/utils/flags/project_ref.go#L54-L75)

The current stable TypeScript legacy shell independently preserves that rule: its project-ref service uses `^[a-z]{20}$`, and its resolver considers the command flag, environment, and `supabase/.temp/project-ref` file. [`v2.113.0` stable-shell validation](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/config/legacy-project-ref.service.ts#L94-L99), [`v2.113.0` stable-shell resolution](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/config/legacy-project-ref.layer.ts#L81-L152)

**Inference:** for a prompt segment whose job is to prevent wrong-environment operations, this file is the best local statement of “what this checkout is linked to.” It is not proof of current network reachability or remote existence, but it is the exact local ref the stable CLI itself resolves for linked commands.

### 1.2 Link and unlink lifecycle

**Verified fact:** in `v2.72.7`, `supabase link` writes `project-ref` after
required project-status and API-key checks pass and the best-effort service-link
attempts finish. Individual service-link failures are non-fatal. `supabase
unlink` reads the ref for cleanup and then removes the entire `supabase/.temp`
directory. [`v2.72.7` link writer](https://github.com/supabase/cli/blob/v2.72.7/internal/link/link.go#L23-L35), [`v2.72.7` best-effort service linking](https://github.com/supabase/cli/blob/v2.72.7/internal/link/link.go#L38-L68), [`v2.72.7` unlink](https://github.com/supabase/cli/blob/v2.72.7/internal/unlink/unlink.go#L15-L41)

The same lifecycle remains in the Go parity implementation at `v2.111.0` and `v2.113.0`. [`v2.111.0` link writer](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/link/link.go#L24-L41), [`v2.111.0` unlink](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/unlink/unlink.go#L15-L41), [`v2.113.0` link writer](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/link/link.go#L24-L41), [`v2.113.0` unlink](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/unlink/unlink.go#L15-L41)

In the actual `v2.113.0` stable legacy TypeScript handler, writing `project-ref` is mandatory and happens after service linking; metadata cache writing happens afterward and is best-effort. [`v2.113.0` stable link writer](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/link.handler.ts#L145-L169), [`v2.113.0` stable link file contract](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L16-L29)

**Recommendation:** continue reading this file freshly on every prompt. Do not let a project-name cache, a manual label, a parent directory, or an earlier render keep output alive after the ref disappears or changes.

### 1.3 What the ref does not prove

**Verified fact:** stable `supabase link` tolerates a 404 from `GET /v1/projects/{ref}` specifically to support linking hosted branch projects, then continues through API-key/service linking and writes the ref. Project metadata is written only when the project lookup resolved. [`v2.113.0` link API rules](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L31-L40), [`v2.113.0` metadata condition](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/link.handler.ts#L153-L169), [`v2.113.0` Go branch-project handling](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/link/link.go#L240-L266)

**Inference:** a valid local ref means “the stable CLI linked this checkout to this ref,” not “this is definitely a top-level project,” “this ref is online,” “the remote name is fresh,” or “a hosted branch name is locally known.” The prompt should remain truthful by always showing the full ref and making any additional meaning explicit.

## 2. `linked-project.json`: useful metadata, not authority

### 2.1 Introduction and purpose

**Verified fact:** `supabase/.temp/linked-project.json` is absent from the inspected `v2.72.7` tree. It first appears between the inspected `v2.86.0` and `v2.87.0` tags in the change titled `feat: add posthog telemetry`; `v2.87.0` includes the file in `internal/telemetry/project.go`. [`v2.87.0` release](https://github.com/supabase/cli/releases/tag/v2.87.0), [PostHog telemetry commit](https://github.com/supabase/cli/commit/b9b62d864cd5df5fa369e872ee7265f958ea8903), [`v2.87.0` telemetry file](https://github.com/supabase/cli/blob/v2.87.0/internal/telemetry/project.go#L14-L49)

The schema has four strings:

```json
{
  "ref": "abcdefghijklmnopqrst",
  "name": "Human-readable project name",
  "organization_id": "...",
  "organization_slug": "..."
}
```

That shape remains in the `v2.111.0` and `v2.113.0` Go parity sources and in the `v2.113.0` stable TypeScript link writer. [`v2.111.0` schema](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/telemetry/project.go#L15-L49), [`v2.113.0` schema](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/telemetry/project.go#L15-L49), [`v2.113.0` stable writer](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/link.handler.ts#L156-L169)

**Verified fact:** the schema has no fetched-at, updated-at, generation, or expiry field. Unlike the next/V3 state discussed later, the stable telemetry snapshot carries no timestamp from which a consumer could establish freshness. [`v2.113.0` four-field telemetry schema](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/telemetry/project.go#L15-L20)

**Verified fact:** current source repeatedly names this a telemetry linked-project cache. The Go post-run hook says it exists so PostHog events can carry project and organization groups; the TypeScript port mirrors that hook. [`v2.113.0` Go post-run purpose](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/cmd/root.go#L206-L233), [`v2.113.0` TypeScript cache purpose](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/telemetry/legacy-linked-project-cache.layer.ts#L21-L35)

**Classification:** the file is **operationally shipped by stable CLI versions**, but it is **internal/telemetry state rather than a documented public identity interface**. This distinction matters. Its existence can be used as a conservative, version-pinned enhancement signal, but the product must work correctly when it is absent, malformed, stale, or removed. The inspected public CLI reference documents `projects list`, `link`, and `unlink`; the linked metadata filename is described in repository implementation notes rather than the public CLI reference. [official CLI reference](https://supabase.com/docs/reference/cli/introduction), [`v2.113.0` repository link side-effects document](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L16-L29)

### 2.2 Write and invalidation behavior

**Verified fact:** an explicit successful `supabase link` writes `linked-project.json` when `GET /v1/projects/{ref}` returns a resolvable project; the write is best-effort and does not determine link success. Hosted branch refs can follow the tolerated 404 path and receive no metadata file. [`v2.113.0` stable link contract](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L16-L40), [`v2.113.0` stable writer](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/link.handler.ts#L153-L169)

**Inference from the verified writer:** the hosted-branch 404 path skips the metadata write but does not remove an already-existing `linked-project.json`. Re-linking one checkout from a regular project to a hosted branch can therefore leave the old metadata file beside the newly written branch `project-ref`. This is stronger than ordinary rename staleness: the stale metadata may name a **different ref**. Exact equality between `linked-project.json.ref` and the current live `project-ref` is consequently a mandatory safety check, not an optimization. [`v2.113.0` mandatory ref write followed by conditional metadata write](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/link.handler.ts#L153-L169)

**Verified fact:** when another ref-resolving CLI command notices the cache is missing, the post-run telemetry hook may fetch the project and create it. That path is authenticated, network-backed, best-effort, and explicitly refuses to overwrite an existing file because `supabase link` is considered the authoritative writer. [`v2.113.0` Go cache-fill hook](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/cmd/root.go#L206-L233), [`v2.113.0` TypeScript cache-fill gate and request](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/telemetry/legacy-linked-project-cache.layer.ts#L64-L102)

**Verified fact:** the current TypeScript cache layer deliberately reads the four fields as strings without applying project-name or ref validation before writing. The source comments explicitly acknowledge this. [`v2.113.0` cache decoding](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/telemetry/legacy-linked-project-cache.layer.ts#L13-L35)

**Verified fact:** `supabase unlink` removes the containing `supabase/.temp` directory, so both `project-ref` and `linked-project.json` disappear together when unlink completes normally. [`v2.113.0` unlink](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/unlink/unlink.go#L15-L41)

### 2.3 Rename and staleness risk

**Verified fact:** a project name is mutable. The official Management API exposes `PATCH /v1/projects/{ref}` with a `name` body, and the generated CLI API model requires a name for the update request. [official Update a project API](https://supabase.com/docs/reference/api/v1-update-a-project), [`v2.113.0` generated request body](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/pkg/api/types.gen.go#L8927-L8930), [`v2.113.0` generated PATCH client](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/pkg/api/client.gen.go#L4824-L4868)

**Inference:** after a dashboard/API rename, an already-present `linked-project.json` can continue carrying the old name indefinitely. Ordinary telemetry cache-fill calls will not replace it. Running `supabase link` again can refresh it because the explicit link writer writes the file, but Supabase does not present this file as a freshness API.

The snapshot's lack of a timestamp means a consumer cannot distinguish “written a moment ago” from “written before a same-ref rename.” Even when its embedded ref matches the live ref, only the identity binding is verified; name freshness is not.

**Recommendation:** if v0.2 ever consumes this file, it must apply all of the following rules:

1. Establish the safe project root and valid live `project-ref` first.
2. Treat the metadata file as untrusted optional input with component symlink checks, a strict byte bound, strict JSON parsing outside the hot path only if a safe Zsh parser is feasible, and prompt-safe name validation.
3. Require `linked-project.json.ref` to exactly equal the current live ref.
4. Use only the name as decoration. Never let the file select or resurrect an identity.
5. Keep the full ref visible.
6. Document the name as a local snapshot that can become stale.
7. Fall back silently to ref-only output on every failure.

Given the parser complexity and the absence of a stable public contract, the lower-risk v0.2 sequence is to ship manual-label improvements first and place automatic `linked-project.json` consumption behind a separate product-contract decision.

### 2.4 v0.2 decision: do not consume the telemetry snapshot

[#5](https://github.com/junyoung2015/spaceship-supabase/issues/5) closed with a
deliberate **no-go** for `supabase/.temp/linked-project.json` in v0.2 and the
first external beta. The decision is not a claim that the file is malicious or
unsupported by the CLI. It follows from the product's safety goal: the file is
undocumented telemetry state, absent from the supported `v2.72.7` layout,
untimestamped, deliberately non-overwriting in normal cache-fill behavior, and
able to retain stale metadata across a top-level-to-hosted-branch relink.

Exact embedded-ref matching would prevent one stale-ref case but cannot make a
same-ref cached name current. A strict Zsh 5.2 JSON parser in the prompt path
would add security, compatibility, performance, and support surface without
providing more trustworthy recognition value than the confirmed explicit sync
path in [#6](https://github.com/junyoung2015/spaceship-supabase/issues/6).

Reconsider this source only if Supabase publishes a documented stable local
project-name metadata contract with a defined schema, lifecycle, and freshness
behavior. Any future reconsideration requires a new product-contract decision,
not a silent expansion of the v0.2 beta scope.

## 3. `supabase projects list` as an explicit discovery source

### 3.1 What it returns

**Verified fact:** at `v2.72.7`, `supabase projects list` calls the Management API, builds records containing the API project plus a CLI-added `linked` boolean, and includes the reference and human-readable name in table and structured output. [`v2.72.7` list implementation](https://github.com/supabase/cli/blob/v2.72.7/internal/projects/list/list.go#L16-L70)

`v2.72.7` uses the global `--output/-o` flag, so its machine-readable invocation is:

```sh
supabase projects list --output json
```

[`v2.72.7` global output flag](https://github.com/supabase/cli/blob/v2.72.7/cmd/root.go#L229-L245)

**Verified fact:** the stable `v2.113.0` TypeScript handler still returns Management API project objects plus `linked`. Its Go-compatible `--output json` path emits an array, while its newer `--output-format json` path emits an object containing `projects`. [`v2.113.0` fields and output branches](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/list.handler.ts#L34-L65), [`v2.113.0` JSON formatting](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/list.handler.ts#L139-L178), [`v2.113.0` documented output examples](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/SIDE_EFFECTS.md#L44-L80)

The local `v2.111.0` help output advertises:

```sh
supabase projects list --output-format json
```

The corresponding `v2.111.0` source uses the same project-list contract: ref/name fields plus `linked`, with Management API access. [`v2.111.0` project-list implementation](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/projects/list/list.go#L16-L70)

The official Management API reference documents the project inventory endpoint,
and the official CLI reference defines `projects list` as listing all projects
accessible to the logged-in user. [official Management API reference](https://supabase.com/docs/reference/api/introduction), [official CLI projects-list reference](https://supabase.com/docs/reference/cli/supabase-projects-list)

### 3.2 Why it cannot run in the prompt

**Verified fact:** `projects list` reads an access token (environment, keyring, or credential file depending on configuration) and calls authenticated `GET /v1/projects`. Network, auth, and API failures are normal command failure modes. [`v2.113.0` projects-list side effects](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/SIDE_EFFECTS.md#L3-L36)

**Recommendation:** never execute this command from `spaceship_supabase` rendering. Doing so would add unpredictable latency, credential access, network failure, rate-limit exposure, and side effects to every prompt. It would also violate the project's existing local-only and read-only renderer contract.

### 3.3 Safe explicit refresh design

An explicit helper is feasible because it runs on user request rather than during rendering. The planned beta.1 surface in [#6](https://github.com/junyoung2015/spaceship-supabase/issues/6) is intentionally narrower than this research originally proposed:

```text
spaceship_supabase_sync project [--yes]
```

It is not implemented by this research document. When implemented, the helper
should:

1. Resolve the same safe root and exact current live ref as the renderer.
2. Refuse to operate without a currently valid live ref.
3. Run the installed stable CLI only in the explicit helper process.
4. Prefer the locally documented structured-output flag, with version-aware fallback from `--output-format json` to `--output json` for older supported CLIs.
5. Accept both supported response shapes: `{ "projects": [...] }` and `[...]`.
6. Match the current 20-letter ref exactly against a validated response field; never choose by project name, organization, order, or the CLI's `linked` marker alone.
7. Validate the selected name before display or storage. For an initial release, the existing printable-ASCII/no-`%`/no-control/no-tab/no-newline/64-byte label policy is safer than attempting arbitrary terminal Unicode.
8. Preview a matching name and, only after confirmation, store it in the separate, clearly versioned synced-decoration file keyed by ref and carrying `fetched_at` and `source`. Do not silently rewrite the user-owned manual-label store.
9. Write state only with the same owner-only, no-symlink, bounded, atomic-update rules as label state.
10. Report failures in the helper, while leaving prompt behavior ref-only and silent.

The beta.1 shape is **discovery plus explicit confirmation**, for example:

```text
$ spaceship_supabase_sync project
Current ref: <validated live ref>
Proposed synced:project decoration: <validated project name> (<validated live ref>)
Save this point-in-time synced decoration? [y/N]
```

That preserves the useful human name without implying background freshness or
overwriting the user's label vocabulary. The future display opt-in remains
separate from the helper confirmation. Hosted-branch mapping remains later
scope in [#13](https://github.com/junyoung2015/spaceship-supabase/issues/13).

## 4. Local database branches and hosted Supabase Branches are different

### 4.1 Local database branch state

**Verified fact:** `v2.72.7` describes `supabase db branch` as local database branching and states that each branch is associated with a separate local database; remote database forking is not supported by that command. [`v2.72.7` local branch command](https://github.com/supabase/cli/blob/v2.72.7/cmd/db.go#L35-L40)

That local command remains in `v2.113.0`, and the current stable TypeScript command explicitly describes it as managing local database branches. [`v2.113.0` Go command](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/cmd/db.go#L40-L44), [`v2.113.0` stable TypeScript command](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/db/branch/branch.command.ts#L7-L15)

The CLI path constant is:

```text
<project root>/supabase/.branches/_current_branch
```

[`v2.72.7` path](https://github.com/supabase/cli/blob/v2.72.7/internal/utils/misc.go#L61-L79), [`v2.113.0` path](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/utils/misc.go#L81-L99)

The local start flow initializes the current branch as `main`, and local branch switching changes local databases before writing the selected local branch to `_current_branch`. [`v2.113.0` local start initialization](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/db/start/start.go#L233-L240), [`v2.113.0` local switch behavior](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/legacy/branch/switch_/switch_.go#L38-L56)

**Recommendation:** retain the existing opt-in rendering and exact language:

```text
abcdefghijklmnopqrst (local-db:feature/refactor-42)
```

Never render `ref@branch`, never call this a preview branch, and never use it to select or qualify the hosted ref.

### 4.2 Hosted preview/persistent branches

**Verified fact:** hosted Supabase Branching creates separate remote environments. The official guide distinguishes preview and persistent branches and describes each branch as a separate environment with its own credentials. [official Supabase Branching guide](https://supabase.com/docs/guides/deployment/branching)

**Verified fact (2026-05-04 product change):** branching without Git is now the default. Users can create and merge hosted branches directly in the Supabase Dashboard without a GitHub integration, while Git-based branching remains supported. [official announcement dated 2026-05-04](https://supabase.com/blog/branching-without-git-is-now-the-default), [official May 2026 Supabase release](https://github.com/supabase/supabase/releases/tag/v1.26.05)

The CLI exposes those remote resources under `supabase branches`, not `supabase db branch`. Its list implementation calls the Management API and returns fields including branch project ref, human-readable branch name, and Git branch. [`v2.113.0` hosted branch-list implementation](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/branches/list/list.go#L16-L81), [`v2.113.0` branch response model](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/pkg/api/types.gen.go#L5921-L5945), [official CLI branches-list reference](https://supabase.com/docs/reference/cli/supabase-branches-list)

The generated response model makes `git_branch` optional, which is consistent with the no-Git workflow. **Recommendation:** never derive hosted branch identity from the current Git branch or require a `git_branch` value. Use exact `project_ref` matching only. [`v2.113.0` optional Git branch and required project/parent refs](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/pkg/api/types.gen.go#L5921-L5945)

**Verified fact:** a hosted branch can be linked by its own ref even when the generic project lookup returns 404; in that case stable link continues and writes `project-ref`, but does not write `linked-project.json`. [`v2.113.0` stable link API behavior](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L31-L40), [`v2.113.0` stable conditional metadata write](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/link.handler.ts#L153-L169)

**Inference:** the stable repo-local legacy files do not provide a dependable hosted branch name. `_current_branch` is local-only, while `linked-project.json` may not exist for the hosted branch ref. Correct hosted-branch naming therefore requires an explicit authenticated Management API/CLI discovery step and an exact match on the branch's project ref.

### 4.3 Safe hosted-branch roadmap

**Recommendation:** do not ship guessed hosted-branch names. A future explicit helper may add them only when it can establish this chain:

```text
current valid local project-ref
        ↓ exact equality
Management API branch.project_ref
        ↓
validated branch name + parent-project identity
```

The resulting display should keep the exact current ref, for example:

```text
Customer API / pr-482 (abcdefghijklmnopqrst)
```

If the helper cannot establish an exact branch-ref match, render only the ref or a user-owned manual label. It must not infer hosted branch identity from a Git branch, directory name, config remote, local DB branch, or cached project name.

The current CLI makes parent discovery an explicit design problem:

- `supabase branches list` sends the resolved `flags.ProjectRef` as the **parent** ref to `GET /v1/projects/{parent-ref}/branches`; it is not a global “find this branch ref” operation. [`v2.113.0` branch-list call](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/branches/list/list.go#L64-L81), [`v2.113.0` generated route](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/pkg/api/client.gen.go#L6198-L6214)
- The list response provides both `parent_project_ref` and `project_ref`, so an exact match is straightforward **after** the correct parent's list is obtained. [`v2.113.0` branch response](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/pkg/api/types.gen.go#L5921-L5945)
- `branches get` can accept a branch ref and call the branch-config endpoint directly, but that detail response contains connection/status fields and `ref`; it does not contain the branch name or parent ref. [`v2.113.0` branch-get flow](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/branches/get/get.go#L54-L81), [`v2.113.0` branch-detail shape](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/pkg/api/types.gen.go#L5904-L5916)

**Recommendation:** an initial hosted-branch refresh helper should require or interactively obtain an explicit parent ref, then list that parent's branches and require one exact `project_ref` match. A broader discovery mode may enumerate the user's top-level projects and query their branch lists, but it must be explicit, bounded, failure-tolerant, and outside prompt rendering. Do not quietly treat the linked branch ref as the parent ref.

## 5. `.supabase/project.json` is next/V3 state, not the stable contract

### 5.1 Release-channel status

**Verified fact:** the `v2.113.0` CLI workspace has two shells. Stable publishes the legacy shell to the `latest` channel; the next/V3 shell is published only to the alpha channel. The production release process likewise maps stable and beta to the legacy shell and reserves alpha for the next rewrite. [`v2.113.0` publishing overview](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/README.md#L154-L181), [`v2.113.0` release matrix](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/docs/release-process.md#L211-L221)

**Verified fact:** the stable legacy `supabase link` implementation explicitly writes flat files under `supabase/.temp` and explicitly does **not** use the next shell's `.supabase/project.json`. [`v2.113.0` stable link contract](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L1-L4)

**Conclusion:** `.supabase/project.json` is present in the pinned source tree, but it is **not released into the `v2.113.0` stable-shell contract**. Calling it “unreleased” should mean “not in stable,” not “no alpha source or channel exists.”

### 5.2 Current next-shell shape and churn signal

The next link command says it stores linked state in `.supabase/project.json`. [`v2.113.0` next link command](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/next/commands/link/link.command.ts#L31-L45)

At the pinned tag, the implementation schema is nested and includes both project and active hosted branch metadata:

```json
{
  "project": {
    "ref": "...",
    "name": "...",
    "organization_id": "...",
    "organization_slug": "..."
  },
  "active_branch": {
    "ref": "...",
    "name": "...",
    "is_default": true
  },
  "fetchedAt": "...",
  "versions": {}
}
```

[`v2.113.0` next-shell state schema](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/next/config/project-link-state.service.ts#L4-L35)

The same tag's internal `supabase-home.md` guide shows an older flat example without `project` and `active_branch` objects. [`v2.113.0` internal next-shell guide](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/docs/supabase-home.md#L87-L112)

**Inference:** the discrepancy within the pinned next-shell materials is a practical sign that this alpha contract is still evolving. It may eventually solve both project-name and hosted-branch-name discovery elegantly, but implementing an adapter now would couple `spaceship-supabase` to an unstable shape that stable users do not receive.

**Recommendation:** retain the documented deferral. Revisit only when all of these are true:

- the stable Supabase CLI release channel writes the file;
- the path, schema, validation, and lifecycle are documented as supported behavior;
- migration behavior from `supabase/.temp` is known;
- branch switching and rename refresh behavior are specified;
- pinned compatibility fixtures cover the first stable adopter and the legacy fallback.

## 6. Source trust and product-use decision table

| Source | What it actually says | May select identity? | Safe prompt-path use | v0.2 recommendation |
|---|---|---:|---:|---|
| `supabase/.temp/project-ref` | Stable CLI's local linked ref | **Yes**, after strict root/path/file/value validation | **Yes** | Continue as authoritative local identity |
| Explicit `[remotes.<name>].project_id` | User-selected configured mapping, not live link state | Only as already-documented non-authoritative fallback | Yes, strict Zsh-only parse | Keep mandatory `configured:<remote>` marker |
| Manual label store | User-owned decoration keyed by ref | **No** | Yes, only when current ref exists and matches | Primary recognizable/custom-name mechanism |
| `supabase/.temp/linked-project.json` | Best-effort telemetry metadata snapshot | **No** | **No** for v0.2 and its first external beta | Deliberate no-go; reconsider only after a documented stable contract and new product decision |
| `supabase projects list` | Authenticated remote project inventory with names | **No**; can enrich an exact current ref | **No** | Explicit discovery/refresh helper only |
| `supabase/.branches/_current_branch` | Selected local database branch | **No** | Yes, under existing opt-in validation | Render only as `local-db:<name>` |
| `supabase branches list` | Authenticated hosted branch inventory | **No**; can enrich an exact branch ref | **No** | Explicit future refresh helper only |
| `.supabase/project.json` | Next/V3 alpha-shell linked project and branch state | Not for stable v0.2 compatibility | **No** in the stable adapter | Defer until stable and documented |

The stable-source basis for this table is the ref resolver and link lifecycle, the telemetry-cache implementation, the project-list side-effects contract, the local branch command, the hosted branch-list implementation, and the stable/alpha release split. [`v2.113.0` ref resolution](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/config/legacy-project-ref.layer.ts#L81-L152), [`v2.113.0` telemetry cache](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/telemetry/legacy-linked-project-cache.layer.ts#L21-L35), [`v2.113.0` projects-list side effects](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/SIDE_EFFECTS.md#L3-L36), [`v2.113.0` local branches](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/db/branch/branch.command.ts#L7-L15), [`v2.113.0` hosted branches](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/branches/list/list.go#L16-L81), [`v2.113.0` channels](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/docs/release-process.md#L211-L221)

## 7. Recommended v0.2 product direction

### 7.1 Preserve the safety invariant

The user's original pain point is operational: prevent commands from targeting the wrong environment. Human readability matters, but only if it cannot hide or replace the exact target.

**Recommendation:** define the invariant in the roadmap as:

> The current valid live ref determines identity. Every human-readable project or branch name is a validated decoration bound to that exact ref, and the full ref remains visible.

That gives a deterministic precedence model:

```text
validated current live ref
  ├─ matching manual label → Manual label (full-ref)
  ├─ matching opt-in refreshed remote name → Remote name (full-ref)
  └─ no safe decoration → full-ref
```

Manual labels may have display preference because they express the user's operational vocabulary (`Production`, `Customer staging`, `Do not touch`), but they never outrank the ref as identity.

### 7.2 Keep prompt rendering local, read-only, and fresh

**Recommendation:** do not change the established runtime contract:

- no Supabase CLI invocation;
- no Management API/network request;
- no credential lookup;
- no Node, Python, `jq`, or external parser;
- no writes or repair;
- no per-directory value cache;
- re-read the safe live ref each render;
- validate every optional decoration and omit it independently on failure;
- keep normal failure silent.

These constraints are especially important if names are introduced: a slow or unavailable network must never delay the shell, and a malformed remote/cache name must never become prompt code or terminal control bytes.

### 7.3 Ship value in two stages

**Recommended Stage A — dependable custom names:**

- make the existing manual label workflow easy to discover;
- add short README examples centered on environment safety (`Production`, `Staging`, `Local demo`);
- consider a non-mutating `spaceship_supabase_label suggest` or a refresh command that asks before setting a label;
- improve doctor output for “valid ref, no recognizable label.”

This immediately solves the recognition problem for all supported CLI versions, including `v2.72.7` and hosted branch refs with no metadata cache.

**Recommended Stage B — explicit remote-name sync (the beta.1 slice):**

- add a user-invoked helper only after its state schema and parser are threat-modeled;
- use `projects list` for top-level project names;
- preview and store a timestamped synced decoration separately from manual labels after explicit confirmation;
- never refresh automatically from prompt rendering;
- make staleness visible in `doctor`/`list`, not necessarily in every prompt;
- require exact ref equality at lookup and display time.

### 7.4 Hosted branch names need a separate feature gate

Project-name discovery and hosted-branch-name discovery should not be bundled as though they have the same source. Top-level projects are directly returned by `projects list`; hosted branch names come from branch Management API resources. [`v2.113.0` projects list](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/list.handler.ts#L81-L142), [`v2.113.0` branches list](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/branches/list/list.go#L16-L81)

**Recommendation:** make hosted branch naming a later roadmap item with an exact-ref proof requirement. Until that proof exists, a manual label bound to the hosted branch ref is safer than a guessed branch name.

## 8. Required tests for any human-name feature

Any implementation following this research should extend the release suite with behavior tests, not merely parser-unit coverage.

### Identity preservation

- A valid live ref always appears in full in `ref` and human-name formats.
- A label or synced decoration never produces output after the live/config identity disappears.
- A synced record for a different ref is ignored.
- Changing `project-ref` in the same directory immediately changes the next render and invalidates the old decoration.
- A configured mapping remains visibly non-authoritative and never inherits a live-only synced decoration by accident.

### Name safety

- Reject `%`, ESC/CSI/OSC, controls, tabs, newlines, excessive length, malformed encodings, and unsafe whitespace according to the chosen documented policy.
- Validate actual bytes passed through `spaceship::section::v4`, not only helper return values.
- Reject oversized, multi-record-ambiguous, insecure-permission, and symlinked synced-decoration state.
- Confirm a safe name can decorate but cannot alter color, symbol, prefix, suffix, or prompt evaluation.

### Refresh helper

- Accept `v2.72.7`-style JSON arrays and current `{ "projects": [...] }` output.
- Reject nonzero CLI exits, malformed JSON, duplicate exact-ref records, missing names, invalid refs, and ref mismatches.
- Never select by name or list position.
- Never expose access tokens, credential paths, raw API bodies, or unvalidated names in errors.
- Use owner-only atomic writes for any new snapshot state.
- Confirm no helper-created state changes identity.

### Branch separation

- `_current_branch` is absent by default and rendered only as `local-db:<validated-name>` when enabled.
- A hosted branch ref renders the full ref regardless of whether a telemetry
  snapshot happens to exist.
- Local branch state never becomes a hosted branch label.
- Hosted branch enrichment is accepted only after an exact API branch-project-ref match.

### Stable versus next state

- Keep pinned stable fixtures for `v2.72.7`, local-era `v2.111.0`, and `v2.113.0`.
- Do not read `.supabase/project.json` in stable-path tests.
- If a future adapter is added, gate it by an explicitly supported stable CLI version and test schema/lifecycle migration separately.

## 9. Open questions before implementing automatic names

1. **Resolved for beta.1: what does the first sync helper write?**

   [#6](https://github.com/junyoung2015/spaceship-supabase/issues/6) requires an exact-match preview and confirmation before one separate, timestamped `synced:project` record is written. It never changes a manual label. Whether a later helper can offer a manual-label conversion remains a separate UX decision.

2. **What name character policy is acceptable?**

   Management API names are strings, while prompt rendering is security-sensitive. The existing 64-byte printable-ASCII/no-`%` policy is conservative and testable. Supporting broader Unicode would require a precise normalization, width, bidi, control, and escaping policy.

3. **How should stale remote names be communicated?**

   Projects can be renamed after a user-confirmed sync. The beta.1 record is
   therefore explicitly point-in-time, carries `fetched_at`, and never claims
   prompt-time freshness. Verbose doctor must make the saved state reviewable;
   automatic prompt-time refresh remains prohibited.

4. **Does `projects list` enumerate hosted branch projects for every account/plan state?**

   The inspected sources define it as `GET /v1/projects`; the branch command uses separate branch endpoints. No inspected primary source guarantees that a linked hosted branch ref will appear in `projects list`. The implementation must not assume it. [projects-list API route](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/SIDE_EFFECTS.md#L16-L20), [hosted branch-list source](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/branches/list/list.go#L16-L81)

5. **What is the efficient exact mapping from an arbitrary linked branch ref to its parent and human name?**

   The list response contains `parent_project_ref`, branch `project_ref`, and `name`, but `branches list` itself is parent-scoped. Direct branch-config lookup by branch ref does not return name or parent. The safest initial helper therefore needs an explicit parent ref; any account-wide discovery should enumerate accessible top-level projects, list branches per parent with clear bounds, and accept only one exact branch-ref match. Git state cannot close this gap because no-Git branching became the default in May 2026.

6. **Should a Supabase remote name ever outrank a manual label?**

   Recommendation: no. A manual label expresses the user's risk vocabulary and is stable by intent; a remote project name is mutable and may be generic. Both remain secondary to the full ref.

7. **When should `.supabase/project.json` support begin?**

   Recommendation: only after the next shell reaches the stable channel and Supabase documents a durable shape and lifecycle. Source presence in a stable tag is insufficient because stable currently publishes the legacy shell.

8. **What is the supported CLI-version floor for explicit top-level discovery?**

   Manual labels work across the entire plugin support range. The beta.1 helper
   can support `v2.72.7` through `v2.113.0` if it handles both `projects list`
   output flags and JSON envelope variants. It does not read
   `linked-project.json`.

9. **Should remote-name state have a TTL?**

   A TTL must not cause identity to vanish or resurrect, and a prompt must not refresh on expiry. If added, expiry should only remove the decoration and `doctor` should explain how to refresh it.

## 10. Roadmap-ready decisions

The research supports recording these decisions directly in the v0.2 milestone:

- **Accepted:** manual custom labels remain the supported human-recognition mechanism.
- **Accepted:** the full exact ref remains visible in every supported human-name format.
- **Accepted:** `supabase/.temp/project-ref` remains the stable local identity source for the current compatibility range.
- **Accepted:** `_current_branch` is local database state and remains labeled `local-db:`.
- **Accepted:** no CLI, network, credential, or write work enters prompt rendering.
- **Accepted beta.1 implementation scope:** explicit top-level project-name discovery via `supabase projects list`, exact live-ref matching, confirmation, and a separate `synced:project` record. [#6](https://github.com/junyoung2015/spaceship-supabase/issues/6) defines the public helper and failure boundary.
- **No-go for v0.2 and first external beta:** do not consume `linked-project.json`; [#5](https://github.com/junyoung2015/spaceship-supabase/issues/5) records the parser, staleness, compatibility, privacy, and support rationale.
- **Deferred:** hosted branch names until exact branch-ref mapping is proven with a bounded primary API workflow.
- **Deferred:** `.supabase/project.json` until it becomes a stable, documented CLI contract.

This sequencing delivers recognizable names without weakening the original safety goal: know the exact linked target before changing an environment.

## Primary source index

### Official releases, changelog, and documentation

- [Supabase CLI `v2.72.7`](https://github.com/supabase/cli/releases/tag/v2.72.7)
- [Supabase CLI `v2.87.0`](https://github.com/supabase/cli/releases/tag/v2.87.0)
- [Supabase CLI `v2.111.0`](https://github.com/supabase/cli/releases/tag/v2.111.0)
- [Supabase CLI `v2.113.0`](https://github.com/supabase/cli/releases/tag/v2.113.0)
- [Supabase changelog](https://supabase.com/changelog)
- [Supabase CLI projects-list reference](https://supabase.com/docs/reference/cli/supabase-projects-list)
- [Supabase CLI branches-list reference](https://supabase.com/docs/reference/cli/supabase-branches-list)
- [Management API reference](https://supabase.com/docs/reference/api/introduction)
- [Management API: Update a project](https://supabase.com/docs/reference/api/v1-update-a-project)
- [Supabase Branching guide](https://supabase.com/docs/guides/deployment/branching)
- [Branching Without Git Is Now The Default — 2026-05-04](https://supabase.com/blog/branching-without-git-is-now-the-default)
- [Supabase Developer Update — May 2026](https://github.com/supabase/supabase/releases/tag/v1.26.05)

### Pinned stable implementation anchors

- [`v2.72.7` path and validation definitions](https://github.com/supabase/cli/blob/v2.72.7/internal/utils/misc.go#L50-L79)
- [`v2.72.7` project-ref resolution](https://github.com/supabase/cli/blob/v2.72.7/internal/utils/flags/project_ref.go#L54-L75)
- [`v2.72.7` link writer](https://github.com/supabase/cli/blob/v2.72.7/internal/link/link.go#L23-L35)
- [`v2.72.7` unlink lifecycle](https://github.com/supabase/cli/blob/v2.72.7/internal/unlink/unlink.go#L15-L41)
- [`v2.72.7` project-list implementation](https://github.com/supabase/cli/blob/v2.72.7/internal/projects/list/list.go#L16-L70)
- [`v2.111.0` path and validation definitions](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/utils/misc.go#L70-L99)
- [`v2.111.0` project-list implementation](https://github.com/supabase/cli/blob/v2.111.0/apps/cli-go/internal/projects/list/list.go#L16-L70)
- [`v2.113.0` stable publishing model](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/README.md#L154-L181)
- [`v2.113.0` stable release-channel matrix](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/docs/release-process.md#L211-L221)
- [`v2.113.0` stable legacy path definitions](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/shared/legacy-temp-paths.ts#L14-L50)
- [`v2.113.0` stable project-ref resolution](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/config/legacy-project-ref.layer.ts#L81-L152)
- [`v2.113.0` stable link state writes](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/link/link.handler.ts#L145-L169)
- [`v2.113.0` telemetry cache behavior](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/telemetry/legacy-linked-project-cache.layer.ts#L21-L35)
- [`v2.113.0` project-list behavior](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/projects/list/list.handler.ts#L81-L185)
- [`v2.113.0` local DB branch command](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/legacy/commands/db/branch/branch.command.ts#L7-L15)
- [`v2.113.0` hosted branch-list implementation](https://github.com/supabase/cli/blob/v2.113.0/apps/cli-go/internal/branches/list/list.go#L16-L81)
- [`v2.113.0` next-shell project-link schema](https://github.com/supabase/cli/blob/v2.113.0/apps/cli/src/next/config/project-link-state.service.ts#L4-L35)

### Changelog check

The official Supabase changelog was reviewed for CLI linking, project-name, branch, and local-state announcements. No entry found in that scoped review announced a stable replacement for `supabase/.temp/project-ref` or promoted `linked-project.json`/`.supabase/project.json` as a public stable identity contract. This is a scoped negative finding, not a guarantee that no unrelated announcement mentions adjacent behavior. [official Supabase changelog](https://supabase.com/changelog)
