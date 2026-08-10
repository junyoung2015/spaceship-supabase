#!/usr/bin/env zsh
# Deliberate non-project and unsupported-layout cases stay silent by default.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_LIVE='aaaaaaaaaaaaaaaaaaaa'

start_negative_runtime() {
  local state_home="$1"
  XDG_STATE_HOME="$state_home"
  reset_public_configuration
  load_plugin_runtime
}

render_negative_case() {
  local directory="$1"
  local output_file="$2"
  local error_file="$3"

  cd "$directory" || return 1
  : > "$output_file"
  : > "$error_file"
  spaceship_supabase > "$output_file" 2> "$error_file"
}

test_non_projects_and_unreleased_layouts_are_silent() {
  local tmp='' output_file='' error_file=''
  new_test_dir || return 1
  tmp="$REPLY"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  start_negative_runtime "$tmp/state" || return 1
  command mkdir -p "$tmp/plain/.supabase"
  print -r -- "$REF_LIVE" > "$tmp/plain/.supabase/project-ref"

  assert_success 'plain directory render returns successfully' render_negative_case "$tmp/plain" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'directory without stable supabase/config.toml emits no section'
  read_file "$error_file"
  assert_empty "$REPLY" 'non-project emits no normal stderr'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_missing_live_ref_and_unsupported_format_are_silent() {
  local tmp='' root='' output_file='' error_file=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  start_negative_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 || return 1

  assert_success 'missing live ref is a normal silent condition' render_negative_case "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'config marker alone does not produce a project segment'
  read_file "$error_file"
  assert_empty "$REPLY" 'missing ref does not emit normal stderr'

  print -r -- "$REF_LIVE" > "$root/supabase/.temp/project-ref"
  SPACESHIP_SUPABASE_FORMAT='arbitrary-template'
  assert_success 'unsupported format remains fail-closed' render_negative_case "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'unsupported display format cannot interpolate live state'
  read_file "$error_file"
  assert_empty "$REPLY" 'unsupported display format stays silent when debug is off'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_empty_workdir_override_is_strict() {
  local tmp='' root='' output_file='' error_file=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  start_negative_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.72.7 "$REF_LIVE" || return 1
  SUPABASE_WORKDIR=''

  assert_success 'empty strict override returns silently' render_negative_case "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'empty SUPABASE_WORKDIR never falls back to PWD'
  read_file "$error_file"
  assert_empty "$REPLY" 'empty strict override has no normal stderr'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_case 'plain and unreleased layouts do not create false positives' test_non_projects_and_unreleased_layouts_are_silent
test_case 'missing identity and unsupported formats fail closed' test_missing_live_ref_and_unsupported_format_are_silent
test_case 'an empty SUPABASE_WORKDIR is a strict override' test_empty_workdir_override_is_strict
finish_tests
