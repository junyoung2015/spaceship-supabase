# Contributing

Thanks for improving `spaceship-supabase`. Prompt output influences which hosted project a developer believes they are using, so identity and filesystem changes receive security review.

## Choose the work

1. Search the [issues](https://github.com/junyoung2015/spaceship-supabase/issues) and milestones for current work.
2. Read the [roadmap](docs/roadmap.md) before proposing product behavior.
3. Open or reference an issue before changing identity precedence, target names, branch semantics, persistence, network or CLI boundaries, or public configuration.

Compatibility proposals need primary Supabase sources and a report under `docs/research/`. Evidence from a nonstable CLI tree or channel does not establish a supported contract.

### Where BMad fits

Maintainers may use BMad for early planning and cross discipline review. GitHub issues and milestones are the current source of truth, and contributors do not need BMad.

## Set up locally

1. Use Zsh 5.2 or later.
2. Clone the repository and create a focused branch.
3. Run the canonical suite before opening a pull request:

   ```zsh
   ZSH_BIN="$(command -v zsh)" tests/run.zsh
   ```

4. Run the performance gate for release sensitive work:

   ```zsh
   ZSH_BIN="$(command -v zsh)" tests/run.zsh --performance
   ```

The runner uses tracked vendor dependencies and temporary synthetic project layouts.

## Protect the prompt boundary

Read [AGENTS.md](AGENTS.md) for the complete contract and [data sources](docs/data-sources.md) before changing resolver behavior.

| Area | Required behavior |
| --- | --- |
| Runtime | Support Zsh 5.2 or later and render through Spaceship v4 |
| Prompt path | Keep it local, read only, fresh, and free of external processes |
| Filesystem input | Bound files, reject symlinks, validate accepted values, and fail closed |
| Identity | Let a valid live project ref win and keep lower authority sources visibly marked |
| Output | Pass only allowlisted values to the renderer and retain the complete ref |
| Scope changes | Require product contract and security review for new identity sources or formats |

Project names and branch sources also require the current [target context research](docs/research/supabase-cli-project-names.md).

## Add tests and fixtures

Cover each behavior change with positive and negative cases. Security sensitive changes need the real Spaceship v4 rendering path where relevant. Keep fixtures flat, synthetic, tracked, and free of real project state, credentials, account refs, home directory paths, and captured Supabase directories.

Review the behavior matrix in [testing](docs/testing.md). Preserve explicit failure path tests when measuring coverage.

## Keep documentation aligned

Update the README, configuration, data sources, labels, troubleshooting, compatibility, testing, and changelog when public behavior changes. Contributors leave release dates to the sanitized release commit. The [beta testing guide](docs/beta-testing.md) defines prerelease installation and rollback.

## Pull request checklist

* Keep the change focused.
* Explain user visible behavior and security impact.
* List each test command and result.
* Flag compatibility and documentation effects.
* Remove secrets, raw user paths, local Supabase state, and unrelated formatting churn.

Report security issues through [SECURITY.md](SECURITY.md). Keep vulnerability details out of pull requests and public issues.
