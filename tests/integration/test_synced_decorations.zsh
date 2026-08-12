#!/usr/bin/env zsh
# Explicit synced-project helper, state, rendering, and safety coverage.

emulate -L zsh
setopt extendedglob nullglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_A='aaaaaaaaaaaaaaaaaaaa'
typeset REF_B='bbbbbbbbbbbbbbbbbbbb'

start_sync_runtime() {
  local state_home="$1"

  XDG_STATE_HOME="$state_home"
  reset_public_configuration
  load_plugin_runtime
}

make_fake_supabase() {
  local bin="$1"

  command mkdir -p "$bin" || return 1
  {
    print -r -- '#!/bin/sh'
    print -r -- 'printf "%s\n" "$*" >> "$SPACESHIP_TEST_SUPABASE_LOG"'
    print -r -- 'if [ -n "${SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE:-}" ]; then'
    print -r -- '  ulimit -f > "$SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE" 2>/dev/null || exit 125'
    print -r -- 'fi'
    print -r -- 'case "$1" in'
    print -r -- '  --version) printf "%s\n" "$SPACESHIP_TEST_SUPABASE_VERSION"; exit "${SPACESHIP_TEST_SUPABASE_VERSION_STATUS:-0}" ;;'
    print -r -- '  projects)'
    print -r -- '    if [ "$2" = list ]; then'
    print -r -- '      if [ -n "${SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS:-}" ] && [ "$*" != "$SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS" ]; then'
    print -r -- '        printf "%s" "${SPACESHIP_TEST_SUPABASE_WRONG_FLAG_OUTPUT:-wrong-list-flag}"'
    print -r -- '        exit "${SPACESHIP_TEST_SUPABASE_WRONG_FLAG_STATUS:-0}"'
    print -r -- '      fi'
    print -r -- '      if [ -n "${SPACESHIP_TEST_SUPABASE_PID_FILE:-}" ]; then'
    print -r -- '        printf "%s\\n" "$$" > "$SPACESHIP_TEST_SUPABASE_PID_FILE"'
    print -r -- '      fi'
    print -r -- '      if [ -n "${SPACESHIP_TEST_SUPABASE_REF_REWRITE:-}" ]; then'
    print -r -- '        printf "%s\n" "$SPACESHIP_TEST_SUPABASE_REF_REWRITE" > "$SPACESHIP_TEST_SUPABASE_REF_FILE"'
    print -r -- '      fi'
    print -r -- '      if [ "${SPACESHIP_TEST_SUPABASE_HANG_SILENT:-}" = true ]; then'
    print -r -- '        exec tail -f /dev/null'
    print -r -- '      fi'
    print -r -- '      if [ "${SPACESHIP_TEST_SUPABASE_HANG_OUTPUT:-}" = true ]; then'
    print -r -- '        while :; do printf x; done'
    print -r -- '      fi'
    print -r -- '      if [ "${SPACESHIP_TEST_SUPABASE_HANG_IGNORE_XFSZ:-}" = true ]; then'
    print -r -- '        trap "" XFSZ TERM 2>/dev/null || :'
    print -r -- '        while :; do printf x || :; done'
    print -r -- '      fi'
    print -r -- '      printf "%s" "$SPACESHIP_TEST_SUPABASE_OUTPUT"'
    print -r -- '      exit "${SPACESHIP_TEST_SUPABASE_STATUS:-0}"'
    print -r -- '    fi'
    print -r -- '    ;;'
    print -r -- 'esac'
    print -r -- 'exit 64'
  } > "$bin/supabase"
  command chmod 700 "$bin/supabase"
}

prepare_fake_supabase() {
  local tmp="$1"
  local original_path="$2"

  make_fake_supabase "$tmp/bin" || return 1
  SPACESHIP_TEST_SUPABASE_LOG="$tmp/supabase.log"
  SPACESHIP_TEST_SUPABASE_VERSION='2.113.0'
  SPACESHIP_TEST_SUPABASE_VERSION_STATUS=0
  SPACESHIP_TEST_SUPABASE_STATUS=0
  SPACESHIP_TEST_SUPABASE_REF_REWRITE=''
  SPACESHIP_TEST_SUPABASE_REF_FILE=''
  SPACESHIP_TEST_SUPABASE_PID_FILE=''
  SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE=''
  SPACESHIP_TEST_SUPABASE_HANG_OUTPUT=''
  SPACESHIP_TEST_SUPABASE_HANG_SILENT=''
  SPACESHIP_TEST_SUPABASE_HANG_IGNORE_XFSZ=''
  SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS='projects list --output-format json'
  SPACESHIP_TEST_SUPABASE_WRONG_FLAG_OUTPUT='wrong-list-flag'
  SPACESHIP_TEST_SUPABASE_WRONG_FLAG_STATUS=0
  export SPACESHIP_TEST_SUPABASE_LOG SPACESHIP_TEST_SUPABASE_VERSION
  export SPACESHIP_TEST_SUPABASE_VERSION_STATUS SPACESHIP_TEST_SUPABASE_STATUS
  export SPACESHIP_TEST_SUPABASE_REF_REWRITE SPACESHIP_TEST_SUPABASE_REF_FILE
  export SPACESHIP_TEST_SUPABASE_PID_FILE SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE
  export SPACESHIP_TEST_SUPABASE_HANG_OUTPUT SPACESHIP_TEST_SUPABASE_HANG_SILENT
  export SPACESHIP_TEST_SUPABASE_HANG_IGNORE_XFSZ
  export SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS
  export SPACESHIP_TEST_SUPABASE_WRONG_FLAG_OUTPUT SPACESHIP_TEST_SUPABASE_WRONG_FLAG_STATUS
  PATH="$tmp/bin:$original_path"
  rehash
}

render_sync_section() {
  local root="$1"
  local output_file="$2"

  cd "$root" || return 1
  render_section_to "$output_file"
}

assert_synced_state_unchanged() {
  local decoration_file="$1"
  local expected="$2"
  local message="$3"
  local -a temporary_files

  read_file "$decoration_file"
  assert_eq "$expected" "$REPLY" "$message preserves the existing synced-decoration bytes"
  temporary_files=("${decoration_file}.tmp."*(N))
  assert_eq 0 "${#temporary_files}" "$message leaves no temporary synced-decoration file"
}

assert_no_cli_capture_file() {
  local message="$1"
  local -a temporary_files

  # Zsh keeps `$$` stable in the command substitutions and background helper
  # used by this suite, so this checks only artifacts created by this test
  # process rather than another user's `/tmp` files.
  temporary_files=(/tmp/spaceship-supabase-cli.${EUID}.${$}.*(N))
  assert_eq 0 "${#temporary_files}" "$message"
}

