# Open Decisions — AIDLC Harness Registry

> **Status:** Core harness registry (Layer A) · harness 1.3.0 · updated 2026-11-09.
> **Purpose:** Every decision that could not be resolved from the brief, the repositories, or verified OpenCode behavior. Options, evidence, recommendation, disposition, and blocking status. The instance-level owner mirror is `docs/project/decisions/decision-register.md`.
> **History rule:** OD-01…OD-20 carry their full option/evidence histories in Git history (WP-0 baseline, approved 2026-11-04) and in the dated audit/finalization documents. This registry preserves dispositions and adds new decisions; nothing approved is rewritten.
> **Approval basis:** OD-01–OD-20 explicitly approved by the owner 2026-11-04. OD-21–OD-25 dispositions recorded 2026-11-09 under the generalization mission (owner directive: complete the harness; preserve approved decisions). OD-26 resolved by mission instruction. OD-27-OD-32 are new decisions from the generalization mission; dispositions below.

---

## Decision index

| ID | Decision | Status (2026-11-09) | Disposition |
|---|---|---|---|
| OD-01 | OpenCode version | **Approved & executed** (2.2.5 verified) | 2.2.6+ upgrade remains an owner action (external-directory/session_move fix); until then governed sessions must not move sessions externally |
| OD-02 | Hallmark owns `DESIGN.md`; Impeccable read-only | Approved | Implemented as core design-tool ownership rule (kit renders project routing); enforcement now in generated config |
| OD-03 | Commands with `subagent: false`; no `mode: all` | Approved | Implemented; kit renders 16 commands on this pattern |
| OD-04 | Depth-2 delegation with named allow-lists | Approved | Implemented; runtime enforcement still to be proven (negative matrix) |
| OD-05 | Role-specific model routing | Approved; conditions open | Models render from `project.yaml`; readiness `gated` until owner verifies privacy + structured output |
| OD-06 | Projects v2 Status; Done/Closed semantics | Approved | Implementation blocked on `project`/`read:project` scopes (owner action) |
| OD-07 | PM-only issue creation | Approved | Implemented in generated permissions (BA/others lack `gh issue create`) |
| OD-08 | `gh` CLI only | Approved | Implemented; MCP servers project-scoped + default deny |
| OD-09 | GitHub scope refresh (`project`, `workflow`, `read:project`) | Approved; execution outstanding | Owner action |
| OD-10 | Browser tooling (BrowserOS pilot, Playwright later) | Approved; pilot blocked | Integration toggle `browser_live`; MCP `ask` per call until owner enables |
| OD-11 | Jurisdiction/regime before Phase 3 | Approved; input outstanding | Instance project decision (the originating project); core carries the framework (data_policy) |
| OD-12 | Backup provider verification | Approved; verification outstanding | Instance project action; core defines the verification discipline |
| OD-13 | Pinned global `puppeteer-core` | Approved & executed | Retained; documented as global-tool footprint with CI-pinned fallback |
| OD-14 | Deny phantom skill IDs | Approved | Implemented via deny-all baseline + explicit allow-lists (15 IDs need no individual denies) |
| OD-15 | Both skill roots retained | Approved | Implemented; kit documents both roots |
| OD-16 | GitHub controls + OpenCode permissions; no plugin | Approved | Implemented and extended by OD-21/ADR-H-004 (`policies` layer); still no plugin |
| OD-17 | Actions-based deployment | Approved | Core pattern: pipeline-only deploy behind Environment reviewer; CLIs rendered from `project.yaml` |
| OD-18 | Material-change definition | Approved | Core governance unchanged |
| OD-19 | Advisory agent verdicts; distinct identity for approve | Approved | Implemented: policy-level hard deny of `gh pr review --approve/-a` (now beats any approval path) |
| OD-20 | Controlled emergency hotfix | Approved | Core pattern in workflow P7 + kit runbook template |
| OD-21 | Permission hardening (deny-by-default etc.) | **Implemented 2026-11-09 (staged; pending owner apply + runtime proof)** | Full enforcement stack: shell deny-default, role allow-lists, protected paths, secrets deny, policies layer, MCP/skill/delegation deny-all |
| OD-22 | Distinct agent identity for approvals | Recommended default retained | Advisory-only until owner creates identity; optional owner action |
| OD-23 | Open Knowledge adoption | **Defined as optional module** | `project.yaml.integrations.open_knowledge` (default false); retrieval layer only; pilot per knowledge-management §8; still not a first-commit dependency |
| OD-24 | MCP/web egress default deny | **Implemented** | Renders from integration toggles; enabled integrations resolve to `ask` (human per-call), not blanket allow |
| OD-25 | Model readiness gate | **Implemented** | `project.yaml.models.readiness`; `gated` = no real sessions; recorded in generated AGENTS.md §8 |
| OD-26 | Agent role reconciliation | **RESOLVED — Option 1 (preserve current seven)** | Owner generalization mission (2026-11-09) directs preserving approved agent hierarchy; Software Architect = Developer duty; Independent Reviewer = Code Reviewer; Security Monitor retained. Recorded as ADR-H-007; DP-DEC-026 |
| OD-27 | Generalization architecture (three layers, kit + project.yaml + generated instances) | **Accepted (mission-authorized)** | ADR-H-001/002; project-agnosticism is a Definition-of-Done item of the mission |
| OD-28 | Lifecycle completion (Phase 7 Operations + tailoring profiles) | **Accepted (mission-authorized)** | ADR-H-003; mission §4 requires full lifecycle + tailoring |
| OD-29 | KB delegation amendment (BA → code-reviewer critic, read-only, no approval transfer) | **Accepted — owner confirmed 2026-11-09** | Demonstrated technical need: independent critic required by benchmark; reviewer remains zero-write |
| OD-30 | Initialization & upgrade mechanism (init/apply scripts; generated-file ownership) | **Accepted (mission-authorized)** | ADR-H-006; owner-run apply is the literal owner-approval mechanism |
| OD-31 | `policies` as hard-deny layer; agent-override hole closed | **Accepted** | ADR-H-004; verified against official docs + observed override behavior; version-dependent → re-prove on upgrades |
| OD-32 | First-instance values (areas, profile `full`, stack command lists, `web_research: false`, `browser_live: true` with ask-gating) | **Accepted — owner confirmed 2026-11-09** | Rendered into `harness/staging/instance/project.yaml`; values mirror prior approved docs; deviations would be project decisions |

