#!/usr/bin/env zsh
#
# Small, dependency-free assertions and fixture helpers for the v0.1.0 release
# suite.  Every suite is executed by tests/run.zsh in a fresh `zsh -f` process.

emulate -L zsh
setopt extendedglob

typeset -g TESTS_RUN=0
typeset -g TESTS_FAILED=0
typeset -g TEST_CASE_FAILURES=0
typeset -g TEST_REPO_ROOT="${${(%):-%N}:A:h:h:h}"
typeset -g TEST_PLUGIN_FILE="$TEST_REPO_ROOT/spaceship-supabase.plugin.zsh"
typeset -g TEST_SECTION_FILE="$TEST_REPO_ROOT/tests/vendor/spaceship/lib/section.zsh"
typeset -g TEST_FIXTURES_DIR="$TEST_REPO_ROOT/tests/fixtures"

test_note() {
  print -r -- "$*"
}

test_failure() {
  (( TEST_CASE_FAILURES++ ))
  print -ru2 -- "    assertion failed: $1"
}

test_case() {
  local description="$1"
  local handler="$2"
  local result_status=0

  (( TESTS_RUN++ ))
  TEST_CASE_FAILURES=0
  "$handler"
  result_status=$?
  if (( result_status != 0 && TEST_CASE_FAILURES == 0 )); then
    test_failure "test returned status $result_status"
  fi

  if (( TEST_CASE_FAILURES == 0 )); then
    print -r -- "ok - $description"
  else
    (( TESTS_FAILED++ ))
    print -r -- "not ok - $description"
  fi
  return 0
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  [[ "$actual" == "$expected" ]] || test_failure "$message"
  return 0
}

assert_empty() {
  local actual="$1"
  local message="$2"

  [[ -z "$actual" ]] || test_failure "$message"
  return 0
}

assert_nonempty() {
  local actual="$1"
  local message="$2"

  [[ -n "$actual" ]] || test_failure "$message"
  return 0
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" == *"$needle"* ]] || test_failure "$message"
  return 0
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" != *"$needle"* ]] || test_failure "$message"
  return 0
}

assert_success() {
  local message="$1"
  shift
  "$@"
  (( $? == 0 )) || test_failure "$message"
  return 0
}

assert_failure() {
  local message="$1"
  shift
  "$@"
  (( $? != 0 )) || test_failure "$message"
  return 0
}

assert_failure_silent() {
  local message="$1"
  shift
  "$@" >/dev/null 2>&1
  (( $? != 0 )) || test_failure "$message"
  return 0
}

assert_file_exists() {
  local path="$1"
  local message="$2"

  [[ -f "$path" ]] || test_failure "$message"
  return 0
}

assert_file_missing() {
  local path="$1"
  local message="$2"

  [[ ! -e "$path" && ! -L "$path" ]] || test_failure "$message"
  return 0
}

assert_owner_only() {
  local path="$1"
  local message="$2"
  local -a mode=()

  zmodload zsh/stat 2>/dev/null || {
    test_failure "$message (zsh/stat unavailable)"
    return 0
  }
  zstat -L -A mode +mode -- "$path" 2>/dev/null || {
    test_failure "$message (unable to stat)"
    return 0
  }
  (( (mode[1] & 8#77) == 0 )) || test_failure "$message"
  return 0
}

new_test_dir() {
  REPLY="$(command mktemp -d "${TMPDIR:-/tmp}/spaceship-supabase-test.XXXXXXXX")" || return 1
}

remove_test_dir() {
  local path="$1"

  case "$path" in
    "${TMPDIR:-/tmp}"/spaceship-supabase-test.*)
      if [[ -d "$path" ]]; then
        zmodload zsh/files 2>/dev/null || return 1
        zf_rm -r "$path"
      fi
      ;;
    *)
      print -ru2 -- "refusing to remove a non-test directory"
      return 1
      ;;
  esac
  return 0
}

fixture_file() {
  local cli_version="$1"
  local name="$2"

  REPLY="$TEST_FIXTURES_DIR/supabase-cli-v${cli_version}/${name}"
  [[ -f "$REPLY" ]]
}

materialize_project() {
  local root="$1"
  local cli_version="$2"
  local project_ref="${3:-}"
  local local_db_branch="${4:-}"
  local config=""

  fixture_file "$cli_version" config.toml || return 1
  config="$REPLY"
  command mkdir -p "$root/supabase/.temp" || return 1
  command cp "$config" "$root/supabase/config.toml" || return 1
  if [[ -n "$project_ref" ]]; then
    print -r -- "$project_ref" > "$root/supabase/.temp/project-ref" || return 1
  fi
  if [[ -n "$local_db_branch" ]]; then
    command mkdir -p "$root/supabase/.branches" || return 1
    print -r -- "$local_db_branch" > "$root/supabase/.branches/_current_branch" || return 1
  fi
  return 0
}

write_config_remote() {
  local root="$1"
  local remote="$2"
  local project_ref="$3"

  {
    print -r -- 'project_id = "local-workspace-only"'
    print -r -- ''
    print -r -- '[api]'
    print -r -- 'enabled = true'
    print -r -- ''
    print -r -- "[remotes.${remote}]"
    print -r -- "project_id = \"${project_ref}\""
  } > "$root/supabase/config.toml"
}

write_top_level_project_id() {
  local root="$1"
  local project_ref="$2"

  {
    print -r -- "project_id = \"${project_ref}\""
    print -r -- ''
    print -r -- '[api]'
    print -r -- 'enabled = true'
  } > "$root/supabase/config.toml"
}

reset_public_configuration() {
  unset SPACESHIP_SUPABASE_SHOW
  unset SPACESHIP_SUPABASE_ASYNC
  unset SPACESHIP_SUPABASE_COLOR
  unset SPACESHIP_SUPABASE_SYMBOL
  unset SPACESHIP_SUPABASE_PREFIX
  unset SPACESHIP_SUPABASE_SUFFIX
  unset SPACESHIP_SUPABASE_FORMAT
  unset SPACESHIP_SUPABASE_SHOW_LOCAL_DB_BRANCH
  unset SPACESHIP_SUPABASE_CONFIG_REMOTE
  unset SPACESHIP_SUPABASE_USE_LABELS
  unset SPACESHIP_SUPABASE_LABEL_FILE
  unset SPACESHIP_SUPABASE_DEBUG
  unset SUPABASE_WORKDIR
  SPACESHIP_PROMPT_DEFAULT_SUFFIX=' '
}

load_plugin_runtime() {
  source "$TEST_SECTION_FILE" || return 1
  source "$TEST_PLUGIN_FILE" || return 1
}

render_section_to() {
  local output_file="$1"

  : > "$output_file"
  spaceship_supabase > "$output_file"
}

render_prompt_tuple() {
  local tuple="$1"

  REPLY="$(spaceship::section::render "$tuple")"
}

read_file() {
  local path="$1"

  REPLY="$(<"$path")"
}

finish_tests() {
  print -r -- "${TESTS_RUN} test case(s), ${TESTS_FAILED} failure(s)"
  (( TESTS_FAILED == 0 ))
}