test_current_envelope_sync_is_confirmed_separate_and_opt_in() {
  local tmp='' root='' output_file='' error_file='' sync_output='' tuple='' rendered=''
  local decoration_file='' state_dir='' before='' doctor='' verbose='' log=''
  local original_path="$PATH"
  local -i sync_status=0

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  error_file="$tmp/sync.err"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 "$REF_A" || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"projects\":[{\"id\":\"$REF_A\",\"ref\":\"$REF_A\",\"name\":\"Customer API\",\"database\":{\"host\":\"ignored\"}}],\"message\":\"\"}"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  decoration_file="$SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE"
  state_dir="${decoration_file:h}"
  cd "$root" || return 1

  sync_output="$(print -r -- n | spaceship_supabase_sync project 2>"$error_file")"
  sync_status=$?
  (( sync_status != 0 )) || test_failure 'default sync confirmation must not save state'
  assert_contains "$sync_output" "preview: Customer API ($REF_A) · synced:project" 'confirmation previews the exact synced-project form'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_CANCELLED' 'cancelled sync emits only a fixed diagnostic code'
  assert_file_missing "$decoration_file" 'cancelled sync creates no decoration file'

  sync_output="$(spaceship_supabase_sync project --yes)"
  sync_status=$?
  (( sync_status == 0 )) || test_failure 'explicit --yes sync succeeds for current envelope output'
  assert_contains "$sync_output" 'source: supabase-cli:projects-list' 'sync preview reports fixed provenance'
  assert_contains "$sync_output" 'action: save separate synced decoration' 'sync preview reports separate state action'
  assert_contains "$sync_output" 'SYNC_SAVED' 'successful sync reports fixed completion code'
  assert_file_exists "$decoration_file" 'sync writes a separate decoration state file'
  assert_owner_only "$state_dir" 'synced-decoration directory is owner-only'
  assert_owner_only "$decoration_file" 'synced-decoration file is owner-only'
  read_file "$decoration_file"
  before="$REPLY"
  assert_contains "$before" $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tCustomer API\tsupabase-cli:projects-list\t' 'separate state records validated ref, kind, name, source, and timestamp'
  typeset -a state_files
  state_files=("$state_dir"/*(N))
  assert_eq 1 "${#state_files}" 'successful atomic sync leaves no temporary record behind'
  read_file "$SPACESHIP_TEST_SUPABASE_LOG"
  log="$REPLY"
  assert_contains "$log" --version 'helper queries CLI version outside the prompt path'
  assert_contains "$log" 'projects list --output-format json' 'v2.113.0 uses its supported structured output form'

  sync_output="$(print -r -- n | spaceship_supabase_sync project 2>"$error_file")"
  sync_status=$?
  (( sync_status != 0 )) || test_failure 'cancelled sync must not replace an existing decoration'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_CANCELLED' 'cancelled refresh uses the same fixed code with existing state'
  assert_synced_state_unchanged "$decoration_file" "$before" 'cancelled sync'

  doctor="$(spaceship_supabase_doctor)"
  assert_contains "$doctor" 'synced-decoration-store: available' 'explicit doctor can report redacted sync health while prompt opt-in is off'
  assert_contains "$doctor" 'synced-decoration: available' 'explicit doctor recognizes a matching saved record without enabling display'
  assert_not_contains "$doctor" 'Customer API' 'default doctor keeps a saved remote name private'
  verbose="$(spaceship_supabase_doctor --verbose)"
  assert_contains "$verbose" 'synced-kind: project' 'verbose doctor exposes validated sync kind while prompt opt-in is off'
  assert_contains "$verbose" 'synced-source: supabase-cli:projects-list' 'verbose doctor exposes fixed provenance while prompt opt-in is off'
  assert_contains "$verbose" 'synced-saved-at: ' 'verbose doctor exposes saved-at audit state while prompt opt-in is off'
  assert_not_contains "$verbose" 'Customer API' 'verbose doctor still withholds the remote-derived name'

  assert_success 'default ref format still renders' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_A" 'default renders full live ref after sync'
  assert_not_contains "$tuple" 'Customer API' 'ref format keeps remote-derived text private'

  SPACESHIP_SUPABASE_FORMAT='label+ref'
  assert_success 'label-plus-ref without opt-in renders' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_A" 'disabled synced display retains live ref'
  assert_not_contains "$tuple" 'Customer API' 'saved synced state needs explicit display opt-in'

  SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS=true
  assert_success 'enabled synced display renders' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "Customer API ($REF_A) · synced:project" 'opt-in display retains full ref and explicit synced provenance'
  render_prompt_tuple "$tuple"
  rendered="$REPLY"
  assert_contains "$rendered" 'Customer API' 'actual Spaceship v4 rendering receives validated synced text only'

  assert_success 'manual label set remains independent from synced state' spaceship_supabase_label set Production
  assert_success 'manual label takes visible precedence' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "Production ($REF_A)" 'manual label visibly wins'
  assert_not_contains "$tuple" 'Customer API' 'manual label hides synced decoration without deleting it'
  assert_success 'manual label clear does not alter sync record' spaceship_supabase_label clear
  read_file "$decoration_file"
  assert_eq "$before" "$REPLY" 'manual label clear never changes synced state'
  assert_success 'cleared manual label reveals matching sync' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_contains "$REPLY" 'Customer API' 'synced decoration reappears after manual label clear'

  assert_success 'manual label can shadow sync for doctor coverage' spaceship_supabase_label set Production
  doctor="$(spaceship_supabase_doctor)"
  assert_contains "$doctor" 'synced-decoration-store: available' 'redacted doctor reports synced store health'
  assert_contains "$doctor" 'synced-decoration: available' 'redacted doctor reports a matching synced record without its name'
  assert_not_contains "$doctor" 'Customer API' 'default doctor never exposes a synced project name'
  assert_not_contains "$doctor" "$REF_A" 'default doctor still redacts identity'
  verbose="$(spaceship_supabase_doctor --verbose)"
  assert_contains "$verbose" 'synced-kind: project' 'verbose doctor reports validated sync kind'
  assert_contains "$verbose" 'synced-source: supabase-cli:projects-list' 'verbose doctor reports validated source'
  assert_contains "$verbose" 'synced-saved-at: ' 'verbose doctor reports bounded fetched-at audit state'
  assert_contains "$verbose" 'synced-status: shadowed' 'verbose doctor identifies manual-label precedence'
  assert_not_contains "$verbose" 'Customer API' 'verbose doctor does not reveal remote-derived name'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_version_selection_is_strict_and_fail_closed() {
  local tmp='' root='' decoration_file='' error_file='' output='' log='' state_before=''
  local original_path="$PATH"
  local -i command_status=0

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  error_file="$tmp/sync.err"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 "$REF_A" || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  decoration_file="$SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE"
  cd "$root" || return 1

  SPACESHIP_TEST_SUPABASE_VERSION='2.111.0'
  SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS='projects list --output-format json'
  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"Boundary Current\"}],\"message\":\"\"}"
  export SPACESHIP_TEST_SUPABASE_VERSION SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS SPACESHIP_TEST_SUPABASE_OUTPUT
  assert_success 'v2.111 boundary selects current structured output exactly' spaceship_supabase_sync project --yes
  read_file "$SPACESHIP_TEST_SUPABASE_LOG"
  log=$REPLY
  assert_contains "$log" 'projects list --output-format json' 'v2.111 calls only the current structured flag'
  assert_file_exists "$decoration_file" 'v2.111 exact flag writes a synced record'

  zmodload zsh/files 2>/dev/null || return 1
  zf_rm "$decoration_file"
  SPACESHIP_TEST_SUPABASE_VERSION='2.113.0'
  SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS='projects list --output-format json'
  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"message\":\"\",\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"Current Reordered\"}]}"
  export SPACESHIP_TEST_SUPABASE_VERSION SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS SPACESHIP_TEST_SUPABASE_OUTPUT
  assert_success 'current envelope accepts its fixed fields in either JSON key order' spaceship_supabase_sync project --yes
  assert_file_exists "$decoration_file" 'reordered current envelope writes a synced record'

  zf_rm "$decoration_file"
  SPACESHIP_TEST_SUPABASE_VERSION='2.110.9'
  SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS='projects list --output json'
  SPACESHIP_TEST_SUPABASE_OUTPUT="[{\"ref\":\"$REF_A\",\"name\":\"Older Current\"}]"
  export SPACESHIP_TEST_SUPABASE_VERSION SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS SPACESHIP_TEST_SUPABASE_OUTPUT
  assert_success 'pre-v2.111 selects legacy structured output exactly' spaceship_supabase_sync project --yes
  read_file "$SPACESHIP_TEST_SUPABASE_LOG"
  log=$REPLY
  assert_contains "$log" 'projects list --output json' 'pre-v2.111 calls only the legacy flag'
  read_file "$decoration_file"
  state_before=$REPLY

  SPACESHIP_TEST_SUPABASE_VERSION='release unknown'
  SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS='projects list --output-format json'
  export SPACESHIP_TEST_SUPABASE_VERSION SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'malformed CLI version must fail closed'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_CLI_VERSION_UNSUPPORTED' 'malformed version has a fixed error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'malformed version'

  SPACESHIP_TEST_SUPABASE_VERSION='2.113.0'
  SPACESHIP_TEST_SUPABASE_VERSION_STATUS=1
  export SPACESHIP_TEST_SUPABASE_VERSION SPACESHIP_TEST_SUPABASE_VERSION_STATUS
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'nonzero version command must fail closed'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_CLI_FAILED' 'version-command failure has a fixed error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'nonzero version command'

  SPACESHIP_TEST_SUPABASE_VERSION_STATUS=0
  SPACESHIP_TEST_SUPABASE_VERSION='2.111.0'
  SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS='projects list --output json'
  SPACESHIP_TEST_SUPABASE_WRONG_FLAG_OUTPUT='{"wrong-flag":true}'
  export SPACESHIP_TEST_SUPABASE_VERSION_STATUS SPACESHIP_TEST_SUPABASE_VERSION
  export SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS SPACESHIP_TEST_SUPABASE_WRONG_FLAG_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'divergent wrong-flag output must not be silently retried'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'wrong-flag shape fails with a fixed parser error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'wrong-flag divergent output'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_legacy_array_and_helper_failures_never_write_state() {
  local tmp='' root='' decoration_file='' error_file='' output='' log='' label_before='' state_before='' pid='' payload='' tuple='' rendered=''
  local original_path="$PATH"
  local -i command_status=0
  local -a fake_unsafe_payloads

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  error_file="$tmp/sync.err"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.72.7 "$REF_A" || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  decoration_file="$SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE"
  SPACESHIP_TEST_SUPABASE_VERSION='2.72.7'
  SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS='projects list --output json'
  SPACESHIP_TEST_SUPABASE_OUTPUT="[{\"id\":\"$REF_A\",\"ref\":\"$REF_A\",\"name\":\"Legacy Project\"}]"
  export SPACESHIP_TEST_SUPABASE_VERSION SPACESHIP_TEST_SUPABASE_EXPECTED_LIST_ARGS SPACESHIP_TEST_SUPABASE_OUTPUT
  cd "$root" || return 1

  # The version probe accepts only 64 bytes, while the direct-child resource
  # ceiling remains a deliberately fixed 1 MiB. This demonstrates that the
  # disk bound does not depend on a parser limit that an untrusted CLI could
  # otherwise bypass by writing before validation.
  SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE="$tmp/capture-limit"
  export SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE
  assert_success 'small CLI probe uses a bounded direct capture' _spaceship_supabase_capture_cli_output "$root" 64 15 --version
  assert_contains "$REPLY" '2.72.7' 'small CLI probe still returns its bounded version output'
  read_file "$SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE"
  case $REPLY in
    # Zsh sets 2048 512-byte blocks. macOS /bin/sh reports the inherited
    # limit in KiB, while Ubuntu /bin/sh reports the 512-byte-block value.
    1024|2048) ;;
    *) test_failure 'direct CLI child has the expected fixed 1 MiB file-size ceiling' ;;
  esac
  assert_no_cli_capture_file 'successful direct capture removes its private named file'
  SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE=''
  export SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE

  output="$(print -r -- yes | spaceship_supabase_sync project 2>"$error_file")"
  command_status=$?
  (( command_status == 0 )) || test_failure 'v2.72.7 array output sync succeeds after explicit confirmation'
  assert_contains "$output" 'Legacy Project' 'legacy array supplies a validated project name'
  read_file "$SPACESHIP_TEST_SUPABASE_LOG"
  log="$REPLY"
  assert_contains "$log" 'projects list --output json' 'v2.72.7 uses the legacy structured output flag'
  assert_not_contains "$log" 'projects list --output-format json' 'old supported CLI avoids newer flag'
  assert_file_exists "$decoration_file" 'legacy helper writes only after confirmation'
  read_file "$decoration_file"
  state_before=$REPLY

  assert_success 'manual label can exist before a later sync' spaceship_supabase_label set 'Keep Me'
  read_file "$SPACESHIP_SUPABASE_LABEL_FILE"
  label_before=$REPLY
  SPACESHIP_TEST_SUPABASE_OUTPUT="[{\"ref\":\"$REF_A\",\"name\":\"Refreshed Legacy\"}]"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  assert_success 'later sync does not touch manual-label state' spaceship_supabase_sync project --yes
  read_file "$SPACESHIP_SUPABASE_LABEL_FILE"
  assert_eq "$label_before" "$REPLY" 'sync never overwrites, converts, or removes a manual label'
  read_file "$decoration_file"
  state_before=$REPLY

  # Every later no-write failure must preserve this valid, already-published
  # decoration byte-for-byte rather than merely avoid creating a new file.
  SPACESHIP_TEST_SUPABASE_OUTPUT='[]'
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'zero exact matches must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_NO_MATCH' 'zero match uses fixed no-match code'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'zero match'

  SPACESHIP_TEST_SUPABASE_OUTPUT="[{\"ref\":\"$REF_A\",\"name\":\"One\"},{\"ref\":\"$REF_A\",\"name\":\"Two\"}]"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'multiple exact matches must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_AMBIGUOUS_MATCH' 'duplicate exact match uses fixed ambiguity code'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'ambiguous output'

  SPACESHIP_SUPABASE_FORMAT='label+ref'
  SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS=true
  SPACESHIP_SUPABASE_USE_LABELS=false
  fake_unsafe_payloads=(
    'bad%name'
    $'bad\tname'
    $'bad\nname'
    $'bad\rname'
    $'bad\001name'
    $'bad\033[31mred\033[0m'
    $'bad\033]0;title\a'
    'bad-π'
  )
  for payload in "${fake_unsafe_payloads[@]}"; do
    SPACESHIP_TEST_SUPABASE_OUTPUT="[{\"ref\":\"$REF_A\",\"name\":\"$payload\"}]"
    export SPACESHIP_TEST_SUPABASE_OUTPUT
    output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
    command_status=$?
    (( command_status != 0 )) || test_failure 'unsafe fake-CLI name must fail'
    read_file "$error_file"
    assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'unsafe fake-CLI payload uses a fixed redacted code'
    assert_not_contains "$REPLY" "$payload" 'helper diagnostics never echo unsafe fake-CLI bytes'
    assert_synced_state_unchanged "$decoration_file" "$state_before" 'unsafe fake-CLI name'
    assert_success 'unsafe fake output does not create prompt state' render_sync_section "$root" "$tmp/unsafe-section.out"
    read_file "$tmp/unsafe-section.out"
    tuple=$REPLY
    assert_contains "$tuple" "Refreshed Legacy ($REF_A) · synced:project" 'saved valid state remains the only synced decoration'
    assert_not_contains "$tuple" "$payload" 'unsafe fake-CLI bytes never enter the section tuple'
    render_prompt_tuple "$tuple"
    rendered=$REPLY
    assert_not_contains "$rendered" "$payload" 'unsafe fake-CLI bytes never reach actual Spaceship rendering'
  done
  SPACESHIP_SUPABASE_FORMAT='ref'
  SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS=false
  SPACESHIP_SUPABASE_USE_LABELS=true

  SPACESHIP_TEST_SUPABASE_OUTPUT='{"unexpected":true}'
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'unsupported JSON envelope must fail'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'unsupported JSON envelope'

  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"Missing Message\"}]}"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'current envelope without its fixed message field must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'missing current-envelope message uses a fixed parser error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'missing current-envelope message'

  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"Unexpected Field\"}],\"message\":\"\",\"unexpected\":true}"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'unknown current-envelope field must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'unknown current-envelope field uses a fixed parser error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'unknown current-envelope field'

  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"First\"}],\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"Second\"}],\"message\":\"\"}"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'duplicate projects field must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'duplicate projects field uses a fixed parser error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'duplicate projects field'

  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"Duplicate Message\"}],\"message\":\"\",\"message\":\"\"}"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'duplicate message field must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'duplicate message field uses a fixed parser error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'duplicate message field'

  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"Nonempty Message\"}],\"message\":\"not accepted\"}"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'nonempty message field must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'nonempty message field uses a fixed parser error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'nonempty message field'

  SPACESHIP_TEST_SUPABASE_OUTPUT='[{"ref":"aaaaaaaaaaaaaaaaaaaa","name":"unterminated"}'
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'malformed JSON must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'malformed JSON uses a fixed parser error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'malformed JSON'

  SPACESHIP_TEST_SUPABASE_OUTPUT=''
  SPACESHIP_TEST_SUPABASE_PID_FILE="$tmp/fake-cli.pid"
  SPACESHIP_TEST_SUPABASE_HANG_OUTPUT=true
  export SPACESHIP_TEST_SUPABASE_OUTPUT SPACESHIP_TEST_SUPABASE_PID_FILE SPACESHIP_TEST_SUPABASE_HANG_OUTPUT
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'oversized streaming output must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_OUTPUT_INVALID' 'bounded CLI capture uses a fixed oversized-output error'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'oversized streaming output'
  read_file "$SPACESHIP_TEST_SUPABASE_PID_FILE"
  pid=$REPLY
  if [[ $pid == <-> ]]; then
    kill -0 "$pid" 2>/dev/null && test_failure 'bounded output terminates and waits for its CLI child'
  else
    test_failure 'fake CLI recorded a bounded child pid for cleanup coverage'
  fi
  assert_no_cli_capture_file 'bounded output removes its private named capture file'
  SPACESHIP_TEST_SUPABASE_PID_FILE=''
  SPACESHIP_TEST_SUPABASE_HANG_OUTPUT=''
  SPACESHIP_TEST_SUPABASE_OUTPUT="[{\"ref\":\"$REF_A\",\"name\":\"Current\"}]"
  export SPACESHIP_TEST_SUPABASE_PID_FILE SPACESHIP_TEST_SUPABASE_HANG_OUTPUT SPACESHIP_TEST_SUPABASE_OUTPUT

  SPACESHIP_TEST_SUPABASE_STATUS=1
  SPACESHIP_TEST_SUPABASE_OUTPUT='credential-like-output-never-reported'
  SPACESHIP_TEST_SUPABASE_PID_FILE="$tmp/fake-cli-nonzero.pid"
  export SPACESHIP_TEST_SUPABASE_STATUS SPACESHIP_TEST_SUPABASE_OUTPUT SPACESHIP_TEST_SUPABASE_PID_FILE
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'nonzero CLI result must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_CLI_FAILED' 'CLI failures use a fixed code'
  assert_not_contains "$REPLY" 'credential-like-output-never-reported' 'CLI output is never echoed on failure'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'nonzero projects-list CLI'
  read_file "$SPACESHIP_TEST_SUPABASE_PID_FILE"
  pid=$REPLY
  if [[ $pid == <-> ]]; then
    kill -0 "$pid" 2>/dev/null && test_failure 'nonzero CLI result is reaped before capture cleanup'
  else
    test_failure 'nonzero fake CLI recorded a child pid for cleanup coverage'
  fi
  assert_no_cli_capture_file 'nonzero CLI result removes its private named capture file'
  SPACESHIP_TEST_SUPABASE_PID_FILE=''
  SPACESHIP_TEST_SUPABASE_STATUS=0

  SPACESHIP_TEST_SUPABASE_OUTPUT="[{\"ref\":\"$REF_A\",\"name\":\"Current\"}]"
  SPACESHIP_TEST_SUPABASE_REF_REWRITE="$REF_B"
  SPACESHIP_TEST_SUPABASE_REF_FILE="$root/supabase/.temp/project-ref"
  export SPACESHIP_TEST_SUPABASE_OUTPUT SPACESHIP_TEST_SUPABASE_REF_REWRITE SPACESHIP_TEST_SUPABASE_REF_FILE
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'live-ref change during sync must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_REF_CHANGED' 'post-discovery recheck uses a fixed stale-proof code'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'CLI-time live-ref change'
  SPACESHIP_TEST_SUPABASE_REF_REWRITE=''
  print -r -- "$REF_A" > "$root/supabase/.temp/project-ref"

  # Rewriting after record collection, rather than while the fake CLI runs,
  # proves the final pre-atomic-write recheck cannot regress.
  functions[_spaceship_supabase_collect_synced_decoration_records_original]="${functions[_spaceship_supabase_collect_synced_decoration_records]}"
  _spaceship_supabase_collect_synced_decoration_records() {
    _spaceship_supabase_collect_synced_decoration_records_original "$@" || return 1
    print -r -- "$REF_B" > "$root/supabase/.temp/project-ref"
  }
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'live-ref change after state preparation must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_REF_CHANGED' 'final pre-write recheck rejects a late live-ref change'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'post-collection live-ref change'
  functions[_spaceship_supabase_collect_synced_decoration_records]="${functions[_spaceship_supabase_collect_synced_decoration_records_original]}"
  unfunction _spaceship_supabase_collect_synced_decoration_records_original
  print -r -- "$REF_A" > "$root/supabase/.temp/project-ref"

  SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE='relative/decorations.tsv'
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'invalid explicit state path must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_DECORATION_STORE_INVALID' 'invalid write path is reported without raw path text'
  assert_not_contains "$REPLY" 'relative/decorations.tsv' 'fixed state-path diagnostic does not echo a path'
  assert_file_missing "$tmp/relative/decorations.tsv" 'invalid state path receives no write'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'invalid decoration path'

  command mkdir -p "$tmp/no-cli"
  PATH="$tmp/no-cli"
  rehash
  SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE="$decoration_file"
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'missing CLI must fail'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_CLI_NOT_FOUND' 'missing CLI uses fixed code'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'missing CLI'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_synced_state_is_live_only_fresh_and_prompt_safe() {
  local tmp='' root='' output_file='' decoration_file='' tuple='' rendered='' payload='' overlong=''
  local owner_changed=false
  local tab=$'\t'
  local -a unsafe_payloads

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 "$REF_A" || return 1
  decoration_file="$SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE"
  command mkdir -p "${decoration_file:h}"
  command chmod 700 "${decoration_file:h}"
  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tCustomer API\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  command chmod 600 "$decoration_file"
  SPACESHIP_SUPABASE_FORMAT='label+ref'
  SPACESHIP_SUPABASE_USE_SYNCED_DECORATIONS=true

  assert_success 'matching live synced record renders' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" 'Customer API (aaaaaaaaaaaaaaaaaaaa) · synced:project' 'valid record decorates only exact live ref'

  print -r -- "$REF_B" > "$root/supabase/.temp/project-ref"
  assert_success 'changed live ref rerenders without stale sync' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_B" 'same-directory ref change is immediately visible'
  assert_not_contains "$tuple" 'Customer API' 'old sync record is not reused after ref change'
  print -r -- "$REF_A" > "$root/supabase/.temp/project-ref"

  zmodload zsh/files 2>/dev/null || return 1
  zf_rm "$root/supabase/.temp/project-ref"
  write_config_remote "$root" staging "$REF_A"
  SPACESHIP_SUPABASE_CONFIG_REMOTE=staging
  assert_success 'configured mapping remains independently renderable' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" 'configured:staging' 'configured mapping retains its required provenance marker'
  assert_not_contains "$tuple" 'Customer API' 'synced decoration never applies to configured mapping'
  print -r -- "$REF_A" > "$root/supabase/.temp/project-ref"
  SPACESHIP_SUPABASE_CONFIG_REMOTE=''

  unsafe_payloads=(
    '%n'
    $'bad\tname'
    $'bad\nname'
    $'bad\rname'
    $'bad\001name'
    $'bad\033[31mred\033[0m'
    $'bad\033]0;title\a'
    'branch-π'
  )
  for payload in "${unsafe_payloads[@]}"; do
    print -r -- "v1${tab}$REF_A${tab}project${tab}$payload${tab}supabase-cli:projects-list${tab}1700000000" > "$decoration_file"
    command chmod 600 "$decoration_file"
    assert_success 'unsafe synced record is omitted' render_sync_section "$root" "$output_file"
    read_file "$output_file"
    tuple="$REPLY"
    assert_contains "$tuple" "$REF_A" 'unsafe decoration does not hide valid live ref'
    assert_not_contains "$tuple" "$payload" 'unsafe decoration bytes never enter the section tuple'
    render_prompt_tuple "$tuple"
    rendered="$REPLY"
    assert_not_contains "$rendered" "$payload" 'unsafe decoration bytes never reach actual Spaceship rendering'
  done

  {
    print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tOne\tsupabase-cli:projects-list\t1700000000'
    print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tTwo\tsupabase-cli:projects-list\t1700000001'
  } > "$decoration_file"
  command chmod 600 "$decoration_file"
  assert_success 'duplicate decoration state is ignored' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_not_contains "$REPLY" One 'duplicate state cannot choose a decoration'
  assert_not_contains "$REPLY" Two 'duplicate state cannot choose a decoration'

  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tCustomer API\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  command chmod 644 "$decoration_file"
  assert_success 'insecure decoration state is ignored' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_not_contains "$REPLY" 'Customer API' 'world-readable state never decorates prompt'

  command chmod 600 "$decoration_file"
  command chmod 755 "${decoration_file:h}"
  assert_success 'insecure decoration directory is ignored' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_not_contains "$REPLY" 'Customer API' 'group-readable state directory never decorates prompt'
  command chmod 700 "${decoration_file:h}"

  command chmod 600 "$decoration_file"
  overlong="${(l:131073::x:)}"
  print -rn -- "$overlong" > "$decoration_file"
  assert_success 'oversized decoration state is ignored' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_contains "$REPLY" "$REF_A" 'oversized state does not hide the live ref'
  assert_not_contains "$REPLY" 'Customer API' 'oversized state cannot decorate prompt'

  print -r -- $'v2\taaaaaaaaaaaaaaaaaaaa\tproject\tCustomer API\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  assert_success 'unknown state version is ignored' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_not_contains "$REPLY" 'Customer API' 'unknown state version cannot decorate prompt'

  print -r -- $'v1\tbbbbbbbbbbbbbbbbbbbb\tproject\tOther Project\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  assert_success 'mismatched ref state is ignored' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_not_contains "$REPLY" 'Other Project' 'mismatched record cannot choose the live identity'

  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tCustomer API\tother-source\t1700000000' > "$decoration_file"
  assert_success 'invalid source state is ignored' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_not_contains "$REPLY" 'Customer API' 'unrecognized provenance cannot decorate prompt'

  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tCustomer API\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  if (( EUID == 0 )); then
    command chown 1 "$decoration_file" && owner_changed=true
  elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n chown 1 "$decoration_file" && owner_changed=true
  else
    test_note 'ok - wrong-owner synced-decoration check skipped (no safe ownership-change authority)'
  fi
  if [[ $owner_changed == true ]]; then
    assert_success 'wrong-owner decoration state is ignored' render_sync_section "$root" "$output_file"
    read_file "$output_file"
    assert_not_contains "$REPLY" 'Customer API' 'another owner cannot supply prompt decoration'
    zf_rm "$decoration_file"
  fi

  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tCustomer API\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  command cp "$decoration_file" "$tmp/decoration-target.tsv"
  zf_rm "$decoration_file"
  command ln -s "$tmp/decoration-target.tsv" "$decoration_file"
  assert_success 'symlinked decoration state is ignored' render_sync_section "$root" "$output_file"
  read_file "$output_file"
  assert_not_contains "$REPLY" 'Customer API' 'symlinked state never decorates prompt'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_sync_refuses_unsafe_storage_and_cleans_interrupted_writes() {
  local tmp='' root='' decoration_file='' error_file='' output='' state_before='' target_file='' interrupt_file=''
  local linked_parent='' original_zf_mv=''
  local original_path="$PATH"
  local -i command_status=0
  local -a temporary_files

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  error_file="$tmp/sync.err"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 "$REF_A" || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  decoration_file="$SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE"
  command mkdir -p "${decoration_file:h}"
  command chmod 700 "${decoration_file:h}"
  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tStored Project\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  command chmod 600 "$decoration_file"
  SPACESHIP_TEST_SUPABASE_OUTPUT="{\"projects\":[{\"ref\":\"$REF_A\",\"name\":\"Fresh Project\"}],\"message\":\"\"}"
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  cd "$root" || return 1

  {
    print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tStored Project\tsupabase-cli:projects-list\t1700000000'
    print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tDuplicate Project\tsupabase-cli:projects-list\t1700000001'
  } > "$decoration_file"
  read_file "$decoration_file"
  state_before=$REPLY
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'duplicate synced state must not be overwritten'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_DECORATION_STORE_INVALID' 'duplicate state has a fixed redacted write refusal'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'duplicate synced state'

  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tStored Project\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  command chmod 644 "$decoration_file"
  read_file "$decoration_file"
  state_before=$REPLY
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'insecure synced file must not be overwritten'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'insecure synced file'
  command chmod 600 "$decoration_file"

  command cp "$decoration_file" "$tmp/symlink-target.tsv"
  zmodload zsh/files 2>/dev/null || return 1
  zf_rm "$decoration_file"
  command ln -s "$tmp/symlink-target.tsv" "$decoration_file"
  read_file "$decoration_file"
  state_before=$REPLY
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'symlinked synced file must not be overwritten'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'symlinked synced file'
  zf_rm "$decoration_file"
  print -r -- "$state_before" > "$decoration_file"
  command chmod 600 "$decoration_file"

  command chmod 755 "${decoration_file:h}"
  read_file "$decoration_file"
  state_before=$REPLY
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'insecure synced parent must not be overwritten'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'insecure synced parent'
  command chmod 700 "${decoration_file:h}"

  target_file="$tmp/actual-private/decorations.tsv"
  command mkdir -p "${target_file:h}"
  command chmod 700 "${target_file:h}"
  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tStored Project\tsupabase-cli:projects-list\t1700000000' > "$target_file"
  command chmod 600 "$target_file"
  linked_parent="$tmp/linked-private"
  command ln -s "${target_file:h}" "$linked_parent"
  SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE="$linked_parent/decorations.tsv"
  read_file "$target_file"
  state_before=$REPLY
  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'symlinked synced parent must not receive a write'
  assert_synced_state_unchanged "$target_file" "$state_before" 'symlinked synced parent target'
  SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE="$decoration_file"

  # The explicit writer runs in a subshell with cleanup traps. Replacing its
  # final move with a self-TERM gives a deterministic interruption point after
  # the private temporary file has been created and written.
  interrupt_file="${decoration_file:h}/interrupted.tsv"
  original_zf_mv=${functions[zf_mv]-}
  zf_mv() {
    kill -TERM "${sysparams[pid]}" 2>/dev/null
    return 1
  }
  _spaceship_supabase_write_private_records "$interrupt_file" $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tInterrupted\tsupabase-cli:projects-list\t1700000000'
  command_status=$?
  if [[ -n $original_zf_mv ]]; then
    functions[zf_mv]=$original_zf_mv
  else
    unfunction zf_mv
  fi
  (( command_status != 0 )) || test_failure 'interrupted atomic writer must fail'
  assert_file_missing "$interrupt_file" 'interrupted writer never publishes a partial state file'
  temporary_files=("${interrupt_file}.tmp."*(N))
  assert_eq 0 "${#temporary_files}" 'interrupted writer cleans its temporary state file'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_cli_capture_interrupt_cleans_direct_child_and_descriptor() {
  local tmp='' root='' error_file='' pid_file='' pid='' sync_pid=''
  local original_path="$PATH"
  local sync_active=false
  local -i attempts=0 command_status=0

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  error_file="$tmp/interrupt.err"
  pid_file="$tmp/interrupt-cli.pid"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 "$REF_A" || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  SPACESHIP_TEST_SUPABASE_PID_FILE="$pid_file"
  SPACESHIP_TEST_SUPABASE_HANG_SILENT=true
  export SPACESHIP_TEST_SUPABASE_PID_FILE SPACESHIP_TEST_SUPABASE_HANG_SILENT
  cd "$root" || return 1

  # The fake CLI records its own PID, then `exec`s a quiet, long-running
  # process. TERM therefore reaches the shell while its direct child is in
  # the parent-side capture poller, exercising local signal cleanup.
  (
    spaceship_supabase_sync project --yes >"$tmp/interrupt.out" 2>"$error_file"
  ) &
  sync_pid=$!
  sync_active=true
  if [[ $sync_pid != <-> ]]; then
    sync_active=false
    test_failure 'interrupted sync starts a waitable helper shell'
  else
    while (( attempts < 100 )); do
      [[ -s $pid_file ]] && break
      command sleep 0.01
      (( attempts++ ))
    done
    if [[ ! -s $pid_file ]]; then
      test_failure 'quiet fake CLI reaches the direct capture wait before interruption'
    fi
    kill -15 "$sync_pid" 2>/dev/null || test_failure 'interrupted sync helper remains signalable'
    wait "$sync_pid" 2>/dev/null
    command_status=$?
    sync_active=false
    (( command_status != 0 )) || test_failure 'interrupted CLI capture returns a failure status'
  fi

  # Always attempt to reap the background test shell on an assertion failure;
  # the normal path has already waited for it above.
  if [[ $sync_active == true ]]; then
    kill -15 "$sync_pid" 2>/dev/null || true
    wait "$sync_pid" 2>/dev/null || true
  fi
  assert_file_exists "$pid_file" 'interrupted fake CLI records its direct child pid'
  if [[ -s $pid_file ]]; then
    read_file "$pid_file"
    pid=$REPLY
    if [[ $pid == <-> ]]; then
      kill -0 "$pid" 2>/dev/null && test_failure 'interrupted capture terminates and reaps its direct CLI child'
    else
      test_failure 'interrupted fake CLI pid is numeric for cleanup coverage'
    fi
  fi
  assert_file_missing "$SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE" 'interrupted capture publishes no synced decoration'
  assert_no_cli_capture_file 'interrupted capture leaves no named private capture artifact'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_cli_capture_watchdog_bounds_resistant_and_silent_children() {
  local tmp='' root='' error_file='' pid_file='' pid='' output_file=''
  local original_path="$PATH"
  local -F 6 started=0 finished=0 elapsed=0
  local -i command_status=0

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  error_file="$tmp/watchdog.err"
  output_file="$tmp/watchdog.out"
  pid_file="$tmp/watchdog-cli.pid"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 "$REF_A" || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  SPACESHIP_TEST_SUPABASE_PID_FILE="$pid_file"
  SPACESHIP_TEST_SUPABASE_HANG_IGNORE_XFSZ=true
  export SPACESHIP_TEST_SUPABASE_PID_FILE SPACESHIP_TEST_SUPABASE_HANG_IGNORE_XFSZ
  cd "$root" || return 1

  # This writer catches both XFSZ and TERM, then repeatedly retries failed
  # writes after the fixed 1 MiB resource ceiling. The private one-second
  # test timeout is only an internal capture-helper argument; the normal
  # sync caller always uses its fixed 15-second production budget.
  started=$EPOCHREALTIME
  _spaceship_supabase_capture_cli_output "$root" 64 1 projects list --output-format json >"$output_file" 2>"$error_file"
  command_status=$?
  finished=$EPOCHREALTIME
  elapsed=$(( finished - started ))
  assert_eq 3 "$command_status" 'resistant over-limit CLI fails with the bounded-output status'
  (( elapsed < 4.0 )) || test_failure 'position watchdog terminates a SIGXFSZ-catching writer promptly'
  assert_empty "$REPLY" 'resistant over-limit CLI never returns untrusted output'
  assert_file_exists "$pid_file" 'resistant writer records its direct child pid'
  if [[ -s $pid_file ]]; then
    read_file "$pid_file"
    pid=$REPLY
    if [[ $pid == <-> ]]; then
      kill -0 "$pid" 2>/dev/null && test_failure 'position watchdog TERM/KILL reaps a resistant direct child'
    else
      test_failure 'resistant writer pid is numeric for cleanup coverage'
    fi
  fi
  assert_no_cli_capture_file 'resistant writer leaves no named private capture artifact'

  # A quiet process cannot cross the output limit. The same direct-child
  # poller therefore reaches its fixed local timeout and cleans up without
  # depending on output or an external timeout program. A two-second test
  # budget also proves Zsh 5.2 cannot expire this watchdog at the next
  # wall-clock boundary before all twenty 100ms polls have elapsed.
  pid_file="$tmp/silent-cli.pid"
  SPACESHIP_TEST_SUPABASE_PID_FILE="$pid_file"
  SPACESHIP_TEST_SUPABASE_HANG_IGNORE_XFSZ=''
  SPACESHIP_TEST_SUPABASE_HANG_SILENT=true
  export SPACESHIP_TEST_SUPABASE_PID_FILE SPACESHIP_TEST_SUPABASE_HANG_IGNORE_XFSZ SPACESHIP_TEST_SUPABASE_HANG_SILENT
  started=$EPOCHREALTIME
  _spaceship_supabase_capture_cli_output "$root" 64 2 projects list --output-format json >"$output_file" 2>"$error_file"
  command_status=$?
  finished=$EPOCHREALTIME
  elapsed=$(( finished - started ))
  assert_eq 1 "$command_status" 'silent CLI fails after the private fixed capture timeout'
  # Container scheduling can delay a two-second test helper beyond its normal
  # wall-clock budget. Its fixed failure status plus direct-child reaping
  # below prove the internal watchdog fired; this broad outer bound merely
  # prevents a future unbounded wait from stalling the focused suite.
  (( elapsed < 30.0 )) || test_failure 'silent CLI reaches the bounded local timeout without hanging the suite'
  (( elapsed >= 1.5 )) || test_failure 'silent CLI honors the full private two-second capture budget'
  assert_empty "$REPLY" 'silent CLI returns no output'
  assert_file_exists "$pid_file" 'silent CLI records its direct child pid'
  if [[ -s $pid_file ]]; then
    read_file "$pid_file"
    pid=$REPLY
    if [[ $pid == <-> ]]; then
      kill -0 "$pid" 2>/dev/null && test_failure 'timeout cleanup reaps a quiet direct child'
    else
      test_failure 'silent CLI pid is numeric for cleanup coverage'
    fi
  fi
  assert_file_missing "$SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE" 'watchdog-only captures publish no synced decoration'
  assert_no_cli_capture_file 'silent timeout leaves no named private capture artifact'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_cli_capture_uses_unshadowable_safety_primitives() {
  local tmp='' root='' error_file='' output_file='' limit_file='' shadow_marker=''
  local original_path="$PATH"
  local -i command_status=0

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  error_file="$tmp/shadow.err"
  output_file="$tmp/shadow.out"
  limit_file="$tmp/shadow-limit"
  shadow_marker="$tmp/shadow-called"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 "$REF_A" || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE="$limit_file"
  export SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE
  cd "$root" || return 1

  # A shell user can define functions with the same names as module and shell
  # builtins. Each shadow records an invocation, returns a misleading success
  # or failure, and would respectively disable signal cleanup, private-file
  # unlinking, the hard size limit, descriptor I/O, or capture setup if this
  # explicit helper did not invoke the native primitives through `builtin`.
  trap() { print -r -- trap >> "$shadow_marker"; return 0; }
  ulimit() { print -r -- ulimit >> "$shadow_marker"; return 0; }
  zf_rm() { print -r -- zf_rm >> "$shadow_marker"; return 0; }
  sysopen() { print -r -- sysopen >> "$shadow_marker"; return 1; }
  sysseek() { print -r -- sysseek >> "$shadow_marker"; return 1; }
  sysread() { print -r -- sysread >> "$shadow_marker"; return 1; }

  _spaceship_supabase_capture_cli_output "$root" 64 1 --version >"$output_file" 2>"$error_file"
  command_status=$?
  assert_eq 0 "$command_status" 'shadowed module and shell functions do not block direct CLI capture'
  assert_contains "$REPLY" '2.113.0' 'native descriptor primitives return the valid version output'
  assert_file_missing "$shadow_marker" 'direct capture never invokes a shadowed safety primitive'
  read_file "$limit_file"
  case $REPLY in
    1024|2048) ;;
    *) test_failure 'native ulimit preserves the fixed 1 MiB direct-child file limit under a shadow function' ;;
  esac
  assert_no_cli_capture_file 'shadowed cleanup primitive cannot leave a named private capture file'

  unfunction trap ulimit zf_rm sysopen sysseek sysread 2>/dev/null || true
  SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE=''
  export SPACESHIP_TEST_SUPABASE_CAPTURE_LIMIT_FILE
  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_cli_capture_observes_a_pre_wait_interrupt() {
  local tmp='' root='' error_file='' output_file='' pid_file='' pid=''
  local original_path="$PATH"
  local capture_debug_target=$$
  local capture_debug_armed=true
  local -i command_status=0

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  error_file="$tmp/pre-wait.err"
  output_file="$tmp/pre-wait.out"
  pid_file="$tmp/pre-wait-cli.pid"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 "$REF_A" || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  SPACESHIP_TEST_SUPABASE_PID_FILE="$pid_file"
  SPACESHIP_TEST_SUPABASE_OUTPUT='[]'
  export SPACESHIP_TEST_SUPABASE_PID_FILE SPACESHIP_TEST_SUPABASE_OUTPUT
  cd "$root" || return 1

  # Zsh's DEBUG trap runs immediately before the private helper's exact
  # `builtin wait "$child_pid"` command. This delivers TERM after `$!` was
  # assigned and after polling completed, but before the status-collecting
  # wait can start—deterministically covering the formerly missed race.
  TRAPDEBUG() {
    if [[ $capture_debug_armed == true && ${ZSH_DEBUG_CMD-} == *'builtin wait "$child_pid"'* ]]; then
      capture_debug_armed=false
      builtin kill -15 "$capture_debug_target" 2>/dev/null || true
    fi
  }
  _spaceship_supabase_capture_cli_output "$root" 64 1 projects list --output-format json >"$output_file" 2>"$error_file"
  command_status=$?
  unfunction TRAPDEBUG 2>/dev/null || true

  assert_eq false "$capture_debug_armed" 'DEBUG trap injected TERM immediately before the direct-child wait'
  assert_eq 143 "$command_status" 'pre-wait TERM returns the fixed local signal status'
  assert_empty "$REPLY" 'pre-wait TERM returns no CLI output'
  # The signal may win before the direct child has exec'd the fake CLI, so a
  # PID record is optional. If it did start, its process must already be gone.
  if [[ -s $pid_file ]]; then
    read_file "$pid_file"
    pid=$REPLY
    if [[ $pid == <-> ]]; then
      kill -0 "$pid" 2>/dev/null && test_failure 'pre-wait interrupt terminates and reaps its direct CLI child'
    else
      test_failure 'pre-wait fake CLI pid is numeric for cleanup coverage'
    fi
  fi
  assert_no_cli_capture_file 'pre-wait interrupt leaves no named private capture artifact'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_sync_refuses_to_invoke_cli_without_a_live_ref() {
  local tmp='' root='' error_file='' output='' decoration_file='' state_before=''
  local original_path="$PATH"
  local -i command_status=0

  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  error_file="$tmp/sync.err"
  start_sync_runtime "$tmp/state" || return 1
  materialize_project "$root" 2.113.0 || return 1
  prepare_fake_supabase "$tmp" "$original_path" || return 1
  SPACESHIP_TEST_SUPABASE_OUTPUT='{"projects":[],"message":""}'
  export SPACESHIP_TEST_SUPABASE_OUTPUT
  decoration_file="$SPACESHIP_SUPABASE_SYNCED_DECORATION_FILE"
  command mkdir -p "${decoration_file:h}"
  command chmod 700 "${decoration_file:h}"
  print -r -- $'v1\taaaaaaaaaaaaaaaaaaaa\tproject\tPrior Project\tsupabase-cli:projects-list\t1700000000' > "$decoration_file"
  command chmod 600 "$decoration_file"
  read_file "$decoration_file"
  state_before=$REPLY
  cd "$root" || return 1

  output="$(spaceship_supabase_sync project --yes 2>"$error_file")"
  command_status=$?
  (( command_status != 0 )) || test_failure 'config-only project must not enter sync'
  read_file "$error_file"
  assert_contains "$REPLY" 'SYNC_NO_LIVE_REF' 'sync requires exact current live ref'
  assert_file_missing "$SPACESHIP_TEST_SUPABASE_LOG" 'no-live-ref helper never invokes fake Supabase CLI'
  assert_synced_state_unchanged "$decoration_file" "$state_before" 'no-live-ref helper'

  PATH="$original_path"
  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_case 'current synced-project sync is explicit, separate, opt-in, and auditable' test_current_envelope_sync_is_confirmed_separate_and_opt_in
test_case 'CLI selection and unsupported versions fail closed' test_version_selection_is_strict_and_fail_closed
test_case 'legacy CLI output and every critical helper failure preserve state' test_legacy_array_and_helper_failures_never_write_state
test_case 'synced state is live-only, fresh, and safe for actual prompt rendering' test_synced_state_is_live_only_fresh_and_prompt_safe
test_case 'unsafe synced storage is preserved and interrupted writes are cleaned' test_sync_refuses_unsafe_storage_and_cleans_interrupted_writes
test_case 'interrupted direct CLI capture reaps its child and private descriptor' test_cli_capture_interrupt_cleans_direct_child_and_descriptor
test_case 'direct CLI capture bounds resistant output and silent children' test_cli_capture_watchdog_bounds_resistant_and_silent_children
test_case 'direct CLI capture bypasses shadowed safety primitives' test_cli_capture_uses_unshadowable_safety_primitives
test_case 'direct CLI capture observes an interrupt before wait begins' test_cli_capture_observes_a_pre_wait_interrupt
test_case 'sync does not invoke a CLI without a current live ref' test_sync_refuses_to_invoke_cli_without_a_live_ref
finish_tests
