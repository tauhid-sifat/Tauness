# AIDLC Harness — Repository Structure

> **Status:** Core harness specification (Layer A) · harness 1.3.0 · 2026-11-09. Defines the three-layer physical layout of every instance; generalizes the 2026-11-02 project-scoped structure.

## 1. Target layout (every harness repository)

```
<project-root>/
├── AGENTS.md                      # generated instance instructions (never hand-edit)
├── opencode.jsonc                 # generated: permissions + policies + mcp (never hand-edit)
├── project.yaml                   # THE per-project input (Layer B; owner-approved edits via PR)
├── README.md                      # project front page → using-the-harness.md
├── .gitignore                     # secrets, tool artifacts, worktrees (kit template at init)
├── .gitattributes                 # line endings (add at scaffold time)
├── skills-lock.json               # installed-skill provenance (per project)
│
├── harness/                       # LAYER A — core harness (project-agnostic)
│   ├── HARNESS-VERSION            # kit version
│   ├── README.md                  # kit guide
│   ├── kit/                       # templates ({{PLACEHOLDER}} tokens)
│   │   ├── project.yaml.tmpl  AGENTS.md.tmpl  gitignore.tmpl  README-project.md.tmpl
│   │   ├── config/opencode.jsonc.tmpl
│   │   ├── agents/*.md.tmpl       # 7 role agents
│   │   ├── commands/*.md.tmpl     # 16 commands
│   │   ├── lifecycle/profiles.yaml
│   │   ├── github/                # CODEOWNERS, PR template, 11 ISSUE_TEMPLATE + config, workflows, labels.json
│   │   └── docs/project/          # workspace skeleton + KB templates (init-only; never overwritten)
│   ├── scripts/                   # init-project / apply-harness-change / validate-harness / sync-labels / negative-tests / lib-*
│   ├── reports/                   # validation outputs (generated)
│   └── staging/                   # (harness home repo only) proposed core docs + instance previews
│
├── .opencode/                     # generated instance runtime (agents + commands rendered)
│   ├── agents/  commands/  skills/  plugins/(optional)  state|cache|logs/(ignored)
├── .agents/skills/                # installed design/security skills (provenance-locked)
├── .github/                       # generated governance + project-authored workflows
│
├── docs/
│   ├── harness/                   # LAYER A docs (specs, ADRs, registry, and the archive/ of dated evidence) - project identity is enforced by tests/check-sources.ps1
│   └── project/                   # LAYER C workspace (canonical project knowledge + status)
│       ├── 00-context/ … 06-operations/      # domain dirs (READMEs from kit, content by roles)
│       ├── knowledge/                         # KB: capabilities/rules/entities/processes/sources/decisions/questions/actions + _staging/
│       ├── working/<agent-id>/                # working memory (inbox/ gitignored)
│       ├── decisions/decisions…/traceability/status/
├── DESIGN.md                      # canonical design system (OD-02 owner tool)
└── <application code per stack>   # src/app/tests/migrations… (created at scaffold)
```

## 2. Ownership rules

| Path | Owner | Change mechanism |
|---|---|---|
| `harness/`, `docs/harness/`, `AGENTS.md`, `opencode.jsonc`, `.opencode/agents|commands`, `.github/**` | Core harness (Layer A) + generated instances | Owner-approved harness change → `apply-harness-change.ps1` |
| `project.yaml` | Layer B | Owner (PR; PM records material edits) |
| `docs/project/**`, `DESIGN.md`, application code | Layer C | Approved roles within their scopes; PRs; gates |
| `docs/project/working/**` | Each agent | Free within own dir; never authoritative |

`init-project` writes `docs/project` skeletons **once**; upgrades never overwrite project-authored files (render scope = instance-owned only).

## 3. Naming conventions

| Artifact | Pattern |
|---|---|
| IDs | `{PREFIX}-{TYPE}-{NNN}`; types: REQ/US/AC/TC/DEF/DEC/ADR/CR/CAP/BR/ENT/PROC/SRC/Q/ACT/INC (prefix from `project.yaml`) |
| Branches | `<type>/<issue>-<slug>` (feat, fix, docs, chore, tests, spike, phase, release, hotfix) |
| Worktrees | `<issue>-<slug>` |
| Commands/agents | lowercase kebab; IDs stable across projects (`project-manager`, `business-analyst`, …) |
| Reports | `harness/reports/<tool>-<yyyymmdd-HHMMSS>.md` |

## 4. Ignore policy

`.env*` (except examples), keys/certs, `.opencode/state|cache|logs|history|tmp|telemetry`, `worktrees/`, `.hallmark/`, `.impeccable/`, `.playwright*`, `.firecrawl/`, `docs/project/working/*/inbox/`, node/build artifacts per stack. Committed: `.opencode/skills|agents|commands`, `.agents/skills` (provenance-locked), `skills-lock.json`, `docs/`, `.github/`, `project.yaml`, and in an **instance** also `harness/reports/` (validation output kept as gate evidence). The kit home repository is the exception: it ignores `harness/reports/` and `harness/staging/` because both are regenerated there and staging carries rendered project values that Layer A must not hold.
