# Security policy

## Report a vulnerability privately

Please **do not put vulnerability details, reproduction steps, impact, affected
revisions, secrets, project state, or exploit information in a public GitHub
issue**.

When GitHub exposes the repository's private vulnerability-reporting route to
your account, submit a GitHub Security Advisory:

<https://github.com/junyoung2015/spaceship-supabase/security/advisories/new>

Confirm that the page is accessible before beginning beta testing; private
repository access alone does not prove that GitHub grants advisory-creation
permission to every collaborator. Include a minimal reproduction, the affected
revision, expected and observed behavior, and impact. Do not include Supabase
access tokens, service-role keys, passwords, full local paths, production
configuration, or a real project reference unless the maintainer explicitly
asks through the private report.

If the advisory route is unavailable, do not post the report or technical
details in an issue. Members of the authorized maintainer-private beta cohort
must use their pre-agreed direct private channel to the release owner. Anyone
without such a channel may open the repository's
[metadata-only private-contact request](https://github.com/junyoung2015/spaceship-supabase/issues/new?template=security_contact.yml).
That public request must contain no vulnerability detail at all; it exists only
so the maintainer can provide an alternate private route. Move the report to
that route before sharing any technical information. No external invitation
should proceed until its intended reporters have a tested private route.

## Supported versions

Security fixes are provided for the latest published stable version on `main`. A pending version becomes supported only after its annotated tag and GitHub Release are published. Alpha-era private history and untagged builds are not supported release artifacts.

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
