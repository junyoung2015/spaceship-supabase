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
has passed the complete release gate and is published for a possible
maintainer-private dogfood gate. Do not use the commands below until the release
owner separately authorizes beta.4 testing in
[#15](https://github.com/junyoung2015/spaceship-supabase/issues/15).

beta.3 test and dogfood evidence may support unchanged identity, sync, and
prompt-safety code, but it is not beta.4 acceptance or authorization. beta.4
now exists as an immutable reviewed tag and GitHub prerelease; the remaining
gate is an explicit beta.4 decision in #15. Each person authorized by that
decision must repeat the Core matrix plus the changed prefix, layout, migration,
and rollback observations before the release owner records `go`, `extend`, or
`pause` in [#15](https://github.com/junyoung2015/spaceship-supabase/issues/15).

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

For a new installation after beta.4 is published **and** #15 explicitly
authorizes you for that exact tag, pin the tag while cloning:

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

After sourcing the beta, use the documented registration guard in the README.
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

## Private cohort and security findings

The current authorization in #15 covers the repository owner and one named
teammate testing beta.3 only. It does not carry forward to beta.4. The exact
reviewed beta.4 tag and prerelease now exist, and the intended two-person
private-repository access boundary has been verified. Dogfood still must not
begin until the release owner records a new beta.4 authorization—including
cohort, access, confidentiality, reporting route, and decision authority.
Neither the beta.3 decision nor a future two-person beta.4 decision authorizes
a third tester, an external or phase-2-alpha cohort, a visibility change, or a
branch-tip installation.

Do not place vulnerability details in ordinary feedback or a GitHub issue. Use
the repository's [security policy](../SECURITY.md): submit a GitHub Security
Advisory when GitHub exposes that route to the reporter, otherwise use the
direct private channel explicitly agreed for the authorized cohort. The
release-owner check for this private beta.4 gate found that GitHub's private
vulnerability-reporting route is unavailable, and no exact direct channel is
yet recorded in #15; that missing route currently blocks authorization. The
policy's metadata-only public contact request asks only for a private route; it
is never a vulnerability report. Confirm that the chosen private route is
accessible before testing. A later external invitation requires a separately
approved and tested reporting route.
