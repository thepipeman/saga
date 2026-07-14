---
name: postgres-migrations
description: PostgreSQL migration conventions — naming, schema organisation, indexing, and backward-compatibility rules. Use when a design or implementation involves a schema change.
---

## Migration rules

- New schema changes always get a **new** migration file — never edit a migration that has already shipped to any environment.
- Every migration must be backward-compatible with the currently-deployed application version for at least one deploy cycle: additive changes (new nullable column, new table) ship first; destructive changes (drop column, rename) ship only after the application code no longer references the old shape.
- Every column that's non-nullable in practice ships as `nullable` or with a `DEFAULT` first, then tightened in a follow-up migration after the backfill is confirmed.

## Indexing

- Any new query pattern introduced by a design must have its indexing needs called out explicitly in the design doc — don't discover them later via a slow-query alert.
- Prefer `CREATE INDEX CONCURRENTLY` for indexes on tables that see live traffic, to avoid locking writes.

## Review checklist for any migration

- [ ] New file — not an edit to an existing shipped migration
- [ ] Backward-compatible with the currently-deployed app version
- [ ] Indexes added for any new query pattern
- [ ] Destructive changes are a separate, later migration from the additive change that precedes them
- [ ] Non-nullable columns ship as nullable/defaulted first

---

## Codebase conventions

Read `.claude/context/conventions/postgres-migrations.md` if it exists in the current project. That file is the authoritative project-specific override for this skill and takes precedence over every generic pattern documented above. If the file is absent, apply the generic guidance in this skill as written.
