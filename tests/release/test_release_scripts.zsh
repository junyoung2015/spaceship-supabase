#!/usr/bin/env zsh
# Deterministic release-script coverage for stable and constrained beta tags.

emulate -L zsh
setopt extendedglob

typeset script_dir="${${(%):-%N}:A:h}"
source "$script_dir/../helpers/testlib.zsh"

typeset -g RELEASE_TEST_ZSH="${ZSH_BIN:-zsh}"
typeset -g RELEASE_CLASSIFY="$TEST_REPO_ROOT/.github/scripts/release-classify.zsh"
typeset -g RELEASE_CREATE="$TEST_REPO_ROOT/.github/scripts/release-create.zsh"

release_contract_kind() {
  "$RELEASE_TEST_ZSH" -f "$RELEASE_CLASSIFY" "$1" "$2"
}

prepare_release_candidate() {
  local parent="$1"
  local source_repo="${2:-$TEST_REPO_ROOT}"
  local candidate="$parent/repo"

  # Test candidates create their own annotated tags. Never inherit an already
  # published tag from the checkout that supplied the source tree.
  command git clone --quiet --no-hardlinks --local --no-tags "$source_repo" "$candidate" || return 1
  command git -C "$candidate" config user.name 'Release script test' || return 1
  command git -C "$candidate" config user.email 'release-script-test@example.invalid' || return 1
  # GitHub Actions checks out PRs at a shallow detached commit, so a local
  # clone has no origin/main ref. Materialize the test-only remote-tracking
  # anchor from that exact candidate commit before testing main ancestry.
  command git -C "$candidate" switch --quiet -C main HEAD || return 1
  command git -C "$candidate" update-ref refs/remotes/origin/main HEAD || return 1

  local script=''
  for script in \
    release-contract.zsh release-classify.zsh release-duplicate-check.zsh release-create.zsh \
    release-preflight.zsh metadata-check.zsh; do
    command cp "$TEST_REPO_ROOT/.github/scripts/$script" \
      "$candidate/.github/scripts/$script" || return 1
  done

  REPLY="$candidate"
  return 0
}

prepare_tagged_release_source() {
  local parent="$1"
  local source="$parent/source"

  # Start without source tags so this fixture remains reproducible after the
  # real beta.1 and beta.2 tags exist in the checkout running the suite.
  command git clone --quiet --no-hardlinks --local --no-tags "$TEST_REPO_ROOT" "$source" || return 1
  command git -C "$source" config user.name 'Release source fixture' || return 1
  command git -C "$source" config user.email 'release-source-fixture@example.invalid' || return 1
  command git -C "$source" tag -a 'v0.2.0-beta.1' -m 'Existing annotated release fixture' || return 1
  command git -C "$source" tag -a 'v0.2.0-beta.2' -m 'Existing annotated release fixture' || return 1

  REPLY="$source"
  return 0
}

append_changelog_section() {
  local candidate="$1"
  local heading="$2"
  local marker="$3"

  {
    print -r -- ''
    print -r -- "$heading"
    print -r -- ''
    print -r -- '### Added'
    print -r -- ''
    print -r -- "- $marker"
  } >> "$candidate/CHANGELOG.md" || return 1
}

commit_release_candidate() {
  local candidate="$1"
  local version="$2"
  local changelog_mode="$3"

  print -r -- "$version" > "$candidate/VERSION" || return 1
  if [[ "$changelog_mode" == present ]]; then
    append_changelog_section "$candidate" "## [$version]" \
      'Deterministic beta release-script fixture.' || return 1
  fi

  command git -C "$candidate" add \
    VERSION CHANGELOG.md .github/scripts/release-contract.zsh \
    .github/scripts/release-classify.zsh .github/scripts/release-duplicate-check.zsh .github/scripts/release-create.zsh \
    .github/scripts/release-preflight.zsh .github/scripts/metadata-check.zsh || return 1
  command git -C "$candidate" commit --quiet -m "test: prepare $version release candidate" || return 1
  return 0
}

