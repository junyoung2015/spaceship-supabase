# Test dependency manifest

The release suite deliberately vendors the small, audited test-time pieces it
needs. The prompt plugin itself has no runtime dependency on either tree.

| Dependency | Upstream | Immutable revision | License | Purpose |
| --- | --- | --- | --- | --- |
| shUnit2 | <https://github.com/kward/shunit2> | `e35296d3be2bcde770f2989d9c09fd1a2af6b567` | Apache-2.0 | Retained historical test utility and compatibility reference. The v0.1 suites use a minimal local harness so they do not need a network bootstrap. |
| Spaceship Prompt | <https://github.com/spaceship-prompt/spaceship-prompt> | `e498b1381df3a122af107b61f5cc8f3ced93ee69` (v4.21.0) | MIT | Actual v4 section packing and rendering used by prompt-safety tests. |

## Updating a vendored dependency

1. Review the upstream release, license, changelog, and full immutable commit.
2. Fetch it into a disposable directory outside this repository; do not turn
   `tests/vendor/` into nested Git repositories and do not run a network fetch
   as part of normal tests.
3. Replace only the reviewed dependency tree, update this table, and add tests
   for any changed API behavior.
4. Run `ZSH_BIN=/path/to/zsh tests/run.zsh --performance` and inspect the
   public-tree and license checks before committing.

`tests/fetch_deps.sh` was intentionally retired: a public checkout must be
self-contained and must not need network access to run the release suite.
