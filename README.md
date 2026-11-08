# AIDLC Harness

A reusable **AI Development Lifecycle** engineering harness for [OpenCode](https://opencode.ai) 2.2.x on Windows, Linux and macOS. It turns an AI coding agent team into a governed engineering org: role-separated agents, deny-by-default permissions, lifecycle phase gates, decision registers, a cited knowledge base, and GitHub-enforced approvals.

**Handbook:** <https://tauhid-sifat.github.io/Tauness/> — a browsable engineering handbook generated from these documents.

The full documentation lives in [`harness/README.md`](harness/README.md). This file is just the front door.

## What you get

- **Seven-role agent team** — a PM orchestrator plus business analyst, designer, developer, QA engineer, code reviewer and security monitor, each with its own permission allow-list.
- **Tailored lifecycle** — Discovery → Design → Architecture → Development → QA → Deployment → Operations, with owner approval gates and five tailoring profiles (`full`, `lean`, `headless`, `brownfield`, `micro`).
- **Governance** — decision register, phase gates, material-change rules, advisory review model, GitHub-enforced approvals.
- **Hybrid knowledge management** — Git Markdown as canonical storage, a per-project knowledge base with source records and a staging → critic → acceptance workflow.
- **Security enforcement** — per-role allow-lists, hard `policies` that agent rules cannot override, protected paths, secret denies, delegation allow-lists.
- **GitHub integration** — issue forms, PR policy, label taxonomy, `CODEOWNERS`, workflows, Environments.
- **Project initialization** — one command renders a complete configured instance from templates plus a single `project.yaml`.

## Layout

```text
.
├── docs/harness/    # canonical core documentation: specifications, audits, ADR-H-001 onward
├── harness/         # the executable kit (Layer A) - full tree in harness/README.md
│   ├── HARNESS-VERSION
│   ├── README.md
│   ├── kit/         # templates with {{PLACEHOLDER}} slots: agents, commands, config, github, docs, lifecycle
│   └── scripts/     # init-project, apply-harness-change, validate-harness, sync-labels,
│                    #   plus lib-render.ps1 and lib-apply.ps1, the shared rendering engine
├── site/            # the GitHub Pages handbook (self-contained HTML, no build step)
└── tests/           # the kit self-test: static source policy, render-and-validate, site checks
```

The handbook in `site/` is deployed to GitHub Pages by `.github/workflows/pages.yml`, gated by `tests/check-site.ps1`.

## Quick start

Start a new project:

```powershell
pwsh -File harness/scripts/init-project.ps1 -Target "<empty directory>"
```

Add the harness to an existing repository:

```powershell
pwsh -File harness/scripts/init-project.ps1 -Target . -InsideRepo
```

Both are guided interviews that write `project.yaml`, then render the instance from the kit. From OpenCode, `/init-project` conducts the same interview and runs the script. Neither script ever deletes anything: existing files are skipped, conflicts are reported, and choices are left to you.

Validate an instance at any time (read-only, exits non-zero on failure):

```powershell
pwsh -File harness/scripts/validate-harness.ps1
```

## The three layers

| Layer | Home | May contain project names? |
|---|---|---|
| **A. Core harness** | `harness/kit/`, `harness/scripts/` | **No** — universal rules and templates only |
| **B. Project configuration** | `project.yaml` | Yes — this is where a project declares itself |
| **C. Project workspace** | `docs/project/`, source, `.github/`, `.opencode/` | Yes — generated artifacts plus human work |

Generated files are build artifacts of the kit. Never hand-edit a rule into an instance: edit the kit, then re-apply with `apply-harness-change.ps1`, which is also the owner-approval mechanism for harness changes.

## Testing the kit

The kit repository holds only templates, so there is no instance here to validate. `tests/` closes that gap:

```powershell
pwsh -File tests/check-sources.ps1          # static policy - runs on any OS
pwsh -File tests/render-and-validate.ps1    # renders and validates every lifecycle profile
```

`check-sources.ps1` enforces the rules the kit was built without: script sources stay ASCII-only (Windows PowerShell 5.1 decodes BOM-less UTF-8 through the ANSI codepage, so a non-ASCII literal can silently break parsing), every template slot has a producer, and the kit contract holds by exact filename and count. `render-and-validate.ps1` renders a throwaway instance for each lifecycle profile plus an all-integrations variant, asserts the artifacts and the enforcement effect of each toggle, then requires `validate-harness.ps1` to exit clean **and** to have recorded specific checks as PASS — so a check that errors out cannot masquerade as a pass.

`.github/workflows/kit-validation.yml` runs the render test on Windows and the static policy on Windows, Linux and macOS.

**Known limitation:** the renderer addresses files with Windows path separators, so `init-project.ps1` and `validate-harness.ps1` are Windows-only in practice even though the harness targets all three platforms. Converting those literals is outstanding work; until then only the Windows runner can exercise a rendered instance.

## Local-only artifacts

`harness/staging/` (pending-apply previews, which carry rendered project values that Layer A must not contain) and `harness/reports/` (validator output) are git-ignored.

## Versioning

See `harness/HARNESS-VERSION` and the commit hash recorded in each instance's `project.yaml.harness` section. Breaking kit changes require an owner-approved harness change and an ADR in `docs/harness/adr/`. The self-test is the gate: a kit change that cannot render a conforming instance does not merge.
