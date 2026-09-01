# Supabase project and hosted branch context

Status: primary source research update for future product decisions

As of: 2026-09-01

Supabase CLI snapshot: stable `v2.116.0`, released 2026-08-26, immutable commit `997a1e69a4a83466964ed874d3a604c88a7b3866`. [Official release](https://github.com/supabase/cli/releases/tag/v2.116.0)

Related records: [earlier CLI project name research](supabase-cli-project-names.md), [accepted v0.2 context contract](../design/v0.2-target-context-contract.md), [hosted branch issue #13](https://github.com/junyoung2015/spaceship-supabase/issues/13), and [prompt glyph issue #36](https://github.com/junyoung2015/spaceship-supabase/issues/36)

This report updates the upstream evidence after the earlier `v2.113.0` review. It does not change the v0.2 contract, reopen the recorded `linked-project.json` decision, or authorize hosted branch sync.

## Executive finding

No stable local file currently supplies an authoritative project name and hosted branch name while satisfying all prompt renderer constraints.

The stable CLI now assembles much richer linked context for `supabase status`. It reads the live branch or project ref from `supabase/.temp/project-ref`, reads a best effort parent project snapshot from `supabase/.temp/linked-project.json`, and may query the authenticated Management API to resolve a hosted branch name. This is useful evidence for a future explicit sync helper. It remains unsuitable for prompt rendering because the command can consult credentials, use the network, inspect Docker, and write telemetry. [Stable `status` side effects](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/commands/status/SIDE_EFFECTS.md#L1-L48)

The current product boundary remains sound:

1. A valid live `project-ref` selects the hosted identity.

2. The existing top level project sync provides optional `synced:project` decoration outside prompt rendering.

3. A manual label bound to the full branch ref provides safe hosted branch recognition today.

4. A future `synced:hosted-branch` flow needs an exact branch ref match under a known parent, separate stored provenance, and its own contract and release gate.

5. `linked-project.json` remains excluded from v0.2 prompt input and sync input.

## Stable linked state

### `supabase link`

The stable command writes `supabase/.temp/project-ref` after service linking. Failure to write this file fails the link command. The file contains the final linked ref. [Stable link handler](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/commands/link/link.handler.ts#L374-L397)

For a directly resolved project, the command also attempts to write `supabase/.temp/linked-project.json` with these fields:

```json
{
  "ref": "abcdefghijklmnopqrst",
  "name": "Example project",
  "organization_id": "example-org-id",
  "organization_slug": "example-org"
}
```

That second write is best effort. The CLI source identifies the file as a linked project cache used for telemetry and parent project context. API, filesystem, parsing, and credential failures can leave it absent. Ordinary cache fill also leaves an existing file untouched. [Go telemetry cache](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli-go/internal/telemetry/project.go#L15-L88) [Stable TypeScript cache](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/telemetry/legacy-linked-project-cache.layer.ts#L21-L46)

The cache existed in the earlier supported stable CLI snapshot. Version `v2.113.0` contains the same filename and project metadata write. [Version 2.113.0 link source](https://github.com/supabase/cli/blob/03880bb15379c308a73b078d98780eef1eb1bd63/apps/cli/src/legacy/commands/link/link.handler.ts#L365-L391)

### Hosted branch linking

Version 2.116.0 can link a branch by name, UUID, or branch project ref. The resulting `project-ref` contains the branch's own ref. Parent scoped CLI commands need the parent project ref, so the branch link path also maintains `linked-project.json` as parent evidence.

The stable source handles two cases:

1. A branch resolved by name or UUID has a known parent. The CLI can write a ref only parent record when no agreeing cache exists. It preserves an agreeing richer cache that already contains the parent name and organization.

2. A raw ref shaped branch has no locally proven parent. When an existing cache points elsewhere, the CLI checks the parent's branch list. Failed or negative correlation removes the divergent cache.

[Stable branch link handling](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/commands/link/link.handler.ts#L427-L515) [Stable link side effects](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/commands/link/SIDE_EFFECTS.md#L40-L76)

These semantics explain why cache ref equality and inequality have different meanings:

1. Equal live and cached refs can describe a plain project link.

2. A different live ref can describe a hosted branch whose parent is the cached ref.

3. Neither file contains the hosted branch name.

4. The cached parent name cannot select, replace, restore, or outrank the live branch ref.

The v0.2 decision to exclude this cache remains appropriate. Its newer parent maintenance improves CLI behavior without turning it into a documented, fresh identity contract.

## Where the hosted branch name comes from

`supabase branches list` sends an authenticated `GET /v1/projects/{parentRef}/branches` request. Each result includes a human branch name, branch `project_ref`, and `parent_project_ref`. [Stable list handler](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/commands/branches/list/list.handler.ts#L38-L102) [Official CLI reference](https://supabase.com/docs/reference/cli/supabase-branches-list)

The pretty table marks the row whose branch ref equals the current linked ref as `<name> (active)`. Machine output returns the original branch records and omits that presentation marker. [Stable branch formatter](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/commands/branches/branches.format.ts#L41-L70)

Supabase describes each hosted Branch as a separate environment with its own instance and credentials. Preview and persistent branches receive their own project refs. [Official Branching guide](https://supabase.com/docs/guides/deployment/branching)

Supabase also documents `[remotes.<branch_name>].project_id` as the project ref for a specific persistent branch. This can provide useful user selected configuration context. The repository's `configured:<name>` qualification remains necessary because a local mapping can be stale, duplicated, or selected incorrectly. [Official CLI config reference](https://supabase.com/docs/guides/local-development/cli/config#remotesbranch_nameproject_id)

## New `supabase status` evidence

Version 2.116.0 adds a linked context block to human `status` output. Depending on locally and remotely available evidence, it can show organization, parent project name and ref, plus branch name and ref. [Stable linked state formatter](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/shared/legacy-linked-state.ts#L305-L345)

Machine output can include:

```text
linked_project_ref
linked_project_name
linked_org_slug
linked_org_id
linked_branch
linked_parent_project_ref
```

[Stable machine fields](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/shared/legacy-linked-state.ts#L347-L373)

The resolver follows this evidence chain:

1. Read the current linked ref from the environment override or `supabase/.temp/project-ref`.

2. Read `linked-project.json` softly.

3. When cache ref equals live ref, expose any cached project and organization fields with no Management API call.

4. When a file sourced live ref differs from a cached parent ref, keep the branch linked shape and attempt a parent scoped branch lookup.

5. Limit the branch lookup to five seconds. Missing credentials, network failures, decoding failures, and timeouts omit the branch name without failing `status`.

[Stable linked state resolver](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/shared/legacy-linked-state.ts#L44-L84) [Branch lookup and cache interpretation](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/shared/legacy-linked-state.ts#L118-L276)

This improves explicit discovery. It does not create a safe prompt dependency. Stable `status` can:

1. Read local configuration and signing key or TLS paths.

2. Inspect the local Docker or Podman stack.

3. Resolve a Supabase access token from environment, keychain, or a credentials file for branch lookup.

4. Contact the Management API.

5. Write `~/.supabase/telemetry.json`.

[Stable `status` side effects](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/legacy/commands/status/SIDE_EFFECTS.md#L1-L88)

## Safe acquisition outside prompt rendering

The accepted top level project sync should remain the only v0.2 remote decoration flow. A future hosted branch helper can reuse its safety model after issue #13 meets its demand and contract gates.

A defensible future branch flow would:

1. Require an explicit user command. Prompt rendering never launches it.

2. Prove a safe current live branch ref before invoking the CLI.

3. Obtain a known parent ref through explicit user input or another separately approved source.

4. Run the official `supabase branches list --project-ref <parent> --output json` command outside prompt rendering.

5. Bound stdout, stderr, runtime, and child cleanup before parsing.

6. Require exactly one branch record whose `project_ref` equals the preflight live ref and whose `parent_project_ref` equals the selected parent.

7. Validate project and branch display text, show a preview, and ask for confirmation by default.

8. Recheck the live ref immediately before an owner accessible atomic write.

9. Store branch decoration separately from manual labels and the existing `synced:project` record. Include source, parent ref, branch ref, CLI version, and fetch time.

10. Keep the full branch ref visible. Mark the decoration `synced:hosted-branch` and treat it as a point in time description.

11. Leave valid ref rendering untouched on lookup, parsing, validation, freshness, or write failure.

`supabase status` could supply the same context in some linked layouts. It is a weaker helper interface because its primary job includes local stack inspection and its machine output may be carried on a failure envelope. The focused parent scoped branch list has a clearer exact match contract.

No direct Management API request is needed. Using the official CLI keeps credential handling outside this plugin, though the helper still requires explicit authorization and network access.

## Local database state

`supabase/.branches/_current_branch` belongs to the deprecated local database branch commands. The CLI initializes and updates this file while operating local branch databases. [Stable local branch writer](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli-go/internal/db/start/start.go#L230-L238) [Deprecated command declaration](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli-go/cmd/db.go#L45-L60)

The existing `local-db:<name>` vocabulary remains accurate. This file supplies no hosted branch evidence.

## Version 3 preview

The alpha next shell stores linked state at `.supabase/project.json`. [Preview state path](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/next/config/cli-project-home.layer.ts#L6-L45)

Its schema defines:

1. `project.ref`, `project.name`, `organization_id`, and `organization_slug`.

2. `active_branch.ref`, `active_branch.name`, and `active_branch.is_default`.

3. `fetchedAt` and linked service versions.

Its writer uses file mode `0600`. [Preview state schema](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/next/config/project-link-state.service.ts#L9-L40) [Preview state persistence](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/next/config/project-link-state.layer.ts#L12-L62)

The initial refresh writes the linked project as active branch `main`. [Preview refresh](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/src/next/config/project-link-refresh.ts#L35-L58)

Supabase publishes the next shell through an alpha channel. Stable releases still use the legacy command tree. [CLI development README](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli/README.md#L160-L168) [Release strategy ADR](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/docs/adr/0011-cli-release-and-distribution-strategy.md#L87-L93)

This schema closely matches the desired context. Adapter work should wait for a stable, documented schema and lifecycle, followed by a product contract review in this repository.

## Brand and terminal glyph research

Supabase publishes official graphic assets. Its brand page says the trademarks and logos must remain unmodified and should represent Supabase. [Official brand assets](https://supabase.com/brand-assets) [Official brand page source](https://github.com/supabase/supabase/blob/96d43099bbefbfd2d291e78d271b87b691b43f27/apps/www/pages/brand-assets.tsx#L42-L77)

The official icon uses opposed polygonal regions, Supabase green, a green gradient, and a translucent overlap. Official source names include `supabase-logo-icon` and `LogoSupabase`. No official source reviewed here calls the shape a lightning bolt or an angular S. [Official logo SVG](https://github.com/supabase/supabase/blob/5faa6b253ca08cee08a90f7785459c144f441089/apps/www/public/images/supabase-logo-icon.svg) [Official logo component](https://github.com/supabase/supabase/blob/ef5c15a652848f3c85d996678cf5632b9fad410a/apps/ui-library/registry/default/platform/platform-kit-nextjs/components/logo-supabase.tsx#L1-L49)

No official terminal, ASCII, Unicode, emoji, Powerline, or Nerd Font mapping was found. The repository's Apache 2.0 license preserves trademark restrictions. [Supabase repository license, section 6](https://github.com/supabase/supabase/blob/accaac81bb84f51006bab836b8569a3e31bb0b31/LICENSE#L138-L141)

Unicode 17 classifies `⚡` and `🔷` for default emoji presentation and assigns both East Asian Width `W`. It classifies `↯` as width neutral. These properties support treating the current diamond and the high voltage sign as width risks in a prompt. Actual cell layout still depends on the terminal and font. [Official Unicode emoji data](https://www.unicode.org/Public/17.0.0/ucd/emoji/emoji-data.txt) [Official East Asian Width data](https://www.unicode.org/Public/17.0.0/ucd/EastAsianWidth.txt)

Nerd Fonts 3.5.1 registers `dev-supabase` at private use code point `U+E8B6`. This is a third party font mapping rather than Supabase guidance. [Pinned Nerd Fonts registry](https://github.com/ryanoasis/nerd-fonts/blob/73e5da3b3353b78afcf32734281a18b5d3dc5c8f/glyphnames.json)

Terminal symbol conclusions:

1. Describe any terminal character as a `prompt glyph` or `unofficial Supabase mnemonic`.

2. Keep the glyph configurable and pair it with validated text. Supabase's design system also recommends pairing icons with text and maintaining clarity at small sizes. [Official icon guidance](https://supabase.com/design-system/docs/icons)

3. `S ` is the strongest portability and brand caution candidate. It uses one ASCII cell and does not attempt to redraw the logo.

4. `SB ` is more explicit and uses two ASCII cells.

5. `↯ ` is a compact bolt shaped mnemonic. It remains unofficial and requires font coverage testing.

6. `⚡` and the current `🔷` carry default emoji presentation and wide width properties. The diamond also has weak visual association with the official mark.

7. Nerd Fonts `dev-supabase` is the most direct existing terminal shape. Keep it behind explicit opt in because `U+E8B6` requires a patched font, carries no portable Unicode meaning, and has no official Supabase endorsement.

8. README and web surfaces can use the official downloaded SVG unchanged. A traced one cell logo needs Supabase clarification because the published guidance prohibits modifying the mark.

A default change should follow screenshot comparisons of `🔷 `, `S `, `SB `, and `↯ ` in macOS Terminal, iTerm2, and Kaku. Record cell width, baseline, color fallback, font fallback, and light and dark theme legibility.

## Recommended disposition

1. Preserve the live 20 character ref as the sole hosted identity.

2. Explain manual branch labels prominently in public documentation. A synthetic example can show `Customer API / staging (abcdefghijklmnopqrst)` without implying remote freshness.

3. Keep the delivered `synced:project` flow and its separate provenance store unchanged for v0.2.

4. Keep `linked-project.json` excluded from v0.2 input. Version 2.116.0 adds useful context and cache maintenance, while the file remains best effort and lacks a public stable lifecycle contract.

5. Treat the new `status` linked fields as evidence for future discovery rather than a prompt integration point.

6. Keep issue #13 in discovery until real user demand, a pinned parent scoped machine output contract, new record schema, rollback behavior, and release evidence all exist.

7. Monitor stable version 3 adoption of `.supabase/project.json`.

8. Keep the current glyph configurable. Test ASCII and text symbol alternatives before changing the default, and avoid calling any terminal glyph official.

## Uncertainties

1. Supabase source documents `linked-project.json` side effects, but the public CLI reference does not promise its schema, permissions, lifecycle, or compatibility.

2. Public CLI documentation has not yet described the version 2.116.0 `status` linked fields with the precision available in source.

3. Project and branch names are untrusted user controlled strings. A future helper needs explicit character and length policies, including behavior for upstream names the prompt refuses.

4. Public documentation does not define branch ref behavior across every rename, restore, merge, and deletion lifecycle.

5. The version 3 state schema and release schedule can change while the next shell remains alpha.

6. Supabase's brand guidance does not address terminal approximations or third party private use glyphs.

7. Unicode width, emoji presentation, baseline, and color fallback vary across terminal, font, locale, and theme combinations.

8. The public brand materials leave the permissibility of a one cell reinterpretation unclear. Legal or brand owner clarification may be needed before presenting a custom shape as the Supabase mark.
