# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added an outcome-driven v0.2 roadmap centered on recognizable project and environment context, with GitHub Issues replacing the archived BMad backlog as the active progress tracker.
- Added a primary-source Supabase CLI research report covering local project-name metadata, hosted/local branch semantics, refresh options, and compatibility risks.
- Added an accepted v0.2 target-context contract that fixes the product vocabulary, exact prompt forms, privacy defaults, manual-label precedence, and synced-decoration provenance before feature code begins.

### Fixed

- Required strict public-tree auditing inside every release-preflight invocation, including the final publication recheck.
- Made the canonical test runner exit immediately with conventional status codes after `HUP`, `INT`, or `TERM` while retaining temporary-directory cleanup.

## [0.1.1] - 2026-08-10

### Fixed

- Documented the required, idempotent Spaceship prompt-order registration for the external `supabase` section.
- Added an end-to-end integration test that loads the real vendored Spaceship v4 runtime, applies the documented registration guard, prevents duplicate registration, and renders the linked project reference through the composed prompt path.

## [0.1.0] - 2026-08-10

### Added

- A public, fail-closed Spaceship Prompt v4 section that renders the full stable Supabase CLI linked-project reference from `supabase/.temp/project-ref`.
- Safe nearest-project resolution with a strict `SUPABASE_WORKDIR` override and nested-project boundaries.
- Opt-in, explicitly marked config mapping from a selected `[remotes.<name>].project_id` block when live link state is unavailable.
- Opt-in local database-branch decoration using the unambiguous `local-db:<name>` marker.
- A local, user-owned label store plus `spaceship_supabase_label` and read-only `spaceship_supabase_doctor` helpers.
- Behavior-focused isolated Zsh test runner, stable CLI layout fixtures, adversarial prompt-rendering tests, and direct-render benchmark policy.
- Public configuration, compatibility, data-source, label, troubleshooting, testing, contribution, support, and security documentation.
- Reusable CI, release preflight, tag-driven GitHub Release automation, Dependabot configuration, and public issue/PR templates.

### Changed

- Replaced the alpha's stale session-cache and broad fallback behavior with fresh per-render local reads and explicit precedence.
- Replaced `ref@branch` rendering with an opt-in `local-db:<name>` marker to avoid implying a hosted Supabase Branch.
- Reduced configuration to a small supported surface that always retains the exact project reference.
- Corrected the stable Supabase CLI contract to `supabase/config.toml` plus `supabase/.temp/project-ref`.

### Security

- Reject untrusted, malformed, oversized, multi-line, unreadable, and symlinked expected input paths before prompt rendering.
- Ensure filesystem-derived values are allowlisted before reaching the Spaceship v4 renderer.
- Keep prompt rendering local-only, read-only, cache-free, and free of CLI, network, credential, and external-runtime calls.
- Restrict label state to explicit, validated, owner-only, atomic helper updates.
