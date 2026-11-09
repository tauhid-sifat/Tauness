# Changelog

All notable changes to the AIDLC Harness kit. Version is `harness/HARNESS-VERSION`; every bump gets an
entry here, and material changes (permissions, policies, gates, approvals - OD-18) also get an ADR in
[`docs/harness/adr/`](docs/harness/adr/INDEX.md).

## [1.2.0] - 2026-11-09

### Added

- **Verification ledger** - `docs/harness/verification-ledger.json`: 31 controls across the permission,
  policy, GitHub, process and kit-development tiers, each `designed`, `implemented` or `verified`. It is
  consumed rather than admired: `validate-harness.ps1` reads it inside every instance and FAILs a
  `verified` row with no evidence; `tests/check-sources.ps1` enforces schema, unique ids, the status
  vocabulary and a two-way join with `negative-tests.md` (every cited `N-`/`G-` id must exist, and every
  runtime test must be claimed by a control); `tests/check-site.ps1` refuses to publish the handbook if
  its printed counts drift from the file. Statuses assigned conservatively - configuration and
  kit-development work verified, runtime enforcement left `implemented` or `designed`, including VC-11,
  the `policies`-evaluated-last assumption everything else leans on. Proven by attack: a verified row
  with no evidence and a dangling test citation each failed `check-sources` naming the control, and a
  tampered ledger inside a rendered instance made `validate-harness` exit 1 before restoring returned it
  to passing. Three more required PASS markers in the self-test; checks per instance now 56.
- **Skill allow-lists moved out of the kit and into `project.yaml`** (`skills.shared`, `skills.<role>`).
  The agent templates carried 42 hardcoded grants naming one machine's installed set, so every fresh
  instance reported 41 identical "skill not found" warnings and a genuinely missing skill could not be
  seen. `Get-RoleSkillGrants` in `lib-apply.ps1` is now the single authority: declared shared + declared
  role + `stack.agent_skills` + what the integration toggles imply. `validate-harness.ps1` **fails** an
  agent granting anything outside that map and **warns** only for a declared-but-uninstalled skill; its
  24-name `globalKnownSkills` snapshot is gone. The interview gained a shared-skills prompt, the
  self-test installs stub skills for whatever a variant granted, and `skills:declared` /
  `skills:installed` are now required PASS markers. Behaviour-preserving by measurement: rendering from
  `HEAD` and from the working tree and comparing per-role grants shows all 7 roles identical - the first
  attempt over-granted `opencode`, `research` and `writing-for-agents` to six roles through
  `skills.shared`, which that comparison caught.
- **MIT license** (`LICENSE`), chosen by the owner; the README now links versions to tags and changelog
  entries, and the handbook footer states it.

### Changed

- **Layer A purity enforcement** in `tests/check-sources.ps1`: every file in the repository - kit, core docs, evidence, ADRs, log, site, tests, top-level docs - is
  scanned for project identity and the build fails on a hit. The check carries a positive control, because the
  first version of it was a vacuous no-op: `@('a' + 'b', 'c')` makes PowerShell concatenate the comma list into
  one string, so the ban list had a single impossible entry and every run "passed". Now the list's shape is
  asserted and a known-bad sample must match before silence counts.

### Changed

- Dated evidence (`final-readiness-audit`, `generalization-audit`, `migration-and-handover`,
  `validation-report`) moved to `docs/harness/archive/`; cross-references updated. `harness/README.md` and
  `repository-structure.md` now state the rule, the narrow history exception (ADRs, the implementation log,
  the archive) and why generic examples are not project identity.
- Project identity scrubbed from the four live specs that named a project (`architecture-specification`,
  `project-initialization`, `implementation-roadmap`, `open-decisions`), leaving only history documents named.
- Branch protection on this repository's `main` is recorded as a deliberate owner exception rather than an
  outstanding defect; instance-side expectations are unchanged.

### Fixed

- A **false negative in the kit's own test suite** was caught while writing the purity check (see Added): the
  same `+`/comma precedence trap applies to any array literal built with concatenation in this codebase, so
  producer lists elsewhere were audited for it and are clean.

## [1.1.1] - 2026-11-09

Patch: a shipped workflow was unrunnable, found by auditing rendered YAML rather than reading the template.

### Fixed

- **`pr-policy.yml` could never run in any instance.** The template ended a step with
  `env: { GH_TOKEN: ${{ github.token }} }` - a YAML flow mapping containing an Actions expression, which
  standard parsers reject (`expected ',' or '}'`). GitHub Actions loads workflow files through a YAML
  parser, so the PR policy gate that the handbook says "fails a PR with no `Closes #n`" was, in every
  instance, a file that would not load. Now block style. Found by parsing all 16 rendered `.github`
  YAML files; it is invisible to a template reader and to the JSONC-only check that `harness-validation.yml`
  performs on `opencode.jsonc`.

### Added

- **Workflow YAML shape gate** in `tests/render-and-validate.ps1`: rendered `.github/**/*.yml` must contain
  no flow mapping holding an expression and no unresolved template slot, and all 16 expected files must be
  present (12 issue forms + 4 workflows). Slot detection excludes `${{ ... }}` expressions, which legitimately
  contain `{{`; an over-crude first version of this check false-positived on them.

## [1.1.0] - 2026-11-09


