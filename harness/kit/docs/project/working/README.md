# Working memory — non-authoritative

Per-agent scratch space. Nothing here is approved knowledge. Rules:

1. Each agent keeps `working/<agent-id>/`. Drafts, notes, inbox files, in-flight analysis.
2. Promotion to authority only through the owning workflow (KB staging for knowledge, gate packs for evidence, register for decisions).
3. `inbox/` subfolder is gitignored for sensitive raw inputs; summaries go through redaction.
4. Pruned at each retrospective and during `/ops` health reviews; stale working notes are a governance smell.
