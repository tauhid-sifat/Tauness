# AIDLC Harness — Project Initialization

> **Status:** Core harness specification (Layer A) · harness 1.1.1 · 2026-11-09. Defines how any new project starts with zero manual editing of core content.

## 1. What initialization produces

A complete instance from one input — `project.yaml` — with: root `AGENTS.md` + `opencode.jsonc` (rendered rules incl. policies, secret denies, protected paths, integration toggles), 7 agents + 16 commands in `.opencode/`, generated `.github/` governance (11 issue forms with the project's phases/areas/prefix, PR template, CODEOWNERS, workflows, labels), the `docs/project/` workspace skeleton (all phase directories with owning-role READMEs, knowledge base structure + templates, decision register, phase-state bound to the chosen lifecycle profile, traceability, working-memory), `.gitignore`, and a README pointing at the handbook. No project ever inherits another's assumptions; no project-specific or stack-specific text exists in the kit.

## 2. New-project flow

```powershell
# from a clone of the harness home repository (owner shell):
pwsh -File harness\scripts\init-project.ps1 -Target ..\my-new-project
```
1. Guided interview (or `-Config <pre-filled project.yaml>` for automation): identity, prefix, owner, repository, **lifecycle profile + areas**, stack commands (dev/qa/reviewer/security lists, deploy CLIs, local URL), data sensitivity + label, integrations (Projects v2, live browser, design tools, Open Knowledge, MCP denies), models + readiness.
2. Owner confirms the assembled `project.yaml` (diff preview; explicit yes).
3. Renderer substitutes every `{{PLACEHOLDER}}`; unresolved placeholders fail the run (leak detection).
4. Safety guarantees: target must be empty or explicitly `-InsideRepo`; existing files are skipped unless `-Force`; **nothing is ever deleted**; backups taken by `apply-harness-change.ps1` before overwrites.
5. Post-render owner steps: `git init -b main` (new projects), review + commit `Initialize from AIDLC harness vX`, run `validate-harness.ps1`, create the remote, `sync-labels.ps1`, enable GitHub protections per `github-governance.md` §13, open OpenCode → `/status` → Phase 1 via `/pm`.

## 3. Existing-project (brownfield) flow

`init-project.ps1 -Target <existing repo> -InsideRepo`: renders only what is missing and reports every conflict; existing agent instructions/code are never overwritten without `-Force`. Afterwards: the Phase-0 assessment (brownfield profile) audits reality (stack, CI, secrets, risks), fills `project.yaml` stack lists from what the project actually runs, records the deltas as decisions, and tailors the profile with owner approval.

## 4. Upgrade/propagation model

Instances record `project.yaml.harness.kit_version + rendered_from_commit`. Upgrades: update the home repo kit → in each instance run `apply-harness-change.ps1 -DryRun` (file plan), then `-Force` with automatic timestamped backup → re-run validators + negative-test matrix → commit as a harness-change PR. Core behavior changes require an ADR; instances never hand-edit generated files (AGENTS.md §2; enforced by protected-path denies + CI validation).

## 5. Customization without forking

Project needs map to `project.yaml` fields, not core edits: extra commands → `stack.*_commands` / `agent_skills`; skill grants → `skills.shared` / `skills.<role>`; stricter rules → `hard_deny_commands`; different lifecycle → `lifecycle.profile` (+ recorded tailoring decisions); new integrations → toggles + MCP deny list; anything genuinely new → `harness-improvement` issue (kit change) or **project-local additions** under `docs/project/` and an instance-specific agent overlay file (new agent ID, never editing a generated one) — both reviewed by the owner.

## 6. Validation gates at initialization

`validate-harness.ps1` must PASS before first governed work: files present, no BOM/placeholder leaks, JSONC parses, deny-by-default + policies present, protected paths enforced, delegation matrix exact, commands→agents references resolve, core docs copied, shape of phase-state/register/traceability, secrets scan clean. `opencode debug config/agents` must load all seven agents with correct models/modes. Runtime negative matrix (`harness/scripts/negative-tests.md`) runs as soon as model readiness permits; until then the instance operates at **read-only/propose** autonomy level only (no delegation, no shell-bearing tasks beyond PM planning).
