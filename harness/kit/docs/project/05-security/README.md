# 05-security — Security Engineering

Security-Monitor-owned. Security is foundational: this directory is written *with* — not after — design and architecture.

- `threat-model.md` — assets, trust boundaries, data flows (incl. agent/AI data flows), threats ranked, controls, residual risk. Updated whenever a boundary or integration changes.
- `security-baseline.md` — enforced controls: permissions, secrets, dependency policy, supply-chain rules, external-content handling, git safety.
- `reviews/` per security-sensitive PR/gate: findings CRITICAL/HIGH/MEDIUM/LOW + remediation + verification.
- `remediation-log.md` — finding → owner → due → status → verification evidence.
- `incidents/{{ID_PREFIX}}-INC-###.md` — incident timeline, containment, post-mortem, preventive actions.
- Gates: architecture gate requires no unmitigated high risk; release gate requires dependency audit + secret scan + verdict (`pass`/`pass-with-risk` with owner record/`block`).
