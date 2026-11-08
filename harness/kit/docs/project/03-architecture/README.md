# 03-architecture — System Architecture

Developer-owned (architecture duty). Includes database/data-architecture and deployment architecture.

- `architecture.md` — system context, components, boundaries, data flows, environment map.
- `data-model.md` — entities, relationships, schema strategy, migrations policy, access-control design.
- `api-contracts.md` / `integrations.md` — interface contracts and external systems with trust boundaries marked.
- `environments.md` — dev/preview/staging/production topology, configs, secrets locations (names only).
- `adr/{{ID_PREFIX}}-ADR-###.md` — decision records for material technical choices (template in `../templates/`).
- `spikes/` — throwaway prototype findings, conclusions, and what is *not* production code.
- `deployment.md` lives under `06-operations/`; this directory defines the topology it deploys.
- Co-owned with Security Monitor: threat model references (full model in `../05-security/threat-model.md`).
