<h1 align="center">spaceship-supabase</h1>

<p align="center"><strong>See the linked Supabase project in your Spaceship Prompt before you run the next command.</strong></p>

<p align="center">
  <a href="https://github.com/junyoung2015/spaceship-supabase/actions/workflows/ci.yml"><img src="https://github.com/junyoung2015/spaceship-supabase/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/junyoung2015/spaceship-supabase/releases"><img src="https://img.shields.io/github/v/release/junyoung2015/spaceship-supabase" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
</p>

<p align="center">
  <a href="#install">Install</a>
  &nbsp;&nbsp;
  <a href="#what-it-shows">Examples</a>
  &nbsp;&nbsp;
  <a href="#safety-model">Safety</a>
  &nbsp;&nbsp;
  <a href="#documentation">Documentation</a>
</p>

Supabase commands can change a hosted project, while the terminal usually gives no persistent reminder of the linked target.

`spaceship-supabase` reads validated local link state and renders the complete 20 character project reference. Prompt rendering stays local, read only, and fresh.

## What it shows

The stable `v0.1.1` release places the linked project beside the prompt character:

```text
~/code/customer-api on main
🔷 abcdefghijklmnopqrst ➜
```

The reference stays visible when you add a local label:

```text
🔷 Production (abcdefghijklmnopqrst)
```

| Display | Meaning |
| --- | --- |
| `🔷 abcdefghijklmnopqrst` | A valid live project ref was found locally |
| `🔷 Production (abcdefghijklmnopqrst)` | A local label decorates that same live ref |
| `local-db:<name>` marker | Optional local database branch context |
| `configured:<name>` marker | Explicit config fallback with lower authority than a live ref |
| No segment | Check visibility, registration, renderer, format, and identity inputs |

A missing segment can mean the section is hidden, unregistered, unavailable, using an unsupported format, or unable to resolve a safe identity. When a live ref is absent or rejected, a valid explicitly selected config mapping may still render with `configured:<name>`. See the stable [data sources and precedence](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/data-sources.md) for the exact identity rules.

## Why use it

| Goal | Behavior |
| --- | --- |
| Keep the target visible | The complete project ref remains in the prompt |
| Avoid stale identity | Local state is read again for every render |
| Respect project boundaries | Resolution stops at the nearest safe `supabase/config.toml` |
| Fail safely | Unsafe input never becomes prompt text |
| Keep rendering lightweight | Normal rendering starts no CLI, network, credential, or parser process |

## Install

