#!/usr/bin/env zsh
# Direct live-render benchmark. This is intentionally not a cache benchmark.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset REF_LIVE='aaaaaaaaaaaaaaaaaaaa'
typeset -ga TEST_SORTED=()

sort_numbers() {
  local index=0 cursor=0 key=0

  TEST_SORTED=("$@")

  for (( index = 2; index <= ${#TEST_SORTED[@]}; index++ )); do
    key="${TEST_SORTED[index]}"
    cursor=$(( index - 1 ))
    while (( cursor >= 1 )); do
      (( ${TEST_SORTED[$cursor]} > key )) || break
      TEST_SORTED[$(( cursor + 1 ))]="${TEST_SORTED[$cursor]}"
      (( cursor-- ))
    done
    TEST_SORTED[$(( cursor + 1 ))]="$key"
  done
}

test_direct_live_render_budget() {
  local tmp='' root='' batch=0 iteration=0 p99_index=99
  local -a batch_p99=() timings=() sorted_p99=()
  local -F 6 started=0 finished=0 elapsed=0 median=0 maximum=0
  new_test_dir || return 1
  tmp="$REPLY"
  root="$tmp/project"
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
  zmodload zsh/datetime 2>/dev/null || {
    test_failure 'zsh/datetime is required for benchmark timing'
    remove_test_dir "$tmp"
    return 0
  }
  cd "$root" || return 1

  # Warm the module and filesystem path without establishing a value cache.
  spaceship_supabase >/dev/null
  for (( batch = 1; batch <= 5; batch++ )); do
    timings=()
    for (( iteration = 1; iteration <= 100; iteration++ )); do
      started="$EPOCHREALTIME"
      spaceship_supabase >/dev/null
      finished="$EPOCHREALTIME"
      elapsed=$(( (finished - started) * 1000.0 ))
      timings+=("$elapsed")
    done
    sort_numbers "${timings[@]}"
    timings=("${TEST_SORTED[@]}")
    batch_p99+=("${timings[p99_index]}")
    printf 'batch=%d p99_ms=%.3f\n' "$batch" "${timings[p99_index]}"
  done

  sort_numbers "${batch_p99[@]}"
  sorted_p99=("${TEST_SORTED[@]}")
  median="${sorted_p99[3]}"
  maximum="${sorted_p99[5]}"
  printf 'median_p99_ms=%.3f max_p99_ms=%.3f\n' "$median" "$maximum"

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" && -w "$GITHUB_STEP_SUMMARY" ]]; then
    {
      print -r -- '### spaceship-supabase benchmark'
      print -r -- ''
      print -r -- '| Batch | P99 (ms) |'
      print -r -- '| ---: | ---: |'
      for (( batch = 1; batch <= 5; batch++ )); do
        printf '| %d | %.3f |\n' "$batch" "${batch_p99[batch]}"
      done
      printf '| **median** | **%.3f** |\n' "$median"
      printf '| **maximum** | **%.3f** |\n' "$maximum"
    } >> "$GITHUB_STEP_SUMMARY"
  fi

  if [[ "$(command uname -s)" == Linux ]]; then
    (( median < 5.0 )) || test_failure 'Ubuntu median P99 must remain below 5 ms'
    (( maximum < 15.0 )) || test_failure 'Ubuntu maximum P99 must remain below 15 ms'
  else
    test_note 'benchmark thresholds are enforced on Ubuntu; macOS samples are reported only'
  fi

  cd "$TEST_REPO_ROOT" || return 1
  remove_test_dir "$tmp"
  return 0
}

test_case 'five independent direct live-render batches meet the release budget' test_direct_live_render_budget
finish_tests
