# ADR-H-001 — Generalize the harness into core/configuration/workspace layers

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Owner (mission) / Architect (proposal)
- **Context:** The harness was built around one project (Dental Park). Stack, domain, GitHub identity, ID prefixes, and deploy CLIs were hardcoded across agents, config, templates, and docs, so any second project required manual surgery.
- **Decision:** Split into Layer A **core harness** (`harness/` kit + `docs/harness/` specs — never project-specific), Layer B **project configuration** (`project.yaml` — the single per-project input), Layer C **project workspace** (`docs/project/`, code, generated instance files). Instance files are generated artifacts; rules change only by editing the kit and owner-applying.
- **Consequences:** upgrades propagate mechanically; doc/config drift is detectable; project work can never contaminate the core; one more generation step (mitigated by init/apply scripts). Dental Park becomes an example instance, not the foundation.
- **Supersedes:** implicit project-coupled structure of the 2026-11-04 baseline.

# ADR-H-002 — Kit templates with `{{PLACEHOLDER}}` substitution rendered from project.yaml

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Architect (routine)
- **Context:** Templates must render for arbitrary stacks without YAML-parsing complexity in Windows PowerShell 5.1 (no `utf8NoBOM`, no parser module, dependency restrictions).
- **Decision:** Plain-text templates with `{{TOKEN}}` substitution + a constrained project.yaml subset parser (flat keys, inline arrays, indentation sections). Render slots inject whole rule blocks (agent command lists, MCP denies, policy items). Unresolved tokens after render = hard failure (leak detection). Output is UTF-8 **without BOM** (PS 5.1 `Set-Content -Encoding UTF8` writes a BOM; use .NET `File.WriteAllText`).
- **Consequences:** zero external dependencies; deterministic output; format discipline on project.yaml; parser documented limits accepted (complex structures are not needed).
- **Alternatives rejected:** powershell-yaml (dependency), full JSON config (worse comments/human editing), PowerShell classes (5.1 friction).

# ADR-H-003 — Lifecycle: seven phases with owner-approved profiles for tailoring

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Owner (mission mandates full lifecycle + tailoring)
- **Context:** The approved baseline covered six phases ending at Deployment. The mission requires ongoing maintenance coverage and forbids forcing every project through every phase.
- **Decision:** Canonical phase set = Discovery, UI/UX Design*, Architecture, Development, QA, Deployment, **Operations & Maintenance (steady state)**. Five profiles (full/lean/headless/brownfield/micro) select active phases; selection is an owner decision recorded in `project.yaml` and rendered into `phase-state.md`; skips stay visible with justification; governance (gates, OD-18, evidence) is identical across profiles.
- **Consequences:** covers idea→operations without ceremony inflation; operations phase formalizes `/ops`, incidents (OD-20), upkeep rhythms; profile table is the single tailoring mechanism.
- **Preserves:** all six original gates and OD-18 material rules.

# ADR-H-004 — `policies` as the delegation-proof hard-deny layer

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Architect (mission: enforcement must survive delegation/shell)
- **Context:** OpenCode permission rules are ordered with last-match-wins and agent rules append **after** project rules — an agent allow silently re-opens project denies (observed: `firecrawl_*`). `--auto` auto-approves anything not denied; saved approvals are project-wide allows.
- **Decision:** Two-tier enforcement: (1) **permissions** layer — deny-by-default shell/delegation/skills/MCP + per-role allow-lists for routine scope; (2) **policies** layer (`tool.use` hard denies, evaluated after permissions + saved approvals + agent rules) for everything irreversible or authority-bearing: dangerous git, GitHub authority verbs, shell write-cmdlets, nested runtimes, publishing, secret-read shapes, plus project `deploy_commands`/`hard_deny_commands`. Agents never allow-list anything the policy layer denies. `validate-harness.ps1` FAILs any agent that re-allows denied MCP classes.
- **Consequences:** governance boundaries cannot be bypassed by configuration drift, delegation, or approval fatigue; policy semantics are version-dependent → re-verified by negative-test matrix each upgrade.
- **Alternatives rejected:** guardrail plugin (OD-16 forbids without proven gap; native policies close the gap); relying on agent prompts (not enforcement).