You need Zsh 5.2 or later and [Spaceship Prompt v4](https://spaceship-prompt.sh/). Install the stable `v0.1.1` release unless you are participating in an authorized prerelease test.

### Oh My Zsh

Clone the stable release:

```zsh
git clone --depth 1 --branch v0.1.1 https://github.com/junyoung2015/spaceship-supabase.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase"
```

In `~/.zshrc`, keep this order. Add the plugin source and registration after your existing Spaceship theme and Oh My Zsh source lines. Leave `spaceship-supabase` out of `plugins=(...)` so it loads once.

```zsh
ZSH_THEME="spaceship"
source "$ZSH/oh-my-zsh.sh"

source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase/spaceship-supabase.plugin.zsh"

if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  spaceship add --before char supabase
fi
```

Start a fresh shell with `exec zsh`.

<details>
<summary><strong>Generic Zsh installation</strong></summary>

Clone the stable release wherever you keep prompt plugins:

```zsh
git clone --depth 1 --branch v0.1.1 https://github.com/junyoung2015/spaceship-supabase.git \
  "$HOME/.local/share/spaceship-supabase"
```

Source Spaceship first, then this section:

```zsh
source "$HOME/.local/share/spaceship/spaceship.zsh"
source "$HOME/.local/share/spaceship-supabase/spaceship-supabase.plugin.zsh"

if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  spaceship add --before char supabase
fi
```

Start a fresh shell with `exec zsh`.

</details>

### Verify the result

Open a new shell inside a linked project containing both files:

```text
<project-root>/supabase/config.toml
<project-root>/supabase/.temp/project-ref
```

When `project-ref` contains exactly 20 lowercase letters, the prompt shows the full ref. If the segment stays hidden, run:

```zsh
spaceship_supabase_doctor
```

Then follow the stable [v0.1.1 troubleshooting guide](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/troubleshooting.md).

## Customize the display

The default format shows the live ref:

```zsh
SPACESHIP_SUPABASE_SHOW=true
SPACESHIP_SUPABASE_FORMAT="ref"
```

Add a local label while retaining the ref:

```zsh
SPACESHIP_SUPABASE_FORMAT="label+ref"
spaceship_supabase_label set "Production"
```

Optional controls cover the symbol, color, format, selected config remote, and local database branch marker. Stable users should follow the [v0.1.1 configuration reference](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/configuration.md) and [v0.1.1 label guide](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/labels.md). The [beta.4 configuration reference](docs/configuration.md) also documents the prerelease prefix, prompt placement, and synced project decoration.

## Safety model

| Boundary | Guarantee |
| --- | --- |
| Live identity | A valid `supabase/.temp/project-ref` always wins |
| Labels | A label decorates a currently resolved ref and cannot select one |
| Config fallback | Only an explicitly selected `[remotes.<name>].project_id` is accepted |
| Filesystem input | Expected paths reject symlinks and stay below the selected safe root |
| Prompt rendering | No writes, network calls, Supabase CLI calls, credential reads, or persistent identity cache |
| Diagnostics | Normal failures stay silent and doctor output is redacted by default |

A project ref can identify a hosted project. Remove refs, labels, paths, and configuration values from screenshots or support logs unless you intend to share them.

## Release channels

| Channel | Status | Guidance |
| --- | --- | --- |
| [`v0.1.1`](https://github.com/junyoung2015/spaceship-supabase/releases/tag/v0.1.1) | Latest stable | Recommended for regular installation |
| [`v0.2.0-beta.4`](https://github.com/junyoung2015/spaceship-supabase/releases/tag/v0.2.0-beta.4) | Owner only dogfood | [Issue 15](https://github.com/junyoung2015/spaceship-supabase/issues/15) authorizes `@junyoung2015` only. Every other person must not install this beta. The current decision is `extend` |
| `main` | Development source | Inspect changes here and install a reviewed release tag |

The [beta testing guide](docs/beta-testing.md) covers eligibility, installation, rollback, verification, and private feedback. Prerelease publication does not expand the named cohort. The [changelog](CHANGELOG.md) records release history.

<details>
<summary><strong>Authorized beta layout example</strong></summary>

The documented `v0.2.0-beta.4` registration places the identity on the context line:

```text
~/code/customer-api on main at 🔷 abcdefghijklmnopqrst
➜
```

</details>

## Documentation

Choose documentation for the release you installed. Files on `main` describe the current beta.4 prerelease.

| Need | Stable `v0.1.1` | Current beta.4 |
| --- | --- | --- |
| Configure the section | [Stable configuration](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/configuration.md) | [Beta configuration](docs/configuration.md) |
| Understand identity precedence | [Stable data sources](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/data-sources.md) | [Beta data sources](docs/data-sources.md) |
| Manage local labels | [Stable labels](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/labels.md) | [Beta labels](docs/labels.md) |
| Fix a missing or unexpected segment | [Stable troubleshooting](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/troubleshooting.md) | [Beta troubleshooting](docs/troubleshooting.md) |
| Check compatibility | [Stable compatibility](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/compatibility.md) | [Beta compatibility](docs/compatibility.md) |
| Run repository checks | [Stable testing](https://github.com/junyoung2015/spaceship-supabase/blob/v0.1.1/docs/testing.md) | [Beta testing reference](docs/testing.md) |

The [documentation index](docs/README.md) routes product, design, research, contribution, and release references for the current source tree.

<details>
<summary><strong>Maintainer product contract and evidence</strong></summary>

* [Roadmap](docs/roadmap.md)
* [v0.2 target context contract](docs/design/v0.2-target-context-contract.md)
* [Supabase CLI research](docs/research/supabase-cli-project-names.md)
* [Spaceship IP research](docs/research/spaceship-ip-load-order.md)
* [v0.1.0 release plan](docs/releases/v0.1.0-release-plan.md)

</details>

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Use [SUPPORT.md](SUPPORT.md) for setup help. Report vulnerabilities through the private route in [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
