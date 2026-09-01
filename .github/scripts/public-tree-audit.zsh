#!/usr/bin/env zsh
# Verify that a release export has an explicit, reviewable public-file surface.

emulate -LR zsh
setopt errexit nounset pipefail

typeset script_dir repo_root tracked_path
script_dir=${0:A:h}
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
cd -- "$repo_root"

fail() {
  print -u2 -r -- "public-tree audit: $1"
  exit 1
}

typeset -a allowed_paths private_paths unknown_paths

while IFS= read -r -d $'\0' tracked_path; do
  case "$tracked_path" in
    # Public release root.
    spaceship-supabase.plugin.zsh|README.md|LICENSE|VERSION|CHANGELOG.md|SECURITY.md|SUPPORT.md|CONTRIBUTING.md|AGENTS.md|.gitignore|.gitattributes)
      allowed_paths+=("$tracked_path")
      ;;

    # Public documentation. Historical and archived material is deliberately
    # not part of the public release history.
    docs/archive/*|docs/plan-before-bmm/*)
      private_paths+=("$tracked_path")
      ;;
    docs/assets/spaceship-supabase-terminal.png)
      allowed_paths+=("$tracked_path")
      ;;
    docs/*.md)
      allowed_paths+=("$tracked_path")
      ;;

    # Public GitHub automation and community configuration.
    .github/agents/*)
      private_paths+=("$tracked_path")
      ;;
    .github/workflows/*.yml|.github/workflows/*.yaml|.github/ISSUE_TEMPLATE/*.yml|.github/ISSUE_TEMPLATE/*.yaml|.github/ISSUE_TEMPLATE/*.md|.github/PULL_REQUEST_TEMPLATE.md|.github/dependabot.yml|.github/scripts/*.zsh)
      allowed_paths+=("$tracked_path")
      ;;

    # The controlled glyph renderer is a release-evidence fixture. New manual
    # rendering fixtures need an explicit public-tree review before export.
    tests/manual/render-glyph-matrix.zsh)
      allowed_paths+=("$tracked_path")
      ;;
    tests/manual/*)
      unknown_paths+=("$tracked_path")
      ;;

    # The maintained test suite and its audited vendored dependencies are
    # intentionally published so contributors can reproduce release gates.
    tests/*)
      allowed_paths+=("$tracked_path")
      ;;

    # Known private-repository-only material. It remains in the private
    # archive, but the allowlist makes it impossible to export accidentally.
    _bmad-output/*|.prettierignore|.shellcheckrc)
      private_paths+=("$tracked_path")
      ;;

    *)
      unknown_paths+=("$tracked_path")
      ;;
  esac
done < <(git ls-files -z)

if (( ${#unknown_paths} > 0 )); then
  print -u2 -r -- "public-tree audit: tracked files are outside the explicit classification:"
  print -u2 -rl -- "${unknown_paths[@]}"
  exit 1
fi

if [[ "${SPACESHIP_SUPABASE_REQUIRE_PUBLIC_TREE:-false}" == true ]] && (( ${#private_paths} > 0 )); then
  print -u2 -r -- "public-tree audit: private-only files are present in a required public tree:"
  print -u2 -rl -- "${private_paths[@]}"
  exit 1
fi

# Allowed files must not retain an internal repository URL or local workspace
# root. Construct the private markers at runtime so this audit utility does not
# embed the private repository identity in the public tree it is auditing. The
# release plan may describe excluded paths, so path names themselves are not
# treated as a failure here.
typeset private_suffix='spaceship-supabase-'
typeset private_marker='internal'
typeset private_repository="junyoung2015/${private_suffix}${private_marker}"
typeset private_root="/"'Users'"/"'eddie'"/"'Desktop'"/${private_suffix}${private_marker}"
typeset -a identity_paths
for tracked_path in "${allowed_paths[@]}"; do
  # Vendored source is separately identified, versioned, and license-audited.
  # Its upstream examples can legitimately contain illustrative home paths;
  # first-party fixtures and documentation cannot.
  [[ "$tracked_path" == tests/vendor/* ]] || identity_paths+=("$tracked_path")
done
if git grep -n -F \
  -e "$private_repository" \
  -e "$private_root" \
  -- "${identity_paths[@]}" >/dev/null 2>&1; then
  fail 'allowed files retain an internal repository reference or developer path'
fi

# Reject absolute macOS/Linux user paths while allowing test-only temporary
# subdirectories such as "$tmp/home/". The anchor requires the slash to begin
# a path token rather than merely appear after a variable expansion.
if git grep -n -E '(^|[^[:alnum:]_])/(Users|home)/' -- "${identity_paths[@]}" >/dev/null 2>&1; then
  fail 'allowed files retain an absolute developer path'
fi

print -r -- "public-tree audit: ${#allowed_paths} allowed path(s), ${#private_paths} private-only path(s) classified"
