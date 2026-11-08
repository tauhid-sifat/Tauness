# Harness Implementation Log

> **Status:** Active · harness 1.0.1 · Rule: evidence only. Approval is not implementation; implementation is not verification.

## Environment (verified 2026-11-09)

OpenCode `2.2.5` (npm global) · Node `v22.19.0` · Chrome 156 at `C:\Program Files\Google\Chrome\Application\chrome.exe` · `puppeteer-core@25.16.0` global (OD-13) · Git `2.53` · gh `2.96` authenticated `tauhid-sifat`, scopes `repo, gist, read:org, admin:public_key` (no `project`/`workflow`/`read:project`) · repo remote `tauhid-sifat/dental-park` (private, created, **no push authorization**).

## Historical packages (condensed; full text in Git history before restructure)

- **WP-0 (complete 2026-11-04):** ten spec docs + OD-01…20 owner-approved; register DP-DEC-001…021.
- **WP-1 (implemented):** AGENTS.md/opencode.jsonc/docs-project created; `opencode debug config` parsed; commit held for authorization at the time.
- **WP-2 (implemented):** 7 agents + 9 commands created; static config checks passed 14/14 (debug agents listing, delegation matrix, protected edits, deny baselines). Runtime negative tests + depth-2 pilot never executed — still pending.
- **WP-3 (partial):** private repo + 37 labels + templates/workflows local; **blocked:** scope refresh (interactive timeout), Projects, branch protection/Environment (needs push authorization).
- **WP-4 (partial):** register/traceability/templates created.
- **WP-5…WP-9 (blocked/not started)** per roadmap table: pilots blocked on apply/GitHub/OD-10/OD-11/OD-12.
- **OD-13 execution (2026-11-04):** `npm install -g puppeteer-core@25.16.0`; Chrome 156 launch + Hallmark capture smoke verified; rollback `npm uninstall -g puppeteer-core`.
- **OD-01 execution (2026-11-03):** upgrade 2.1.4→2.2.5 with backup at `%TEMP%\opencode\backup-2.1.4-20261103-212825`; skill advertisement anomaly (`/api/skill` empty; fresh session listed 41 incl. project skills).
- **2026-11-08/09 finalization + completion reports:** architecture docs closed; implementation-spec authored (not applied then); Open Knowledge evaluated (Windows archive, npm 404, handshake untested); OD-26 recorded.
- **Concurrent-session hardening (2026-11-09, 00:58–01:10):** owner-run second session applied OD-21 agent-frontmatter hardening + a first hardened root config (staged via `bootstrap/`), then was stopped by owner decision; its work absorbed (BOM'd agent files parsed correctly; deprecated `mcp.<name>` config form and the retained `firecrawl_*` agent allow were identified and are corrected by this mission's generated config).

## 2026-11-09 — AIDLC generalization (this mission)

