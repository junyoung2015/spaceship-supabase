# Contributing

Thanks for helping improve `spaceship-supabase`. This project is deliberately small because terminal prompts cross a sensitive trust boundary: input may come from an arbitrary checkout, but output influences what a developer believes they are operating on.

## Planning and issues

Read the [product roadmap](docs/roadmap.md) before proposing a behavior change.
GitHub milestones and issues are the active backlog; the private initial-plan
and BMad archives are historical context only. Open or reference an issue before
changing identity precedence, target naming, branch semantics, persistence,
network/CLI boundaries, or the public configuration contract.

Compatibility proposals must cite primary Supabase sources and update or add a
report under `docs/research/`. A source file existing in a non-stable CLI tree
or channel is not, by itself, a supported contract.

## Local setup

1. Use Zsh 5.2 or later.
2. Clone the repository and work on a focused branch.
3. Run the canonical suite before opening a pull request:

   ```sh
   ZSH_BIN="$(command -v zsh)" tests/run.zsh
   ZSH_BIN="$(command -v zsh)" tests/run.zsh --performance
   ```

The runner uses tracked vendor dependencies and creates temporary synthetic project layouts. Do not run a network fetch script as part of normal testing.

## Zsh and safety conventions

- Support Zsh 5.2+ and use Zsh-native code in the prompt path.
- Keep prompt rendering local-only and read-only: no network, Supabase CLI, Node, Python, jq, credential read, prompt-time write, or persistent render cache.
- Treat every filesystem value as untrusted. Bound files, reject symlinks, validate values before rendering, and fail closed with no normal stderr output.
- Never interpolate raw filesystem, TOML, label, or path data into the prompt. Use the supported Spaceship v4 renderer only after strict allowlist validation.
- A live valid `supabase/.temp/project-ref` always wins. A selected config mapping is marked and non-authoritative; a label can only decorate a currently resolved reference.
- Do not add an automatic remote lookup, historical identity cache, arbitrary output templates, truncation, branch-only output, or `.supabase/project.json` support without an approved product-contract and security review.

Read [AGENTS.md](AGENTS.md) for the complete implementation constraints,
[docs/data-sources.md](docs/data-sources.md) before changing resolver behavior,
and the current
[Supabase CLI target-context research](docs/research/supabase-cli-project-names.md)
before changing project-name or branch sources.

## Tests and fixtures

Add or update behavior tests for every behavior change. Security-sensitive changes need positive and negative coverage, including the actual Spaceship v4 rendering path where relevant. Fixtures must be flat, synthetic, tracked inputs; materialize runtime layouts only under a temporary directory. Never commit real Supabase state, a project ref from a real account, credentials, a home-directory path, or an ignored runtime tree.

Do not trade explicit critical failure-path tests for an xtrace percentage. Review the behavior matrix in [docs/testing.md](docs/testing.md).

## Documentation and changelog

Keep `README.md`, configuration, data-source, label, troubleshooting, compatibility, and testing documentation synchronized with implementation. Update `CHANGELOG.md` under `Unreleased` for user-visible changes. During a version cut, the release manager adds one undated `## [X.Y.Z]` section for the candidate; the sanitized public release commit may add its ISO date before the annotated tag is pushed. Contributors should not pre-date a future release.

If a stable Supabase CLI layout changes, add a synthetic versioned fixture, document the evidence and compatibility impact, and retain the previous supported fixture until the support policy changes.

## Pull requests

Keep pull requests focused, explain the user-visible and security impact, list test commands and results, and flag compatibility or documentation changes. Do not include secrets, raw user paths, local Supabase files, generated archives, or unrelated formatting churn. Security issues must follow [SECURITY.md](SECURITY.md), not a pull request or public issue.
