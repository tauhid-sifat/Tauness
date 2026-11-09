# AIDLC Harness — Implementation Roadmap

> **Status:** Core harness document · harness 1.1.0 · 2026-11-09. Records both the original WP-0…WP-10 program (statuses as of today) and the generalization program (WP-G series). Approval ≠ implementation ≠ verification — each package tracks all three.

## 1. Current package status

| Package | Scope | Approval | Implemented | Verified |
|---|---|---|---|---|
| WP-0 Specification baseline | 10 core docs + OD-01…20 | **Owner-approved 2026-11-04** | — | — |
| WP-1 Repository foundations | AGENTS/config/project skeleton/ignores | Approved | **Yes (superseded by WP-G3 regeneration pending apply)** | config/agents parsed `opencode debug` |
| WP-2 Agents + commands | 7+9 | Approved | Yes; hardened 2026-11-09 (concurrent session + this mission) | Static; runtime pending |
| WP-3 GitHub governance | repo/labels/templates/workflows/protection | Approved | Partial: repo+37 labels+templates local; **no push/protection/Projects/Environment** (owner actions OD-09/DP-DEC-010) | Blocked |
| WP-4 Knowledge templates + traceability | docs/project | Approved | Partial; extended by KB structures (staged) | Pending apply |
| WP-5 Discovery pilot (P1) | instance work | — | Not started (harness-first) | — |
| WP-6 Design pilot (P2) | instance | — | Prereq OD-13 done; pilot not started | — |
| WP-7 Architecture pilot (P3) | instance | — | Blocked: OD-11 input | — |
| WP-8 Dev/QA/security pilot | instance | — | Blocked: OD-10 + apply | — |
| WP-9 Deployment readiness | instance | — | Docs drafted; pipeline/backup/Environment outstanding | — |
| WP-10 Open Knowledge pilot | optional | OD-23 direction | Not started; now a module (integration toggle) | — |
| **WP-11 Security remediation (OD-21)** | hardening + policies + MCP fix | **Implemented 2026-11-09; staged for owner apply** | Agents hardened (concurrent session); config regenerated with policies layer (staged); **runtime matrix pending** | Partial static |

## 2. Generalization program (this mission, 2026-11-09)

| Package | Deliverable | Status |
|---|---|---|
| WP-G1 Audit & gap analysis | `generalization-audit-2026-11-09.md` | **Complete** |
| WP-G2 Core kit | `harness/` kit: project.yaml schema, config/AGENTS/agents/commands templates, lifecycle profiles, github+docs templates, scripts (init/apply/validate/sync-labels/negative-tests) | **Complete (staged; owner apply for live repo)** |
| WP-G3 Dental Park instance regeneration | `harness/staging/instance/**` rendered preview (config, agents×7, commands×15, github, project.yaml, KB/working/status docs) | **Complete (staged)** — apply owner-run |
| WP-G4 Core documentation | 13 staged core docs incl. knowledge-management, project-initialization, using-the-harness, ADRs, updated registries | **Complete (staged)** — apply owner-run |
| WP-G5 Enforcement proof | runtime negative matrix + fresh-session skill check + delegation pilot | **Not executed** (needs owner terminal + OD-25 readiness) |
| WP-G6 Validation report + readiness audit | `validation-report-2026-11-09.md`, `final-readiness-audit-2026-11-09.md` | **Complete** |
| WP-G7 Migration & handover | `migration-and-handover-2026-11-09.md` | **Complete** |
| WP-G8 GitHub activation | push, protections, labels, Projects, Environment | Owner-authorized actions (see handover) |

## 3. Critical path to first governed project work

1. Owner applies staged transformation (handover §2 commands) → validators green → `opencode debug config/agents` confirmed → commit.
2. Owner GitHub actions: scopes, push, protections, labels (`sync-labels.ps1`), Projects, `production` Environment.
3. Owner model-readiness verification → flip `project.yaml models.readiness` to `verified`.
4. Runtime negative matrix (`harness/scripts/negative-tests.md`) + delegation pilot + fresh-session skill check.
5. Independent review session → findings fixed → then `/pm` opens **Phase 1 Discovery** (instance work; OD-11 input still gates Phase 3).

## 4. Decision-to-package map (new ODs)

OD-21→WP-11 · OD-23→kit integrations (module, default off) · OD-24→WP-G2/G3 (deny renders) · OD-25→project.yaml readiness · OD-26→ADR-H-007 · OD-27/30/31→WP-G2/G3 · OD-28→profiles + workflow doc · OD-29→BA/reviewer encoding.

## 5. Risks

Over-broad denies blocking routine work (mitigation: narrow allow-lists + matrix; fixes go through kit); policy-precedence drift on OpenCode upgrade (mitigation: re-run matrix every upgrade); single-owner approval queue (batching; async gates); generated-file desync (CI harness-validation + apply plan); Dental Park usability during transition (all instance values preserved in `staging/instance/project.yaml`; no project docs overwritten).

## 6. Rollback

Every apply takes a timestamped backup; git history + checkpoint commit `6b13e14` preserve the pre-transformation state; reverting = restore backup / `git revert`. No runtime state is mutated by configuration; no push occurs without separate authorization.
