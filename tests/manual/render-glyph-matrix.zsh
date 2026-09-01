#!/usr/bin/env zsh
# Render one controlled glyph candidate through the vendored Spaceship v4
# runtime and this checkout's plugin. This fixture is for isolated visual
# review only. It never invokes the Supabase CLI or a network command.

emulate -L zsh
setopt pipefail

typeset output_mode='print'
if [[ "${1:-}" == '--hold' ]]; then
  output_mode='hold'
  shift
fi

typeset candidate="${1:-current}"
typeset color_choice="${2:-cyan}"
typeset theme_name="${3:-dark}"
typeset layout="${4:-two-line}"
typeset script_dir="${0:A:h}"
typeset repo_root="${script_dir:h:h}"
typeset fixture_tmpdir="${TMPDIR:-/tmp}"
while [[ "$fixture_tmpdir" != / && "$fixture_tmpdir" == */ ]]; do
  fixture_tmpdir="${fixture_tmpdir%/}"
done
if [[ -z "$fixture_tmpdir" || "$fixture_tmpdir" == / || "$fixture_tmpdir" != /* || ! -d "$fixture_tmpdir" ]]; then
  fixture_tmpdir='/tmp'
fi
fixture_tmpdir="$(builtin cd "$fixture_tmpdir" 2>/dev/null && command pwd -P)" || exit 73
[[ "$fixture_tmpdir" == /* && "$fixture_tmpdir" != / && -d "$fixture_tmpdir" ]] || exit 73
typeset fixture_prefix="${fixture_tmpdir}/spaceship-supabase-glyph."
typeset fixture_root=''
typeset glyph=''

usage() {
  print -ru2 -- 'usage: render-glyph-matrix.zsh [--hold] {current|s|sb|zigzag|voltage|voltage-text|nerd} {cyan|green} {dark|light} {two-line|one-line}'
}

case "$candidate" in
  current) glyph='🔷 ' ;;
  s) glyph='S ' ;;
  sb) glyph='SB ' ;;
  zigzag) glyph='↯ ' ;;
  voltage) glyph='⚡ ' ;;
  voltage-text) glyph=$'⚡\ufe0e ' ;;
  nerd) glyph=$'\ue8b6 ' ;;
  *)
    usage
    exit 64
    ;;
esac

case "$color_choice" in
  cyan|green) ;;
  *)
    usage
    exit 64
    ;;
esac

case "$theme_name" in
  dark|light) ;;
  *)
    usage
    exit 64
    ;;
esac

case "$layout" in
  two-line|one-line) ;;
  *)
    usage
    exit 64
    ;;
esac

[[ -r "$repo_root/spaceship-supabase.plugin.zsh" ]] || {
  print -ru2 -- 'fixture repository is unavailable'
  exit 66
}
[[ -r "$repo_root/tests/vendor/spaceship/spaceship.zsh" ]] || {
  print -ru2 -- 'vendored Spaceship v4 is unavailable'
  exit 66
}

fixture_root="$(mktemp -d "${fixture_prefix}XXXXXXXX")" || exit 73

cleanup() {
  if [[ -n "$fixture_root" && -d "$fixture_root" && "$fixture_root" == ${fixture_prefix}* ]]; then
    command rm -rf -- "$fixture_root"
  fi
}
trap cleanup EXIT HUP INT TERM

# A fixture cannot permit an account's prompt configuration or workdir override
# to select identity or alter visible output. Clear every inherited Spaceship
# setting before loading the vendored runtime, then set this fixture's complete
# visible configuration below.
typeset parameter_name=''
for parameter_name in ${(k)parameters}; do
  case "$parameter_name" in
    SPACESHIP_*|SUPABASE_WORKDIR) unset "$parameter_name" ;;
  esac
done

command mkdir -p -- \
  "$fixture_root/home/code/customer-api/supabase/.temp" \
  "$fixture_root/zdotdir" \
  "$fixture_root/state" || exit 73
command chmod 700 "$fixture_root" "$fixture_root/home" "$fixture_root/zdotdir" "$fixture_root/state" || exit 73
print -r -- '[api]' > "$fixture_root/home/code/customer-api/supabase/config.toml"
print -r -- 'abcdefghijklmnopqrst' > "$fixture_root/home/code/customer-api/supabase/.temp/project-ref"

# A temporary environment prevents user startup files, history, labels, and
# real project state from entering either the fixture setup or prompt render.
export HOME="$fixture_root/home"
export ZDOTDIR="$fixture_root/zdotdir"
export XDG_CONFIG_HOME="$fixture_root/config"
export XDG_CONFIG_DIRS="$fixture_root/config-dirs"
export XDG_STATE_HOME="$fixture_root/state"
export HISTFILE="$fixture_root/history"
export TERM='xterm-256color'
export SUPABASE_WORKDIR="$fixture_root/home/code/customer-api"
unsetopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY
export SPACESHIP_CONFIG="$fixture_root/missing-spaceship.zsh"
SPACESHIP_PROMPT_ASYNC=false
if [[ "$layout" == 'two-line' ]]; then
  SPACESHIP_PROMPT_SEPARATE_LINE=true
else
  SPACESHIP_PROMPT_SEPARATE_LINE=false
fi

# Prevent a manual fixture run from generating bytecode in the audited vendor
# tree. This does not participate in prompt rendering.
zcompile() { return 0; }

builtin cd "$fixture_root/home/code/customer-api" || exit 73
source "$repo_root/tests/vendor/spaceship/spaceship.zsh"

# Explicitly restore the four sections included in the synthetic composition.
SPACESHIP_PROMPT_DEFAULT_PREFIX='via '
SPACESHIP_PROMPT_DEFAULT_SUFFIX=' '
SPACESHIP_CHAR_PREFIX=''
SPACESHIP_CHAR_SUFFIX=''
SPACESHIP_CHAR_SYMBOL='➜ '
SPACESHIP_CHAR_SYMBOL_ROOT='➜ '
SPACESHIP_CHAR_SYMBOL_SUCCESS='➜ '
SPACESHIP_CHAR_SYMBOL_FAILURE='➜ '
SPACESHIP_CHAR_SYMBOL_SECONDARY='➜ '
SPACESHIP_CHAR_COLOR_SUCCESS='green'
SPACESHIP_CHAR_COLOR_FAILURE='red'
SPACESHIP_CHAR_COLOR_SECONDARY='yellow'

SPACESHIP_SUPABASE_SHOW=true
SPACESHIP_SUPABASE_ASYNC=false
SPACESHIP_SUPABASE_SYMBOL="$glyph"
SPACESHIP_SUPABASE_COLOR="$color_choice"
SPACESHIP_SUPABASE_PREFIX='at '
SPACESHIP_SUPABASE_SUFFIX=' '
SPACESHIP_SUPABASE_FORMAT='label+ref'
SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH=false
SPACESHIP_SUPABASE_CONFIG_REMOTE=''
SPACESHIP_SUPABASE_USE_LABELS=true
SPACESHIP_SUPABASE_LABEL_FILE="$fixture_root/state/labels.tsv"
SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS=false
SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE="$fixture_root/state/decorations.tsv"
SPACESHIP_SUPABASE_DEBUG=false
source "$repo_root/spaceship-supabase.plugin.zsh"

# This explicit helper write is setup work. The later section render reads the
# resulting owner-only synthetic label state without writing any state.
spaceship_supabase_label set 'Customer API / staging' >/dev/null || exit 73

spaceship_context() {
  spaceship::section::v4 \
    --symbol '' \
    --prefix '' \
    --suffix "$SPACESHIP_PROMPT_DEFAULT_SUFFIX" \
    '~/code/customer-api on main'
}

SPACESHIP_PROMPT_ORDER=(context supabase line_sep char)
for section in context supabase line_sep char; do
  spaceship::core::refresh_section --sync "$section"
done

typeset rendered
rendered="$(spaceship::core::compose_order "${SPACESHIP_PROMPT_ORDER[@]}")"
print -r -- "glyph-matrix: candidate=${candidate} color=${color_choice} theme=${theme_name} layout=${layout}"
print -P -n -- "$rendered"

# This is literal display text, never an input buffer or a command invocation.
print -n -- 'supabase db push'

if [[ "$output_mode" == 'hold' ]]; then
  # Keep the controlled scene visible. Ctrl-C closes this disposable hold.
  tail -f /dev/null
fi
