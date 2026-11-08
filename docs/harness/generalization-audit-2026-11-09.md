# AIDLC Generalization — Audit and Gap Analysis

> **Date:** 2026-11-09 · **Method:** complete read of all harness documents (15), all `.opencode/` agents and commands, `.github/` governance, `docs/project/`, root config, the AI BA Harness reference handbook, and live verification against OpenCode 2.2.5 runtime (`opencode debug agents` ×2, official V2 docs: permissions, agents, plugins, config schema) plus `gh auth status`.
> **Legend:** `[VERIFIED]` runtime/file inspection · `[APPROVED]` owner decision on record · `[GAP]` required and absent · `[PARTIAL]` present but incomplete.

---

## 1. Capability classification

### 1.1 Documented and implemented `[VERIFIED]`

OpenCode capability matrix (accurate on every re-checked point); seven-agent hierarchy with models/steps/skill allow-lists loading in `opencode debug agents`; nine commands with `subagent: false` (OD-03); governance spine (owner-only merge, advisory verdicts OD-19, phase gates, OD-18 material threshold, decision register DP-DEC-001…021, phase-state file, gate process); knowledge split with authority/reading order; GitHub local artifacts (11 issue forms, PR template, CODEOWNERS, 3 placeholder workflows, 37 labels remote); skills inventory + OD-02 design ownership; 41 project skills installed with provenance; evidence culture (task envelope, result contract, DoD, anti-patterns).

### 1.2 Partially implemented `[PARTIAL]`

| Capability | Gap at audit |
|---|---|
| Permission enforcement (OD-16/21) | `shell * ask` baseline (not deny); no per-agent shell allow-lists; `policies` unused; `gh pr review -a`, `gh auth token`, `gh secret` not denied; `DESIGN.md`/status editable by unauthorized roles |
| Delegation (OD-04) | `general`/`explore` allow-listed (privilege-escape) |
| Agent-rule override hole | `firecrawl_*`/`browseros_*` allowed at agent level, silently beating project denies (last-match-wins) `[VERIFIED]` |
| GitHub control plane (WP-3) | repo + remote exist; no push/default branch/protection/Projects/Environment; scopes still `repo,gist,read:org,admin:public_key` `[VERIFIED 2026-11-09]` |
| Knowledge management | Open Knowledge designed, zero config; BA lacks benchmark depth (no KB/staging/critic/authority-check/intake/ask) |
| Lifecycle | 6 phases, no operations/maintenance; no tailoring profiles; dependency management informal |
| Ops | runbooks drafted; workflows placeholder |

### 1.3 Planned, not implemented at audit start

OD-21 remediation (`implementation-spec-2026-11-09.md` "not applied"), Open Knowledge pilot, runtime negative tests, fresh-session phantom-skill check, delegation pilot, independent review. **Mid-audit update:** a concurrent owner session applied the agent-permission half of the remediation and staged then applied a hardened root config; absorbed as baseline (see §4).

### 1.4 Missing `[GAP]`

G-01 project-agnostic structure (stack/domain/identity hardcoded across agents, config, templates, docs — new projects required manual surgery); G-02 core/config/workspace layering (no project identity file); G-03 project initialization workflow; G-04 full lifecycle (operations phase, intake); G-05 lifecycle tailoring; G-06 agent working memory; G-07 harness ADRs; G-08 validation tooling; G-09 modular integration toggles; G-10 enforcement gaps of §1.2; G-11 BA benchmark depth; G-12 doc drift (AGENTS.md staleness, delegation table vs OD-21, `git push *` caveat vs verified semantics, deprecated `mcp.<name>` config form).

## 2. Strengths preserved

Runtime-verified capability analysis; governance spine; seven-role hierarchy with least privilege; task envelope/evidence culture; skill inventory with honest risk audit; reference-harness study; OD-02 design ownership.

## 3. Weaknesses found

Project-specific foundations; enforcement holes (ask-baseline, agent-override, missing policies layer); lifecycle/knowledge/init gaps as above; all implementation uncommitted at audit start (389 files; fixed by checkpoint `6b13e14` before any modification); global-environment debt (plaintext global config credentials — owner action; 2.2.5 session_move gap; gh scopes).

## 4. Concurrent-session observation `[VERIFIED]`

00:58–01:03 another owner-run OpenCode session applied the OD-21 agent hardening (all 7 frontmatters: general/explore removed, narrow shell/edit allows added, UTF-8 BOM introduced — parse verified OK), staged `bootstrap/opencode.jsonc` (deprecated `mcp.<name>` form; kept the `firecrawl_*` agent allow), applied it to the root config, and touched one AGENTS.md blockers line. **Owner disposition (2026-11-09): session stopped; its applied changes absorbed as baseline.** This transformation supersedes the staged config with the generated instance config (fixes BOM, deprecated mcp form, and agent-override hole; adds the policies layer).

## 5. Enforcement verification notes (this audit round)

- `[VERIFIED]` Official V2 permissions doc: agent rules appended after project rules; **policies evaluate after permissions/saved approvals and can only harden** — adopted as the delegation-proof layer (ADR-H-004).
- `[VERIFIED]` Config schema keys: `permissions`, `policies`, `mcp.servers` (top-level `mcp.<name>` entries are deprecated), `experimental.subagent_depth`, `instructions`, `skills`, `references`, `plugins`, `worktree`.
- `[VERIFIED]` Built-in shipped policies: base `* allow` + `.env` ask; `explore` permits shell at base — confirming delegation must exclude built-ins.
- `[VERIFIED]` Runtime effectivity: after the concurrent session's hardening, `shell` and protected-path `edit` calls in governed sessions return hard denials (this transformation experienced both: `edit` rejected on `docs/harness/**`, `shell` rejected post-apply) — enforcement demonstrated live, and it constrained this mission's method (staged output + owner-run apply, ADR-H-006).

## 6. Conclusion

Strong single-project harness; transformation is extract-and-generalize, not rebuild. Gap register → solution mapping in the generalization design (architecture-spec §2 layers, kit+init, profiles+operations phase, policies enforcement, KB workflow, ADRs, validator). Remaining owner-level items unchanged: credential rotation, GitHub scopes/push/protection, OD-11/OD-12 inputs (project-level), OpenCode 2.2.6 decision, model-readiness verification, gated approvals identity, live-session authorization.
