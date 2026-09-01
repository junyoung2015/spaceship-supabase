# Spaceship IP section load-order research

- **Status:** compatibility input for the `v0.2.0-beta.4` prompt-boundary fix
- **As of:** 2026-09-01
- **Question:** why can an Oh My Zsh `spaceship-ip` section lose the separator
  before a following Supabase section, and what is the narrow repair?
- **Pinned inputs:** Oh My Zsh
  [`146461f7c6d95f4ba1220559d66eb113418b40a8`](https://github.com/ohmyzsh/ohmyzsh/blob/146461f7c6d95f4ba1220559d66eb113418b40a8/oh-my-zsh.sh#L204-L229),
  `spaceship-ip`
  [`801b351ad6ff48ce4a5f3d356400cb6d1de2bb31`](https://github.com/TheArqsz/spaceship-ip/blob/801b351ad6ff48ce4a5f3d356400cb6d1de2bb31/spaceship-ip.plugin.zsh#L11-L18),
  and Spaceship Prompt v4.21.0
  [`e498b1381df3a122af107b61f5cc8f3ced93ee69`](https://github.com/spaceship-prompt/spaceship-prompt/blob/e498b1381df3a122af107b61f5cc8f3ced93ee69/spaceship.zsh#L115-L124).

## Verified load order

Oh My Zsh sources every configured plugin before it sources the selected theme.
The pinned `spaceship-ip` plugin evaluates this assignment while its plugin file
is sourced:

```zsh
SPACESHIP_IP_SUFFIX="${SPACESHIP_IP_SUFFIX="$SPACESHIP_PROMPT_DEFAULT_SUFFIX"}"
```

When the Spaceship theme has not initialized yet,
`SPACESHIP_PROMPT_DEFAULT_SUFFIX` is empty or unset. `SPACESHIP_IP_SUFFIX`
therefore becomes an explicit empty value. Spaceship later initializes its
default suffix to one space, but the already assigned IP suffix does not update
itself.

Spaceship v4 renders a section's suffix after that section's content and renders
the next section's prefix only after the boundary. The pinned renderer shows
those as separate operations in
[`lib/section.zsh`](https://github.com/spaceship-prompt/spaceship-prompt/blob/e498b1381df3a122af107b61f5cc8f3ced93ee69/lib/section.zsh#L68-L109).
An empty IP suffix therefore produces:

```text
@ 192.0.2.1at 🔷 abcdefghijklmnopqrst
```

Adding a leading space to the Supabase prefix would repair only this one broken
predecessor and would double-space after normal Spaceship sections. The
predecessor must restore its own standard suffix instead.

## Compatibility decision

After Spaceship core or the Spaceship Oh My Zsh theme has initialized, and
before the IP and Supabase sections are registered, use:

```zsh
SPACESHIP_IP_SUFFIX="$SPACESHIP_PROMPT_DEFAULT_SUFFIX"
```

The resulting boundary is:

```text
@ 192.0.2.1 at 🔷 abcdefghijklmnopqrst
```

This assignment is user-owned host configuration. It does not change Supabase
identity, provenance, prompt-time I/O, or the default suffix of any other
section. A user who intentionally wants a custom IP suffix can set that value
instead.

## Regression-test boundary

The integration suite reproduces the pinned assignment semantics without
executing the third-party plugin's network-interface commands. It proves that:

1. the IP suffix captured before Spaceship initialization is empty;
2. Spaceship later initializes its default suffix without retroactively
   changing the captured IP suffix;
3. the unrepaired real Spaceship v4 composition joins the IP content to
   `at 🔷`;
4. the documented assignment restores exactly one separator; and
5. an ordinary section that already uses the default suffix also produces
   exactly one separator.

If Oh My Zsh changes plugin/theme ordering, `spaceship-ip` changes its default
assignment, or Spaceship changes v4 suffix rendering, re-audit this guidance
against new immutable revisions before changing the compatibility claim.
