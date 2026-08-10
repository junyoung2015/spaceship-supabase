# spaceship-supabase

[![CI](https://github.com/junyoung2015/spaceship-supabase/actions/workflows/ci.yml/badge.svg)](https://github.com/junyoung2015/spaceship-supabase/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/junyoung2015/spaceship-supabase)](https://github.com/junyoung2015/spaceship-supabase/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`spaceship-supabase` is a small, local-only [Spaceship Prompt](https://spaceship-prompt.sh/) section for a safely linked Supabase project. It answers one deliberately narrow question: **does this directory have a valid stable-Supabase-CLI linked project reference?**

```text
~/code/api $ git status --short
🔷 abcdefghijklmnopqrst
```

That segment means a valid local linked-project reference was found beneath the current project boundary. It does **not** claim a friendly project name, a hosted Supabase Branch, remote status, credentials, network freshness, or the state of a deployment. The full 20-character reference is always shown so the prompt remains unambiguous.

## Requirements

- Zsh 5.2 or later.
- Spaceship Prompt v4. The release suite uses Spaceship v4.21.0.
- A project linked by a stable Supabase CLI release, with `supabase/config.toml` and a valid `supabase/.temp/project-ref` where live identity should be displayed.

No Supabase CLI executable, network access, credential lookup, Node, Python, or jq is used while a prompt is rendered.

## Install

### Oh My Zsh

Install and configure Spaceship Prompt first. Clone this repository into your custom plugin directory:

```zsh
git clone https://github.com/junyoung2015/spaceship-supabase.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase"
```

In `.zshrc`, source the section **after** Oh My Zsh has loaded your Spaceship theme:

```zsh
ZSH_THEME="spaceship"
source "$ZSH/oh-my-zsh.sh"

source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase/spaceship-supabase.plugin.zsh"
```

Restart the shell or run `source ~/.zshrc`.

### Generic Zsh

Source Spaceship Prompt before the section. Adjust both paths to your installation:

```zsh
source "$HOME/.local/share/spaceship/spaceship.zsh"
source "$HOME/.local/share/spaceship-supabase/spaceship-supabase.plugin.zsh"
```

For either installation route, make configuration assignments before the next prompt is drawn. The section can be loaded once and reconfigured in the current shell.

## Quick verification

Open a new shell in a directory inside a linked project:

```text
<project-root>/supabase/config.toml
<project-root>/supabase/.temp/project-ref
```

If `project-ref` contains exactly 20 lowercase letters, the next prompt includes:

```text
🔷 abcdefghijklmnopqrst
```

If no segment appears, that is normally intentional fail-closed behavior. Start with [troubleshooting](docs/troubleshooting.md) rather than loosening file permissions or adding shell parsing commands.

## Common controls

The default is compact and uses the live local reference:

```zsh
SPACESHIP_SUPABASE_SHOW=true
SPACESHIP_SUPABASE_FORMAT="ref"
```

You may add a local, manually maintained label while retaining the exact reference:

```zsh
SPACESHIP_SUPABASE_FORMAT="label+ref"
spaceship_supabase_label set "Production"
```

```text
🔷 Production (abcdefghijklmnopqrst)
```

Labels never select a project or make a segment appear by themselves. They only decorate a reference that the renderer has just resolved. See [labels](docs/labels.md).

To opt in to the local database-branch marker used by the stable CLI's deprecated local branch command when a live reference is present:

```zsh
SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH=true
```

```text
🔷 abcdefghijklmnopqrst (local-db:feature/refactor-42)
```

This is explicitly local database state, not a hosted Supabase Branch. The plugin never formats it as `ref@branch`.

An optional config mapping is available only when selected explicitly. Given this local configuration:

```toml
[remotes.staging]
project_id = "abcdefghijklmnopqrst"
```

set:

```zsh
SPACESHIP_SUPABASE_CONFIG_REMOTE="staging"
```

When there is no valid live `project-ref`, the deliberately non-authoritative output is:

```text
🔷 abcdefghijklmnopqrst · configured:staging
```

A live `project-ref` always wins. The top-level `project_id` in `config.toml` is never interpreted as a hosted project reference.

## Trust boundary and privacy

Prompt input is untrusted filesystem state. The plugin accepts only narrow, validated values, rejects unsafe identity-critical root/ref/config input, and interpolates no raw file contents into the prompt. An unsafe optional local-db branch is simply omitted; it cannot alter an independently valid live reference. Normal failures are silent. Optional debug output uses fixed diagnostic codes rather than paths or raw values.

The reference displayed in a prompt is not a secret, but it can still identify a hosted project. Treat screenshots, recordings, support logs, and copied prompts accordingly. `spaceship_supabase_doctor` is local-only and redacts status by default; use `--verbose` only when you intend to share its sanitized values.

## Documentation

- [Configuration reference](docs/configuration.md)
- [Data sources and precedence](docs/data-sources.md)
- [Labels and local state](docs/labels.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Compatibility](docs/compatibility.md)
- [Testing](docs/testing.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Support](SUPPORT.md)
- [Release history](CHANGELOG.md)
- [v0.1.0 release plan](docs/releases/v0.1.0-release-plan.md)

## License

MIT. See [LICENSE](LICENSE).