## Standing owner actions (not architecture decisions)

1. Apply the staged transformation (`apply-harness-change.ps1 -Force -AcceptStagedDocs`) and run validators + `opencode debug config/agents`.
2. Rotate/remove plaintext credentials in global OpenCode config; keep secrets out of configs.
3. GitHub: scopes (`project`, `workflow`, `read:project`), push authorization, branch protection/CODEOWNERS/required checks/production Environment; label sync; Projects v2.
4. OD-05/OD-25: verify workspace Global privacy setting + Hy3 structured output; flip `models.readiness` to `verified` to unlock sessions.
5. OD-11: originating project jurisdiction/regime input before Architecture phase.
6. OD-12: provider backup evidence + RPO/RTO + restore test before production.
7. OD-10: restore BrowserOS Neo connectivity for the pilot (or disable the integration).
8. OpenCode 2.2.6+ upgrade decision (session_move fix).
9. Runtime negative-test matrix execution (owner terminal; script provided).
10. Independent review session authorization after apply (mission Step 7/§15).

## Consequential decisions surfaced to the owner during this mission

- Harness-change path: staged output + owner-run apply (owner answered 2026-11-09).
- Concurrent session: absorbed, then stopped (owner answered 2026-11-09).
- OD-26: resolved by mission instruction rather than a new question (mission pre-approved Option 1's content).
- OD-29 (critic delegation): **owner confirmed 2026-11-09** — BA may delegate the read-only KB critic pass to the code-reviewer (no approval transfer).
- `web_research` default changed from agent-allow (pre-audit config) to deny; **owner confirmed 2026-11-09** as the new default; re-enable per project via `project.yaml`.
