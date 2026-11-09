# AIDLC Harness — Security and Permissions

> **Status:** Core harness specification (Layer A) · harness 1.1.1 · 2026-11-09. Incorporates OD-21 hardening as implemented configuration (not aspiration), the `policies` discovery from the 2026-11-09 audit, and the project-scoped data rules moved to `project.yaml`.
> **Depends on:** `agent-specifications.md`, `workflow-and-governance.md`, `opencode-capability-matrix.md`

---

## 1. Security model

Every harness session assumes: some data may be personal or regulated; the workstation is trusted but is **not** a boundary between agents; prompt injection via issues, web content, documents, and skill text is realistic; agents can cause irreversible damage with broad shell access; OpenCode has **no OS sandbox** and shell runs with host-user authority.

Model: **least privilege + isolation + verifiable approval + defence in depth.**

1. **Least privilege** — deny-by-default shell/delegation/skills/MCP; per-role allow-lists only as wide as the role's duty.
2. **Isolation** — branches/worktrees for files; external OS isolation (container/VM/sandbox/CI) for risky execution; per-session scoped issues.
3. **Verifiable approval** — identity lives in GitHub (approvals, merges, Environments); agent verdicts advisory (OD-19); `ask` prompts are not identity.
4. **Defence in depth** — the layers below; each layer's failure is survivable.

## 2. Enforcement layers (implementation, not documentation)

| # | Layer | Mechanism | Cannot be bypassed by |
|---|---|---|---|
| 1 | Read/Edit protection | project `permissions`: secrets + protected paths deny; role agent rules re-allow **their** domain only | delegation (child agents use their own rules); saved approvals never override deny |
| 2 | Shell least privilege | `shell * deny` baseline + per-role allow-lists; scanner fails closed on dynamic/compound input | `--auto` (nothing ask-denied remains for dangerous classes) |
| 3 | **Policies hard-denies** | `tool.use` denies evaluated **after** permissions + saved approvals + agent rules | **agent allow rules** — this is the anti-override layer (ADR-H-004) |
| 4 | GitHub | branch protection/rulesets, CODEOWNERS, required checks, Environments reviewer | local process entirely (identity-bound) |
| 5 | Process | negative-test matrix after every permission change; drift validation in CI; no `--auto`; incident rules | drift and good intentions |

**The anti-override discovery `[VERIFIED]`:** agent rules append after project rules and win. The pre-hardening config proved it (agent `firecrawl_*` allow silently beat the project deny). Consequence: *everything irreversible or authority-bearing lives in `policies`*; agent allows cover only routine role work. The enforced policy set (generated): dangerous git, GitHub authority verbs (`gh pr merge`, `gh pr review --approve/-a`, `gh api`, `gh auth`, `gh secret/variable`, `gh repo`, `gh issue delete`, `gh workflow`, `gh release`, `gh codespace`), destructive shell file ops (`Set-Content`, `Add-Content`, `Out-File`, `Remove-Item`, `Move-Item`, `Copy-Item`, `New-Item`, `rm`, `del`, `mv`, `cp`), nested runtimes (`opencode`, `powershell`, `pwsh`, `cmd`, `bash`, `wsl`, `sh`), publishing (`npm/pnpm/yarn publish`, `docker push`, `twine`, `cargo`, `nuget`, `mvn deploy`), secret-read shapes, plus `project.yaml` `deploy_commands` and `hard_deny_commands` rendered in.

## 3. Role capability matrix (target; enforced in generated files)

Legend A allow · Q ask · D deny · — n/a.

| Capability | PM | BA | Designer | Developer | QA | Reviewer | Security |
|---|---|---|---|---|---|---|---|
| Read project/harness docs | A | A | A | A | A | A | A |
| Read secrets/`.env` (non-example) | D | D | D | D | D | D | D |
| Edit requirements / knowledge base | D | **A** | D | D | D | D | D |
| Edit design docs + `DESIGN.md` | D | D | **A** | D | D | D | D |
| Edit code/tests/migrations | D | D | D | **A** | **e2e tests only** | D | D |
| Edit quality / security / architecture docs | D | D | D | arch A | quality A | D | security A |
| Edit status/decisions/traceability | status+decisions+trace A | trace A | trace A | trace A | trace A | D | trace A |
| Edit harness/config/protected paths | D | D | D | D | D | D | D |
| Shell read-only git | A | A | A | A | A | A | A |
| Shell build/test/lint (project list) | D | D | design-tool cmds | **A (dev list)** | **A (qa list)** | **A (review list)** | audit tools list |
| Shell feature push / commit | D | D | D | **A (scoped refs)** | D | D | D |
| Shell merge/approve/deploy/destructive | D | D | D | D | D | D | D |
| Shell write-cmdlets / nested runtimes | policy-D all roles ||||||
| Delegation | six specialists | designer, dev, critic | BA, dev | designer, QA, sec | dev, designer, sec | — | reviewer, dev |
| Skills | per §agent-spec | per §agent-spec | per OD-02/tooling | implementation set | QA set (scoped) | review set | audit set |
| webfetch/websearch | A/A | A/A | A/A | A/A | **localhost/preview only**; search D | D/D | Q/A |
| MCP (project servers) | per project.yaml | per project.yaml | design/browser if enabled | research-docs if enabled | browser QA if enabled | D | audit-only |
| External directories | Q | Q | Q | Q | Q | Q | Q |

