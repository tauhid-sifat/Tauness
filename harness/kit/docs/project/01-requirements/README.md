# 01-requirements — Requirements & Specification

BA-owned. Long-form views over the knowledge base (`../knowledge/`).

- `brd.md` — business requirements: problem, goals, stakeholders, high-level scope, success criteria.
- `prd.md` — product requirements: capabilities with linked CAP/BR ids, user journeys, feature behaviour, NFRs (EARS with measures).
- `user-stories/{{ID_PREFIX}}-US-###.md` — INVEST stories with ≥2 Given/When/Then ACs.
- `acceptance-criteria/{{ID_PREFIX}}-AC-###-#.md` — when not inline.
- `nfr.md` — non-functional requirements: performance, availability, security, accessibility, compatibility, constraints — each with a measurable target or an explicit TBD + owner question.
- `issue-drafts/` — BA drafts; only the PM turns them into issues (OD-07).
- `change-requests/{{ID_PREFIX}}-CR-###.md` — impact analysis + owner decision record.

Definition of Ready (PM gate before scheduling): clear, testable, AC complete, dependencies known, sized, no unresolved blocker, traceability row created.
