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
repair for the stable current-style envelope. The immutable
[`v0.2.0-beta.4` successor prerelease](https://github.com/junyoung2015/spaceship-supabase/releases/tag/v0.2.0-beta.4)
has passed the complete release gate and is in owner only dogfood.
[#15](https://github.com/junyoung2015/spaceship-supabase/issues/15)
authorizes repository owner `@junyoung2015` only and explicitly excludes every
other person. The initial matrix passed and the release owner recorded an
`extend` decision for continued owner only testing.

beta.3 evidence remains historical. The beta.4 initial matrix covers the changed
prefix, layout, migration, rollback, identity, sync, and prompt safety checks.
Longer real world evidence is still required before a stable readiness decision.
The current authorization does not permit a teammate, contributor, external
tester, or phase 2 alpha cohort to install or test beta.4.

[Issue 9](https://github.com/junyoung2015/spaceship-supabase/issues/9) still
requires sufficient redacted two person dogfood evidence before stable v0.2 can
receive a `go` decision. The current owner only authorization cannot satisfy
that gate. A second tester must receive a separate exact authorization in #15
before contributing evidence toward stable promotion.

> **beta.4 release scope:** beta.4 retains beta.3's strict support for the
> v2.111.0+ `{ "projects": [...], "message": "" }` envelope. It adds the
> documented default that registers the prompt section before Spaceship's
> optional `line_sep`, uses the contextual `at ` prefix before the project
> symbol, keeps the identity on the status/context line, and leaves the prompt
> character on the following line under Spaceship's default two-line layout.
> It does not change identity resolution, the prompt-time trust boundary, or
> explicit-sync scope. Missing, unknown, duplicate, malformed, escaped, or
> nonempty companion fields still save no state. An explicit empty section
> prefix remains a user-owned compact-style opt-out.

## Install or move to a reviewed beta

The commands below are currently for `@junyoung2015` only. A future tester may
use them only if [#15](https://github.com/junyoung2015/spaceship-supabase/issues/15)
explicitly names that person and the exact tag. Public repository access and a
published prerelease do not authorize testing.

Pin the tag while cloning:

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

The repository is public, so cloning and fetching require no private repository
access. Eligibility still comes only from the exact authorization in #15.

## Upgrade the prompt registration from beta.3

Checking out beta.4 updates the plugin, but it does not edit user-owned
`.zshrc` configuration. An existing beta.3 installation that still has:

```zsh
if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  spaceship add --before char supabase
fi
```

must **replace that block**, not append another one, with the beta.4 guard:

```zsh
if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]} != 0 )); then
    spaceship add --before line_sep supabase
  else
    spaceship add --before char supabase
  fi
fi
```

Start a fresh shell with `exec zsh`; re-sourcing an already initialized shell
does not move an existing idempotently registered section. Verify that exactly
one `supabase` entry exists and, in the standard two-line layout, its order is
`supabase < line_sep < char`. The expected visible result is
`<status/context> at 🔷 <ref>` followed by `➜` on the next line. Do not paste
the real ref into feedback.

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

Tag rollback does not undo `.zshrc` changes. If the rollback must also restore
the pre-beta.4 prompt-line layout, replace the beta.4 registration guard with
the earlier `spaceship add --before char supabase` guard, then run `exec zsh`.
The `spaceship-ip` suffix repair may remain: it restores that section's normal
Spaceship separator and is independent of Supabase identity resolution. Record
plugin-tag rollback and host-configuration rollback as separate observations.

After sourcing the beta, use the beta.4 guard in
[Upgrade the prompt registration from beta.3](#upgrade-the-prompt-registration-from-beta3).
Its default puts the section before a present `line_sep`, producing
`<status/context> at 🔷 <ref>` followed by `➜` on the next line when
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

## Authorized cohort and security findings

The current beta.4 authorization in #15 covers `@junyoung2015` only and
explicitly excludes `@eddiesohn`, every other contributor, third parties,
external testers, and the phase 2 alpha cohort. The initial owner matrix passed,
and the `extend` decision permits continued owner only dogfood. It does not
authorize stable publication, another tag, a branch tip installation, or a
larger cohort.

Do not place vulnerability details in ordinary feedback or a GitHub issue. Use
the exact direct email route recorded in #15 for the currently authorized owner.
That route is a beta.4 gate specific exception documented in the repository's
[security policy](../SECURITY.md). Other reporters should use GitHub's private
vulnerability reporting route when it is available. The policy's metadata only
public contact request asks only for a private route; it is never a vulnerability
report. A later cohort expansion requires a separately approved and tested route
before another person begins testing.
