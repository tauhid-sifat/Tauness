# Migration and Handover — AIDLC Harness 1.0.0 (2026-11-09)

## 1. What changed conceptually

The the originating project-specific harness is now a **project-agnostic AIDLC core** (`harness/` kit + `docs/harness/` specs) with the originating project reduced to **one instance** defined by `project.yaml` + generated files + `docs/project/`. Lifecycle extended to include Operations & Maintenance and five tailoring profiles. Enforcement upgraded: shell deny-by-default, role allow-lists, delegation-proof `policies` layer, integration toggles. BA discipline raised to the AI BA Harness benchmark (knowledge base + staging/critic/acceptance + authority checks + `/intake`/`/ask`).

## 2. Apply the transformation to the originating project (owner, one time)

From `D:\My Code\the originating project Website` in **your** PowerShell (agents cannot self-apply — by design):

```powershell
# 0) Commit the staged harness work first (restore point before apply; nothing is pushed):
git add -A
git commit -m "chore: stage AIDLC harness 1.0.0 core kit, scripts, and generalized transformation"

# 1) Review what apply will change (file plan, no writes). The script auto-places project.yaml
#    from the staging tree if the repo root doesn't have one yet:
pwsh -File harness\scripts\apply-harness-change.ps1 -DryRun

# 2) Apply: regenerates AGENTS.md, opencode.jsonc, .opencode agents+commands, .github governance
#    from kit + project.yaml; accepts harness\staging\docs-harness\* into docs\harness\*;
#    backs up every overwritten file first (temp dir printed by the script):
pwsh -File harness\scripts\apply-harness-change.ps1 -Force -AcceptStagedDocs

# 3) Copy the staged NEW project-workspace files (knowledge base, working memory, updated status/register):
Copy-Item -Recurse harness\staging\instance\docs\project\* docs\project\

# 4) Verify live:
opencode debug config            # parses; see permissions+policies
opencode debug agents            # 7 agents, models/modes correct
pwsh -File harness\scripts\validate-harness.ps1          # static PASS + report in harness\reports\
pwsh -File harness\scripts\validate-harness.ps1 -IncludeRuntime   # debug-config/agents runtime checks

# 5) Commit (traceability; backup exists in the temp dir the script printed):
git add -A
git commit -m "feat: transform harness to project-agnostic AIDLC core 1.0.0 (staged->applied); extend lifecycle to operations; add KB workflow; policies enforcement layer"
```

If apply/validate surface script issues (PS 5.1 edge cases), fix forward — the kit is the source of truth; stage fixes in `harness/` and re-run.

**Post-apply tidying (PM can then do inside the harness):** refresh `docs/project/README.md` reading order to include `knowledge/` and `working/`; reconcile `00-context/constraints.md` to reference `project.yaml` as its machine-readable twin.

## 3. Then unlock enforcement proof (owner)

1. **Model readiness (OD-25/OD-05):** verify OpenCode Go workspace Global-privacy setting + Hy3 structured output → set `models.readiness: verified` in `project.yaml` (PR).
2. **Negative matrix:** follow `harness/scripts/negative-tests.md` (30 runtime tests + 4 GitHub tests). Log results in `docs/harness/implementation-log.md`. Any DENIED→ALLOWED regression = stop governed work; fix kit; re-apply.
3. **Delegation pilot:** allow-listed path succeeds; non-listed denied; depth-3 denied; child uses own permissions. Until proven, treat delegation as unverified (PM runs everything through direct commands instead).
4. **GitHub control plane:** scopes (`project,workflow,read:project`) → authorize push → protect `main` (owner/Code-Owner review, required checks incl. harness-validation) → `production` Environment (owner reviewer) → `sync-labels.ps1` → Projects v2.
5. **Independent review session** of the applied transformation (mission P-09).

## 4. Using the harness for a completely new project

```powershell
# anywhere, from a clone/copy of this harness (or just the harness/ + docs/harness/ trees):
pwsh -File harness\scripts\init-project.ps1 -Target ..\my-new-project
```
- Guided interview → confirms `project.yaml` → renders full instance (agents, commands, config with policies, lifecycle profile, governance forms, workspace skeleton incl. knowledge base) → leak-check + next steps.
- Existing codebase: add `-InsideRepo` (only creates missing files, reports conflicts, never deletes; then run the brownfield Phase-0 assessment).
- Post-init owner checklist: validate → git init/commit → remote + scopes + protections → labels/Projects → model readiness → negative matrix → Phase 1.

**New-project sanity test (recommended):** after the originating project apply, spin one throwaway project (e.g. `headless` + `lean`) and grep its files for the originating project name, its domain nouns and its stack vendor names — zero hits expected by construction; report any leak as a P0 harness bug.

## 5. Upgrading any instance later

Edit kit → bump `HARNESS-VERSION` → in each project: `apply-harness-change.ps1 -DryRun` → `-Force` → validators → commit. Project-authored files (`docs/project/**`, code) are never touched (init-scope protection).

## 6. Owner decisions still outstanding (inherited + new)

| # | Decision | Where |
|---|---|---|
| 1 | OD-11 jurisdiction/regime (the originating project) | gates Phase 3 |
| 2 | OD-12 provider backup verification + RPO/RTO | gates production |
| 3 | BrowserOS restore vs disable (OD-10) | QA path |
| 4 | OpenCode 2.2.6 upgrade vs keep prohibition | security hygiene |
| 5 | Credential rotation (global config) + scope refresh | security hygiene |
| 6 | Push/commit authorization pattern | GitHub plane |
| 7 | Agent identity for gated approvals (OD-19/22) | optional |
| 8 | ~~OD-29 veto check~~ **confirmed 2026-11-09** | KB workflow |
| 9 | ~~`web_research` deny-default~~ **confirmed 2026-11-09**; re-enable per project in `project.yaml` | disclosed change |

## 7. Deliverable index

Core kit `harness/` (README, HARNESS-VERSION, kit/**, scripts/**) · staged core docs `harness/staging/docs-harness/` (14 docs incl. ADRs, audit, validation report, readiness audit, updated registries) · staged instance `harness/staging/instance/` (project.yaml, opencode.jsonc, AGENTS.md, .opencode/{agents×7,commands×15}, .github/**, docs/project/**) · rollbacks: temp backup `aidlc-backup-20261109-010215` + checkpoint commit `6b13e14`.
