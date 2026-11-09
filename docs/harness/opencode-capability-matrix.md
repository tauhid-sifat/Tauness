# OpenCode Capability Matrix — AIDLC Harness

> **Status:** Core harness specification (Layer A) · harness 1.1.0 · 2026-11-09. Baseline verified on OpenCode v2.2.5 (Windows 11, PowerShell 5.1, Node 22.19, Git 2.53, gh 2.96) against the installed runtime and official V2 documentation (permissions, agents, plugins, config schema `https://opencode.ai/config.json`). The 2026-11-02/04 baseline below is retained where re-verified; the 2026-11-09 addendum captures the re-check plus the enforcement findings that shaped ADR-H-004.

## 1. Legend

| Class | Meaning |
|---|---|
| 1 | Natively supported (config files only) |
| 2 | Supported through configuration |
| 3 | Requires external tooling (`gh`, CLIs, sandbox) |
| 4 | Requires GitHub-side enforcement (identity, protection, environments) |
| 5 | Not supported — do not design around it |
| 6 | Documented but not runtime-proven — test before relying |

## 2. Matrix (core, verified)

| Capability | Class | Evidence | Consequence for the harness |
|---|---|---|---|
| Agents (`.opencode/agents/*.md`; `description|mode|model|steps|permissions|hidden|disabled|color|request`) | 1/2 | `opencode debug agents`; V2 docs | 7 role agents executable |
| `default_agent` primary selection | 2 | docs + runtime | PM is entry point |
| V2 `permissions` array `{action,resource,effect}`; **last match wins**; base policy = `* allow` + `.env` ask | 1 | docs re-verified 2026-11-09 | Deny-by-default + allow-lists work; ordering matters |
| **Agent rules append after project rules** | 1 | docs 2026-11-09 | Agent `allow` beats project `deny` — hence: agents only re-allow narrow scope; dangerous classes live in policies |
| Child agents use **their own** permissions | 1 | docs | Delegation can't launder privileges into a child that is properly scoped |
| `policies` (`tool.use` hard-deny evaluated after permissions **and saved approvals**; can only harden; global/console policies beat project) | 1/6 | docs verified 2026-11-09; runtime precedence test pending (negative matrix) | **The delegation-proof layer** (ADR-H-004) |
| Shell scanner (PS 5.1 + bash dialects; whole-value wildcards; `cmd *` also matches bare `cmd`; fail-closed on malformed/dynamic) | 1 | docs | Allow-lists are the control; patterns are textual, not semantic |
| `external_directory` defaults ALLOW unless configured | 1 | docs | Instance sets `ask` |
| session_move external-directory approval fix | 6 | v2.2.6 changelog; installed 2.2.5 lacks it | Owner upgrade decision; interim rule: no external session moves |
| `subagent` action + `experimental.subagent_depth` | 2/6 | configured; runtime depth enforcement unproven | Negative matrix N-19…N-22 before trusting delegation |
| Commands (`.opencode/commands/*.md`; `agent`, `subagent: false`, `$ARGUMENTS`/`$n`, `!` shell blocks, nested paths) | 1 | docs + runtime | 16 commands; `subagent:false` direct-access pattern (OD-03) |
| **Command shell blocks run outside the tool permission flow** | 1 | docs | No untrusted input in `!` blocks (harness bans issue/PR text in them) |
| Skills: 3 roots, nested groups, deny via `skill` action + deny-all baseline | 1 | runtime 2.2.5 | Per-role allow-lists; phantom skills neutralized |
| `/api/skill` project listing unreliable on 2.2.5 (empty while skills load) | — | observed 2026-11-03/09 | Acceptance test = fresh-session skill advertisement, not API listing |
| MCP: project `mcp.servers.<name>` (local `type|command|cwd|environment|enabled|timeout`, remote `url|headers|oauth`); deprecated `mcp.<name>` still parsed; global servers leak into all sessions unless denied; tools are `<server>_<tool>` actions | 1 | schema pulled 2026-11-09 | Kit renders `servers` form; integrations toggle deny/ask; **never** re-allow at agent level |
| GitHub integration | 3/4 | gh only (OD-08) | Issue/PR ops via scoped `gh` allow-lists; merge/approve/deploy denied locally + enforced by GitHub |
| Branch protection/CODEOWNERS/Environments/required checks | 4 | GitHub-side | Identity-bound approvals; primary defence for `main` |
| Worktrees (`worktree.directory`, `worktree_create/list/remove`) | 1/2 | runtime | File isolation only — **never** claimed as security boundary |
| Sessions (`--continue/--session/--fork`, export) + compaction + snapshots | 1 | docs | Long-running governed work resumable |
| `--auto` auto-approves all non-denied asks | 1 | CLI | Banned in governed sessions (AGENTS.md) |
| Human approval *identity* | 5 | — | Only GitHub records it; `ask` proves nothing |
| OS sandbox / process isolation | 5 | — | External isolation (container/VM/CI) for risky execution; workstation holds no production credentials |
| Plugins/hooks (`tool.execute.before/after`, `permission.hook("evaluate")`, `shell.hook`, session hooks; local `.opencode/plugins/*.ts` auto-discovered; run with full server authority) | 2 | docs verified 2026-11-09 | **Unused** (OD-16): native permissions + policies suffice; plugin = later owner decision with security review |
| Agent `request` overlays | 6 | docs: stored, not yet sent | Do not rely on per-agent headers/temperature |
| Model routing per agent (`model: provider/model#variant`) | 2 | runtime catalog | `project.yaml.models` render; readiness gate OD-25 |

## 3. Environment facts (2026-11-09)

OpenCode 2.2.5 (npm global), Node v22.19.0, Chrome 156 (global `puppeteer-core@25.16.0`, OD-13), gh 2.96 authenticated (`repo, gist, read:org, admin:public_key` — `project`/`workflow`/`read:project` missing, owner action), git 2.53. Global OpenCode config carries third-party credentials in plaintext (owner rotation action; project denies neutralize agent access).

## 4. Verified vs assumed

**Verified by runtime/docs:** everything marked 1/3 in §2 including rule ordering, deny-all mechanics, config schema shapes, agent/command/skill loading.
**Documented, runtime-pending (6):** policy precedence under saved approvals/`--auto` (N-matrix), `subagent_depth=2` enforcement chain, fresh-session phantom-skill exclusion, Open Knowledge handshake (module off by default).
**Assumed (owner confirmations):** GitHub plan supports rulesets/Environments/Projects; provider backup capabilities; Go workspace Global privacy setting; Hy3 structured output.
