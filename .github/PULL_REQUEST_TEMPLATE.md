## Summary

<!-- What changed, why it matters, and any user-visible prompt text. -->

## Validation

<!-- List exact commands and their results. Example: ZSH_BIN=/path/to/zsh tests/run.zsh -->

## Safety and compatibility

- [ ] No prompt-time network, CLI, credential, or write behavior was added.
- [ ] Filesystem-derived values are strictly validated before rendering.
- [ ] Tests cover relevant failure paths and adversarial input.
- [ ] Documentation and CHANGELOG.md were updated when behavior or configuration changed.
- [ ] This change works with Zsh 5.2+ and Spaceship Prompt v4.

## Checklist

- [ ] `tests/run.zsh` passes locally.
- [ ] `tests/run.zsh --performance` passes when render-path performance changed.
- [ ] `zsh -n spaceship-supabase.plugin.zsh` passes.
- [ ] I removed project references, credentials, private paths, and terminal escape sequences from this PR.

## Related issues

<!-- Closes #123 -->
