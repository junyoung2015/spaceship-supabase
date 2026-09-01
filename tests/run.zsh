#!/usr/bin/env zsh
# Canonical local and CI entrypoint for all maintained first-party tests.

emulate -L zsh
setopt errexit pipefail

typeset script_dir="${${(%):-%N}:A:h}"
typeset repo_root="${script_dir:h}"
typeset zsh_bin="${ZSH_BIN:-zsh}"
typeset run_dir=""
typeset include_performance=false
typeset -a suites

case "${1:-}" in
  '') ;;
  --performance) include_performance=true ;;
  *)
    print -ru2 -- "usage: ZSH_BIN=/path/to/zsh tests/run.zsh [--performance]"
    exit 64
    ;;
esac

if ! command -v "$zsh_bin" >/dev/null 2>&1 && [[ ! -x "$zsh_bin" ]]; then
  print -ru2 -- "ZSH_BIN is not executable: $zsh_bin"
  exit 69
fi

suites=(
  tests/unit/test_configuration.zsh
  tests/integration/test_resolution.zsh
  tests/integration/test_labels_and_doctor.zsh
  tests/integration/test_synced_decorations.zsh
  tests/integration/test_spaceship_registration.zsh
  tests/release/test_glyph_fixture.zsh
  tests/release/test_release_scripts.zsh
  tests/negative/test_fail_closed.zsh
  tests/security/test_untrusted_state.zsh
)
if [[ "$include_performance" == true ]]; then
  suites+=(tests/performance/benchmark.zsh)
fi

run_dir="$(command mktemp -d "${TMPDIR:-/tmp}/spaceship-supabase-run.XXXXXXXX")"
cleanup() {
  if [[ -n "$run_dir" && -d "$run_dir" ]]; then
    zmodload zsh/files 2>/dev/null || return 0
    zf_rm -r "$run_dir"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

typeset failed=0
typeset suite=""
typeset index=0
for suite in "${suites[@]}"; do
  (( ++index ))
  typeset zdotdir="$run_dir/zdotdir-$index"
  command mkdir -p "$zdotdir"
  print -r -- "==> $suite"
  if ! ZDOTDIR="$zdotdir" "$zsh_bin" -f "$repo_root/$suite"; then
    failed=1
  fi
done

if (( failed != 0 )); then
  print -ru2 -- "release test suite failed"
  exit 1
fi

print -r -- "release test suite passed"
