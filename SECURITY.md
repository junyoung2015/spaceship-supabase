# Security policy

## Report a vulnerability privately

Please **do not open a public GitHub issue** for a suspected security vulnerability.

Use the repository's private vulnerability-reporting route to submit a GitHub Security Advisory:

<https://github.com/junyoung2015/spaceship-supabase/security/advisories/new>

Include a minimal reproduction, the affected revision, expected and observed behavior, and impact. Do not include Supabase access tokens, service-role keys, passwords, full local paths, production configuration, or a real project reference unless the maintainer explicitly asks through the private report.

If the private route is unavailable, do not post the report or technical details in a public issue. Use an existing private channel with the maintainer to request an alternate reporting route.

## Supported versions

Security fixes are provided for the latest released stable version on `main`. During the initial public release, that is v0.1.0. Alpha-era private history and untagged builds are not supported release artifacts.

## Security scope

This project handles local filesystem state that is rendered in a terminal prompt. Security-relevant reports include, but are not limited to:

- prompt injection through project-ref, config, local branch, label, or path content;
- symlink, traversal, race, permission, or ownership flaws in expected project paths or label state;
- unsafe label-store creation, update, parsing, or disclosure;
- unintended prompt-time writes, network access, Supabase CLI execution, credential reads, or external-runtime invocation;
- a stale, configured, or historical identity being rendered as if it were live; and
- bypasses of the documented validation, redaction, or fail-closed behavior.

Ordinary feature requests, support questions, cosmetic output changes, and compatibility discussions belong in the appropriate public issue form after checking [SUPPORT.md](SUPPORT.md).

## Disclosure process

The maintainer will acknowledge a private report, assess impact and affected versions, work toward a fix, and coordinate disclosure with the reporter when possible. Timelines depend on severity, reproducibility, and availability of a safe remediation. Please allow time for a patch and release before publicly disclosing exploit details.
