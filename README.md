# spaceship-supabase

[![CI](https://github.com/junyoung2015/spaceship-supabase/actions/workflows/ci.yml/badge.svg)](https://github.com/junyoung2015/spaceship-supabase/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/junyoung2015/spaceship-supabase)](https://github.com/junyoung2015/spaceship-supabase/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`spaceship-supabase` is a small, local-only [Spaceship Prompt](https://spaceship-prompt.sh/) section for a safely linked Supabase project. It answers one deliberately narrow question: **does this directory have a valid stable-Supabase-CLI linked project reference?**

```text
~/code/api $ git status --short
🔷 abcdefghijklmnopqrst
```

That default segment means a valid local linked-project reference was found beneath the current project boundary. It does **not** automatically claim a friendly project name, a hosted Supabase Branch, remote status, credentials, network freshness, or the state of a deployment. The full 20-character reference is always shown so the prompt remains unambiguous.

The `v0.2.0-beta.4` candidate carries one explicitly confirmed, point-in-time
project-name decoration after a user runs a command. It remains off by default,
keeps the full ref visible, says `synced:project`, and never does a remote
lookup while a prompt is drawn. beta.4 also makes the documented installation
default place the section with the status context when Spaceship has a
`line_sep`; a user can still opt into prompt-line placement. It may be used for
maintainer-only private dogfood only after its reviewed annotated tag has passed
the release gate and published a GitHub prerelease; it is not a stable release
and does not authorize external or phase-2-alpha invitations. The earlier
`v0.2.0-beta.1` tag is immutable but rejected and unpublished, so it must not
be installed or reused. The published `v0.2.0-beta.2` prerelease found that
current v2.111.0+ projects-list JSON envelope incompatibility safely and wrote
no decoration; it remains immutable and is superseded for that sync path.
`v0.2.0-beta.3` carried the focused [#27](https://github.com/junyoung2015/spaceship-supabase/issues/27)
repair and remains immutable. beta.4 is its successor candidate.

The project started from a practical safety need: Supabase commands can mutate
a hosted target while the terminal provides no persistent, recognizable target
context. The stable `v0.1.1` release establishes a truthful full-ref safety
baseline, with a ref-only default display. The `v0.2.0-beta.4` private-dogfood
candidate carries the beta.1-defined behavior without adding prompt-time network
access or hiding the authoritative ref. It retains beta.3's merged current-CLI
compatibility repair and adds only documented, host-owned prompt placement. The
accepted vocabulary, exact v0.2 prompt forms, privacy defaults, and
manual-label/synced-decoration precedence are recorded in the [v0.2 target-context contract](docs/design/v0.2-target-context-contract.md).

## Requirements

- Zsh 5.2 or later.
- Spaceship Prompt v4. The release suite uses Spaceship v4.21.0.
- A project linked by a stable Supabase CLI release, with `supabase/config.toml` and a valid `supabase/.temp/project-ref` where live identity should be displayed.
- Only for the explicit v0.2 beta sync helper: an installed, authenticated Supabase CLI that can list the intended project. It is not required for normal prompt rendering.

No Supabase CLI executable, network access, credential lookup, Node, Python, or jq is used while a prompt is rendered.

## Install

### Oh My Zsh

Install and configure Spaceship Prompt first. Clone the current release into your custom plugin directory:

```zsh
git clone --depth 1 --branch v0.2.0-beta.4 https://github.com/junyoung2015/spaceship-supabase.git \
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

# Default: keep the project identity on the status/context line. If the host
# has no line separator, retain the safe prompt-character fallback.
if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]} != 0 )); then
    spaceship add --before line_sep supabase
  else
    spaceship add --before char supabase
  fi
fi
```

Restart the shell or run `source ~/.zshrc`.

### Generic Zsh

Clone the current release wherever you keep prompt plugins, then source
Spaceship Prompt before the section. This example uses a local-share directory:

```zsh
git clone --depth 1 --branch v0.2.0-beta.4 https://github.com/junyoung2015/spaceship-supabase.git \
  "$HOME/.local/share/spaceship-supabase"
```

Adjust the Spaceship path to your installation:

```zsh
source "$HOME/.local/share/spaceship/spaceship.zsh"
source "$HOME/.local/share/spaceship-supabase/spaceship-supabase.plugin.zsh"

# Default: keep the project identity on the status/context line. If the host
# has no line separator, retain the safe prompt-character fallback.
if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]} != 0 )); then
    spaceship add --before line_sep supabase
  else
    spaceship add --before char supabase
  fi
fi
```

The registration guard is intentional and idempotent. A loaded external section
is not rendered until it is named in `SPACESHIP_PROMPT_ORDER`; repeatedly
running `spaceship add` without the guard would duplicate the section. The
default prefers the context side of Spaceship's optional `line_sep`, so the
section stays beside status information in the normal two-line Spaceship
layout (`SPACESHIP_PROMPT_SEPARATE_LINE=true`, the Spaceship default). Its
intended shape is:

```text
<status and context> 🔷 abcdefghijklmnopqrst
➜
```

The integration does not set `SPACESHIP_PROMPT_SEPARATE_LINE` or otherwise
override the shell's global layout choice.

To keep the entire prompt on one physical line, set this Spaceship setting:

```zsh
SPACESHIP_PROMPT_SEPARATE_LINE=false
```

To deliberately put the Supabase section on the prompt-character line instead,
replace the default registration target with `char`:

```zsh
if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  spaceship add --before char supabase
fi
```

For either installation route, make configuration assignments before the next
prompt is drawn. The section can be loaded once and reconfigured in the current
shell.

### Tagged updates, private dogfooding, and rollback

The beta deliberately has no auto-updater or `curl | sh` installer. A prompt
plugin runs in your interactive shell, so use an explicit release tag that you
can inspect and roll back. From a clone installed by the instructions above:

```zsh
# Set this to the clone you installed. This is the Oh My Zsh default.
plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase"
git -C "$plugin_dir" fetch --tags --prune origin
git -C "$plugin_dir" show --no-patch --format=fuller v0.2.0-beta.4
git -C "$plugin_dir" checkout --detach v0.2.0-beta.4
exec zsh
```

Replace `v0.2.0-beta.4` only after reviewing the next release's notes and tag. While
the repository is private, these commands require authenticated GitHub read
access. To roll back, check out a previous reviewed tag with the same command.
`v0.2.0-beta.1` is immutable but rejected and unpublished; do not install,
retag, or republish it. `v0.2.0-beta.2` is published but superseded for
current-style sync; do not retag it. The
`v0.2.0-beta.3` is immutable and superseded by the `v0.2.0-beta.4` successor
candidate, which may be used for maintainer-only private dogfood only after its
reviewed annotated tag has published a GitHub prerelease.
It does not authorize an external beta, phase-2-alpha invitations, or the
Dongtan-report decision. Use a reviewed beta tag—not a branch—and follow the
exact [beta install, rollback, verification, and feedback steps](docs/beta-testing.md).

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

### Explicit synced project name — v0.2 private dogfood

The normal prompt never calls Supabase or exposes a remote project name. After
the reviewed `v0.2.0-beta.4` annotated tag has published a GitHub prerelease,
maintainer-private dogfood can deliberately discover the name for the **current
live ref** and save it as a separate, point-in-time decoration:

> **beta.4 candidate scope:** beta.4 retains beta.3's stable current-style
> v2.111.0+ `{ "projects": [...], "message": "" }` envelope support only in
> the explicit user-invoked helper. It remains fail-closed for missing,
> unknown, duplicate, malformed, escaped, or nonempty companion fields. The
> only additional beta.4 behavior is the documented default prompt placement;
> normal live-ref rendering never invokes the CLI.

```zsh
spaceship_supabase_sync project
# Review the preview, then answer y to save it.

# For an intentional non-interactive confirmation:
spaceship_supabase_sync project --yes
```

The command runs the installed Supabase CLI only after proving a safe root and
live ref. It matches that exact full ref in `supabase projects list`, previews
the following form, and asks before writing its own owner-only state file:

```text
🔷 Customer API (abcdefghijklmnopqrst) · synced:project
```

Saving does not make a name visible. Opt in to the remote-derived decoration
separately, while retaining the full identity ref:

```zsh
SPACESHIP_SUPABASE_FORMAT="label+ref"
SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS=true
```

`synced:project` means user-confirmed lookup data saved earlier, not network
freshness at this prompt. A matching manual label visibly wins; clearing that
manual label can reveal an independently valid synced decoration on the next
render. Synced text never decorates a configured mapping, recovers a missing
identity, or implies a hosted branch. See [configuration](docs/configuration.md),
[data sources](docs/data-sources.md), and [labels and local state](docs/labels.md).

## Trust boundary and privacy

Prompt input is untrusted filesystem state. The plugin accepts only narrow, validated values, rejects unsafe identity-critical root/ref/config input, and interpolates no raw file contents into the prompt. An unsafe optional local-db branch is simply omitted; it cannot alter an independently valid live reference. Normal failures are silent. Optional debug output uses fixed diagnostic codes rather than paths or raw values.

The explicit sync helper is outside that prompt boundary: it may invoke the
installed Supabase CLI, which may use credentials and network access. Its
output is size-bounded, parsed only as the two audited project-list JSON forms,
matched to the exact current ref, validated before preview/storage, and never
echoed raw on failure. It rechecks live identity immediately before its atomic
write.

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
- [Beta testing, rollback, and feedback](docs/beta-testing.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Support](SUPPORT.md)
- [Release history](CHANGELOG.md)
- [v0.1.0 release plan](docs/releases/v0.1.0-release-plan.md)

## License

MIT. See [LICENSE](LICENSE).
