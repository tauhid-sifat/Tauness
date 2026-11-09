# AIDLC Harness — Core Kit

> **Layer:** Core harness (project-agnostic). Do not put project-specific values here.
> **Canonical documentation:** `docs/harness/` (specifications, decisions, audits). This directory is the **executable kit**: the templates, scripts, and configuration sources from which every project instance is generated.

## What this harness is

A reusable AI Development Lifecycle (AIDLC) engineering harness for OpenCode 2.2.x on Windows/Linux/macOS. It provides:

- a seven-role agent team (PM orchestrator + six specialists) with deny-by-default permissions;
- a tailored software lifecycle (Discovery → Design → Architecture → Development → QA → Deployment → Operations) with owner approval gates and five lifecycle profiles;
- governance: decision registers, phase gates, material-change rules, advisory review model, GitHub-enforced approvals;
- hybrid knowledge management: Git Markdown as canonical storage, a per-project knowledge base with source records and a staging/critic acceptance workflow, and optional Open Knowledge retrieval;
- security enforcement: per-role permission allow-lists, hard `policies` that agent rules cannot override, protected paths, secret denies, delegation allow-lists;
- GitHub integration: issue forms, PR policy, labels, CODEOWNERS, workflows, Environments;
- project initialization: one command or script renders a complete, configured instance for a new project.

## Layout

```text
harness/
├── HARNESS-VERSION              # semantic version of the core harness
├── README.md                    # this file
├── kit/                         # templates (placeholders {{LIKE_THIS}})
│   ├── project.yaml.tmpl        # project configuration — the single per-project input
│   ├── AGENTS.md.tmpl           # root agent instructions for the instance
│   ├── gitignore.tmpl           # instance .gitignore
│   ├── README-project.md.tmpl   # instance README
│   ├── config/opencode.jsonc.tmpl # permission + policy baseline, rendered per project
│   ├── agents/*.md.tmpl         # 7 role agents (generic bodies; stack slots rendered)
│   ├── commands/*.md.tmpl       # 16 slash commands
│   ├── github/**                # issue forms, PR template, CODEOWNERS, workflows, labels.json
│   ├── docs/**                  # project documentation + knowledge-base templates
│   └── lifecycle/profiles.yaml  # lifecycle profiles for tailoring
├── scripts/
│   ├── init-project.ps1         # render a new project from kit + project.yaml
│   ├── apply-harness-change.ps1 # owner-run updater: re-render instance from kit
│   ├── validate-harness.ps1     # static + structural validation of an instance
│   ├── sync-labels.ps1          # GitHub label taxonomy sync
│   ├── lib-render.ps1           # shared rendering engine (project.yaml subset + templates)
│   ├── lib-apply.ps1            # shared render plan: init and apply use the same engine
│   └── negative-tests.md        # runtime enforcement test procedure (see OD-25 gate)
```

Generated and local-only paths, never committed: `harness/reports/` (written by
`validate-harness.ps1`) and `harness/staging/` (the pending-apply preview produced by
`apply-harness-change.ps1`, which carries rendered project values).

## The three layers (never mix them)

| Layer | Home | Contains | May contain project names? |
|---|---|---|---|
| **A. Core harness** | `harness/` + `docs/harness/` | universal rules, agents, commands, workflows, enforcement, templates | **No** |
| **B. Project configuration** | `project.yaml` (+ `docs/project/00-context/constraints.md`) | identity, stack, areas, IDs, integrations, data policy, lifecycle profile | Yes — this is where projects declare themselves |
| **C. Project workspace** | `docs/project/`, source code, tests, `.github/` instance, `.opencode/` instance | requirements, designs, code, issues, reports, status | Yes |

Instance files (layer C roots: `AGENTS.md`, `opencode.jsonc`, `.opencode/`, `.github/`, `docs/project/`) are **generated** from layer A templates plus layer B values. Never hand-edit generated files to change a rule: edit the kit, then re-apply (`harness/scripts/apply-harness-change.ps1`). The kit is the source of truth; instances are build artifacts.

## Starting a new project

1. `pwsh harness/scripts/init-project.ps1 -Target "<empty dir or --inside-repo>"` — guided interview for `project.yaml`, then renders the instance.
2. Or from OpenCode in a cloned harness: run `/init-project` (PM conducts the same interview and executes the script).

No prior project knowledge is required or inherited. See `docs/harness/project-initialization.md`.

## Integrating into an existing project

Run init with `-InsideRepo` against a clone, or copy `harness/`, run `init-project.ps1 -Target . --inside-repo`, and accept the rendered files. Existing docs are never overwritten: the script writes new files only, reports conflicts, and stops for explicit choices (same safety rule as `AGENTS.md`).

## Developing the kit in this repository

The kit home repository holds templates only, so it has no instance to validate. The self-test in
`tests/` closes that gap: it renders a throwaway instance for every lifecycle profile plus an
all-integrations variant, then validates each one with `validate-harness.ps1`.

```powershell
pwsh -File tests/check-sources.ps1          # static policy, runs anywhere
pwsh -File tests/render-and-validate.ps1    # render + validate all profiles (Windows)
```

`check-sources.ps1` enforces the rules this kit was built without and cannot be edited safely
without them:

- **Script sources are ASCII-only, with no BOM.** Windows PowerShell 5.1 decodes BOM-less UTF-8
  using the ANSI codepage, so a non-ASCII literal such as `U+2192` arrives as bytes containing an
  apostrophe and silently breaks string parsing. When rendered output needs a glyph, emit it from
  its code point (see `PHASE_LIST` in `lib-render.ps1`) rather than writing it into the source.
- **Every template slot must have a producer.** A `{{TOKEN}}` no renderer branch assigns is a leak
  in whichever variant happens to reach it; the audit catches it statically instead.
- **The kit contract is asserted by name**: `HARNESS-VERSION` semantics, 7 agent templates, 15
  command templates, 5 profiles, the documented core docs, and file extensions that survive the
  `.tmpl` suffix being stripped by character count.

`.github/workflows/kit-validation.yml` runs the render test on Windows and the static policy on
Windows, Linux and macOS.

**Known limitation:** the renderer addresses files with Windows separators (`Join-Path $Root
'docs\harness\x.md'`), so `init-project.ps1` and `validate-harness.ps1` are Windows-only in
practice even though the harness targets all three platforms. Converting those path literals is
outstanding work; until then only the Windows runner can exercise a rendered instance.

## Versioning

`HARNESS-VERSION` + the commit hash recorded in each instance's `project.yaml.harness` section. `apply-harness-change.ps1` shows the kit diff before writing. Breaking kit changes require an owner-approved harness change and an ADR in `docs/harness/adr/`.
