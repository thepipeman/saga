# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-ALPHA] - 2026-09-10

First packaged release of the **saga** Claude Code plugin — a gated development
workflow for a Java 25 / Spring Boot 4 / PostgreSQL stack.

### Added

- **Workflow commands** — `/init-context` (bootstraps `.claude/context/` docs,
  per-project skill conventions, workflow state, and a scoped permission
  allowlist), `/design` (spec → design doc), `/implement` (design doc → code),
  `/mark-reviewed` (human review gate), `/finish` (changelog, commit, push, PR).
  `/document-service` generates `docs/about-this-service/` standalone, outside
  the pipeline.
- **Subagents** — `design-architect` (design documents only, never code),
  `code-executor` (implements a design at a caller-decided test scope),
  `changelog-writer` (drafts a Keep a Changelog entry in isolated context so the
  diff never enters the orchestrating session).
- **Commit gate hook** — `check-finish-gate.sh` blocks git commit/push via
  `PreToolUse` until `/mark-reviewed` has been run. Enforced mechanically rather
  than left to model judgment, because commits are the one hard-to-reverse step.
- **Tech-stack skills** — `spring-boot-patterns` (+ Java 25 reference),
  `spring-data-jpa` (entities, queries, performance references),
  `jooq-conventions`, `postgres-migrations`, `testcontainers-testing`. Baselines
  are overridden per project via `.claude/context/conventions/<skill>.md` rather
  than by editing the plugin.
- **Persistence-stack detection** — `/init-context` records JPA or jOOQ under
  `## Persistence stack` in `PATTERNS.md`; the two skills are mutually exclusive
  and `code-executor` loads only the matching one.
- **Opt-in test scope** — `/implement` asks for `none` / `unit` /
  `unit+integration` up front, and infers it for test-only designs. Skipped tests
  are reported as an explicit tradeoff, not silently dropped.
- **Model recommendation** — design docs record a recommended implementation
  model with a reason; `/implement` confirms it before delegating.
- **Resumable phases** — every phase reads `.claude/workflow/state.json` and
  on-disk documents rather than conversation history, so `/clear` between phases
  is safe and keeps per-phase context minimal.
- **Cursor port** — the five tech-stack skills are mirrored as
  `.cursor/rules/*.mdc`. The workflow layer (commands, agents, templates) has no
  Cursor equivalent and is not ported.
- **Distribution** — plugin manifest plus `marketplace.json` for opt-in team
  installs; see `INSTALL.md`.

### Notes

- Java 25 and Spring Boot 4.x are an unconditional floor, not a migration
  target. Boot 3.x-era APIs (`@MockBean`, `spring-boot-starter-web`, JUnit 4,
  `hibernate-jpamodelgen`) are documented as removed; `/init-context` flags
  older projects and `code-executor` stops rather than downgrading its output.
- Generated code is a draft. `/mark-reviewed` gates the pipeline mechanically
  but cannot verify that a review actually happened.