| Action | Result |
|---|---|
| Full repository audit (all docs/config/instance files; runtime + official-schema re-verification) | `generalization-audit-2026-11-09.md` |
| Pre-change backup | `%TEMP%\opencode\aidlc-backup-20261109-010215` (7.84 MB incl. .git) + checkpoint commit `6b13e14` (389 files; first-ever commit of harness files) |
| Core kit authored (`harness/`) | README, HARNESS-VERSION 1.0.0, project.yaml.tmpl, config/opencode.jsonc.tmpl (permissions+policies+mcp.servers render slots), AGENTS.md.tmpl, 7 agent templates, 15 command templates, lifecycle/profiles.yaml (5 profiles incl. new Phase 7), github templates (CODEOWNERS/PR/11 issue forms/workflows/labels.json), docs/project skeleton + KB templates, scripts (lib-render, lib-apply, init-project, apply-harness-change, validate-harness, sync-labels, negative-tests) |
| Enforcement design decision | `policies` hard-deny layer adopted after docs verification (agent rules append last → agent allows can beat project denies; policies evaluate after everything and can only harden). Fixed the observed `firecrawl_*` override; dangerous git push shapes corrected (feature pushes allowed via scoped agent allow-lists — ADR-H-009) |
| Governance decision path | Protected-path denies blocked agent writes to `AGENTS/opencode/.opencode/.github/docs/harness` — experienced live; owner chose staged output + owner-run apply (ADR-H-006); zero deny-rule bypasses performed |
| Dental Park instance rendered (preview) | `harness/staging/instance/**`: project.yaml, opencode.jsonc, AGENTS.md, 7 agents, 15 commands, .github (12 forms+config+CODEOWNERS+PR+4 workflows), docs/project new files (knowledge README+3 templates, working README, status README+phase-state, updated decision register) |
| Core docs rewritten (14 staged) | architecture/agent/workflow/security/github/knowledge-management/project-initialization/using-the-harness/skills-inventory/capability-matrix/repository-structure/open-decisions(+OD-27…32, OD-26 resolved)/roadmap/this log + `adr/` (9 ADRs) |
| Validation | `validation-report-2026-11-09.md` — static review + logic verification via executable JS twins of the renderer (5 generator bugs found and fixed pre-apply: indented-key parser, block comma join, missing render token, labels placeholder leak, duplicate rule line); runtime items explicitly NOT executed (shell policy-denied) |
| Root files updated directly (unprotected) | `README.md` (harness + example project framing), `.gitignore` (working inbox) |
| Kit relocated to its own home repository | Public repo `Tauness`; core docs seeded to `docs/harness/` (19 files incl. `adr/INDEX.md`); `harness/staging/` deleted (Layer C content in a Layer A repo), `harness/reports/` ignored; Dental Park instance frozen and untouched (ADR-H-010) |
| Kit defects fixed (5, all live simultaneously) | (1) non-ASCII literals in all 6 `.ps1` files made `lib-render.ps1` unparseable under Windows PowerShell 5.1 (BOM-less UTF-8 read via ANSI codepage; U+2192 decodes to bytes containing an apostrophe); (2) stray quote in `Get-StackPolicyDenies` broke parsing independently; (3) `New-RenderContext` read `HARNESS-VERSION` from `kit/`, where it does not live; (4) `init-project.ps1` assigned `$Target` from `Resolve-Path`, which returns nothing for a not-yet-existing directory, so creating a new project always failed; (5) `lib-apply.ps1` stripped the 5-char `.tmpl` suffix by removing 6 chars, truncating every generated extension (`business-analyst.m`, `bug.ym`, `phase-state.m`) |
| Validator scope corrected | Placeholder sweep now covers generated files only (kit scripts hold the substitution code; `docs/harness` documents the token syntax - both were false failures); `.Count` calls wrapped for `Set-StrictMode` so `agents:count`/`commands:count` can no longer error out silently and be skipped rather than failed |
| Kit self-test added (ADR-H-011) | `tests/check-sources.ps1` (ASCII-only sources, tokenizer parse, template-slot producer audit, kit contract by name/count) + `tests/render-and-validate.ps1` (5 lifecycle profiles + all-integrations variant; asserts artifacts, toggle effects, policy/permission denies, then requires validator exit 0 and named PASS markers) + `.github/workflows/kit-validation.yml`. 6/6 variants clean at 51 PASS / 0 FAIL; teeth verified by re-injecting defect (5): 14 diagnostics, exit 1 |
| Version | `HARNESS-VERSION` 1.0.0 -> 1.0.1 (rendered output materially changed: correct filenames, working init path) |
| Known gap open | Renderer addresses files with Windows separators, so `init-project.ps1`/`validate-harness.ps1` remain Windows-only; Linux/macOS exercise the static policy only |

## Outstanding evidence (unchanged unless marked)

Runtime negative matrix; delegation/depth-2 pilot; fresh-session phantom-skill check; GitHub activation suite; Open Knowledge handshake pilot (module off); independent review session; OD-05 conditions verification; OD-11 input; OD-12 evidence; OD-10 connectivity; credential rotation; 2.2.6 upgrade decision; apply + commit of this transformation.
