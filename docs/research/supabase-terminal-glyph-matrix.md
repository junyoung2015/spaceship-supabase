# Supabase terminal glyph matrix

## Outcome

The release-compatible default remains exactly `🔷 ` with `cyan`.
Issue [#36](https://github.com/junyoung2015/spaceship-supabase/issues/36)
remains open because the supported-terminal visual matrix has no safe,
controlled captures yet. `S ` is the leading future portable candidate; it has
not received a default-change decision.

1. A prompt glyph is an unofficial Supabase mnemonic. It is never an official
   Supabase terminal mark.
2. The complete validated 20-character ref remains the identity. A visual
   glyph never establishes identity, branch provenance, authorization, or
   freshness.
3. This record makes no plugin-default, user-configuration, release, cohort,
   or issue-milestone change.

## Current decision

| Setting | Current value | Decision |
| --- | --- | --- |
| `SPACESHIP_SUPABASE_SYMBOL` | `🔷 ` | Preserve exactly. |
| `SPACESHIP_SUPABASE_COLOR` | `cyan` | Preserve exactly. |
| Future portable candidate | `S ` | Evaluate only after the visual matrix is complete. |
| Future patched-font candidate | Nerd Fonts `dev-supabase` at `U+E8B6` | Opt-in-only evaluation path. |
| Tracker state | [#36](https://github.com/junyoung2015/spaceship-supabase/issues/36) | Keep open. |

The hold protects compatibility while the repository gathers evidence. The
existing diamond is an emoji-presentation character, so its visual width and
appearance remain terminal and font dependent. A switch to green alone would
also recolor the full section payload, including the label and full ref, rather
than the glyph alone.

## Primary-source record

| Subject | Evidence | Finding used here |
| --- | --- | --- |
| Supabase brand assets | [Pinned brand-assets source](https://github.com/supabase/supabase/blob/8d4a16beeacab3f7fa831c1c27c1324722b0b9b8/apps/www/pages/brand-assets.tsx#L42-L73) and [official brand-assets page](https://supabase.com/brand-assets) | Official assets are SVG brand material. They do not publish a terminal Unicode, ASCII, Powerline, or Nerd Fonts mapping. |
| Supabase icon color treatment | [Pinned official icon SVG](https://github.com/supabase/supabase/blob/8d4a16beeacab3f7fa831c1c27c1324722b0b9b8/apps/www/public/images/supabase-logo-icon.svg) | The mark includes `#249361` to `#3ECF8E` gradient treatment and an opaque `#3ECF8E` region. A one-color terminal foreground is an approximation. |
| Small-icon guidance | [Supabase design-system icon guidance](https://supabase.com/design-system/docs/icons) | Icons need legible text context at small sizes. The validated ref supplies that context here. |
| Unicode classification | [Unicode 17 emoji data](https://www.unicode.org/Public/17.0.0/ucd/emoji/emoji-data.txt), [East Asian Width data](https://www.unicode.org/Public/17.0.0/ucd/EastAsianWidth.txt), [UAX #11](https://www.unicode.org/reports/tr11/), and [UTS #51](https://www.unicode.org/reports/tr51/) | Emoji presentation and width classes are inputs to a matrix. They do not replace observed terminal cells. |
| Emoji variation sequences | [Unicode 17 variation-sequence data](https://www.unicode.org/Public/17.0.0/ucd/emoji/emoji-variation-sequences.txt) | `U+26A1 U+FE0E` requests text presentation and still needs terminal observation. |
| Nerd Fonts | [v3.5.1 release](https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1) and [pinned registry](https://github.com/ryanoasis/nerd-fonts/blob/b894ea7803af6aade63d60a4381e006098ec9c4d/glyphnames.json) | `dev-supabase` maps to Private Use Area code point `U+E8B6`. |
| Spaceship renderer | [Audited v4.21.0 renderer](https://github.com/spaceship-prompt/spaceship-prompt/blob/e498b1381df3a122af107b61f5cc8f3ced93ee69/lib/section.zsh#L68-L108) and [repository v4 call](https://github.com/junyoung2015/spaceship-supabase/blob/7aab213c37c63db8f172be3e40a75ec4786fc749/spaceship-supabase.plugin.zsh#L1599-L1609) | Spaceship styles the whole supplied symbol and content payload with the configured color. |
| macOS Terminal | [Text settings](https://support.apple.com/guide/terminal/trmltxt/mac) and [advanced settings](https://support.apple.com/guide/terminal/trmladvn/mac) | Profile font, color, encoding, and ambiguous-width settings affect the observation. |
| iTerm2 | [Font documentation](https://iterm2.com/documentation-fonts.html) and [Unicode documentation](https://iterm2.com/documentation-one-page.html) | Non-ASCII font and Unicode width settings are profile choices. |
| Kaku | [v0.19.0 release](https://github.com/tw93/Kaku/releases/tag/V0.19.0), [pinned default configuration](https://github.com/tw93/Kaku/blob/9a5cebaf4b065890dfd1e22dd2bf08ae2e8c5153/assets/macos/Kaku.app/Contents/Resources/kaku.lua#L3818-L3860), and [Unicode-width configuration](https://github.com/tw93/Kaku/blob/9a5cebaf4b065890dfd1e22dd2bf08ae2e8c5153/config/src/config.rs#L973-L980) | Kaku also has terminal-specific font-stack and width behavior. |

## Candidate register

Unicode width below is the nominal UCD classification. Terminal cell advance,
font fallback, baseline alignment, and wrapping require visual evidence.

| Candidate | Exact sequence | Presentation and nominal width | Current position |
| --- | --- | --- | --- |
| Current control `🔷 ` | `U+1F537 U+0020` | Default emoji presentation; `W` plus a space | Preserve while the matrix is incomplete. |
| Portable `S ` | `U+0053 U+0020` | Text; `Na` plus a space | Leading future portable candidate. |
| Explicit `SB ` | `U+0053 U+0042 U+0020` | Text; `Na Na` plus a space | Portable control and fallback; too wide for a default without evidence. |
| Compact `↯ ` | `U+21AF U+0020` | Text; `N` plus a space | Test-only candidate. |
| High voltage `⚡ ` | `U+26A1 U+0020` | Default emoji presentation; `W` plus a space | Rejected as a default pending evidence. |
| Text-style high voltage `⚡︎ ` | `U+26A1 U+FE0E U+0020` | Text variation request; base class `W` | Matrix control only. |
| Nerd Fonts `dev-supabase` | `U+E8B6 U+0020` | Private Use Area; `A` context-sensitive width | Patched-font opt-in path only. |

## Controlled fixture

[`tests/manual/render-glyph-matrix.zsh`](../../tests/manual/render-glyph-matrix.zsh)
renders each candidate through the audited vendored Spaceship Prompt v4 runtime
and the checked-out plugin. It builds all state beneath a temporary root and
uses only these visible values:

1. Context path: `~/code/customer-api`
2. Git text: `main`
3. Label: `Customer API / staging`
4. Ref: `abcdefghijklmnopqrst`
5. Display-only command text: `supabase db push`
6. A run header containing only the allowlisted candidate, color, theme label,
   and layout values.

The fixture creates the label through `spaceship_supabase_label` before a
render. The actual render then performs its normal local read path through
`spaceship::section::v4`. It excludes user, host, real-directory, real-Git,
IP, Docker, history, credential, and CLI-result sections. It does not invoke
the Supabase CLI, a network command, or a credential provider.

The `dark` or `light` argument is an explicit capture declaration. The fixture
prints it in the run header and does not alter a terminal application's theme.
Before a visual capture, the reviewer must select a documented isolated profile
whose exact foreground and background values match that declaration. A header
alone is not theme evidence.

Use print mode for deterministic composition inspection:

```zsh
zsh -f tests/manual/render-glyph-matrix.zsh s green dark two-line
```

Use `--hold` only inside a disposable terminal profile or an isolated macOS
account. It keeps the already-rendered synthetic scene visible with a harmless
`tail -f /dev/null` process. The displayed Supabase command is literal output,
not an input buffer, and cannot execute accidentally.

## Fixture-composition checks completed

These checks exercised the real v4 composition path in an isolated Zsh process.
They establish the deterministic text construction only; they do not establish
an observed terminal cell width or a visual acceptance result.

| Candidate | Color input | Layouts composed | Synthetic ref visible | Composition result |
| --- | --- | --- | --- | --- |
| `🔷 ` | `cyan` | Two-line | Yes | Complete. |
| `S ` | `green` | Two-line | Yes | Complete. |
| `SB ` | `green` | One-line | Yes | Complete. |
| `↯ ` | `green` | Two-line | Yes | Complete. |
| `⚡ ` | `cyan` | One-line | Yes | Complete. |
| `⚡︎ ` | `green` | Two-line | Yes | Complete. |
| `U+E8B6` | `green` | Two-line | Yes | Complete as a text-composition probe. |

## Supported-terminal visual matrix

The visual matrix remains intentionally incomplete. Safe control of the
application surfaces did not yield a verified isolated terminal for any target.
No new terminal image was retained or added to the repository.

| Target | Observed version | Safe controlled target | Exact missing visual cells | Status |
| --- | --- | --- | --- | --- |
| macOS Terminal | `2.15` | No verified isolated capture target was available within the current control boundary. | Dark and light; system font; patched Nerd Font when available; unpatched fallback; one-line and two-line; all seven candidates; width, baseline, presentation, color, fallback, copy and paste, selection, wrap, and 20-character-ref legibility observations. | Blocked pending an isolated target. |
| iTerm2 | `3.6.11` | No verified isolated capture target was available within the current control boundary. | Dark and light; system font; patched Nerd Font when available; unpatched fallback; one-line and two-line; all seven candidates; width, baseline, presentation, color, fallback, copy and paste, selection, wrap, and 20-character-ref legibility observations. | Blocked pending an isolated target. |
| Kaku | `0.19.0` | No verified isolated capture target was available within the current control boundary. No Kaku output was retained. | Dark and light; bundled font; patched Nerd Font; unpatched fallback; one-line and two-line; all seven candidates; width, baseline, presentation, color, fallback, copy and paste, selection, wrap, and 20-character-ref legibility observations. | Blocked pending an isolated target. |

The matrix has no visual rows marked pass, fail, or not applicable. The
unexecuted cells are specific by terminal, theme, font path, candidate,
placement, and observation in the table above. Copy-and-paste observation is
also deferred because it would otherwise risk reading or overwriting an
account-owned clipboard.

## Required visual-observation schema

Each future visual row must record every field below. A screenshot alone is
insufficient.

| Field | Required record |
| --- | --- |
| Run identity | Immutable run identifier and capture time. |
| Terminal | Bundle identifier, app version, macOS version, and architecture. |
| Profile | Primary font, size, non-ASCII font, fallback chain, ligature state, line height, and horizontal spacing. |
| Width behavior | Unicode table version, ambiguous-width policy, locale, and any cell-width override. |
| Theme | Exact foreground and background values for the dark or light profile. |
| Prompt composition | Plugin commit, audited Spaceship version, prompt order, and `SPACESHIP_PROMPT_SEPARATE_LINE` value. |
| Candidate | Candidate ID, exact code points, configured symbol, and configured color. |
| Synthetic context | The five fixture values above and confirmation that no real section was enabled. |
| Advance probe | ASCII sentinels and an 80-column wrap probe, observed in cells. |
| Visual result | Glyph presence or tofu, fallback font, baseline, clipping, wrapping, contrast, and complete-ref legibility. |
| Clipboard result | Exact synthetic code-point preservation and test-specific clipboard handling. |
| Evidence | Screenshot path, image SHA-256, visible-value review, metadata review, and reasoned disposition. |

## Image privacy and provenance gate

If a future controlled capture becomes possible, retain an image only after the
following review.

1. Inspect the original-resolution image and confirm that every visible value
   is synthetic.
2. Scan printable strings and inspect PNG chunks for text, EXIF, location, or
   other metadata.
3. Remove embedded EXIF and text chunks while preserving decoded pixels.
4. Compare decoded pixel hashes before and after metadata removal.
5. Record dimensions, format, alpha behavior, public blob hash, concise alt
   text, fixture command, and source-provenance review.
6. Add an explicit public-tree allowlist entry and metadata requirement before
   a new image becomes a release artifact.

The existing [README screenshot record](readme-terminal-screenshot.md) remains
the model for this review. Its already-reviewed image is baseline evidence for
the current default only. It is not a candidate comparison matrix.

## Recommendation and rejected alternatives

1. Preserve the default `🔷 ` plus `cyan`. Changing it now would turn an
   evidence gap into a compatibility change.
2. Evaluate `S ` first after controlled visual evidence exists. It is ordinary
   ASCII, has `Na` width, avoids emoji presentation, and does not imitate the
   official logo.
3. Keep `SB ` as an explicit portable control. Its two visible letters increase
   width and visual noise.
4. Keep `↯ ` as a compact test candidate. It is unofficial and needs
   font-coverage and recognition evidence.
5. Reject `⚡ ` as a future default unless a later matrix overturns its emoji
   presentation and width risk. Text-style `⚡︎ ` remains a matrix control.
6. Keep Nerd Fonts `dev-supabase` opt-in-only. It is third-party Private Use
   Area data rather than Supabase brand guidance and needs a patched-font path.
7. Do not use a green-only default decision. It cannot reproduce the official
   gradient and recolors the whole v4 section payload.

## Compatibility, migration, and rollback

There is no migration because there is no default change.

If a separately approved release later adopts a new default, it must retain
`SPACESHIP_SUPABASE_SYMBOL` and `SPACESHIP_SUPABASE_COLOR` as user-owned
overrides. Identity validation, live-ref precedence, label precedence, prompt
freshness, and prompt-rendering I/O boundaries must remain unchanged.

The exact rollback configuration is:

```zsh
SPACESHIP_SUPABASE_SYMBOL='🔷 '
SPACESHIP_SUPABASE_COLOR='cyan'
```

A future default decision needs its own implementation issue, review, release
decision, documentation update, migration notes, and rollback validation. This
research record supplies no authorization for that work.

## Tracker completion boundary

Issue #36 can close after the matrix has controlled visual evidence for all
supported-terminal rows, the image privacy gate has passed for any retained
artifact, the recommendation and rejected alternatives have been reviewed, and
the compatibility, migration, and rollback boundaries remain documented. Until
then, the exact next research requirement is a disposable macOS account or a
tool-provided terminal window target that can be verified as isolated before
any screen content is inspected.
