# Status Directory

| File | Purpose | Writer |
|---|---|---|
| `phase-state.md` | Machine-readable lifecycle state (frontmatter authoritative) | PM (except `approved_by`/`approved_at`: owner-authored) |
| `blockers.md` | Open blockers with owner + next action | PM |
| `metrics.md` | Harness/quality metrics with definitions and evidence | PM |
| `gates/` | Phase-gate evidence packs `<phase>-<name>.md` | PM prepares; owner approves |
| `retrospectives/` | Post-phase and post-incident retros | PM facilitates |

Status values are never duplicated between files; `phase-state.md` is the single lifecycle state source, GitHub Projects `Status` is the single work-item state source (OD-06).
