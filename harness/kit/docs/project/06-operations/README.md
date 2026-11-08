# 06-operations — Deployment & Operations

PM/Developer-owned; runs after the deployment gate and defines the steady-state (Phase 7) rhythm.

- `deployment.md` — pipeline topology, triggers, approvals (owner Environment), rollback procedure, smoke tests.
- `backup-restore.md` — per-asset capability evidence (verified, not assumed), RPO/RTO, restore drill log.
- `hotfix-runbook.md` — OD-20 emergency path: owner authorisation, PR still required, post-hoc reviews within 24h, retrospective mandatory.
- `monitoring.md` — health signals, alert routing, on-call (owner) — active in Phase 7.
- `maintenance.md` — steady-state rhythm: dependency updates, security advisories, KB staleness review, metrics, quarterly retro, release train.
- `smoke-tests.md` — post-deploy checks with commands.
- `release-notes/` per version.
