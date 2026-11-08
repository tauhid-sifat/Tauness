# AIDLC Harness

A reusable **AI Development Lifecycle** engineering harness for [OpenCode](https://opencode.ai) 2.2.x on Windows, Linux and macOS. It turns an AI coding agent team into a governed engineering org: role-separated agents, deny-by-default permissions, lifecycle phase gates, decision registers, a cited knowledge base, and GitHub-enforced approvals.

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
harness/
├── HARNESS-VERSION          # semantic version of the core kit
├── README.md                # the real documentation
├── kit/                     # templates with {{PLACEHOLDER}} slots
│   ├── project.yaml.tmpl    # the single per-project input
│   ├── agents/  commands/   # 7 roles, 15 slash commands
│   ├── config/  github/     # opencode baseline, issue forms, workflows
│   ├── docs/project/        # documentation + knowledge-base templates
│   └── lifecycle/           # profile definitions
└── scripts/
    ├── init-project.ps1         # render a new project from kit + project.yaml
    ├── apply-harness-change.ps1 # owner-run updater: re-render an instance from the kit
    ├── validate-harness.ps1     # static + structural validation of an instance
    ├── sync-labels.ps1          # GitHub label taxonomy sync
    └── negative-tests.md        # runtime enforcement test procedure
```

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

## Not published here

`harness/staging/` (the pending-apply instance preview and staged core docs) and `harness/reports/` (validation output) are git-ignored: the staging tree carries rendered project values, which layer A must not contain.

## Versioning

See `harness/HARNESS-VERSION` and the commit hash recorded in each instance's `project.yaml.harness` section. Breaking kit changes require an owner-approved harness change and an ADR.
