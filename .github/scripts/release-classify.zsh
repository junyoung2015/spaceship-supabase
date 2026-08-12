#!/usr/bin/env zsh
# Print the release kind for an exact tag/VERSION pair.

emulate -LR zsh
setopt errexit nounset pipefail

typeset script_dir
script_dir=${0:A:h}
source "$script_dir/release-contract.zsh"

(( $# == 2 )) || {
  print -ru2 -- 'usage: release-classify.zsh <vX.Y.Z|vX.Y.Z-beta.N> <X.Y.Z|X.Y.Z-beta.N>'
  exit 64
}

release_contract_tag_kind "$1" "$2" || {
  print -ru2 -- 'release classify: tag and VERSION must use the same supported release form'
  exit 1
}

print -r -- "$REPLY"
