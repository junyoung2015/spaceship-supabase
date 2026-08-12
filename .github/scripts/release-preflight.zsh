#!/usr/bin/env zsh
# Validate an annotated release tag and optionally write its curated notes.

emulate -LR zsh
setopt errexit nounset pipefail

typeset script_dir repo_root tag version release_kind tag_object tag_type commit notes
script_dir=${0:A:h}
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
cd -- "$repo_root"
source "$script_dir/release-contract.zsh"

fail() {
  print -u2 -r -- "release preflight: $1"
  exit 1
}

(( $# == 1 )) || fail 'usage: release-preflight.zsh <annotated-vX.Y.Z-or-vX.Y.Z-beta.N-tag>'
tag=$1

# A release preflight always operates on the publishable tree. Keep this
# invariant inside the script so every caller, including the final publish
# recheck, rejects private-only paths without relying on workflow-local env.
SPACESHIP_SUPABASE_REQUIRE_PUBLIC_TREE=true \
  zsh -f "$repo_root/.github/scripts/metadata-check.zsh"

version=$(<VERSION)
release_contract_tag_kind "$tag" "$version" || \
  fail "tag $tag and VERSION $version must use the same supported release form"
release_kind="$REPLY"

git rev-parse --verify --quiet "refs/tags/$tag" >/dev/null || fail "tag $tag does not exist"
tag_object=$(git rev-parse "refs/tags/$tag")
tag_type=$(git cat-file -t "$tag_object")
[[ "$tag_type" == tag ]] || fail "tag $tag must be annotated"
commit=$(git rev-parse "$tag^{commit}") || fail "tag $tag does not resolve to a commit"

# actions/checkout with fetch-depth: 0 already supplies origin/main. Reuse that
# authenticated checkout state: persisted credentials are intentionally disabled
# for this release gate, so an unnecessary second fetch fails for private repos.
if ! git show-ref --verify --quiet refs/remotes/origin/main; then
  git fetch --no-tags origin +refs/heads/main:refs/remotes/origin/main >/dev/null 2>&1 || fail 'could not fetch origin/main'
fi
git merge-base --is-ancestor "$commit" origin/main || fail "tag $tag is not reachable from main"

notes=$(awk -v heading="## [$version]" -v dated_heading_prefix="## [$version] - " '
  # VERSION is already validated, but use literal string comparison rather
  # than interpolating it into a regular expression. This keeps the selected
  # changelog section exact even when a nearby heading resembles it.
  $0 == heading { found = 1; next }
  index($0, dated_heading_prefix) == 1 {
    date = substr($0, length(dated_heading_prefix) + 1)
    if (date ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
      found = 1
      next
    }
  }
  found && /^## / { exit }
  found { print }
  END { if (!found) exit 2 }
' CHANGELOG.md) || fail "could not extract the $version changelog section"
[[ -n "${notes//[[:space:]]/}" ]] || fail "the $version changelog section is empty"

if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
  : > "$RELEASE_NOTES_FILE" || fail 'could not create the release-notes file'
  print -r -- "$notes" > "$RELEASE_NOTES_FILE" || fail 'could not write the release-notes file'
fi

print -r -- "release preflight: $tag ($release_kind) is annotated, reaches main, matches VERSION, and has curated notes"
