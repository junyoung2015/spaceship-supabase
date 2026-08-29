#!/usr/bin/env zsh
# Documented external-section registration through a real Spaceship v4 runtime.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_LIVE='aaaaaaaaaaaaaaaaaaaa'

test_documented_registration_is_idempotent_and_renders() {
  local tmp='' root='' rendered='' context_line='' prompt_line='' section='' count=0
  local RETVAL=0
  local -i supabase_index=0 line_sep_index=0 char_index=0
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
  # Verify the ordinary Spaceship v4 layout that users get by default: sections
  # before line_sep form the first line, and char forms the second.
  SPACESHIP_PROMPT_SEPARATE_LINE=true
  source "$TEST_PLUGIN_FILE" || {
    remove_test_dir "$tmp"
    return 1
  }

  assert_eq 0 "${SPACESHIP_PROMPT_ORDER[(Ie)supabase]}" 'external section is not implicitly registered by sourcing'

  # This is the exact documented beta.4 installation guard. Evaluate it twice
  # to protect shells that source their configuration more than once.
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
    if (( ${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]} != 0 )); then
      spaceship add --before line_sep supabase
    else
      spaceship add --before char supabase
    fi
  fi
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
    if (( ${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]} != 0 )); then
      spaceship add --before line_sep supabase
    else
      spaceship add --before char supabase
    fi
  fi

  for section in "${SPACESHIP_PROMPT_ORDER[@]}"; do
    [[ "$section" == supabase ]] && (( ++count ))
  done
  assert_eq 1 "$count" 'documented registration creates exactly one section entry'
  supabase_index=${SPACESHIP_PROMPT_ORDER[(Ie)supabase]}
  line_sep_index=${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]}
  char_index=${SPACESHIP_PROMPT_ORDER[(Ie)char]}
  if (( line_sep_index == 0 || char_index == 0 )); then
    test_failure 'vendored Spaceship v4 default order retains line separator and prompt character'
  fi
  if (( supabase_index >= line_sep_index )); then
    test_failure 'documented default registration precedes Spaceship line separator'
  fi
  if (( line_sep_index >= char_index )); then
    test_failure 'Spaceship line separator precedes the prompt character'
  fi

  cd "$root" || return 1
  assert_success 'registered external section refreshes through Spaceship core' spaceship::core::refresh_section --sync supabase
  assert_success 'Spaceship line separator refreshes through Spaceship core' spaceship::core::refresh_section --sync line_sep
  assert_success 'Spaceship prompt character refreshes through Spaceship core' spaceship::core::refresh_section --sync char
  rendered="$(spaceship::core::compose_order "${SPACESHIP_PROMPT_ORDER[@]}")"
  assert_contains "$rendered" '🔷 ' 'real Spaceship v4 composition renders the configured symbol'
  assert_contains "$rendered" "$REF_LIVE" 'real Spaceship v4 composition renders the full linked ref'
  context_line=${rendered%%$'\n'*}
  assert_contains "$context_line" "$REF_LIVE" 'default registration keeps the full ref before the rendered line separator'
  prompt_line=${rendered#*$'\n'}
  assert_contains "$prompt_line" '➜' 'default registration keeps the prompt character after the rendered line separator'
  assert_not_contains "$prompt_line" "$REF_LIVE" 'default registration does not move the full ref onto the prompt-character line'

  # Prompt-line placement remains an explicit user choice. It must be after the
  # separator and before char, without changing the renderer itself.
  SPACESHIP_PROMPT_ORDER=("${(@)SPACESHIP_PROMPT_ORDER:#supabase}")
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
    spaceship add --before char supabase
  fi
  supabase_index=${SPACESHIP_PROMPT_ORDER[(Ie)supabase]}
  line_sep_index=${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]}
  char_index=${SPACESHIP_PROMPT_ORDER[(Ie)char]}
  if (( supabase_index <= line_sep_index || supabase_index >= char_index )); then
    test_failure 'explicit prompt-line registration places the section after line separator and before char'
  fi

  # A custom prompt may omit line_sep. The documented default must retain the
  # char fallback instead of failing or adding a duplicate section.
  SPACESHIP_PROMPT_ORDER=("${(@)SPACESHIP_PROMPT_ORDER:#supabase}")
  SPACESHIP_PROMPT_ORDER=("${(@)SPACESHIP_PROMPT_ORDER:#line_sep}")
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
    if (( ${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]} != 0 )); then
      spaceship add --before line_sep supabase
    else
      spaceship add --before char supabase
    fi
  fi
  if (( ${SPACESHIP_PROMPT_ORDER[(Ie)supabase]} == 0 )); then
    if (( ${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]} != 0 )); then
      spaceship add --before line_sep supabase
    else
      spaceship add --before char supabase
    fi
  fi
  supabase_index=${SPACESHIP_PROMPT_ORDER[(Ie)supabase]}
  char_index=${SPACESHIP_PROMPT_ORDER[(Ie)char]}
  assert_eq 0 "${SPACESHIP_PROMPT_ORDER[(Ie)line_sep]}" 'line-separator fallback test removes separator from prompt order'
  if (( supabase_index == 0 || supabase_index >= char_index )); then
    test_failure 'documented default falls back to registration before the prompt character'
  fi

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_case 'documented Spaceship registration is idempotent and renders' test_documented_registration_is_idempotent_and_renders
finish_tests
