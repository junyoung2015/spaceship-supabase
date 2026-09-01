#!/usr/bin/env zsh
# Verify that the manual glyph renderer stays synthetic and cleanup-safe.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset -g GLYPH_FIXTURE_ZSH="${ZSH_BIN:-zsh}"
typeset -g GLYPH_FIXTURE="$TEST_REPO_ROOT/tests/manual/render-glyph-matrix.zsh"

assert_fixture_usage_failure() {
  local tmp="$1" stub_dir="$2" marker="$3" description="$4" output='' exit_status=0
  shift 4

  output="$(
    builtin cd "$tmp" || exit 1
    TMPDIR="$tmp/" PATH="$stub_dir:$PATH" \
      GLYPH_FIXTURE_MKTEMP_MARKER="$marker" \
      "$GLYPH_FIXTURE_ZSH" -f "$GLYPH_FIXTURE" "$@" 2>&1
  )"
  exit_status=$?
  assert_eq '64' "$exit_status" "$description exits with the strict usage status"
  assert_contains "$output" 'usage: render-glyph-matrix.zsh' \
    "$description prints the strict usage message"
  assert_file_missing "$marker" "$description rejects input before synthetic setup"
}

test_fixture_clears_inherited_prompt_and_workdir_state() {
  local output=''

  output="$(
    SUPABASE_WORKDIR='/invalid/inherited/workdir' \
      SPACESHIP_SUPABASE_SHOW=false \
      SPACESHIP_SUPABASE_SUFFIX='INHERITED-SUFFIX ' \
      SPACESHIP_PROMPT_DEFAULT_SUFFIX='INHERITED-DEFAULT ' \
      SPACESHIP_CHAR_SYMBOL='INHERITED-CHAR ' \
      "$GLYPH_FIXTURE_ZSH" -f "$GLYPH_FIXTURE" s green dark two-line
  )" || test_failure 'glyph fixture renders with hostile inherited configuration'

  assert_contains "$output" \
    'glyph-matrix: candidate=s color=green theme=dark layout=two-line' \
    'glyph fixture emits the selected immutable run header'
  assert_contains "$output" 'S Customer API / staging (abcdefghijklmnopqrst)' \
    'glyph fixture retains the synthetic live ref and selected candidate'
  assert_contains "$output" '➜ ' \
    'glyph fixture retains the fixed synthetic prompt character'
  assert_contains "$output" 'supabase db push' \
    'glyph fixture retains the static command text'
  assert_not_contains "$output" 'INHERITED-' \
    'glyph fixture excludes inherited prompt text'
  assert_not_contains "$output" '/invalid/inherited/workdir' \
    'glyph fixture excludes inherited workdir state'
  return 0
}

test_fixture_records_distinct_declared_theme_runs() {
  local dark_output='' light_output=''

  dark_output="$("$GLYPH_FIXTURE_ZSH" -f "$GLYPH_FIXTURE" s green dark two-line)" || \
    test_failure 'dark glyph fixture run succeeds'
  light_output="$("$GLYPH_FIXTURE_ZSH" -f "$GLYPH_FIXTURE" s green light two-line)" || \
    test_failure 'light glyph fixture run succeeds'

  assert_contains "$dark_output" 'theme=dark' \
    'dark run records its external-theme declaration'
  assert_contains "$light_output" 'theme=light' \
    'light run records its external-theme declaration'
  [[ "$dark_output" != "$light_output" ]] || \
    test_failure 'theme declaration prevents dark and light evidence from collapsing'
  return 0
}

