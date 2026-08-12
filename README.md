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

The project started from a practical safety need: Supabase commands can mutate
a hosted target while the terminal provides no persistent, recognizable target
context. The current release establishes a truthful full-ref safety baseline,
with a ref-only default display. The [roadmap](docs/roadmap.md) develops that
baseline toward human-readable project and environment context without adding
prompt-time network access or hiding the authoritative ref.
The planned vocabulary, exact v0.2 prompt forms, privacy defaults, and
manual-label/synced-decoration precedence are recorded before feature work in
the [v0.2 target-context contract](docs/design/v0.2-target-context-contract.md).

## Requirements

- Zsh 5.2 or later.
- Spaceship Prompt v4. The release suite uses Spaceship v4.21.0.
- A project linked by a stable Supabase CLI release, with `supabase/config.toml` and a valid `supabase/.temp/project-ref` where live identity should be displayed.

No Supabase CLI executable, network access, credential lookup, Node, Python, or jq is used while a prompt is rendered.

## Install

### Oh My Zsh

Install and configure Spaceship Prompt first. Clone the current release into your custom plugin directory:

```zsh
git clone --depth 1 --branch v0.1.1 https://github.com/junyoung2015/spaceship-supabase.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase"
```

While the repository is private, run the clone with a GitHub account that has
read access (or use its SSH URL). Do not also add `spaceship-supabase` to Oh My
Zsh's `plugins=(...)` list: source it once, **after** Oh My Zsh has loaded your
Spaceship theme, then register the external section in the prompt order:

```zsh
ZSH_THEME="spaceship"
source "$ZSH/oh-my-zsh.sh"

source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase/spaceship-supabase.plugin.zsh"

# Add the custom section once, before the prompt character.
if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  spaceship add --before char supabase
fi
```

Restart the shell or run `source ~/.zshrc`.

### Generic Zsh

Clone the current release wherever you keep prompt plugins, then source
Spaceship Prompt before the section. This example uses a local-share directory:

```zsh
git clone --depth 1 --branch v0.1.1 https://github.com/junyoung2015/spaceship-supabase.git \
  "$HOME/.local/share/spaceship-supabase"
```

Adjust the Spaceship path to your installation:

```zsh
source "$HOME/.local/share/spaceship/spaceship.zsh"
source "$HOME/.local/share/spaceship-supabase/spaceship-supabase.plugin.zsh"

# Add the custom section once, before the prompt character.
if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  spaceship add --before char supabase
fi
```

The registration guard is intentional and idempotent. A loaded external section
is not rendered until it is named in `SPACESHIP_PROMPT_ORDER`; repeatedly
running `spaceship add` without the guard would duplicate the section. For
either installation route, make configuration assignments before the next
prompt is drawn. The section can be loaded once and reconfigured in the current
shell.

### Manual private dogfooding and updates

v0.1.1 deliberately has no auto-updater or `curl | sh` installer. A prompt
plugin runs in your interactive shell, so use an explicit release tag that you
can inspect and roll back. From a clone installed by the instructions above:

```zsh
# Set this to the clone you installed. This is the Oh My Zsh default.
plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase"
git -C "$plugin_dir" fetch --tags --prune origin
git -C "$plugin_dir" show --no-patch --format=fuller v0.1.1
git -C "$plugin_dir" checkout --detach v0.1.1
exec zsh
```

Replace `v0.1.1` only after reviewing the next release's notes and tag. While
the repository is private, these commands require authenticated GitHub read
access. To roll back, check out a previous reviewed tag with the same command.

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

- [Product roadmap and planning history](docs/roadmap.md)
- [v0.2 target-context contract](docs/design/v0.2-target-context-contract.md)
- [Supabase CLI project-name and target-context research](docs/research/supabase-cli-project-names.md)
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
