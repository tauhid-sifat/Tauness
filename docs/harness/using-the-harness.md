# AIDLC Harness — Using the Harness (Operations Guide)

> **Status:** Core harness guide (Layer A) · harness 1.0.0 · 2026-11-09. The day-to-day manual for owner and agents.

## 0. Mental model in one paragraph

You (owner) state intent → the **PM agent** decomposes it into ledger items and **task envelopes**, delegates to **specialists**, and returns **evidence-backed** results; you **approve at gates**, never micromanage routine work; everything authoritative is a **cited Git-Markdown** artifact; enforcement is **permissions + policies + GitHub**, so agents *cannot* merge/deploy/approve/bypass even if instructed or tricked. The lifecycle you get is the **profile** you picked; you can tailor it as one recorded decision.

## 1. Owner quick reference

| I want to | How |
|---|---|
| Kick off the project | `/pm <intent>` — PM opens Phase 1 issues and a task plan |
| See where things stand | `/status` (one-screen truth + the next owner decision) |
| Approve a phase | review the **gate pack** in `docs/project/status/gates/` + the phase-gate issue, then merge the phase-state PR |
| Feed a meeting/doc into knowledge | `/intake <source>` — accept staged items one by one |
| Ask what's known | `/ask <question>` — cited, read-only |
| Get a slice built | `/plan <scope>` then let PM run Development; you approve material items before build |
| Review a PR | Read the **Reviewer advisory verdict** + **Security verdict** (if sensitive); you approve/merge |
| Ship it | Deployment gate → owner Environment approval; smoke/rollback evidence |
| Change the harness | open a `harness-improvement` issue; after approval `apply-harness-change.ps1` |

## 2. Agent invocation

PM is the default primary (`/pm`, `/plan`, `/status`, `/issue`, `/phase`, `/ops`). Specialists run in-session via commands (`/ba /design /dev /qa /review /security /intake /ask`, `subagent: false`) or as delegated subagents through the PM. Delegation is allow-listed (`agent-specifications.md` §1.4), depth 2, never transfers approval. A specialist can be addressed directly for a focused task but cannot bypass gates or permissions.

## 3. A normal work item, end to end

1. **Intent** → PM restates goal + DoD; checks phase/profile/decision register.
2. **Plan** → PM `/plan`: smallest sufficient items, dependencies, parallel-safety, change class (A/B/C/D).
3. **Knowledge** → BA `/intake` (new facts), `/ask` (queries), drafts issues; you accept staged items.
4. **Spec** → BA requirements/AC with IDs; PM DoR gate; you approve material requirements.
5. **Build** → Developer implements on `feat/<issue>` with tests + ADR if material; opens PR.
6. **Review** → Code Reviewer advisory verdict; Security Monitor verdict if sensitive; you are the only approver/merger.
7. **QA** → QA independently verifies AC on preview with evidence; defects return to Developer.
8. **Gate** → PM packs evidence; you approve and merge the phase-state PR.
9. **Deploy** → pipeline behind `production` Environment (owner reviewer); smoke + rollback evidence.
10. **Operate** → `/ops` steady state; incidents via hotfix runbook; retros feed harness improvements.

## 4. Handling the awkward cases

**Ambiguity:** Low→proceed+assumption; Medium→2–3 options, PM decides in scope; High→stop+escalate (workflow §8). **Blocked:** two-attempt cap → evidence → PM escalation → you. **Discovery finds the brief is wrong:** stop, change-request issue, impact analysis, you decide. **Review finding disputed:** Reviewer cites standard/AC; PM adjudicates in scope; you if material. **Security vs deadline:** Security wins until you record accepted risk. **Model/privacy unverified:** readiness gate keeps sessions off. **Concurrent edits to the repo:** stop the overlap, reconcile, preserve others' work (AGENTS.md §2).

## 5. Reading order & context budget

`AGENTS.md` → `project.yaml` → `phase-state.md` → issue → artifact. Don't load everything; path-reference rather than paste; ≤2 skills per task unless PM approves; Open Knowledge retrieval for narrow cited questions.

## 6. Keeping the harness honest

After any permission/config change re-run `validate-harness.ps1` (static) and, when model readiness allows, `negative-tests.md` (runtime). CI runs `harness-validation.yml`. The rule that closes every gap: **approved ≠ implemented ≠ verified** — a control is real only when a test proves it blocks. Log evidence in `implementation-log.md`; record choices in ADRs and the register.

## 7. Start here checklist (new instance)

`init-project.ps1` done → `validate-harness.ps1` PASS → `opencode debug agents` shows 7 roles → GitHub controls active (protection/CODEOWNERS/labels/production Environment) → data policy + lifecycle profile confirmed in `project.yaml` → `/status` → Phase 1 via `/pm`. If readiness is `gated`, operate read-only/propose until provider privacy + structured-output are verified.