test_fixture_never_executes_displayed_command_and_cleans_hold_state() {
  local tmp='' stub_dir='' marker='' output=''
  new_test_dir || return 1
  tmp="$REPLY"
  stub_dir="$tmp/bin"
  marker="$tmp/supabase-invoked"
  command mkdir -p "$stub_dir" || return 1

  print -r -- '#!/bin/sh' > "$stub_dir/supabase" || return 1
  print -r -- ': > "$SUPABASE_GLYPH_FIXTURE_MARKER"' >> "$stub_dir/supabase" || return 1
  command chmod 700 "$stub_dir/supabase" || return 1

  output="$(
    PATH="$stub_dir:$PATH" \
      SUPABASE_GLYPH_FIXTURE_MARKER="$marker" \
      "$GLYPH_FIXTURE_ZSH" -f "$GLYPH_FIXTURE" current cyan dark two-line
  )" || test_failure 'glyph fixture prints without invoking Supabase'
  assert_contains "$output" 'supabase db push' \
    'glyph fixture displays the literal command text'
  assert_file_missing "$marker" 'displayed command never invokes the Supabase executable'

  print -r -- '#!/bin/sh' > "$stub_dir/tail" || return 1
  print -r -- 'exit 0' >> "$stub_dir/tail" || return 1
  command chmod 700 "$stub_dir/tail" || return 1
  TMPDIR="$tmp/" PATH="$stub_dir:$PATH" \
    "$GLYPH_FIXTURE_ZSH" -f "$GLYPH_FIXTURE" --hold current cyan dark two-line >/dev/null || \
    test_failure 'glyph fixture hold mode exits cleanly when its safe hold process ends'
  if [[ -n ${(M)${(f)"$(command find "$tmp" -maxdepth 1 -type d -name 'spaceship-supabase-glyph.*' -print)"}:#?*} ]]; then
    test_failure 'glyph fixture removes its synthetic state after hold completion'
  fi

  remove_test_dir "$tmp"
  return 0
}

test_fixture_rejects_relative_tmpdir_without_leaking_state() {
  local tmp='' output='' leaked=''
  new_test_dir || return 1
  tmp="$REPLY"

  output="$(
    builtin cd "$tmp" || exit 1
    TMPDIR='.' "$GLYPH_FIXTURE_ZSH" -f "$GLYPH_FIXTURE" s green dark two-line
  )" || test_failure 'glyph fixture falls back safely from a relative temporary directory'
  assert_contains "$output" 'glyph-matrix: candidate=s color=green theme=dark layout=two-line' \
    'glyph fixture renders after rejecting a relative temporary directory'

  leaked="$(command find "$tmp" -maxdepth 1 -type d -name 'spaceship-supabase-glyph.*' -print)"
  assert_empty "$leaked" 'glyph fixture does not leave state below a relative temporary directory'

  remove_test_dir "$tmp"
  return 0
}

test_fixture_rejects_invalid_arguments_before_setup() {
  local tmp='' stub_dir='' marker=''
  new_test_dir || return 1
  tmp="$REPLY"
  stub_dir="$tmp/bin"
  marker="$tmp/mktemp-invoked"
  command mkdir -p "$stub_dir" || return 1

  print -r -- '#!/bin/sh' > "$stub_dir/mktemp" || return 1
  print -r -- ': > "$GLYPH_FIXTURE_MKTEMP_MARKER"' >> "$stub_dir/mktemp" || return 1
  print -r -- 'exit 99' >> "$stub_dir/mktemp" || return 1
  command chmod 700 "$stub_dir/mktemp" || return 1

  assert_fixture_usage_failure "$tmp" "$stub_dir" "$marker" \
    'invalid candidate' invalid cyan dark two-line
  assert_fixture_usage_failure "$tmp" "$stub_dir" "$marker" \
    'invalid color' current invalid dark two-line
  assert_fixture_usage_failure "$tmp" "$stub_dir" "$marker" \
    'invalid theme' current cyan invalid two-line
  assert_fixture_usage_failure "$tmp" "$stub_dir" "$marker" \
    'invalid layout' current cyan dark invalid

  remove_test_dir "$tmp"
  return 0
}

test_case 'glyph fixture clears inherited prompt and workdir state' test_fixture_clears_inherited_prompt_and_workdir_state
test_case 'glyph fixture records distinct declared theme runs' test_fixture_records_distinct_declared_theme_runs
test_case 'glyph fixture never executes the displayed command and cleans hold state' test_fixture_never_executes_displayed_command_and_cleans_hold_state
test_case 'glyph fixture rejects a relative temporary directory without leaking state' test_fixture_rejects_relative_tmpdir_without_leaking_state
test_case 'glyph fixture rejects invalid arguments before synthetic setup' test_fixture_rejects_invalid_arguments_before_setup
finish_tests