# ADR-H-005 — Knowledge: staging + critic + item acceptance; optional Open Knowledge retrieval

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Owner (mission: OpenKnowledge as part of KM; BA benchmark quality)
- **Context:** Reference AI BA Harness demonstrates a materially deeper BA discipline: atomized knowledge with IDs/statuses/source records, extract→judge→stage→critic→item-accept, RACI authority checks, `/ask`, health reviews. Existing harness lacked it. OD-23 already authorized Open Knowledge as retrieval layer with Git canonical.
- **Decision:** Adopt the knowledge-base model into the core (`docs/project/knowledge/` + `/intake` + `/ask` + critic pass). Critic is the **code-reviewer** agent delegated read-only (its zero-write permissions make it structurally independent). Open Knowledge remains an optional, default-off `project.yaml` integration: `mcp.servers` local read-only entries, telemetry off, bundles exclude secrets/personal data, proposals via Git only.
- **Consequences:** BA capability meets benchmark; single source of truth preserved (retrieval never stores); BA→reviewer delegation is a recorded amendment to OD-04's matrix (scoped: critic only, no approval transfer) — flagged to owner as OD-29.
- **Rejected:** Jira/Confluence-centric KB (external dependency; harness ledger is GitHub), second content DB, agent-written MCP knowledge.

# ADR-H-006 — Initialization/apply as the only write path for instance files

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Owner decision 2026-11-09 (staged output + owner-run apply)
- **Context:** Protected-path denies correctly block agents (including this transformation) from editing `AGENTS.md/opencode.jsonc/.opencode/.github/docs/harness` — enforcement working as designed. Bypass via shell would violate the harness's own non-negotiable and the mission's anti-bypass rule.
- **Decision:** All harness changes are produced by the agent into `harness/` (kit/staging/reports — unprotected) and land in protected locations only through owner-run `apply-harness-change.ps1` (backup + diff plan + render + optional staged-doc acceptance) or `init-project.ps1` for new projects. Live validation happens post-apply with `opencode debug` + validators + negative matrix.
- **Consequences:** "owner-approved harness change" becomes a literal mechanism, not prose; agent and owner powers are cleanly separated; validation rounds belong after apply.
- **Rejected:** shell-writes to protected paths (bypasses deny); permanent relaxation of edit denies (weakens protection for all sessions).

# ADR-H-007 — Role architecture stays seven; mission roles map to duties (OD-26 resolved)

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Owner (mission §6 preserves approved hierarchy; no demonstrable reason to change)
- **Context:** OD-26 asked whether Software Architect / Independent Reviewer needed new agents. The mission's own instruction preserves approved delegation/hierarchy absent technical necessity; the completion doc recommended Option 1.
- **Decision:** Preserve PM + BA + Designer + Developer + QA + Code Reviewer + Security Monitor. Architect/DB/DevOps = Developer duties; Independent Reviewer = Code Reviewer; Product Manager/Research Analyst/Technical Writer duties distributed (PM/BA+PM/every role + `writing-for-agents`). Duty→role mapping documented in architecture-spec §6 so mission wording and configuration agree.
- **Consequences:** delegation matrix, commands, and OD approvals remain stable; agent count cost stays low. Revisit only if a duty demonstrably needs separate enforcement (would be an OD-18 harness change).

# ADR-H-008 — No volatile state in AGENTS.md; status lives in machine-readable files

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Architect (routine, from audit finding)
- **Context:** Embedded "current blockers"/WP status in AGENTS.md went stale against implementation reality — the exact doc-drift the mission prohibits.
- **Decision:** AGENTS.md carries only stable policy. Volatile state lives in `docs/project/status/phase-state.md`, `blockers.md`, `docs/harness/implementation-roadmap.md` + `implementation-log.md`; AGENTS.md links to them and validator checks their shape.
- **Consequences:** one source per volatility class; the 2-minute `/status` command reads the same files agents do.

