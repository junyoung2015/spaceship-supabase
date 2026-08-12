#!/usr/bin/env zsh
# Validate the release metadata and the public documentation contract.

emulate -LR zsh
setopt errexit nounset pipefail

typeset script_dir repo_root version release_kind doc line release_heading release_date
script_dir=${0:A:h}
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
cd -- "$repo_root"
source "$script_dir/release-contract.zsh"

fail() {
  print -u2 -r -- "metadata: $1"
  exit 1
}

require_file() {
  [[ -s "$1" ]] || fail "required file is missing or empty: $1"
}

for doc in \
  README.md LICENSE VERSION CHANGELOG.md SECURITY.md SUPPORT.md CONTRIBUTING.md AGENTS.md \
  docs/configuration.md docs/data-sources.md docs/labels.md docs/troubleshooting.md \
  docs/compatibility.md docs/testing.md docs/roadmap.md \
  docs/design/v0.2-target-context-contract.md \
  docs/research/supabase-cli-project-names.md docs/releases/v0.1.0-release-plan.md; do
  require_file "$doc"
done

version=$(<VERSION)
release_contract_version_kind "$version" || \
  fail 'VERSION must contain X.Y.Z or the constrained prerelease form X.Y.Z-beta.N'
release_kind="$REPLY"
[[ "$(wc -l < VERSION)" -eq 1 ]] || fail 'VERSION must be exactly one line'
grep -Fq 'Keep a Changelog' CHANGELOG.md || fail 'CHANGELOG.md must use the Keep a Changelog format'
grep -qxF '## [Unreleased]' CHANGELOG.md || fail 'CHANGELOG.md must retain an exact ## [Unreleased] heading'

# Private development keeps the section undated. The clean public release cut
# may add one ISO calendar date in its single release commit. Both forms use
# the same section identity and are extracted by the release workflow.
typeset -a release_headings
while IFS= read -r line; do
  if [[ "$line" == "## [$version]" || "$line" == "## [$version] - "* ]]; then
    release_headings+=("$line")
  fi
done < CHANGELOG.md

(( ${#release_headings} == 1 )) || fail "CHANGELOG.md must contain exactly one ## [$version] release heading"
release_heading=${release_headings[1]}
if [[ "$release_heading" != "## [$version]" ]]; then
  release_date=${release_heading#"## [$version] - "}
  [[ "$release_date" =~ ^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$ ]] || \
    fail "the $version changelog date must use YYYY-MM-DD"

  integer year=$(( 10#${release_date[1,4]} ))
  integer month=$(( 10#${release_date[6,7]} ))
  integer day=$(( 10#${release_date[9,10]} ))
  integer max_day
  (( year >= 1 && month >= 1 && month <= 12 )) || fail "the $version changelog date is not a valid ISO calendar date"
  case "$month" in
    1|3|5|7|8|10|12) max_day=31 ;;
    4|6|9|11) max_day=30 ;;
    2)
      if (( (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 )); then
        max_day=29
      else
        max_day=28
      fi
      ;;
  esac
  (( day >= 1 && day <= max_day )) || fail "the $version changelog date is not a valid ISO calendar date"
fi

for doc in \
  docs/configuration.md docs/data-sources.md docs/labels.md docs/troubleshooting.md \
  docs/compatibility.md docs/testing.md docs/roadmap.md \
  docs/design/v0.2-target-context-contract.md \
  docs/research/supabase-cli-project-names.md docs/releases/v0.1.0-release-plan.md; do
  if ! grep -Fq "$doc" README.md; then
    fail "README.md must link to $doc"
  fi
done

zsh -f "$repo_root/.github/scripts/public-tree-audit.zsh"

print -r -- "metadata: $release_kind VERSION $version and public documentation contract are valid"