prepare_exact_prerelease_candidate() {
  local candidate="$1"
  local version="$2"
  local line=''
  local heading="## [$version]"
  local heading_count=0

  # A source checkout may be either the committed beta.3 candidate (CI) or the
  # preceding beta.2 tree while this metadata change is still uncommitted
  # locally. Materialize exactly one beta.3 section in the latter case, but
  # never append a duplicate section in the former.
  [[ -r "$candidate/CHANGELOG.md" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$heading" ]] && (( heading_count += 1 ))
  done < "$candidate/CHANGELOG.md"
  (( heading_count <= 1 )) || return 1

  print -r -- "$version" > "$candidate/VERSION" || return 1
  if (( heading_count == 0 )); then
    append_changelog_section "$candidate" "$heading" \
      'Deterministic beta.3 release-script fixture.' || return 1
  fi

  command git -C "$candidate" add VERSION CHANGELOG.md || return 1
  if ! command git -C "$candidate" diff --cached --quiet; then
    command git -C "$candidate" commit --quiet -m "test: prepare $version release candidate" || return 1
  fi
  return 0
}

mark_candidate_as_main() {
  command git -C "$1" update-ref refs/remotes/origin/main HEAD
}

create_annotated_tag() {
  command git -C "$1" tag -a "$2" -m "Release $2"
}

cleanup_release_test_dir() {
  # Local test clones preserve Git's read-only object modes. Make the synthetic
  # tree owner-writable before the shared safe test cleanup removes it.
  command chmod -R u+w "$1" 2>/dev/null || return 1
  remove_test_dir "$1"
}

run_preflight() {
  local candidate="$1"
  local tag="$2"
  local notes_file="$3"

  RELEASE_NOTES_FILE="$notes_file" \
    "$RELEASE_TEST_ZSH" -f "$candidate/.github/scripts/release-preflight.zsh" "$tag"
}

run_duplicate_check() {
  local candidate="$1"
  local tag="$2"
  local curl_status="$3"
  local stub_dir="$4"

  PATH="$stub_dir:$PATH" \
    GITHUB_REPOSITORY='example/spaceship-supabase' \
    GH_TOKEN='test-token' \
    FAKE_CURL_STATUS="$curl_status" \
    "$RELEASE_TEST_ZSH" -f "$candidate/.github/scripts/release-duplicate-check.zsh" "$tag"
}

run_release_create_dry() {
  local candidate="$1"
  local tag="$2"
  local notes_file="$3"

  GITHUB_REPOSITORY='example/spaceship-supabase' \
    RELEASE_NOTES_FILE="$notes_file" \
    SPACESHIP_SUPABASE_RELEASE_DRY_RUN=true \
    "$RELEASE_TEST_ZSH" -f "$candidate/.github/scripts/release-create.zsh" "$tag"
}

test_stable_and_beta_contract_forms_are_exact() {
  local actual=''

  actual="$(release_contract_kind v0.1.1 0.1.1)" || test_failure 'stable release contract accepts v0.1.1'
  assert_eq stable "$actual" 'stable release kind remains stable'
  actual="$(release_contract_kind v0.2.0-beta.3 0.2.0-beta.3)" || test_failure 'beta release contract accepts beta.3'
  assert_eq prerelease "$actual" 'valid beta is classified as a prerelease'

  assert_failure_silent 'beta.0 is not a positive beta number' \
    release_contract_kind v0.2.0-beta.0 0.2.0-beta.0
  assert_failure_silent 'leading-zero beta number is rejected' \
    release_contract_kind v0.2.0-beta.01 0.2.0-beta.01
  assert_failure_silent 'other prerelease channels are rejected' \
    release_contract_kind v0.2.0-rc.1 0.2.0-rc.1
  assert_failure_silent 'tag and VERSION must be identical' \
    release_contract_kind v0.2.0-beta.1 0.2.0-beta.2
  assert_failure_silent 'stable major identifier cannot have a leading zero' \
    release_contract_kind v00.2.3 00.2.3
  assert_failure_silent 'stable minor identifier cannot have a leading zero' \
    release_contract_kind v0.02.3 0.02.3
  assert_failure_silent 'stable patch identifier cannot have a leading zero' \
    release_contract_kind v0.2.03 0.2.03
  assert_failure_silent 'beta major identifier cannot have a leading zero' \
    release_contract_kind v00.2.3-beta.1 00.2.3-beta.1
  assert_failure_silent 'beta minor identifier cannot have a leading zero' \
    release_contract_kind v0.02.3-beta.1 0.02.3-beta.1
  assert_failure_silent 'beta patch identifier cannot have a leading zero' \
    release_contract_kind v0.2.03-beta.1 0.2.03-beta.1

  return 0
}

test_synthetic_candidates_isolate_existing_release_tags() {
  local tmp='' source='' candidate='' tag_type=''
  new_test_dir || return 1
  tmp="$REPLY"
  prepare_tagged_release_source "$tmp" || return 1
  source="$REPLY"

  tag_type="$(command git -C "$source" cat-file -t refs/tags/v0.2.0-beta.1)" || \
    test_failure 'source fixture creates an annotated beta.1 tag'
  assert_eq tag "$tag_type" 'source fixture beta.1 tag is annotated'
  tag_type="$(command git -C "$source" cat-file -t refs/tags/v0.2.0-beta.2)" || \
    test_failure 'source fixture creates an annotated beta.2 tag'
  assert_eq tag "$tag_type" 'source fixture beta.2 tag is annotated'

  prepare_release_candidate "$tmp" "$source" || return 1
  candidate="$REPLY"
  assert_failure_silent 'candidate does not inherit the source beta.1 tag' \
    command git -C "$candidate" show-ref --verify --quiet refs/tags/v0.2.0-beta.1
  assert_failure_silent 'candidate does not inherit the source beta.2 tag' \
    command git -C "$candidate" show-ref --verify --quiet refs/tags/v0.2.0-beta.2
  assert_failure_silent 'candidate does not inherit a beta.3 tag' \
    command git -C "$candidate" show-ref --verify --quiet refs/tags/v0.2.0-beta.3
  assert_success 'candidate can create its own annotated beta.3 tag' \
    create_annotated_tag "$candidate" 'v0.2.0-beta.3'
  tag_type="$(command git -C "$candidate" cat-file -t refs/tags/v0.2.0-beta.3)" || \
    test_failure 'candidate beta.3 tag is readable after isolated creation'
  assert_eq tag "$tag_type" 'candidate beta.3 tag remains annotated'

  cleanup_release_test_dir "$tmp"
  return 0
}

test_valid_stable_preflight_and_dry_run() {
  local tmp='' candidate='' notes_file='' output=''
  new_test_dir || return 1
  tmp="$REPLY"
  prepare_release_candidate "$tmp" || return 1
  candidate="$REPLY"
  commit_release_candidate "$candidate" '0.2.1' present || return 1
  mark_candidate_as_main "$candidate" || return 1
  create_annotated_tag "$candidate" 'v0.2.1' || return 1
  notes_file="$tmp/notes.md"

  assert_success 'valid stable tag retains the complete local preflight' \
    run_preflight "$candidate" 'v0.2.1' "$notes_file"
  assert_file_exists "$notes_file" 'preflight writes curated stable notes'

  output="$(run_release_create_dry "$candidate" 'v0.2.1' "$notes_file")" || \
    test_failure 'stable release dry-run succeeds after preflight'
  assert_contains "$output" 'release create dry-run: stable' \
    'stable release dry-run remains on the stable channel'
  assert_not_contains "$output" '--prerelease' \
    'stable release dry-run never adds --prerelease'

  cleanup_release_test_dir "$tmp"
  return 0
}

test_valid_prerelease_preflight_and_dry_run() {
  local tmp='' candidate='' notes_file='' output=''
  new_test_dir || return 1
  tmp="$REPLY"
  prepare_release_candidate "$tmp" || return 1
  candidate="$REPLY"
  # The checked-out candidate may itself be beta.3. Use another valid beta
  # identifier here so this synthetic fixture owns exactly one matching section.
  commit_release_candidate "$candidate" '0.2.0-beta.7' present || return 1
  mark_candidate_as_main "$candidate" || return 1
  create_annotated_tag "$candidate" 'v0.2.0-beta.7' || return 1
  notes_file="$tmp/notes.md"

  assert_success 'valid beta tag passes the complete local preflight' \
    run_preflight "$candidate" 'v0.2.0-beta.7' "$notes_file"
  assert_file_exists "$notes_file" 'preflight writes curated beta notes'
  read_file "$notes_file"
  assert_contains "$REPLY" 'Deterministic beta release-script fixture.' \
    'preflight extracts the exact beta changelog section'

  output="$(run_release_create_dry "$candidate" 'v0.2.0-beta.7' "$notes_file")" || \
    test_failure 'beta release dry-run succeeds after preflight'
  assert_contains "$output" 'release create dry-run: prerelease' \
    'beta release dry-run selects the prerelease channel'
  assert_contains "$output" '--prerelease' \
    'beta release dry-run passes --prerelease to gh release create'
  assert_contains "$output" "$notes_file" \
    'beta release dry-run receives the preflight-generated notes file'
  assert_contains "$output" 'release' \
    'beta release dry-run reaches the gh release create command shape'

  cleanup_release_test_dir "$tmp"
  return 0
}

test_preflight_extracts_only_the_exact_beta_section() {
  local tmp='' candidate='' notes_file=''
  new_test_dir || return 1
  tmp="$REPLY"
  prepare_release_candidate "$tmp" || return 1
  candidate="$REPLY"
  append_changelog_section "$candidate" '## [0x2x0-betaZ6] - 2026-01-01' \
    'Deceptive near-match changelog fixture.' || return 1
  commit_release_candidate "$candidate" '0.2.0-beta.6' present || return 1
  mark_candidate_as_main "$candidate" || return 1
  create_annotated_tag "$candidate" 'v0.2.0-beta.6' || return 1
  notes_file="$tmp/notes.md"

  assert_success 'preflight ignores a regex-like near-match beta heading' \
    run_preflight "$candidate" 'v0.2.0-beta.6' "$notes_file"
  read_file "$notes_file"
  assert_contains "$REPLY" 'Deterministic beta release-script fixture.' \
    'preflight keeps the real beta changelog section'
  assert_not_contains "$REPLY" 'Deceptive near-match changelog fixture.' \
    'preflight never selects a near-match beta changelog section'

  cleanup_release_test_dir "$tmp"
  return 0
}

test_release_preflight_rejects_tag_and_history_failures() {
  local tmp='' candidate='' notes_file=''

  new_test_dir || return 1
  tmp="$REPLY"
  prepare_release_candidate "$tmp" || return 1
  candidate="$REPLY"
  # beta.3 is the checked-in candidate, so use a different valid identifier to
  # isolate this tag/VERSION mismatch fixture from its exact changelog section.
  commit_release_candidate "$candidate" '0.2.0-beta.8' present || return 1
  mark_candidate_as_main "$candidate" || return 1
  create_annotated_tag "$candidate" 'v0.2.0-beta.3' || return 1
  notes_file="$tmp/mismatch-notes.md"
  assert_failure_silent 'mismatched beta tag and VERSION fail preflight' \
    run_preflight "$candidate" 'v0.2.0-beta.3' "$notes_file"
  cleanup_release_test_dir "$tmp"

  new_test_dir || return 1
  tmp="$REPLY"
  prepare_release_candidate "$tmp" || return 1
  candidate="$REPLY"
  commit_release_candidate "$candidate" '0.2.0-beta.3' present || return 1
  mark_candidate_as_main "$candidate" || return 1
  command git -C "$candidate" tag 'v0.2.0-beta.3' || return 1
  notes_file="$tmp/lightweight-notes.md"
  assert_failure_silent 'lightweight beta tag fails annotated-tag preflight' \
    run_preflight "$candidate" 'v0.2.0-beta.3' "$notes_file"
  cleanup_release_test_dir "$tmp"

  new_test_dir || return 1
  tmp="$REPLY"
  prepare_release_candidate "$tmp" || return 1
  candidate="$REPLY"
  commit_release_candidate "$candidate" '0.2.0-beta.4' present || return 1
  create_annotated_tag "$candidate" 'v0.2.0-beta.4' || return 1
  notes_file="$tmp/non-main-notes.md"
  assert_failure_silent 'beta tag outside origin/main fails ancestry preflight' \
    run_preflight "$candidate" 'v0.2.0-beta.4' "$notes_file"
  cleanup_release_test_dir "$tmp"

  new_test_dir || return 1
  tmp="$REPLY"
  prepare_release_candidate "$tmp" || return 1
  candidate="$REPLY"
  commit_release_candidate "$candidate" '0.2.0-beta.5' absent || return 1
  mark_candidate_as_main "$candidate" || return 1
  create_annotated_tag "$candidate" 'v0.2.0-beta.5' || return 1
  notes_file="$tmp/missing-changelog-notes.md"
  assert_failure_silent 'missing beta changelog section fails preflight' \
    run_preflight "$candidate" 'v0.2.0-beta.5' "$notes_file"
  cleanup_release_test_dir "$tmp"
  return 0
}

test_duplicate_refusal_and_beta_dry_run() {
  local tmp='' source='' candidate='' notes_file='' output='' stub_dir=''
  new_test_dir || return 1
  tmp="$REPLY"
  prepare_tagged_release_source "$tmp" || return 1
  source="$REPLY"
  prepare_release_candidate "$tmp" "$source" || return 1
  candidate="$REPLY"
  assert_failure_silent 'beta.3 candidate does not inherit the source beta.1 tag' \
    command git -C "$candidate" show-ref --verify --quiet refs/tags/v0.2.0-beta.1
  assert_failure_silent 'beta.3 candidate does not inherit the source beta.2 tag' \
    command git -C "$candidate" show-ref --verify --quiet refs/tags/v0.2.0-beta.2
  assert_failure_silent 'beta.3 candidate does not inherit its own tag' \
    command git -C "$candidate" show-ref --verify --quiet refs/tags/v0.2.0-beta.3
  # Use an exact beta.3 candidate. This is idempotent for a checked-in beta.3
  # source and materializes that one section for an uncommitted local run.
  prepare_exact_prerelease_candidate "$candidate" '0.2.0-beta.3' || return 1
  read_file "$candidate/VERSION"
  assert_eq '0.2.0-beta.3' "$REPLY" 'candidate VERSION is exactly beta.3'
  # The candidate owns its tag even when its source fixture models an existing
  # immutable annotated beta.1 and beta.2 tags.
  mark_candidate_as_main "$candidate" || return 1
  create_annotated_tag "$candidate" 'v0.2.0-beta.3' || return 1
  notes_file="$tmp/notes.md"
  assert_success 'beta.3 preflight writes its candidate release notes' \
    run_preflight "$candidate" 'v0.2.0-beta.3' "$notes_file"
  assert_file_exists "$notes_file" 'beta.3 preflight notes are readable by release creation'
  read_file "$notes_file"
  assert_nonempty "$REPLY" 'beta.3 preflight produces non-empty curated notes'
  stub_dir="$tmp/bin"
  command mkdir -p "$stub_dir" || return 1
  print -r -- '#!/bin/sh' > "$stub_dir/curl" || return 1
  print -r -- 'printf "%s" "$FAKE_CURL_STATUS"' >> "$stub_dir/curl" || return 1
  command chmod 700 "$stub_dir/curl" || return 1

  assert_success '404 permits a new beta release' \
    run_duplicate_check "$candidate" 'v0.2.0-beta.3' 404 "$stub_dir"
  assert_failure_silent '200 refuses a duplicate beta release' \
    run_duplicate_check "$candidate" 'v0.2.0-beta.3' 200 "$stub_dir"
  assert_failure_silent 'unexpected release API status fails closed' \
    run_duplicate_check "$candidate" 'v0.2.0-beta.3' 500 "$stub_dir"

  output="$(run_release_create_dry "$candidate" 'v0.2.0-beta.3' "$notes_file")" || \
    test_failure 'beta release dry-run succeeds'
  assert_contains "$output" '--prerelease' 'beta create path includes --prerelease'
  assert_contains "$output" "$notes_file" \
    'beta create path receives the preflight-generated notes file'

  cleanup_release_test_dir "$tmp"
  return 0
}

test_case 'stable and constrained beta release identifiers are exact' test_stable_and_beta_contract_forms_are_exact
test_case 'synthetic candidates isolate existing release tags' test_synthetic_candidates_isolate_existing_release_tags
test_case 'valid stable preflight retains stable creation behavior' test_valid_stable_preflight_and_dry_run
test_case 'valid beta preflight reaches prerelease creation dry-run' test_valid_prerelease_preflight_and_dry_run
test_case 'preflight extracts only the literal matching beta changelog section' test_preflight_extracts_only_the_exact_beta_section
test_case 'preflight rejects mismatched, lightweight, non-main, and missing-note tags' test_release_preflight_rejects_tag_and_history_failures
test_case 'duplicate refusal and beta release command behavior are retained' test_duplicate_refusal_and_beta_dry_run
finish_tests
