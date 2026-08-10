#!/usr/bin/env zsh
# Explicit label-store helpers and read-only diagnostics tests.

emulate -L zsh
setopt extendedglob nullglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_LIVE='aaaaaaaaaaaaaaaaaaaa'

start_label_runtime() {
  local state_home="$1"
  XDG_STATE_HOME="$state_home"
  reset_public_configuration
  load_plugin_runtime
}

render_label_section() {
  local directory="$1"
  local output_file="$2"

  cd "$directory" || return 1
  render_section_to "$output_file"
}

test_label_set_list_clear_and_format() {
  local tmp='' root='' output_file='' tuple='' listed='' label_file='' state_dir='' record=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_label_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  label_file="$SPACESHIP_SUPABASE_LABEL_FILE"
  state_dir="${label_file:h}"
  cd "$root" || return 1

  assert_success 'label set accepts a safe label with live identity' spaceship_supabase_label set Production
  assert_file_exists "$label_file" 'label set creates state file only through explicit command'
  assert_owner_only "$state_dir" 'label state directory is owner-only'
  assert_owner_only "$label_file" 'label state file is owner-only'
  read_file "$label_file"
  record="$REPLY"
  assert_contains "$record" $'v1\taaaaaaaaaaaaaaaaaaaa\tProduction\t' 'label file is versioned TSV keyed by ref'
  typeset -a state_files
  state_files=("$state_dir"/*(N))
  assert_eq 1 "${#state_files}" 'atomic update leaves no temporary state files behind'

  SPACESHIP_SUPABASE_FORMAT='label+ref'
  assert_success 'label format renders' render_label_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "Production (${REF_LIVE})" 'label format decorates but never replaces ref'

  listed="$(spaceship_supabase_label list)"
  assert_contains "$listed" "$REF_LIVE" 'label list retains exact project ref'
  assert_contains "$listed" Production 'label list reports safe label'

  assert_success 'label clear accepts current live identity' spaceship_supabase_label clear
  assert_success 'ref still renders after clear' render_label_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'clear never removes live identity'
  assert_not_contains "$tuple" Production 'clear removes only decoration'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_label_helpers_require_live_ref_and_reject_unsafe_input() {
  local tmp='' root='' label_file='' before='' after='' invalid_label=''
  local -a invalid_labels
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  start_label_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.72.7 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  label_file="$SPACESHIP_SUPABASE_LABEL_FILE"
  cd "$root" || return 1
  assert_success 'safe baseline label is stored' spaceship_supabase_label set Production
  read_file "$label_file"
  before="$REPLY"

  invalid_labels=(
    'bad%label'
    $'bad\tlabel'
    $'bad\nlabel'
    $'bad\033]0;title\a'
  )
  for invalid_label in "${invalid_labels[@]}"; do
    assert_failure_silent 'unsafe label is rejected' spaceship_supabase_label set "$invalid_label"
  done
  typeset long_label="${(l:65::x:)}"
  assert_failure_silent 'overlong label is rejected' spaceship_supabase_label set "$long_label"
  read_file "$label_file"
  after="$REPLY"
  assert_eq "$before" "$after" 'rejected labels never alter stored state'

  zmodload zsh/files 2>/dev/null || return 1
  zf_rm "$root/supabase/.temp/project-ref"
  assert_failure_silent 'label set without a current live ref fails' spaceship_supabase_label set Missing
  assert_failure_silent 'label clear without a current live ref fails' spaceship_supabase_label clear
  read_file "$label_file"
  assert_eq "$before" "$REPLY" 'failed helper commands do not mutate prior label records'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_labels_cannot_resurrect_identity() {
  local tmp='' root='' output_file='' tuple=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_label_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  cd "$root" || return 1
  assert_success 'label set succeeds for current ref' spaceship_supabase_label set Production
  SPACESHIP_SUPABASE_FORMAT='label+ref'
  assert_success 'decorated live ref renders' render_section_to "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" Production 'label decorates a live rendering'

  zmodload zsh/files 2>/dev/null || return 1
  zf_rm "$root/supabase/.temp/project-ref"
  assert_success 'missing link remains a silent prompt condition' render_section_to "$output_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'label record never resurrects a missing project identity'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_label_options_control_rendering_and_custom_state_location() {
  local tmp='' root='' output_file='' tuple='' custom_file=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_label_runtime "$tmp/default-state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  custom_file="$tmp/explicit-state/labels.tsv"
  SPACESHIP_SUPABASE_LABEL_FILE="$custom_file"
  cd "$root" || return 1
  assert_success 'custom absolute label file accepts explicit set' spaceship_supabase_label set Production
  assert_file_exists "$custom_file" 'custom label path is used instead of default state path'
  assert_file_missing "$tmp/default-state/spaceship-supabase/labels.tsv" 'custom label path does not create default state file'

  SPACESHIP_SUPABASE_FORMAT='label+ref'
  assert_success 'enabled labels decorate custom state' render_label_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" 'Production (aaaaaaaaaaaaaaaaaaaa)' 'enabled labels decorate a currently live ref'

  SPACESHIP_SUPABASE_USE_LABELS=false
  assert_success 'disabled labels keep live ref renderable' render_label_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'disabled labels retain full live ref'
  assert_not_contains "$tuple" Production 'disabled labels do not decorate prompt output'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_invalid_label_store_is_ignored_not_rendered() {
  local tmp='' root='' output_file='' tuple='' label_file='' record='' altered=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_label_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.72.7 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  label_file="$SPACESHIP_SUPABASE_LABEL_FILE"
  cd "$root" || return 1
  assert_success 'initial label set succeeds' spaceship_supabase_label set One
  read_file "$label_file"
  record="$REPLY"
  altered="${record/One/Two}"
  print -r -- "$record" "$altered" > "$label_file"
  command chmod 600 "$label_file"
  SPACESHIP_SUPABASE_FORMAT='label+ref'

  assert_success 'duplicate label store is ignored' render_section_to "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'invalid label store does not hide live ref'
  assert_not_contains "$tuple" One 'ambiguous duplicate label is not rendered'
  assert_not_contains "$tuple" Two 'second ambiguous label is not rendered'

  print -r -- "$record" > "$label_file"
  command chmod 644 "$label_file"
  assert_success 'world-readable label store is ignored' render_section_to "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'insecure label file keeps live ref'
  assert_not_contains "$tuple" One 'insecure file label is never rendered'

  command chmod 600 "$label_file"
  command cp "$label_file" "$tmp/label-target.tsv"
  zmodload zsh/files 2>/dev/null || return 1
  zf_rm "$label_file"
  command ln -s "$tmp/label-target.tsv" "$label_file"
  assert_success 'symlinked label store is ignored' render_section_to "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'symlinked state keeps live ref'
  assert_not_contains "$tuple" One 'symlinked state label is never rendered'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_label_store_rejects_oversized_records() {
  local tmp='' root='' output_file='' tuple='' label_file='' oversized=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_label_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  label_file="$SPACESHIP_SUPABASE_LABEL_FILE"
  command mkdir -p "${label_file:h}"
  oversized="${(l:131073::x:)}"
  print -rn -- "$oversized" > "$label_file"
  command chmod 600 "$label_file"
  SPACESHIP_SUPABASE_FORMAT='label+ref'

  assert_success 'oversized state is ignored' render_label_section "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_LIVE" 'oversized label state does not hide live ref'
  assert_not_contains "$tuple" " (${REF_LIVE})" 'oversized label state does not render a decoration'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_label_write_rejects_an_insecure_state_directory() {
  local tmp='' root='' label_file='' state_dir=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  start_label_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.72.7 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  label_file="$SPACESHIP_SUPABASE_LABEL_FILE"
  state_dir="${label_file:h}"
  command mkdir -p "$state_dir"
  command chmod 755 "$state_dir"
  cd "$root" || return 1

  assert_failure_silent 'label set rejects an insecure state directory' spaceship_supabase_label set Production
  assert_file_missing "$label_file" 'insecure state directory does not receive a label file'
  command chmod 700 "$state_dir"

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_label_store_rejects_missing_child_beneath_symlinked_ancestor() {
  local tmp='' root='' label_file='' target_dir='' linked_dir=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  target_dir="$tmp/state-target"
  linked_dir="$tmp/state-link"
  start_label_runtime "$tmp/default-state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  command mkdir -p "$target_dir"
  command chmod 700 "$target_dir"
  command ln -s "$target_dir" "$linked_dir"
  label_file="$linked_dir/missing/labels.tsv"
  SPACESHIP_SUPABASE_LABEL_FILE="$label_file"
  cd "$root" || return 1

  assert_failure_silent 'label set rejects a missing child under a symlinked ancestor' \
    spaceship_supabase_label set Production
  assert_failure_silent 'label list rejects a missing child under a symlinked ancestor' \
    spaceship_supabase_label list
  assert_file_missing "$target_dir/missing" 'rejected symlinked ancestry receives no state directory'
  assert_file_missing "$target_dir/missing/labels.tsv" 'rejected symlinked ancestry receives no state file'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_doctor_is_redacted_and_read_only() {
  local tmp='' root='' label_file='' before='' after='' doctor='' verbose=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project-with-sensitive-name"
  start_label_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }
  label_file="$SPACESHIP_SUPABASE_LABEL_FILE"
  cd "$root" || return 1
  assert_success 'doctor fixture label is set' spaceship_supabase_label set Production
  read_file "$label_file"
  before="$REPLY"

  doctor="$(spaceship_supabase_doctor)"
  assert_contains "$doctor" 'root: detected' 'doctor reports root status without raw path'
  assert_contains "$doctor" 'source: live' 'doctor reports live source status'
  assert_contains "$doctor" 'live-link: valid' 'doctor reports validated link state'
  assert_not_contains "$doctor" "$root" 'default doctor output never exposes root path'
  assert_not_contains "$doctor" "$REF_LIVE" 'default doctor output redacts project ref'
  assert_not_contains "$doctor" Production 'default doctor output redacts label text'
  read_file "$label_file"
  after="$REPLY"
  assert_eq "$before" "$after" 'doctor is read-only and does not modify label state'

  verbose="$(spaceship_supabase_doctor --verbose)"
  assert_contains "$verbose" "ref: $REF_LIVE" 'verbose doctor may show pre-validated ref'
  assert_contains "$verbose" 'label: Production' 'verbose doctor may show pre-validated label'
  assert_not_contains "$verbose" "$root" 'verbose doctor still never exposes raw root path'
  assert_failure_silent 'doctor rejects unknown flags' spaceship_supabase_doctor --unknown

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_case 'explicit labels set, list, clear, and retain the ref' test_label_set_list_clear_and_format
test_case 'label helpers require live identity and reject unsafe labels' test_label_helpers_require_live_ref_and_reject_unsafe_input
test_case 'labels never resurrect a missing live target' test_labels_cannot_resurrect_identity
test_case 'label options control rendering and custom state location' test_label_options_control_rendering_and_custom_state_location
test_case 'duplicate, insecure, and symlinked label state is ignored' test_invalid_label_store_is_ignored_not_rendered
test_case 'oversized label state is ignored' test_label_store_rejects_oversized_records
test_case 'label writes reject insecure state directories' test_label_write_rejects_an_insecure_state_directory
test_case 'label helpers reject missing children under symlinked ancestors' test_label_store_rejects_missing_child_beneath_symlinked_ancestor
test_case 'doctor is redacted by default and read-only' test_doctor_is_redacted_and_read_only
finish_tests
