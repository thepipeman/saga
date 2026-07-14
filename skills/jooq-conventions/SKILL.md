---
name: jooq-conventions
description: jOOQ codegen, DSL usage, and query-structure conventions. Use when writing or reviewing any repository-layer or data-access code.
---

## Codegen

- Generated records/tables come from jOOQ codegen run against the migration-managed schema — never hand-write generated classes, and never edit generated output directly.
- Regenerate after any migration that changes a table this repository layer touches; don't let generated code drift from the schema.
- Generated sources are typically excluded from version control — the codegen step runs as part of the build (often via Testcontainers in the test phase). See the `testcontainers-testing` skill for how the test database is provisioned.

## Repository structure

Repositories use `DSLContext` for all queries. `@Transactional` is applied at the **method level only** — never on the class.

```java
@Repository
@RequiredArgsConstructor
public class FooRepository {

    private final DSLContext dsl;

    @Transactional
    public Long create(Foo foo) {
        return dsl.insertInto(FOO)
            .set(FOO.NAME, foo.name())
            .returning(FOO.ID)
            .fetchAny(FOO.ID);
    }

    @Transactional(readOnly = true)
    public Foo findById(Long id) {
        return dsl.selectFrom(FOO)
            .where(FOO.ID.eq(id))
            .fetchOptional(/* mapping */)
            .orElseThrow(() -> new ResourceNotFoundException(Foo.class, id));
    }
}
```

## Records vs. DTOs

Don't leak generated jOOQ records past the repository layer. Map to domain/DTO objects before returning to the service layer — this keeps the service layer decoupled from schema changes.

Use `org.jooq.Records.mapping(Constructor::new)` for clean record-to-object projection:

```java
import static org.jooq.Records.mapping;

.fetch(mapping(Foo::new))
```

## DSL usage rules

- Use the jOOQ DSL (`DSLContext`) for all non-trivial queries — no string-concatenated SQL.
- Prefer typed multi-table joins over N+1 sequential queries. If a repository method makes more than one dependent DSL call for a single request, consider whether it should be one query.
- Batch inserts/updates (`batch()`, `batchStore()`) for bulk operations — don't loop single-row calls.
- Build dynamic filter conditions starting from `DSL.noCondition()`, then chain `.and(...)` for each optional filter — avoids SQL concatenation and keeps the base query readable:

```java
var condition = DSL.noCondition();
if (criteria.status() != null) condition = condition.and(FOO.STATUS.eq(criteria.status()));
if (criteria.name() != null)   condition = condition.and(FOO.NAME.eq(criteria.name()));
```

## Nested object projection

Use `row(...).mapping(...)` for nested objects in a single query, avoiding N+1:

```java
private SelectField<Bar> barRow() {
    return row(BAR.ID, BAR.CODE, BAR.LABEL)
        .mapping(Bar::new);
}
```

## Raw SQL

Only acceptable for Postgres-specific constructs the DSL genuinely cannot express cleanly. Isolate in a clearly-named private method — never inline in business logic.

---

## Codebase conventions

Read `.claude/context/conventions/jooq-conventions.md` if it exists in the current project. That file is the authoritative project-specific override for this skill and takes precedence over every generic pattern documented above. If the file is absent, apply the generic guidance in this skill as written.
