# Security Policy

The AIDLC Harness is a governance layer for AI coding agents. Its threat model is a **capable agent
that is confused, tricked, or over-eager** - not a remote attacker. That shapes what counts as a
vulnerability here.

## Report privately

Do **not** open a public issue. Use [GitHub's private security
advisory](https://github.com/tauhid-sifat/Tauness/security/advisories/new) for anything in scope.

## In scope

- **An agent can reach an irreversible or authority-bearing action the kit claims to hard-deny** -
  merge, deploy, publish, force-push, `reset --hard`, `clean`, `branch -D`, `gh secret`, or a
  `policies` entry generally. The delegation-proof layer is the last line, so a bypass there is the
  most serious class.
- **A rendered instance is weaker than the kit says.** For example an agent allow-list that re-opens
  a project deny, a deploy command from `project.yaml` that reaches the permissions layer but not the
  policies layer, or a protected path an agent can edit.
- **Secret exposure.** `.env`, keys, `.ssh`, and private keys are denied for read and edit; anything
  that makes them reachable through a tool is a defect.
- **A prompt-injection path that defeats enforcement**, such as fetched content that ends up executed
  as a command or accepted as owner approval.
- **Renderer or script behaviour that silently produces an ungoverned instance** - a placeholder left
  unresolved, a governance file not generated, or provenance stamps that misreport which kit a
  instance came from.

## Out of scope

- Findings that require the owner to deliberately widen their own `project.yaml` allow-lists or
  disable policies.
- A local process being a security boundary against an adversary with the same user account. Deny
  rules and approvals stop the documented bypasses; they are not a sandbox, and the handbook says so.
- Vulnerabilities in OpenCode itself, or in a project's application code. Those go to their own
  maintainers.

## What to include

Kit version (`harness/HARNESS-VERSION`), OpenCode version, OS and PowerShell version, the exact
reproduction, and the enforcement tier you believe was defeated (permissions, policies, or
GitHub-side controls). A failing test beats a description - a pull request that adds a red assertion
to `tests/` is the fastest possible report.

## Response

This is a single-owner project. Expect acknowledgement within a week. Fixes land through the same
gate as everything else: an ADR when the change touches permissions, policies, gates, or approvals
(material under OD-18), a self-test assertion that proves the bypass is closed, and a changelog entry.
Advisories are published once a fix is available.
