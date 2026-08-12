# Troubleshooting

The normal failure mode is no segment and no ordinary error output. That is intentional: the prompt refuses to display untrusted, malformed, stale, or ambiguous local state.

Start with the local, read-only diagnostic command:

```zsh
spaceship_supabase_doctor
```

Use `spaceship_supabase_doctor --verbose` only when you explicitly want to inspect the sanitized values it is permitted to reveal. The command is local-only; it does not run the Supabase CLI or contact a service.

## No segment appears

Check the supported stable layout from the project root:

```text
supabase/config.toml
supabase/.temp/project-ref
```

The live `project-ref` must contain exactly 20 lowercase letters. Whitespace, digits, multiple lines, control characters, an oversized file, unreadable identity-critical components, and a symlink in the selected root/ref/config path cause the section to render nothing. Do not work around this by loosening the plugin's validation; repair or recreate the project state with your normal Supabase workflow.

The resolver selects the nearest safe ancestor with `supabase/config.toml`, up to 32 levels. A nested project intentionally hides a parent's reference.

## `SUPABASE_WORKDIR` is set

When `SUPABASE_WORKDIR` is present, it overrides upward search completely. Relative values are resolved from the current directory. If the value is invalid, unsafe, outside the supported layout, or unreadable, the plugin intentionally does not fall back to `$PWD`.

To return to normal nearest-project selection, remove the override from the current shell and `.zshrc`:

```zsh
unset SUPABASE_WORKDIR
```

## A project has `config.toml` but no live `project-ref`

By default, a config-only project shows no segment. If you have consciously configured a mapping for a named remote, make the selection explicit:

```zsh
SPACESHIP_SUPABASE_CONFIG_REMOTE="staging"
```

Only a valid `project_id` inside `[remotes.staging]` is considered, and the display must say:

```text
🔷 abcdefghijklmnopqrst · configured:staging
```

This is not live link state. A valid `supabase/.temp/project-ref` always takes priority. Top-level `project_id` is never a fallback source.

## The prompt looks like it has a hosted branch

It should not. v0.1.1 never uses `ref@branch`. If you opt in to local database branch display:

```zsh
SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH=true
```

the only supported branch output is clearly marked:

```text
🔷 abcdefghijklmnopqrst (local-db:feature/refactor-42)
```

That value comes from local database state and is not a hosted Supabase Branch.

If the optional local-db file is malformed, unreadable, oversized, or symlinked, the marker is omitted while an independently valid live reference remains rendered. This differs intentionally from unsafe root, config, or live-ref state, which fails closed with no segment.

## My label is missing

Labels are visible only when all of the following are true:

1. `SPACESHIP_SUPABASE_FORMAT="label+ref"` is set.
2. `SPACESHIP_SUPABASE_USE_LABELS=true` is set.
3. The label file is a safe owner-controlled state file containing one unambiguous valid label for the currently resolved reference.
4. The current prompt has a valid live or explicitly configured identity to render.

Set or clear labels only through the helpers:

```zsh
spaceship_supabase_label set "Production"
spaceship_supabase_label clear
spaceship_supabase_label list
```

`set` and `clear` require a live `project-ref`, not merely a configured mapping. Labels cannot bring back a segment when a reference disappears. See [labels](labels.md).

## The plugin does not load

The section must be sourced after Spaceship Prompt v4. In a generic shell, source Spaceship first and then `spaceship-supabase.plugin.zsh`. In Oh My Zsh, source the section after `source "$ZSH/oh-my-zsh.sh"` has loaded the Spaceship theme. See the [installation examples](../README.md#install).

Check your shell version:

```zsh
print -r -- "$ZSH_VERSION"
```

Zsh 5.2 or later is required.

## The plugin loads, but its segment is never part of the prompt

Spaceship renders only sections named in `SPACESHIP_PROMPT_ORDER`. After
sourcing this plugin, register it once before the prompt character:

```zsh
if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
  spaceship add --before char supabase
fi
```

Keep that guard after both your Spaceship source line and this plugin's source
line. It is safe to evaluate on every shell start. Do not use an unguarded
`spaceship add` line: it adds another `supabase` entry each time the file is
sourced.

## Debugging without leaking state

Set `SPACESHIP_SUPABASE_DEBUG=true` temporarily to enable fixed diagnostic codes. Debug output intentionally omits raw paths, file contents, config lines, labels, and malformed values. Do not add `set -x`, `eval`, a TOML source command, or arbitrary parser output to your prompt configuration: those defeat the section's trust boundary.

## Unsupported layouts

The stable v0.1.1 contract does not support `.supabase/project.json`. That path
belongs to the alpha next/V3 shell rather than the stable release channel and is
intentionally not interpreted. See [compatibility](compatibility.md) for the
supported layout and future-adapter policy.
