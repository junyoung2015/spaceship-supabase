#!/usr/bin/env zsh
# Public configuration and v4 section contract tests.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_LIVE='aaaaaaaaaaaaaaaaaaaa'

test_documented_defaults() {
  local tmp=""
  new_test_dir || return 1
  tmp="$REPLY"
  XDG_STATE_HOME="$tmp/state"
  reset_public_configuration
  SPACESHIP_PROMPT_DEFAULT_SUFFIX=' '
  load_plugin_runtime || {
    remove_test_dir "$tmp"
    return 1
  }

  assert_eq true "$SPACESHIP_SUPABASE_SHOW" 'SHOW defaults to true'
  assert_eq true "$SPACESHIP_SUPABASE_ASYNC" 'ASYNC defaults to true'
  assert_eq cyan "$SPACESHIP_SUPABASE_COLOR" 'COLOR defaults to cyan'
  assert_eq '🔷 ' "$SPACESHIP_SUPABASE_SYMBOL" 'SYMBOL defaults to the blue diamond'
  assert_eq '' "$SPACESHIP_SUPABASE_PREFIX" 'PREFIX defaults to empty'
  assert_eq ' ' "$SPACESHIP_SUPABASE_SUFFIX" 'SUFFIX follows Spaceship default suffix'
  assert_eq ref "$SPACESHIP_SUPABASE_FORMAT" 'FORMAT defaults to ref'
  assert_eq false "$SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH" 'local DB branch is opt-in'
  assert_eq '' "$SPACESHIP_SUPABASE_CONFIG_REMOTE" 'configured mapping is opt-in'
  assert_eq true "$SPACESHIP_SUPABASE_USE_LABELS" 'labels are enabled by default'
  assert_eq "$tmp/state/spaceship-supabase/labels.tsv" "$SPACESHIP_SUPABASE_LABEL_FILE" 'label path follows XDG state home'
  assert_eq false "$SPACESHIP_SUPABASE_DEBUG" 'DEBUG defaults to false'
  (( $+functions[spaceship_supabase] )) || test_failure 'main Spaceship section is defined'
  (( $+functions[spaceship_supabase_label] )) || test_failure 'label helper is defined'
  (( $+functions[spaceship_supabase_doctor] )) || test_failure 'doctor helper is defined'
  (( $+functions[spaceship::section::v4] )) || test_failure 'actual Spaceship v4 section API is available'

  remove_test_dir "$tmp"
  return 0
}

test_alpha_settings_are_not_reintroduced() {
  local tmp=""
  new_test_dir || return 1
  tmp="$REPLY"
  XDG_STATE_HOME="$tmp/state"
  reset_public_configuration
  unset SPACESHIP_SUPABASE_USE_PROJECT_REF
  unset SPACESHIP_SUPABASE_USE_CONFIG_TOML
  unset SPACESHIP_SUPABASE_USE_CACHE
  unset SPACESHIP_SUPABASE_CACHE_FILE
  unset SPACESHIP_SUPABASE_CACHE_TTL
  unset SPACESHIP_SUPABASE_PROJECT_ID_PREFIX
  unset SPACESHIP_SUPABASE_PROJECT_ID_TRUNCATE
  unset SPACESHIP_SUPABASE_ERROR_SYMBOL
  unset SPACESHIP_SUPABASE_ERROR_COLOR
  load_plugin_runtime || {
    remove_test_dir "$tmp"
    return 1
  }

  (( ! $+SPACESHIP_SUPABASE_USE_PROJECT_REF )) || test_failure 'old project-ref source toggle is absent'
  (( ! $+SPACESHIP_SUPABASE_USE_CONFIG_TOML )) || test_failure 'old config source toggle is absent'
  (( ! $+SPACESHIP_SUPABASE_USE_CACHE )) || test_failure 'old cache toggle is absent'
  (( ! $+SPACESHIP_SUPABASE_CACHE_FILE )) || test_failure 'old cache file setting is absent'
  (( ! $+SPACESHIP_SUPABASE_CACHE_TTL )) || test_failure 'old cache TTL setting is absent'
  (( ! $+SPACESHIP_SUPABASE_PROJECT_ID_PREFIX )) || test_failure 'old project prefix setting is absent'
  (( ! $+SPACESHIP_SUPABASE_PROJECT_ID_TRUNCATE )) || test_failure 'old truncation setting is absent'
  (( ! $+SPACESHIP_SUPABASE_ERROR_SYMBOL )) || test_failure 'old raw error symbol is absent'
  (( ! $+SPACESHIP_SUPABASE_ERROR_COLOR )) || test_failure 'old raw error color is absent'

  remove_test_dir "$tmp"
  return 0
}

test_visual_settings_reach_the_v4_section() {
  local tmp='' root='' output_file='' tuple='' rendered=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  XDG_STATE_HOME="$tmp/state"
  reset_public_configuration
  load_plugin_runtime || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  cd "$root" || return 1
  SPACESHIP_SUPABASE_COLOR=magenta
  SPACESHIP_SUPABASE_SYMBOL='◆ '
  SPACESHIP_SUPABASE_PREFIX='via '
  SPACESHIP_SUPABASE_SUFFIX='!'

  assert_success 'valid section render succeeds' render_section_to "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" magenta 'v4 tuple has configured color'
  assert_contains "$tuple" 'via ' 'v4 tuple has configured prefix'
  assert_contains "$tuple" '◆ ' 'v4 tuple has configured symbol'
  assert_contains "$tuple" "$REF_LIVE" 'v4 tuple contains full live reference'
  render_prompt_tuple "$tuple"
  rendered="$REPLY"
  assert_contains "$rendered" '◆ ' 'actual Spaceship v4 rendering contains configured symbol'
  assert_contains "$rendered" "$REF_LIVE" 'actual Spaceship v4 rendering contains full reference'

  remove_test_dir "$tmp"
  return 0
}

test_show_false_is_silent_before_state_is_required() {
  local tmp='' root='' output_file=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  XDG_STATE_HOME="$tmp/state"
  reset_public_configuration
  load_plugin_runtime || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.72.7 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  cd "$root" || return 1
  SPACESHIP_SUPABASE_SHOW=false

  assert_success 'disabled section returns successfully' render_section_to "$output_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'disabled section emits no tuple'
  assert_file_missing "$tmp/state/spaceship-supabase/labels.tsv" 'disabled section does not create label state'

  remove_test_dir "$tmp"
  return 0
}

test_ref_format_keeps_the_full_reference() {
  local tmp='' root='' output_file='' tuple=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  XDG_STATE_HOME="$tmp/state"
  reset_public_configuration
  load_plugin_runtime || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  cd "$root" || return 1
  SPACESHIP_SUPABASE_FORMAT=ref

  assert_success 'ref format renders successfully' render_section_to "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'ref format contains complete project reference'
  assert_not_contains "$tuple" 'configured:' 'live ref format does not claim configured fallback'
  assert_not_contains "$tuple" '@' 'ref format does not imply a hosted branch'

  remove_test_dir "$tmp"
  return 0
}

test_case 'documented defaults and public commands' test_documented_defaults
test_case 'retired alpha settings stay absent' test_alpha_settings_are_not_reintroduced
test_case 'visual settings are packed by actual Spaceship v4' test_visual_settings_reach_the_v4_section
test_case 'SHOW=false remains silent and read-only' test_show_false_is_silent_before_state_is_required
test_case 'ref format retains the exact linked reference' test_ref_format_keeps_the_full_reference
finish_tests
