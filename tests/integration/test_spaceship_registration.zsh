#!/usr/bin/env zsh
# Documented external-section registration through a real Spaceship v4 runtime.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_LIVE='aaaaaaaaaaaaaaaaaaaa'

test_documented_registration_is_idempotent_and_renders() {
  local tmp='' root='' rendered='' section='' count=0
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"

  # Isolate the full vendor runtime from user configuration and prevent its
  # optional ZWC optimization from writing into the tracked vendor snapshot.
  HOME="$tmp/home"
  XDG_CONFIG_HOME="$tmp/config"
  XDG_CONFIG_DIRS="$tmp/config-dirs"
  SPACESHIP_CONFIG="$tmp/missing-spaceship.zsh"
  unset SPACESHIP_ROOT SPACESHIP_CONFIG_PATH SPACESHIP_PROMPT_ORDER SPACESHIP_RPROMPT_ORDER
  SPACESHIP_PROMPT_ASYNC=false
  zcompile() { return 0; }

  materialize_project "$root" 2.113.0 "$REF_LIVE" || {
    remove_test_dir "$tmp"
    return 1
  }

  source "$TEST_REPO_ROOT/tests/vendor/spaceship/spaceship.zsh" || {
    remove_test_dir "$tmp"
    return 1
  }
  reset_public_configuration
  source "$TEST_PLUGIN_FILE" || {
    remove_test_dir "$tmp"
    return 1
  }

  assert_eq 0 "${SPACESHIP_PROMPT_ORDER[(Ie)supabase]}" 'external section is not implicitly registered by sourcing'

  # This is the exact documented installation guard. Evaluate it twice to
  # protect shells that source their configuration more than once.
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
    spaceship add --before char supabase
  fi
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
    spaceship add --before char supabase
  fi

  for section in "${SPACESHIP_PROMPT_ORDER[@]}"; do
    [[ "$section" == supabase ]] && (( ++count ))
  done
  assert_eq 1 "$count" 'documented registration creates exactly one section entry'
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} >= ${SPACESHIP_PROMPT_ORDER[(Ie)char]} )); then
    test_failure 'registered section precedes the Spaceship prompt character'
  fi

  cd "$root" || return 1
  assert_success 'registered external section refreshes through Spaceship core' spaceship::core::refresh_section --sync supabase
  rendered="$(spaceship::core::compose_order "${SPACESHIP_PROMPT_ORDER[@]}")"
  assert_contains "$rendered" '🔷 ' 'real Spaceship v4 composition renders the configured symbol'
  assert_contains "$rendered" "$REF_LIVE" 'real Spaceship v4 composition renders the full linked ref'

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_case 'documented Spaceship registration is idempotent and renders' test_documented_registration_is_idempotent_and_renders
finish_tests
