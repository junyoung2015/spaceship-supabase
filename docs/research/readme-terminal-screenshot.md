# README terminal screenshot record

## Status

The current README image is [`docs/assets/spaceship-supabase-terminal.png`](../assets/spaceship-supabase-terminal.png). It was captured from Kaku at 960 by 272 pixels using actual Spaceship Prompt v4 composition and the current plugin code.

The image previews the `v0.2.0-beta.4` context-line layout. It is documentation evidence only and does not authorize beta installation or contribute dogfood evidence.

Related tracker: [README screenshot issue #35](https://github.com/junyoung2015/spaceship-supabase/issues/35)

## Synthetic scene

Every visible value is synthetic:

1. Context path: `~/code/customer-api`
2. Git branch: `main`
3. Project label: `Customer API`
4. Project ref: `abcdefghijklmnopqrst`
5. Typed command: `supabase db push`

The command was typed to show why target context matters and was never executed.

## Privacy boundary

1. Start a separate terminal window and a separate interactive Zsh process.
2. Use a temporary `ZDOTDIR`, synthetic `supabase/config.toml`, synthetic live ref, and owner-only synthetic label state.
3. Compose only a synthetic context section, `supabase`, `line_sep`, and `char` through actual Spaceship v4.
4. Exclude the normal user, host, directory, Git, IP, environment, credential, and history sections.
5. Clear inherited terminal content before capture.
6. Capture the exact isolated window rather than a display or existing terminal session.
7. Interrupt the typed example command after capture so it cannot be executed accidentally.

Do not reuse a normal shell window and attempt to crop secrets afterward. A clean synthetic source makes the absence of personal and operational information reviewable before capture.

## Validation performed

1. Visual inspection found only the five synthetic values listed above.
2. The image contains no username, hostname, IP address, real local path, real project ref, real project or label name, credential, raw CLI output, or command result.
3. The PNG is 960 by 272 pixels, RGBA, and non-interlaced.
4. A printable-string scan found no user path, account name, inherited window title, IP address, or location metadata.
5. A PNG chunk scan found no embedded text or EXIF chunks.
6. The captured prompt was verified separately in a pseudo-terminal before the graphical capture.

## Recapture triggers

Recapture and review the image when any of these change:

1. The stable default prompt placement or prefix
2. The default symbol or color
3. The recommended display format
4. Spaceship v4 composition behavior
5. The README release channel presented beside the image

The replacement must repeat the privacy checks above and update this record with the reviewed release layout.
