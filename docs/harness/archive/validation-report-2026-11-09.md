# Validation Report — AIDLC Harness 1.0.0 Transformation

> **Date:** 2026-11-09 · **Method:** audit-time verification (runtime + official docs + file review) + post-implementation static review.
> **Honest scope:** runtime/apply-time tests are listed as PENDING because this session's tool permissions (the harness's own deny layer, enforced live on 2026-11-09) prohibit shell/git execution; owner-run scripts carry them.

## 1. Verified during the mission

| # | Check | Evidence | Result |
|---|---|---|---|
| V-01 | OpenCode V2 permissions semantics (ordered rules, last match wins, agent rules append, deny/ask/allow, wildcards, ` *` matching bare commands, fail-closed scanner, base policy shape, built-in agent policies) | Official docs re-fetched 2026-11-09 | **Pass** — core config design conforms |
| V-02 | `policies` semantics: evaluate after permissions + saved approvals, can only harden; `tool.use` shape | Official docs | **Pass** — adopted as delegation-proof layer (ADR-H-004) |
| V-03 | Config schema keys: `permissions`, `policies`, `mcp.servers` (top-level `mcp.<name>` deprecated), `experimental.subagent_depth`, `worktree.directory`, `instructions` | `https://opencode.ai/config.json` fetched + parsed 2026-11-09 | **Pass** — generated config uses current forms (fixes staged spec's deprecated `mcp.<name>`) |
| V-04 | Agents frontmatter (description/mode/model/steps/permissions), built-ins (build/plan/general/explore), override/disable mechanics | Official docs + `opencode debug agents` (pre-hardening runs) | **Pass** |
| V-05 | 7 hardened agent files (concurrent session's versions) parse on 2.2.5 despite BOM | `opencode debug agents` exit 0, all 7 listed | **Pass** (staged versions BOM-free by design) |
| V-06 | gh token scopes current-state | `gh auth status` (redacted) | **Confirmed gap**: missing `project`, `workflow`, `read:project` → owner action, not a code defect |
| V-07 | Enforcement live-effectivity | Session experienced hard `permission.rejected` on protected-path `edit` **and** on `shell` after the concurrent session applied hardening | **Pass** — deny layer demonstrably enforced mid-session; transformation path adjusted to staged-output + owner-apply (ADR-H-006) |
| V-08 | Pre-change backup + checkpoint | `C:\Users\tauhi\AppData\Local\Temp\opencode\aidlc-backup-20261109-010215` (7.84 MB incl. .git); commit `6b13e14` (389 files, first commit of harness) | **Pass** — full rollback exists |
| V-09 | Kit completeness (files present + internally consistent by review): templates ×(1 project.yaml + 1 config + 1 AGENTS + 7 agents + 15 commands + github 12+PR+CODEOWNERS+labels+4 workflows + docs/project tree + 2 roots), scripts ×7 | Directory listings | **Pass** |
| V-10 | Staged instance completeness (project.yaml, opencode.jsonc full re-read incl. policies tail; 7 agents; 15 commands; 12 forms + config + CODEOWNERS + PR + 4 workflows; docs/project new files; decision register DP-DEC-022…030) | File re-reads | **Pass** |
| V-11 | Cross-consistency: delegation matrix ↔ agent subagent allows ↔ docs (agent-spec §1.4, AGENTS §5); profile phases ↔ phase-state ↔ issue-form dropdowns ↔ label generator; model IDs ↔ OD-05 approved routing ↔ project.yaml; feature-push design (permission deny + scoped agent allow + policy shapes) ↔ ADR-H-009 ↔ negative tests N-10/N-11 | Review | **Pass** |
| V-12 | Placeholder discipline: every `{{...}}` token in templates is produced by project.yaml fields or the renderer (audited token list against New-RenderContext/New-RenderSlots) | Review | **Pass** — validator `validate-harness.ps1` re-checks at apply |

## 2. Pipeline dry-verification of the scripts (Code Mode JS twins of the renderer logic, 2026-11-09)

Because agent shell is policy-denied, the PowerShell scripts cannot be executed from this session. As the strongest available substitute, the three highest-risk logic paths were ported to executable JavaScript (Code Mode) against the real file contents and passed; two latent generator bugs were found and fixed in the PowerShell sources during this review:

| Fix | Bug | Effect had it shipped |
|---|---|---|
| **F-1 parser** (`lib-render.ps1`) | `Get-ProjectConfig` required keys at column 0; indented leaves (`  name:`) were never captured | Rendered config would contain empty project values — silently gutted rules; **critical** |
| **F-2 join** (`lib-render/lib-apply`) | MCP/stack generated blocks trimmed each other's commas | Generated `opencode.jsonc` would fail JSON parsing whenever `deploy_commands` were present |
| **F-3 token** (`lib-render.ps1`) | `ONE_LINE_PROJECT_DESCRIPTION` not in render context | init-project hard-failed on leak check |
| **F-4 labels** (`kit/github/labels.json`) | Contained `{{...}}`-style tokens while copied verbatim (not a `.tmpl`) | CI + validator placeholder-leak failures |
| **F-5 duplication** (`security-monitor` template) | Data-policy line rendered twice | Cosmetic; removed |

JS-twin verification results (executed): 38-key parse of the real staged `project.yaml` with all expected values; JSONC assembly parses in both stack-present and stack-empty shapes; profile-phase parser handles multi-line and inline forms. **These verify logic, not PowerShell syntax** — PS-level errors (e.g. cmdlet parameter edge cases) remain possible and are the known residual apply risk (fix-forward per handover §2).

## 3. Pending owner-run verification (designed, scripted, not executed here)

| # | Test | How | Blocks |
|---|---|---|---|
| P-01 | Apply regeneration: `apply-harness-change.ps1 -DryRun` then real apply + backup | PowerShell (owner) | Everything below |
| P-02 | `opencode debug config` parses generated config; `opencode debug agents` lists 7 | After P-01 | Live validity |
| P-03 | Static validator suite | `validate-harness.ps1` (JSONC parse, BOM, leaks, policies, matrix drift, MCP audit, docs, shapes, secret scan) | Merge-readiness |
| P-04 | Runtime negative matrix N-01…N-30 + GitHub-side G-01…G-04 | `harness/scripts/negative-tests.md` — requires model sessions ⇒ OD-25/OD-05 readiness first | Delegation trust, P4+ |
| P-05 | Depth-2 delegation pilot + child-permission proof | same doc | OD-04 confidence |
| P-06 | Fresh-session skill advertisement + phantom exclusion | fresh `opencode run` listing | OD-14 close-out |
| P-07 | Commit + push + GitHub activation (protection/CODEOWNERS/checks/Environment/labels/Projects) | git + gh (owner; push needs explicit authorization) | WP-3 completion |
| P-08 | CI `harness-validation.yml` runs green on the PR | GitHub | WP-3 evidence |
| P-09 | Independent review of the transformation by a separate session | owner-launched | Mission step 7 |
| P-10 | Open Knowledge pilot (module currently `false`) | knowledge-management §8 | optional WP-10 |
| P-11 | the originating project instance docs refresh (README/knowledge pointer lines, traceability ID list) | small staged doc updates + PM edit pass | post-apply tidy |

## 3. Known limitations accepted (disclosed)

1. Shell pattern enforcement is textual, not semantic (mitigated by allow-lists + policy shapes; scanner fails closed).
2. `policies` precedence on 2.2.5 is documented but needs runtime proof (P-04) — no enforcement claim is made before it.
3. Built-in `general`/`explore` cannot be removed by this config (they may be disabled via `agents` overrides; deliberately not done to preserve OpenCode internals; delegation denies neutralize reachability — proven at P-04/P-05).
4. Saved "always allow" approvals are project-persistent by design; governance bans `--auto` and mandates allow-list review in retros.
5. Runtime validation (P-04) cannot execute while model readiness is `gated` (OD-25) — owner-side verification first.
6. This session cannot commit (shell denied) — the transformation is staged; commit is part of the owner apply step. The live repo still runs the *hardened baseline* (concurrent session) until apply; that state is safe but not yet generalized.
