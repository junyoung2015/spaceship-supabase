#!/usr/bin/env zsh
# Define the constrained stable and beta release identifier contract.

emulate -L zsh
setopt errexit nounset pipefail

# Set REPLY to either "stable" or "prerelease" when VERSION is an accepted
# unprefixed SemVer release version. Numeric core identifiers are either 0 or
# a non-zero digit followed by digits, so a leading zero is never accepted.
# The beta form is intentionally narrow: N is a positive canonical decimal
# integer, so beta.0 and beta.01 are not releases.
release_contract_version_kind() {
  emulate -L zsh

  (( $# == 1 )) || return 64

  if [[ "$1" =~ ^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$ ]]; then
    REPLY=stable
    return 0
  fi

  if [[ "$1" =~ ^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)-beta[.][1-9][0-9]*$ ]]; then
    REPLY=prerelease
    return 0
  fi

  return 1
}

# Set REPLY to the release kind only when TAG is the exact annotated-tag name
# expected for VERSION. Annotation itself is deliberately checked by the
# release preflight because it is Git state, not identifier syntax.
release_contract_tag_kind() {
  emulate -L zsh

  (( $# == 2 )) || return 64

  local tag="$1"
  local version="$2"
  local kind=""

  release_contract_version_kind "$version" || return 1
  kind="$REPLY"
  [[ "$tag" == "v$version" ]] || return 1

  REPLY="$kind"
  return 0
}
