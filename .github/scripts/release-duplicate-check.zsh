#!/usr/bin/env zsh
# Refuse to publish a second GitHub Release for a validated release tag.

emulate -LR zsh
setopt errexit nounset pipefail

typeset script_dir repo_root tag version http_status
script_dir=${0:A:h}
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
cd -- "$repo_root"

fail() {
  print -ru2 -- "release duplicate check: $1"
  exit 1
}

(( $# == 1 )) || fail 'usage: release-duplicate-check.zsh <validated-release-tag>'
tag=$1
version=$(<VERSION)
source "$script_dir/release-contract.zsh"
release_contract_tag_kind "$tag" "$version" || \
  fail 'tag and VERSION must use the same supported release form'

[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail 'GITHUB_REPOSITORY is required'
[[ -n "${GH_TOKEN:-}" ]] || fail 'GH_TOKEN is required'

http_status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  --header "Authorization: Bearer $GH_TOKEN" \
  --header 'X-GitHub-Api-Version: 2022-11-28' \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$tag")" || \
  fail 'could not query the GitHub Release API'

case "$http_status" in
  404) ;;
  200) fail "a GitHub Release for $tag already exists" ;;
  *) fail "unexpected GitHub API status while checking releases: $http_status" ;;
esac

print -r -- "release duplicate check: no GitHub Release exists for $tag"
