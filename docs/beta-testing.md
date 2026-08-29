# Beta testing

Every published beta is an immutable annotated Git tag. Do not install a branch
tip, `main`, or a mutable “latest” reference. Beta releases exercise the same
full release gate as stable releases but are marked as GitHub prereleases, so
they do not replace the latest stable release.

`v0.2.0-beta.1` is an immutable, rejected, unpublished tag: its tag-triggered
release gate failed before GitHub publication. Do not install, retag, or
republish it. `v0.2.0-beta.2` is an immutable published prerelease, but its
current-style explicit-sync path is superseded by `v0.2.0-beta.3`. beta.3 is
immutable and carried the narrow [#27](https://github.com/junyoung2015/spaceship-supabase/issues/27)
repair for the stable current-style envelope. `v0.2.0-beta.4` is the sole
successor candidate for maintainer-only private dogfood. Use the commands below
only after its reviewed annotated tag has passed the release gate and a GitHub
prerelease exists.

> **beta.4 candidate scope:** beta.4 retains beta.3's strict support for the
> v2.111.0+ `{ "projects": [...], "message": "" }` envelope. It adds the
> documented default that registers the prompt section before Spaceship's
> optional `line_sep`, keeping the identity on the status/context line and the
> prompt character on the following line under Spaceship's default two-line
> layout.
> It does not change the renderer, prompt-time trust boundary, or explicit-sync
> scope. Missing, unknown, duplicate, malformed, escaped, or nonempty companion
> fields still save no state.

## Install or move to a reviewed beta

For a new installation after beta.4 is published, pin the exact tag while
cloning:

```zsh
release_tag='v0.2.0-beta.4'
git clone --depth 1 --branch "$release_tag" https://github.com/junyoung2015/spaceship-supabase.git \
  "$HOME/.local/share/spaceship-supabase"
```

For an existing clone, inspect the exact tag before checking it out:

```zsh
plugin_dir="$HOME/.local/share/spaceship-supabase"
release_tag='v0.2.0-beta.4'

git -C "$plugin_dir" fetch --tags --prune origin
git -C "$plugin_dir" show --no-patch --format=fuller "$release_tag"
git -C "$plugin_dir" checkout --detach "$release_tag"
git -C "$plugin_dir" describe --exact-match --tags HEAD
exec zsh
```

Use the location where you installed the plugin. Oh My Zsh’s default is
`"${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/spaceship-supabase"`.

During private dogfood, the clone/fetch requires an account with read access to
the repository (or its SSH clone URL). The exact same tag-pinned procedure
works for a later public beta without authentication.

## Roll back

Return to a previously reviewed stable or beta tag rather than a branch:

```zsh
plugin_dir="$HOME/.local/share/spaceship-supabase"
rollback_tag='v0.1.1'

git -C "$plugin_dir" fetch --tags --prune origin
git -C "$plugin_dir" show --no-patch --format=fuller "$rollback_tag"
git -C "$plugin_dir" checkout --detach "$rollback_tag"
git -C "$plugin_dir" describe --exact-match --tags HEAD
exec zsh
```

The checkout is deliberately detached: it keeps the installed prompt tied to
the tag you inspected and prevents `git pull` from silently moving it.

After sourcing the beta, use the documented registration guard in the README.
Its default puts the section before a present `line_sep`, producing
`<status/context> 🔷 <ref>` followed by `➜` on the next line when
`SPACESHIP_PROMPT_SEPARATE_LINE=true` (the Spaceship default). To show the
whole prompt on one physical line, set `SPACESHIP_PROMPT_SEPARATE_LINE=false`;
to put the identity beside the prompt character, explicitly register it before
`char`.

## Send ordinary feedback safely

First confirm the pinned revision and capture only redacted diagnostics:

```zsh
plugin_dir="$HOME/.local/share/spaceship-supabase"
print -r -- "plugin tag: $(git -C "$plugin_dir" describe --exact-match --tags HEAD)"
print -r -- "zsh: $ZSH_VERSION"
spaceship_supabase_doctor
```

For ordinary setup or expected-behavior feedback, open the repository’s [Support form](https://github.com/junyoung2015/spaceship-supabase/issues/new/choose). Use **Bug report** only for a reproducible non-security defect. State the exact tag, operating system, Zsh/Spaceship/Supabase CLI versions when relevant, the safe reproduction steps, and expected versus observed behavior.

Do not paste a project reference, manual label, full local path, TOML contents,
credentials, terminal recording, or `spaceship_supabase_doctor --verbose`
output unless you have deliberately sanitized it.

## Beta invitations and security findings

The board has not yet approved a private beta invitation/access model or
verified a private vulnerability-reporting route for this repository. Therefore
this guide does not authorize beta invitations and does not provide a security
reporting route. Do not place a security finding in ordinary feedback or a
public issue. After the board adds and verifies a named private route, use only
that named route for a suspected vulnerability; until then, no beta invitation
or security-finding reporting should proceed.