Rendering output changed: instances are now more complete and self-consistent than before.

### Added

- **`/improve-harness`** (16th command, PM-bound): evidence-backed harness-change proposal with a
  duplicate check, change classification, version-bump mapping, and a drafted `harness-improvement`
  issue. Proposes only - applying stays with the owner and `apply-harness-change.ps1`. Writes inside
  the PM's existing `docs/project/working/project-manager/**` scope, so no permission was widened.
  (ADR-H-012)
- **`.github/CODEOWNERS` and `.github/pull_request_template.md` are now rendered into instances.**
  Both existed as templates and were absent from `Get-RenderPlan`, so no instance ever had them -
  while `project-initialization.md` claimed they did and the GitHub-side control test G-02 depends on
  CODEOWNERS review.
- **Render-plan reachability audit** in `tests/check-sources.ps1`: every file under `harness/kit/`
  must be rendered by `Get-RenderPlan` or be a declared non-rendered input with a stated reason. This
  is the check that turns the above class of defect into a build failure.
- **Kit JSON validation** in `tests/check-sources.ps1`: every `kit/**/*.json` must parse as JSON.
- **Interview-template slot audit**: `kit/project.yaml.tmpl` is substituted by `init-project.ps1`'s
  interview, not `Expand-Template`, so it had been outside every slot check.
- **Upgrade coverage in the self-test**: each variant now runs `apply-harness-change.ps1 -DryRun` and
  `-Force`, asserts the promised backup of every overwritten file, asserts re-rendering is
  deterministic, and re-validates afterwards. The kit's central promise had no test at all.
- **Governance files for this repository**: issue forms (bug, harness-improvement), issue config with
  a private security contact path, `CONTRIBUTING.md`, `SECURITY.md`, `CODEOWNERS`.

### Fixed

- **`sync-labels.ps1` could not run.** `harness/kit/github/labels.json` was commented YAML while the
  script parsed it with `ConvertFrom-Json`, so the label step of setup failed on every instance. The
  taxonomy is now real JSON and its prose notes live in `docs/harness/github-governance.md`.
- **`project.yaml` shipped an unresolved placeholder.** The interview path substituted every token but
  `{{KIT_COMMIT}}`, so an instance created through the documented onboarding route failed
  `validate-harness.ps1`'s own placeholder check on its own configuration file.
- **Ambiguous provenance.** `rendered_from_commit` used to be whatever git reported for the directory
  holding the kit copy - which inside an instance is the *instance* commit, making two instances of
  one kit claim different provenance and letting a re-apply rewrite its own history. Resolution now:
  inside an instance the recorded stamp is carried forward; otherwise it is attested by the kit
  repository; otherwise `unknown`. `init-project.ps1` writes the same value the templates were
  rendered with, so record and generated files can no longer disagree.

### Changed

- `validate-harness.ps1` expects 16 commands (was 15).
- Documentation stamps updated to `harness 1.1.0` (13 files); `open-decisions.md` header claimed
  OD-27-OD-34 when the index ends at OD-32.
- `docs/harness/repository-structure.md` reconciled on `harness/reports/`: committed as gate evidence
  in an instance, ignored in the kit home repository, where it is regenerated on every run.
- `kit/github/ISSUE_TEMPLATE/spec.yaml` (a "removed" tombstone) deleted.
- Handbook: sixteen commands, new command row, `What is not yet proven` updated to match what is now
  fixed versus genuinely outstanding.

## [1.0.1] - 2026-11-09

### Fixed

Five defects that were live simultaneously, all found by building the first automated kit self-test:

- `lib-render.ps1` was unparseable under Windows PowerShell 5.1 (non-ASCII literals in BOM-less
  UTF-8; `U+2192` decodes to bytes containing an apostrophe). All six scripts are now ASCII-only, and
  glyphs needed in rendered output are emitted from code points.
- A stray quote in `Get-StackPolicyDenies` broke parsing independently of encoding - the renderer had
  never run.
- `New-RenderContext` looked for `HARNESS-VERSION` inside `kit/`, where it does not live.
- `init-project.ps1` assigned `$Target` from `Resolve-Path`, which returns nothing for a directory
  that does not exist yet, so creating a new project always failed.
- `lib-apply.ps1` stripped the 5-character `.tmpl` suffix by removing 6 characters, truncating every
  generated file's extension (`business-analyst.m`, `bug.ym`, `phase-state.m`).

`validate-harness.ps1` was also corrected: the placeholder sweep no longer flags the substitution code
and core docs as leaks, and `Set-StrictMode` `Count` errors can no longer make the agent-count and
command-count checks silently skip.

### Added

- Kit self-test: `tests/check-sources.ps1`, `tests/render-and-validate.ps1`,
  `.github/workflows/kit-validation.yml`.

## [1.0.0] - 2026-11-09

- Initial project-agnostic AIDLC core kit: 7 role agents, 15 commands, 5 lifecycle profiles over 7
  phases, two-tier enforcement (deny-by-default permissions + delegation-proof `policies`), Git-markdown
  knowledge base with staging/critic/acceptance, GitHub governance assets, renderer (`lib-render.ps1`,
  `lib-apply.ps1`), and the init/apply/validate/sync-labels scripts. Extracted from the first instance,
  which was built project-specifically and then generalized (ADR-H-001).