Residual risks stated plainly: shell matching is textual (allow-listing is the control, pattern cleverness is not); read-only roles are read-only because their **shell lists** are; test runners may write coverage files — that is accepted scope; the policy layer is OpenCode-version-dependent (verified 2.2.5) and re-verified by the negative-test matrix on every upgrade.

## 4. Protected paths

| Path | Rule |
|---|---|
| `AGENTS.md`, `opencode.jsonc`, `project.yaml`, `.opencode/**`, `.agents/**`, `.github/**`, `harness/**`, `docs/harness/**`, `.git/**`, `worktrees/**` | edit deny for every role (project layer); changes only via owner-applied kit changes |
| `DESIGN.md` | edit deny + Designer sole re-allow (OD-02) |
| `docs/project/**` | project-level deny; each role re-allows its owned subtree(s) |
| `.env*`, keys, `.ssh` | read + edit deny (secret material never reachable; shell read shapes policy-denied) |

## 5. Threat model (agent-system) — persistent register per project

| Threat | Vector | Impact | Controls |
|---|---|---|---|
| Prompt injection | issue/PR/web/CMS/skill text | rogue actions/exfiltration | content-is-data rules; no shell interpolation of fetched text; deny-by-default tools; owner review at gates |
| Credential exposure | config/env/agent reads | compromise | read denies; no secrets in repo/knowledge; rotation on suspicion; `gh auth token`/`gh secret` policy-denied |
| Destructive git/data | shell mistakes | loss | policy hard-denies; branch protection; additive migrations; backups |
| Authority capture | agent merge/approve/phase-set | governance defeat | policy denies + GitHub identity + PM-can't-self-approve |
| Delegation escape | built-in subagents / depth loops | role bypass | no general/explore; depth-2 cap; child own-permissions verified; matrix tests |
| MCP/data egress | external servers carry content | privacy/supply-chain | toggles default deny; ask when enabled; bundle exclusions; no sensitive data to external services until owner regime decision |
| Supply chain | malicious skill/package/plugin | code execution | pinned project-local skills with provenance; never run installer scripts; inspect-before-use rule; lockfile-consistent installs; third-party plugins prohibited without audit |
| Browser with live logins | live-session automation | account exposure | disabled by default; when enabled: localhost/preview only, no credentials, owner approval |
| Model privacy | provider retention/training | data regime breach | readiness gate (OD-25): verified privacy settings before real sessions; project data policy binds external flows |
| Unreviewed production | broad deploy access | outage/exposure | deploy only in CI behind Environment reviewer |
| Sandbox absence | host-authority shell | lateral damage | no prod credentials on agent workstation; external isolation for untrusted execution; least privilege everywhere |

Incident response: contain → notify owner → preserve evidence → eradicate → recover → retrospective → disclose only if law/contract requires (owner decision). Records: `docs/project/05-security/incidents/`.

## 6. Secrets and credentials (framework)

`.env.example` names only; no secrets in issues/PRs/docs/prompts/logs/screenshots; redact diagnostics; rotate anything suspected exposed; production secrets live in CI/Environment stores, never the agent workstation; provider-specific tables (e.g. service-role/read-token scoping) belong in the instance `docs/project/05-security/security-baseline.md`.

## 7. Dependency, supply-chain, deployment

Dependency additions are material (OD-18): approved via change request, lockfile-committed, audited (`security_commands` allow-list), Dependabot/alerts enabled where the platform supports. Deploy CLIs never execute locally (policy): GitHub Actions + Environment reviewer = owner; destructive data operations are separate owner-approved workflows with explicit confirmation; post-deploy smoke tests; rollback path verified before first production release; short-lived credentials preferred. Backup/retention: verify provider capabilities with evidence (no assumptions), define RPO/RTO, test restores before production, encrypt backups, deletion is owner-only.

## 8. Security gates

Architecture: threat model reviewed, no unmitigated HIGH. Every PR: no secrets, no unreviewed new dependency. Sensitive PR: Security review; criticals block merge. Pre-release: audit + secret scan + access-control review + verdict. Production: owner approval + smoke + rollback ready. Post-change to permissions/config: negative-test matrix re-run. Pen-testing only with explicit owner authorization. Critical findings block release `[APPROVED]`.

## 9. Data protection framework

`project.yaml.data_policy.sensitivity` ∈ `public|business|personal|regulated` renders the AGENTS.md rule (§2) and drives: external-service egress rules, KB/bundle exclusions, browser-test limits, and (regulated) the requirement for a recorded legal regime — jurisdiction, lawful basis, retention, residency, consent, breach duties — **before the architecture gate**. The harness never assumes a specific regime; missing determination = high-risk posture by default.

## 10. Enforcement checklist (instance bring-up + periodic)

- [ ] Generated config parses; shell deny-by-default present; policies present
- [ ] Negative-test matrix N-01…N-30 executed on this OpenCode version → results logged
- [ ] Protected-path denies + role re-allows match `agent-specifications.md` matrix (validator)
- [ ] MCP inventory audited against `integrations` + `mcp_deny`
- [ ] Branch protection/CODEOWNERS/required checks/production Environment active before P4
- [ ] `--auto` never used; external-directory asks honoured
- [ ] No secrets anywhere in repo or bundles; scanner clean
- [ ] Backup/restore evidence before first production release
- [ ] Independent security review performed for every material control change
