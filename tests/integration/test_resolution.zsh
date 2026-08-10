#!/usr/bin/env zsh
# Stable Supabase layout, precedence, root selection, and freshness tests.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_A='aaaaaaaaaaaaaaaaaaaa'
typeset REF_B='bbbbbbbbbbbbbbbbbbbb'
typeset REF_C='cccccccccccccccccccc'
typeset REF_D='dddddddddddddddddddd'

start_runtime() {
  local state_home="$1"
  XDG_STATE_HOME="$state_home"
  reset_public_configuration
  load_plugin_runtime
}

render_at() {
  local directory="$1"
  local output_file="$2"

  cd "$directory" || return 1
  render_section_to "$output_file"
}

test_stable_cli_fixture_anchors_render() {
  local tmp='' root='' output_file='' tuple='' cli_version='' expected_ref=''
  new_test_dir || return 1
  tmp="$REPLY"
  start_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }

  for cli_version in 2.72.7 2.113.0; do
    fixture_file "$cli_version" project-ref.txt || {
      test_failure "fixture $cli_version includes a synthetic project-ref anchor"
      continue
    }
    read_file "$REPLY"
    expected_ref="$REPLY"
    root="$tmp/fixture-${cli_version}"
    output_file="$tmp/${cli_version}.out"
    materialize_project "$root" "$cli_version" "$expected_ref" || {
      test_failure "fixture $cli_version materializes"
      continue
    }
    assert_success "stable CLI $cli_version renders" render_at "$root" "$output_file"
    read_file "$output_file"
    tuple="$REPLY"
    assert_contains "$tuple" "$expected_ref" "stable CLI $cli_version preserves its full reference"
    assert_not_contains "$tuple" 'configured:' "live fixture $cli_version does not render fallback marker"
  done

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_config_mapping_is_explicit_and_marked() {
  local tmp='' root='' output_file='' tuple=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 || {
    remove_test_dir "$tmp"
    return 1
  }
  write_top_level_project_id "$root" "$REF_C"

  assert_success 'config-only root renders silently by default' render_at "$root" "$output_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'top-level config project_id is never treated as a hosted reference'

  SPACESHIP_SUPABASE_CONFIG_REMOTE=staging
  assert_success 'missing selected mapping remains silent' render_at "$root" "$output_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'selected remote without matching mapping remains silent'

  write_config_remote "$root" staging "$REF_C"
  assert_success 'explicit configured mapping renders' render_at "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_C" 'configured mapping keeps the complete project reference'
  assert_contains "$tuple" 'configured:staging' 'configured mapping carries mandatory non-live marker'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_live_identity_wins_over_configured_mapping() {
  local tmp='' root='' output_file='' tuple=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.72.7 "$REF_A" || {
    remove_test_dir "$tmp"
    return 1
  }
  write_config_remote "$root" staging "$REF_B"
  SPACESHIP_SUPABASE_CONFIG_REMOTE=staging

  assert_success 'live reference renders over config fallback' render_at "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_A" 'live reference wins'
  assert_not_contains "$tuple" "$REF_B" 'configured mapping does not replace live reference'
  assert_not_contains "$tuple" 'configured:' 'live reference does not claim fallback source'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_nearest_project_is_a_hard_boundary() {
  local tmp='' parent='' child='' output_file='' tuple=''
  new_test_dir || return 1
  tmp="$REPLY"
  parent="$tmp/parent"
  child="$parent/packages/child"
  output_file="$tmp/section.out"
  start_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$parent" 2.72.7 "$REF_A" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$child" 2.113.0 || {
    remove_test_dir "$tmp"
    return 1
  }
  command mkdir -p "$child/src"

  assert_success 'nested config boundary resolves safely' render_at "$child/src" "$output_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'a child project missing live identity cannot inherit its parent reference'

  print -r -- "$REF_B" > "$child/supabase/.temp/project-ref"
  assert_success 'nested project own ref renders' render_at "$child/src" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_B" 'nearest project reference renders'
  assert_not_contains "$tuple" "$REF_A" 'parent reference never leaks through nested boundary'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_supabase_workdir_is_strict_and_relative_to_pwd() {
  local tmp='' selected='' elsewhere='' output_file='' tuple=''
  new_test_dir || return 1
  tmp="$REPLY"
  selected="$tmp/selected"
  elsewhere="$tmp/work/inside"
  output_file="$tmp/section.out"
  start_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$selected" 2.113.0 "$REF_C" || {
    remove_test_dir "$tmp"
    return 1
  }
  command mkdir -p "$elsewhere"

  SUPABASE_WORKDIR='../../selected'
  assert_success 'relative workdir override resolves from PWD' render_at "$elsewhere" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_C" 'relative workdir uses selected project only'

  SUPABASE_WORKDIR="$tmp/missing"
  assert_success 'invalid override fails closed' render_at "$selected" "$output_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'invalid override never falls back to current project'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_link_changes_are_visible_without_changing_directory() {
  local tmp='' root='' output_file='' first='' second=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.113.0 "$REF_A" || {
    remove_test_dir "$tmp"
    return 1
  }
  cd "$root" || return 1

  assert_success 'initial linked ref renders' render_section_to "$output_file"
  read_file "$output_file"
  first="$REPLY"
  print -r -- "$REF_D" > "$root/supabase/.temp/project-ref"
  assert_success 'ref refresh after link update renders' render_section_to "$output_file"
  read_file "$output_file"
  second="$REPLY"
  assert_contains "$first" "$REF_A" 'first render shows first live ref'
  assert_contains "$second" "$REF_D" 'next render sees changed live ref without cd'
  assert_not_contains "$second" "$REF_A" 'changed live ref does not remain stale'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_local_db_branch_is_explicitly_local_and_opt_in() {
  local tmp='' root='' output_file='' tuple='' branch=''
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  output_file="$tmp/section.out"
  start_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  fixture_file 2.72.7 local-db-branch.txt || {
    remove_test_dir "$tmp"
    return 1
  }
  read_file "$REPLY"
  branch="$REPLY"
  materialize_project "$root" 2.72.7 "$REF_A" "$branch" || {
    remove_test_dir "$tmp"
    return 1
  }

  assert_success 'default local branch state renders ref' render_at "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_A" 'default still renders live ref'
  assert_not_contains "$tuple" "$branch" 'local DB branch is hidden by default'
  assert_not_contains "$tuple" '@' 'default never implies a hosted branch'

  SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH=true
  assert_success 'enabled local branch renders' render_at "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "(local-db:${branch})" 'local DB branch carries explicit local-db marker'
  assert_not_contains "$tuple" "@${branch}" 'local DB branch never uses hosted-looking ref@branch form'

  print -r -- 'feature branch with spaces' > "$root/supabase/.branches/_current_branch"
  assert_success 'unsafe local branch is ignored' render_at "$root" "$output_file"
  read_file "$output_file"
  tuple="$REPLY"
  assert_contains "$tuple" "$REF_A" 'unsafe branch does not remove valid live ref'
  assert_not_contains "$tuple" 'feature branch with spaces' 'unsafe branch is never rendered'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_search_is_bounded_to_32_ancestors() {
  local tmp='' root='' deep='' output_file='' level=0
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
  deep="$root"
  output_file="$tmp/section.out"
  start_runtime "$tmp/state" || {
    remove_test_dir "$tmp"
    return 1
  }
  materialize_project "$root" 2.72.7 "$REF_A" || {
    remove_test_dir "$tmp"
    return 1
  }
  for (( level = 1; level <= 34; level++ )); do
    deep="$deep/d$level"
  done
  command mkdir -p "$deep"

  assert_success 'deep path search returns silently' render_at "$deep" "$output_file"
  read_file "$output_file"
  assert_empty "$REPLY" 'project beyond the 32-ancestor limit is not selected'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_case 'pinned stable CLI fixture anchors render correctly' test_stable_cli_fixture_anchors_render
test_case 'config mapping is opt-in and truthfully marked' test_config_mapping_is_explicit_and_marked
test_case 'live ref takes precedence over configured mapping' test_live_identity_wins_over_configured_mapping
test_case 'nearest Supabase root is a hard boundary' test_nearest_project_is_a_hard_boundary
test_case 'SUPABASE_WORKDIR is strict and PWD-relative' test_supabase_workdir_is_strict_and_relative_to_pwd
test_case 'live project-ref refreshes in the same directory' test_link_changes_are_visible_without_changing_directory
test_case 'local database branch is opt-in and explicitly labeled' test_local_db_branch_is_explicitly_local_and_opt_in
test_case 'ancestor search has a bounded depth' test_search_is_bounded_to_32_ancestors
finish_tests
