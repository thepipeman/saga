---
name: postgres-migrations
description: PostgreSQL migration conventions — naming, schema organisation, indexing, and backward-compatibility rules. Use when a design or implementation involves a schema change.
---

## Migration rules

- New schema changes always get a **new** migration file — never edit a migration that has already shipped to any environment.
- Every migration must be backward-compatible with the currently-deployed application version for at least one deploy cycle: additive changes (new nullable column, new table) ship first; destructive changes (drop column, rename) ship only after the application code no longer references the old shape.
- Every column that's non-nullable in practice ships as `nullable` or with a `DEFAULT` first, then tightened in a follow-up migration after the backfill is confirmed.

## The migration is the source of truth

The schema is defined by migrations, never by the ORM. In a Spring Data JPA project that means `spring.jpa.hibernate.ddl-auto: validate` in every environment including tests — never `update` or `create-drop`. `validate` turns a drift between entity mapping and schema into a startup failure, which is where you want to find it.

Write the migration and the entity (or the jOOQ codegen run) in the same change, and make sure the entity's `@Column(nullable = ...)`, lengths, and types mirror what the migration actually creates.

Sequences deserve specific attention: if an entity uses `GenerationType.SEQUENCE` with an `allocationSize`, the migration's `CREATE SEQUENCE ... INCREMENT BY` must match it. A mismatch produces duplicate-key errors that only appear under concurrent load across multiple instances.

## Indexing

- Any new query pattern introduced by a design must have its indexing needs called out explicitly in the design doc — don't discover them later via a slow-query alert.
- Prefer `CREATE INDEX CONCURRENTLY` for indexes on tables that see live traffic, to avoid locking writes.

## Review checklist for any migration

- [ ] New file — not an edit to an existing shipped migration
- [ ] Backward-compatible with the currently-deployed app version
- [ ] Indexes added for any new query pattern
- [ ] Destructive changes are a separate, later migration from the additive change that precedes them
- [ ] Non-nullable columns ship as nullable/defaulted first
- [ ] Entity mapping (or jOOQ codegen) updated in the same change, and `ddl-auto` is still `validate`
- [ ] Sequence `INCREMENT BY` matches the entity's `allocationSize`, if applicable

---

## Codebase conventions

Read `.claude/context/conventions/postgres-migrations.md` if it exists in the current project. That file is the authoritative project-specific override for this skill and takes precedence over every generic pattern documented above. If the file is absent, apply the generic guidance in this skill as written.