# ADR-H-009 — Feature-branch pushes: permission-scoped, not policy-blanket

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Architect (routine, correcting audit-time draft)
- **Context:** A first-pass policy denied `git push *` wholesale, which would also break the approved Developer feature-branch push. The over-broad `git *push*` wildcard also false-positives on benign commands (`git add push.js`).
- **Decision:** Push control split: permission layer denies all push; Developer agent allow-lists explicit `git push [origin|-u origin] <feature-prefix>/*`; policies hard-deny only irreversibility shapes (`--force`, `-f`, `--delete`, `--mirror`, protected refs, `git.exe` variant, `reset --hard`, `clean`, `branch -D`, `filter-branch`). GitHub-side protection remains the final control.
- **Consequences:** least privilege without breaking the approved workflow; no wildcard false-positive hazards; N-10/N-11 negative tests pin behaviour.

# ADR-H-010 — The kit has its own home repository; core docs live at `docs/harness/`

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Owner
- **Context:** The kit was developed inside the Dental Park repository while the project was its only instance. Layer A (core harness) and Layer C (one project's workspace) shared a tree, and the generalized kit still referenced `docs/harness/` as canonical while holding no copy of it.
- **Decision:** This repository is the kit's home; the Dental Park instance is frozen and is no longer a development site. Core specifications, audits and ADRs are seeded to `docs/harness/` at the repo root — not inside `harness/` — because `init-project.ps1` resolves `DocsHarnessPath` as `<repo root>/docs/harness` and `validate-harness.ps1` section 7 requires those 13 documents there. `harness/staging/` (rendered project values, Layer C) and `harness/reports/` (generator output) stay git-ignored; the stale staging tree was deleted after seeding.
- **Consequences:** one place to change the harness; a rendered instance is reproducible from kit + `project.yaml` alone; layer separation is enforced by the ignore rules rather than by convention; existing instances keep their own history and are unaffected.
- **Rejected:** publishing `staging/instance/` (project identity in a Layer A repo); `harness/docs/` (breaks the documented layout and the renderer's path contract).

# ADR-H-011 — Kit self-test is the development gate; script sources must be ASCII

- **Status:** accepted · **Date:** 2026-11-09 · **Decider:** Architect (from defects found by running the kit)
- **Context:** Building the first automated check for the kit exposed that nothing had ever run it end to end. Five defects were live simultaneously: (1) `lib-render.ps1` contained `U+2192` in BOM-less UTF-8, so Windows PowerShell 5.1 decoded it through the ANSI codepage into bytes containing an apostrophe and refused to parse the file — the scripts were unrunnable on the platform the kit claims to support; (2) a stray quote in `Get-StackPolicyDenies` broke parsing independently of encoding; (3) `New-RenderContext` read `HARNESS-VERSION` from inside `kit/`, where it does not live; (4) `init-project.ps1` overwrote `$Target` with `Resolve-Path`, which returns nothing for a directory that does not exist yet, so creating a new project always failed; (5) `lib-apply.ps1` stripped the 5-character `.tmpl` suffix by removing 6 characters, so every generated file lost its last extension letter (`business-analyst.m`, `bug.ym`, `phase-state.m`) and downstream checks silently skipped rather than failing.
- **Decision:** `tests/check-sources.ps1` (static: ASCII-only script sources with no BOM, tokenizer parse of every script, every template slot must have a producer, kit contract asserted by filename and count) plus `tests/render-and-validate.ps1` (renders a throwaway instance per lifecycle profile and for the all-integrations variant, asserts artifact names/counts/toggle effects, then requires `validate-harness.ps1` to exit 0 **and** to have recorded specific `[PASS]` markers). `.github/workflows/kit-validation.yml` runs the render test on Windows and the static policy on Windows, Linux and macOS. Glyphs needed in rendered output are emitted from code points, never as source literals.
- **Consequences:** template and renderer edits are verified before merge; a validator check that errors out can no longer masquerade as a pass (marker assertions); the harness gains a reproducible development loop it did not previously have. Known gap: the renderer still addresses files with Windows separators, so instance rendering is exercised on Windows only until those literals are converted.
- **Rejected:** trusting exit codes alone (an errored check records nothing); scanning all instance files for placeholder leaks (the kit's own scripts and core docs legitimately contain token syntax — the sweep is now scoped to generated files).
