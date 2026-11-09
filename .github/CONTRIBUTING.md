# Contributing to the AIDLC Harness

This repository is the **kit's home**: templates, the renderer, the scripts, the core
specifications, and the self-test that renders throwaway instances. No project work happens here, and
that distinction is the whole design (see *The three layers* in [`harness/README.md`](../harness/README.md)).

## Before you change anything

Read, in this order:

1. [`harness/README.md`](harness/README.md) - the kit contract and the three layers.
2. [`docs/harness/adr/INDEX.md`](../docs/harness/adr/INDEX.md) - fourteen decisions already made, with the
   reasons and the alternatives rejected. Re-litigating one needs a new ADR that supersedes it.
3. [`docs/harness/security-and-permissions.md`](../docs/harness/security-and-permissions.md) - why the
   enforcement model is two-tiered.

## The rules that will decide whether a change lands

- **Layer A never names a project.** `harness/kit/`, `harness/scripts/`, and the living parts of
  `docs/harness/` hold universal rules only. Project values belong in `project.yaml` (Layer B).
- **Generated files are build artifacts.** Never hand-edit an instance's `AGENTS.md` or
  `opencode.jsonc` to change a rule - edit the kit, then re-apply.
- **Script sources are ASCII-only, no BOM.** Windows PowerShell 5.1 decodes BOM-less UTF-8 with the
  ANSI codepage, so a non-ASCII literal can silently break parsing. Emit needed glyphs from code
  points (`[string][char]0x2192`).
- **Never widen the permission layer to make a workflow convenient.** If something needs a new grant,
  say what it exposes. The refusal in `/improve-harness` applies to proposals too.
- **Approved is not implemented is not verified.** A control needs a test that shows it blocking, not
  a paragraph saying it does.

## Proposing a change

Use the **Harness improvement** issue form, or run `/improve-harness` inside a project instance that
already uses the kit - it conducts the same interview and writes the proposal file for you. Include
what would prove the change works: a self-test assertion, a negative-test row from
`harness/scripts/negative-tests.md`, or a validation marker.

## Sending a pull request

Run the gates locally and paste the output:

```powershell
pwsh -File tests/check-sources.ps1          # static policy: sources, slots, contract, reachability
pwsh -File tests/render-and-validate.ps1    # render + validate + re-apply every lifecycle profile
```

Both must pass. CI runs the same two on Windows plus the static policy on Linux and macOS, and a
handbook check on the site.

Every change to `HARNESS-VERSION` needs a `CHANGELOG.md` entry. Changes to permissions, policies,
gates, or approval rules are material (OD-18) and require an ADR in `docs/harness/adr/`. Dated audits
and validation reports are point-in-time evidence: they are never edited to match a later decision -
new findings get a new dated document.
