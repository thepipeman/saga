# Working on this repo

This repo is the **saga** Claude Code plugin. It also ships a manually-maintained
Cursor port under `.cursor/rules/*.mdc`. Cursor has no equivalent of Claude Code's
subagents or slash commands, so only the tech-stack skills are ported — `agents/`,
`commands/`, and `templates/` (the `/design` → `/implement` workflow layer) have no
Cursor counterpart and never need porting.

## Keep the Cursor port in sync

Whenever a change is made to a `skills/*/SKILL.md` (or its `references/*.md`), check
whether the matching `.cursor/rules/*.mdc` file needs the same change and port it over:

| Skill source | Cursor rule(s) |
|---|---|
| `skills/jooq-conventions/SKILL.md` | `.cursor/rules/jooq-conventions.mdc` |
| `skills/postgres-migrations/SKILL.md` | `.cursor/rules/postgres-migrations.mdc` |
| `skills/spring-boot-patterns/SKILL.md`, `references/java-25.md` | `.cursor/rules/spring-boot-patterns.mdc`, `.cursor/rules/spring-boot-patterns-java-25.mdc` |
| `skills/spring-data-jpa/SKILL.md`, `references/entities.md`, `references/performance.md`, `references/queries.md` | `.cursor/rules/spring-data-jpa.mdc`, `-entities.mdc`, `-performance.mdc`, `-queries.mdc` |
| `skills/testcontainers-testing/SKILL.md` | `.cursor/rules/testcontainers-testing.mdc` |

Don't copy files verbatim — `.mdc` files use Cursor frontmatter (`description`,
`alwaysApply`) instead of the plugin's `name`/`description`, and their "Codebase
conventions" footer points at `.claude/context/conventions/*.md` with a note that
it's written by the saga Claude Code plugin. Preserve that framing when porting prose.
