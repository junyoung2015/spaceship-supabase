#!/usr/bin/env zsh
# Create a stable GitHub Release or a constrained beta prerelease safely.

emulate -LR zsh
setopt errexit nounset pipefail

typeset script_dir repo_root tag version release_kind
script_dir=${0:A:h}
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
cd -- "$repo_root"

fail() {
  print -ru2 -- "release create: $1"
  exit 1
}

(( $# == 1 )) || fail 'usage: release-create.zsh <validated-release-tag>'
tag=$1
version=$(<VERSION)
source "$script_dir/release-contract.zsh"
release_contract_tag_kind "$tag" "$version" || \
  fail 'tag and VERSION must use the same supported release form'
release_kind="$REPLY"

[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail 'GITHUB_REPOSITORY is required'
[[ -n "${RELEASE_NOTES_FILE:-}" ]] || fail 'RELEASE_NOTES_FILE is required'
[[ -f "$RELEASE_NOTES_FILE" ]] || fail 'RELEASE_NOTES_FILE does not name a readable file'

typeset -a gh_args
gh_args=(
  release create "$tag"
  --repo "$GITHUB_REPOSITORY"
  --verify-tag
  --title "$tag"
  --notes-file "$RELEASE_NOTES_FILE"
)
if [[ "$release_kind" == prerelease ]]; then
  gh_args+=(--prerelease)
fi

# The dry-run contract is deliberately local-only. It exists solely for tests
# and release engineering review; the workflow never sets it.
if [[ "${SPACESHIP_SUPABASE_RELEASE_DRY_RUN:-false}" == true ]]; then
  print -r -- "release create dry-run: $release_kind"
  print -rl -- "${gh_args[@]}"
  exit 0
fi

exec gh "${gh_args[@]}"
