# AIDLC Harness — GitHub Governance

> **Status:** Core harness specification (Layer A) · harness 1.0.0 · 2026-11-09. Mechanically generated instance artifacts live in `harness/kit/github/`; this document governs their meaning.
> **Depends on:** `workflow-and-governance.md`, `security-and-permissions.md`

---

## 1. Principles

GitHub is the identity and control plane: OpenCode blocks tools; only GitHub attributes approval to the owner, enforces branch protection, and gates production deployment. One issue per work item; one PR per change set; required checks are non-negotiable; no agent merges; traceability by link, never by duplication.

## 2. Repository and access

Private by default; single repository for product + harness instance + docs; `main` protected; agent access via local `gh` CLI with the owner's token (OD-08); bot identities only by explicit owner decision (OD-19/22 — approvals require distinct identity, otherwise advisory-only forever). Token scope requirements: `repo`; `project` + `read:project` for Projects v2 (OD-09); `workflow` for pushing workflow files. Missing scopes are owner actions, never silent fallbacks.

## 3. Branching model

```
main                    protected; always deployable
feat/<issue>-<slug>     feature      fix/<issue>-<slug>    docs/<issue>-<slug>
chore/<issue>-<slug>    tooling/harness      tests/<issue>-<slug>   spike/<issue>-<slug>
epic/<slug>             optional integration branch
phase/<n>-<name>        phase-state PRs only        release/<version>  optional
```
Agents push only the scoped prefixes the generated Developer file allows (feature branches); `main`, `phase/*`, `release/*` and force/delete pushes are denied locally **and** rejected by GitHub. Lowercase kebab naming; one issue per branch; never force-push shared branches.

## 4. Pull requests

Required body content (template enforced): `Closes #<issue>`, `Req: <prefix>-REQ-###` (or justified `N/A`), summary, test evidence (commands + results), review evidence, security impact, risk/rollback, checklist. Review requirements by change type: every PR → Code Reviewer advisory + owner approve/merge; sensitive (auth/access-control/data/deps/deploy/secrets) → + Security Monitor; material architecture → + owner-approved ADR; design-system/UI → Designer review notes; docs/harness → PM + owner CODEOWNERS; phase-state → owner only; release → owner + QA sign-off. Merge: squash for features/fixes, merge-commit for epics/releases; delete branch after; never merge with failing checks or without the gate-issue link on phase PRs. Agent verdicts `[advisory:<role>]` never satisfy required reviews (OD-19; policy-denied approve verbs; branch protection requires owner/Code-Owner approval, tested negative).

## 5. Issue forms

Generated from `harness/kit/github/ISSUE_TEMPLATE/*.tmpl` with project prefix, areas, and profile phases substituted. Types: feature, requirement, bug, investigation, qa, change-request, security, docs, refactor, phase-gate, harness-improvement (+ `config.yml` disabling blanks). Every form enforces: summary, context, outcome, scope, acceptance criteria, requirement IDs, phase, area, priority, dependencies, risks, DoD, owner-decision flag. Issue forms are the quality gate; free-form issues are disabled.

## 6. Labels

Taxonomy in `harness/kit/github/labels.json` → `sync-labels.ps1` creates/updates: `type:*` (exactly one), `phase-*` (profile-derived, exactly one), `area:*` (from `project.yaml`), `priority:p0-p3`, `risk-*`, plus `blocked`, `needs-approval`, `security`, `experimental`, `good-first-task`. **Status is not a label** (Projects v2 owns it, OD-06). No ad-hoc labels: extend the taxonomy doc first.

## 7. Projects v2 (when enabled)

Fields: Status (Backlog/Ready/In Progress/In Review/In QA/Blocked/Done), Type, Phase, Area, Priority, Risk, Size, Target release. Mapping and automation per `workflow-and-governance.md` §6: PR open → In Review; merge → In QA; QA sign-off → Done; close at owner acceptance; `blocked` label + Status=Blocked together. If scopes are absent, the fallback (labels-as-status) is an **owner decision**, not a silent downgrade.

## 8. Duplicate prevention

PM procedure before `gh issue create`: search open+closed by keywords and requirement ID; search PRs; link or reuse; record the duplicate check in the new issue; uncertain → draft locally or ask owner. CI policy (`pr-policy.yml`) enforces link/ID/label fields on PRs.

## 9. Traceability

ID scheme (project prefix from `project.yaml`): REQ/US/AC/TC/DEF/DEC/ADR/CR + knowledge types. `docs/project/traceability.md` traces important requirements end-to-end; trivial work untraced; PM audits orphaned requirements/untested ACs monthly; optional Node/CI validator (external tooling) once IDs exist.

## 10. Actions and environments

Workflows (generated where stack-independent, enabled progressively): `harness-validation.yml` (always — structure, placeholders, config shape), `pr-policy.yml` (always once PRs exist), `ci.yml` (skeleton → real commands at scaffold), `security.yml` (dependency audit + secret scan once manifests exist; third-party Actions pinned by SHA + owner review), later `preview/deploy-staging/deploy-production/backup-verify/traceability` per project. Required checks minimum: baseline + policy (+ CI once real). Production: `production` Environment with owner required reviewer; short-lived credentials; destructive operations a separate confirmed workflow; smoke tests after deploy; rollback documented and rehearsed. Environments map: `preview` (auto, non-prod data), `staging` (optional reviewer), `production` (owner), plus any data-destructive gate.

## 11. Branch protection / CODEOWNERS

Rules on `main`: require PR; require approval satisfiable **only** by owner/Code Owner; require CODEOWNERS review; required status checks; up-to-date branches; conversation resolution; block force-pushes and deletions; restrict pushes to owner. `release/*` adds QA sign-off check; `phase/*` owner-only merge. CODEOWNERS (generated): harness/config/governance/status/decisions/knowledge paths → owner. Branch protection is the primary defence against a compromised or confused agent reaching `main`.

## 12. Operational constraints register (instance)

Each instance records its own: token scope gaps, plan-level assumptions (rulesets/Environments/Projects availability), Actions minutes budget, reviewer queue (single owner) with the mitigations: batched gate requests, async issue approvals, lean CI, heavy scans nightly.

## 13. Implementation checklist

Repo private + `main` default; scopes refreshed/recorded; labels synced; Projects fields created or fallback approved; templates + PR policy + CODEOWNERS live; protection/ruleset active with negative test (agent push rejected; advisory comment insufficient); `production` Environment reviewer = owner; CI/security workflows real at Phase 4/6; traceability validation once IDs exist; agent-cannot-merge/deploy proof logged.
