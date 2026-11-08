# 04-quality — QA & Verification

QA-owned.

- `test-strategy.md` — risk-based approach, levels, environments, entry/exit, regression policy, accessibility & responsive scope.
- `test-plans/` per scope slice; `test-cases/{{ID_PREFIX}}-TC-###.md` traced to AC ids.
- `reports/` execution summaries with evidence (commands, links, screenshots where visual).
- `defects/{{ID_PREFIX}}-DEF-###.md` — reproducible reports; severity P0–P3; release impact.
- `reviews/` durable copies of advisory review verdicts (`PR-<n>-review.md`).
- Invariants: every AC has ≥1 test; critical flows include negative/permission/invalid-input paths; "pass" always means command + result evidence, never a claim.
