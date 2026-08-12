#!/usr/bin/env zsh
# Fail-closed handling of repository-controlled state and prompt-safety tests.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_LIVE='aaaaaaaaaaaaaaaaaaaa'
typeset REF_CONFIG='bbbbbbbbbbbbbbbbbbbb'

start_security_runtime() {
  local state_home="$1"
  XDG_STATE_HOME="$state_home"
  reset_public_configuration
  load_plugin_runtime
}

render_quietly_at() {
  local directory="$1"
  local output_file="$2"
  local error_file="$3"

  cd "$directory" || return 1
  : > "$output_file"
  : > "$error_file"
  spaceship_supabase > "$output_file" 2> "$error_file"
}

test_exact_project_ref_parser_accepts_only_stable_form() {
  local tmp='' root='' output_file='' error_file='' tuple='' value='' name=''
  local -a names values
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  start_security_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }

  print -rn -- "${REF_LIVE}"$'\r\n' > "$root/supabase/.temp/project-ref"
  assert_success 'CRLF project ref renders' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'CRLF is the one accepted alternate terminal newline'
  read_file "$error_file"
  assert_empty "$REPLY" 'valid CRLF source is silent on stderr'

  names=(empty short uppercase digit whitespace multiline duplicate-newline oversized control unicode)
  values=(
    ''
    'short'
    'AAAAAAAAAAAAAAAAAAAA'
    'aaaaaaaaaaaaaaaaaaa1'
    ' aaaaaaaaaaaaaaaaaaaa'
    $'aaaaaaaaaaaaaaaaaaaa\nextra'
    $'aaaaaaaaaaaaaaaaaaaa\n\n'
    'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
    $'aaaaaaaaaaaaaaaaaa\033]0;title\a'
    'aaaaaaaaaaaaaaaaaaéé'
  )
  for (( name = 1; name <= ${#names[@]}; name++ )); do
    value="${values[$name]}"
    print -rn -- "$value" > "$root/supabase/.temp/project-ref"
    assert_success "${names[$name]} ref is silent" render_quietly_at "$root" "$output_file" "$error_file"
    read_file "$output_file"
    assert_empty "$REPLY" "${names[$name]} ref cannot render a section"
    read_file "$error_file"
    assert_empty "$REPLY" "${names[$name]} ref produces no normal stderr"
  done

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_unreadable_project_ref_fails_closed() {
  local tmp='' root='' output_file='' error_file=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  start_security_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.72.7 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  command chmod 000 "$root/supabase/.temp/project-ref"

  if (( EUID == 0 )); then
    test_note 'ok - unreadable project-ref check skipped for root'
  else
    assert_success 'unreadable ref is a silent prompt condition' render_quietly_at "$root" "$output_file" "$error_file"
    read_file "$output_file"
    assert_empty "$REPLY" 'unreadable ref does not render'
    read_file "$error_file"
    assert_empty "$REPLY" 'unreadable ref has no normal stderr'
  fi
  command chmod 600 "$root/supabase/.temp/project-ref"

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_symlinked_expected_components_never_supply_prompt_data() {
  local tmp='' root='' target='' output_file='' error_file='' tuple=''
  new_test_dir || return 1
  tmp="$REPLY"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  start_security_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  zmodload zsh/files 2>/dev/null || return 1

  # The root's supabase directory itself must not be a link.
  root="$tmp/supabase-link-root"
  target="$tmp/supabase-link-target"
  materialize_project "$target" 2.72.7 "$REF_LIVE" || return 1
  command mkdir -p "$root"
  command ln -s "$target/supabase" "$root/supabase"
  assert_success 'symlinked supabase dir is silent' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'symlinked supabase root does not render'

  # A config marker cannot be a link, even to a safe-looking file.
  root="$tmp/config-link-root"
  target="$tmp/config-link-target.toml"
  materialize_project "$root" 2.113.0 "$REF_LIVE" || return 1
  print -r -- '[api]' 'enabled = true' > "$target"
  zf_rm "$root/supabase/config.toml"
  command ln -s "$target" "$root/supabase/config.toml"
  assert_success 'symlinked config marker is silent' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'symlinked config cannot define a root'

  # A .temp directory link cannot provide a live ref.
  root="$tmp/temp-link-root"
  target="$tmp/temp-link-target"
  materialize_project "$root" 2.72.7 "$REF_LIVE" || return 1
  command mkdir -p "$target"
  print -r -- "$REF_LIVE" > "$target/project-ref"
  zf_rm -r "$root/supabase/.temp"
  command ln -s "$target" "$root/supabase/.temp"
  assert_success 'symlinked .temp is silent' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'symlinked .temp cannot provide a live ref'

  # A project-ref link cannot provide a live identity.
  root="$tmp/ref-link-root"
  target="$tmp/ref-link-target"
  materialize_project "$root" 2.113.0 "$REF_LIVE" || return 1
  print -r -- "$REF_LIVE" > "$target"
  zf_rm "$root/supabase/.temp/project-ref"
  command ln -s "$target" "$root/supabase/.temp/project-ref"
  assert_success 'symlinked project-ref is silent' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'symlinked project-ref cannot render'

  # Branch links never enrich a safe live ref with untrusted local data.
  root="$tmp/branch-link-root"
  target="$tmp/branch-link-target"
  materialize_project "$root" 2.72.7 "$REF_LIVE" || return 1
  command mkdir -p "$target"
  print -r -- 'feature/refactor-42' > "$target/_current_branch"
  command mkdir -p "$root/supabase/.branches"
  command ln -s "$target/_current_branch" "$root/supabase/.branches/_current_branch"
  SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH=true
  assert_success 'symlinked local branch is ignored' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'bad branch link does not hide valid ref'
  assert_not_contains "$tuple" 'feature/refactor-42' 'symlinked branch text is never rendered'

  root="$tmp/branches-link-root"
  target="$tmp/branches-link-target"
  materialize_project "$root" 2.113.0 "$REF_LIVE" || return 1
  command mkdir -p "$target"
  print -r -- 'feature/refactor-42' > "$target/_current_branch"
  command ln -s "$target" "$root/supabase/.branches"
  assert_success 'symlinked branches dir is ignored' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'branch-dir link does not hide live ref'
  assert_not_contains "$tuple" 'feature/refactor-42' 'branch-dir link text is never rendered'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_config_mapping_and_branch_payloads_cannot_inject_prompt_bytes() {
  local tmp='' root='' output_file='' error_file='' tuple='' rendered='' payload='' selector=''
  local -a payloads selectors
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  start_security_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  command mkdir -p "$root/supabase/.branches"
  SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH=true

  payloads=(
    '%n'
    $'\033[31mred\033[0m'
    $'\033]0;title\a'
    'feature with spaces'
    'branch-π'
  )
  for payload in "${payloads[@]}"; do
    print -rn -- "$payload" > "$root/supabase/.branches/_current_branch"
    assert_success 'unsafe branch stays silent' render_quietly_at "$root" "$output_file" "$error_file"
    read_file "$output_file"
    tuple="$REPLY"
    assert_contains "$tuple" "$REF_LIVE" 'unsafe branch does not suppress valid live ref'
    assert_not_contains "$tuple" "$payload" 'unsafe branch bytes do not reach v4 section tuple'
    render_prompt_tuple "$tuple"
    rendered="$REPLY"
    assert_not_contains "$rendered" "$payload" 'unsafe branch bytes do not reach actual v4 rendered prompt'
  done

  zmodload zsh/files 2>/dev/null || return 1
  zf_rm "$root/supabase/.temp/project-ref"
  write_config_remote "$root" staging "$REF_CONFIG"
  selectors=( 'stage%evil' $'stage\033]0;title\a' 'remote name' 'équipe' )
  for selector in "${selectors[@]}"; do
    SPACESHIP_SUPABASE_CONFIG_REMOTE="$selector"
    assert_success 'unsafe remote selector is silent' render_quietly_at "$root" "$output_file" "$error_file"
    read_file "$output_file"
    assert_empty "$REPLY" 'unsafe selector cannot activate configured mapping'
  done

  SPACESHIP_SUPABASE_CONFIG_REMOTE=staging
  write_config_remote "$root" staging 'AAAAAAAAAAAAAAAAAAAA'
  assert_success 'invalid configured ref is silent' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'configured mapping validates exact lower-letter ref grammar'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_actual_spaceship_v4_is_used_for_safe_rendering() {
  local tmp='' root='' output_file='' error_file='' tuple=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  XDG_STATE_HOME="$tmp/state"
  reset_public_configuration
  source "$TEST_SECTION_FILE" || return 1
  typeset -g TEST_V4_CALLS=0
  spaceship::section::v4() {
    (( TEST_V4_CALLS++ ))
    # In the audited Spaceship dependency, v4 delegates to this actual
    # packer. Keeping the named wrapper proves the plugin uses the v4
    # entrypoint without functions -c, which Zsh 5.2 does not support.
    spaceship::section "$@"
  }
  source "$TEST_PLUGIN_FILE" || return 1
  materialize_project "$root" 2.72.7 "$REF_LIVE" || return 1

  assert_success 'safe live ref calls section renderer' render_quietly_at "$root" "$output_file" "$error_file"
  assert_eq 1 "$TEST_V4_CALLS" 'plugin calls the versioned Spaceship v4 API exactly once'
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'v4 tuple contains validated live ref'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_prompt_path_never_uses_cli_network_or_label_writes() {
  local tmp='' root='' output_file='' error_file='' bin='' tool='' decoration_before='' original_path="$PATH"
  local -a tools
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  bin="$tmp/bin"
  tools=(
    supabase curl wget nc ssh git
    node nodejs python python3 jq perl ruby
    readlink realpath stat find awk sed grep cat date
  )
  command mkdir -p "$bin"
  for tool in "${tools[@]}"; do
    print -r -- \
      '#!/bin/sh' \
      'printf "%s\\n" "$0" >> "$SPACESHIP_TEST_TOOL_LOG"' \
      'exit 97' \
      > "$bin/$tool"
    command chmod 700 "$bin/$tool"
  done
  XDG_STATE_HOME="$tmp/state"
  SPACESHIP_TEST_TOOL_LOG="$tmp/tool-calls.log"
  export SPACESHIP_TEST_TOOL_LOG
  reset_public_configuration
  SPACESHIP_SUPABASE_FORMAT='label+ref'
  SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS=true
  load_plugin_runtime || return 1
  materialize_project "$root" 2.113.0 "$REF_LIVE" || return 1
  command mkdir -p "$tmp/state/spaceship-supabase"
  command chmod 700 "$tmp/state/spaceship-supabase"
  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tSentinel Project\tsupabase-cli:projects-list\t1700000000' > "$tmp/state/spaceship-supabase/decorations.tsv"
  command chmod 600 "$tmp/state/spaceship-supabase/decorations.tsv"
  read_file "$tmp/state/spaceship-supabase/decorations.tsv"
  decoration_before=$REPLY
  command mkdir -p "$tmp/home/.supabase"
  print -r -- 'credential-sentinel-never-rendered' > "$tmp/home/.supabase/access-token"
  HOME="$tmp/home"
  PATH="$bin:$original_path"

  assert_success 'normal prompt render remains local-only' render_quietly_at "$root" "$output_file" "$error_file"
  assert_file_missing "$SPACESHIP_TEST_TOOL_LOG" 'prompt path invokes no CLI, network, parser, or external helper tool'
  assert_file_missing "$tmp/state/spaceship-supabase/labels.tsv" 'prompt path performs no label-state writes'
  read_file "$tmp/state/spaceship-supabase/decorations.tsv"
  assert_eq "$decoration_before" "$REPLY" 'prompt path preserves enabled synced-decoration state without writing it'
  read_file "$output_file"
  assert_contains "$REPLY" "Sentinel Project ($REF_LIVE) · synced:project" 'enabled synced decoration really reaches the prompt under the no-I/O sentinel'
  assert_not_contains "$REPLY" credential-sentinel-never-rendered 'prompt does not expose credential-like data'
  read_file "$error_file"
  assert_empty "$REPLY" 'normal prompt render emits no stderr'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_debug_uses_fixed_redacted_diagnostics_only() {
  local tmp='' root='' output_file='' error_file='' diagnostics='' unsafe_ref=$'aaaaaaaaaaaaaaaaaa\033]0;secret\a'
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project-with-sensitive-name"
  output_file="$tmp/section.out"
  error_file="$tmp/section.err"
  start_security_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.72.7 "$REF_LIVE" || return 1
  print -rn -- "$unsafe_ref" > "$root/supabase/.temp/project-ref"
  SPACESHIP_SUPABASE_DEBUG=true

  assert_success 'debug still fails closed' render_quietly_at "$root" "$output_file" "$error_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'debug does not turn malformed input into prompt output'
  read_file "$error_file"
  diagnostics="$REPLY"
  assert_nonempty "$diagnostics" 'debug emits a fixed diagnostic code for malformed state'
  assert_not_contains "$diagnostics" "$unsafe_ref" 'debug never echoes raw malformed bytes'
  assert_not_contains "$diagnostics" "$root" 'debug never echoes raw paths'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_case 'stable project-ref grammar accepts only bounded safe input' test_exact_project_ref_parser_accepts_only_stable_form
test_case 'unreadable project-ref fails closed' test_unreadable_project_ref_fails_closed
test_case 'symlinked expected components cannot supply prompt state' test_symlinked_expected_components_never_supply_prompt_data
test_case 'config and local branch payloads cannot inject prompt bytes' test_config_mapping_and_branch_payloads_cannot_inject_prompt_bytes
test_case 'actual Spaceship v4 renderer is invoked' test_actual_spaceship_v4_is_used_for_safe_rendering
test_case 'prompt rendering makes no CLI, network, or state-write calls' test_prompt_path_never_uses_cli_network_or_label_writes
test_case 'debug diagnostics remain fixed and redacted' test_debug_uses_fixed_redacted_diagnostics_only
finish_tests
