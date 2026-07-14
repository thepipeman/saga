---
name: init-context
description: Bootstrap reusable context documents and customize plugin skills for this project. For existing codebases it reads actual patterns and updates the skills to match; for new projects it keeps the generic skill baselines. Run once when adopting this workflow, or re-run with --refresh after major refactors.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Bash(git log:*), Bash(find:*), Bash(mkdir:*)
argument-hint: "[--refresh]"
---

You are bootstrapping this project for the saga plugin. The goal is twofold: (1) generate reusable context documents for future sessions, and (2) customise the plugin's generic skill baselines to reflect this project's actual conventions, so the design and implementation phases produce code that fits the codebase from day one.

If `--refresh` was NOT passed and `.claude/context/` already contains these files, ask the user to confirm before overwriting rather than silently regenerating.

---

## Step 0 — Detect project type

Check whether source code already exists:

- Look for `src/` directories, `pom.xml`, `build.gradle` / `build.gradle.kts`, and non-trivial source files (`.java`, `.kt`, `.ts`, `.py`, etc.).
- **If no source code found:** this is a **new project**. Skip steps 1–2 and go straight to step 3. Skills stay at their generic baselines — add a note in each skill's `## Codebase conventions` section that says "New project — conventions to be established." Then proceed to steps 4–5.
- **If source code found:** this is an **existing project**. Complete all steps.

---

## Step 1 — Explore the codebase (existing projects)

Use Glob/Grep/Read (read-only — do not modify source) to determine:

- **Module/service boundaries** — how the project is split (Maven/Gradle modules, packages, microservices), and how they communicate (REST, messaging, shared libs)
- **Layering convention** — controller → service → repository, or equivalent; where business rules live vs. persistence logic
- **Transaction boundaries** — where `@Transactional` is applied; whether it's at the class or method level; any rules about not spanning external calls
- **Persistence stack** — jOOQ / Spring Data / plain JDBC; migration tool (Flyway/Liquibase) and its naming convention and config; how jOOQ codegen is triggered; whether generated sources are committed
- **REST client pattern** — `RestClient`, `@HttpExchange`, `RestTemplate`, `WebClient`, Feign — what's used and how it's configured (interceptors, error handling, auth)
- **Security approach** — JWT resource server, session-based, IDP in use; how roles/authorities are extracted from the token; Spring Security config style
- **Testing conventions** — test framework, Testcontainers usage and container setup pattern, base test class name, test profile names, HTTP testing library (RestAssured / MockMvc), auth bypass mechanism in tests
- **Build tooling** — Maven/Gradle, CI config, any lint/static-analysis rules (ArchUnit, Checkstyle, etc.)
- **Domain vocabulary** — core entities and what they're called in code vs. any business glossary (README, docs/, package names)
- **Shared/utility libraries** — any internal BOM or common modules providing base exception types, command abstractions, pagination helpers, logging interceptors, etc.

---

## Step 2 — Write context documents (existing projects)

Create `.claude/context/` (if absent) and write the following. Use `${CLAUDE_PLUGIN_ROOT}/templates/ARCHITECTURE.md.template` as a starting structure for `ARCHITECTURE.md`; match its header style for the others. Keep each document under ~150 lines — link to specific source files rather than reproducing large code blocks.

- **`ARCHITECTURE.md`** — module boundaries, service topology, how requests flow through layers
- **`PATTERNS.md`** — transaction boundary rules, persistence conventions, error handling, REST client patterns, security config style, naming conventions — the things a new contributor would learn by osmosis
- **`DOMAIN.md`** — entity glossary, key business rules tied to specific entities
- **`TESTING.md`** — test conventions, Testcontainers setup (container class names, base class, profile), coverage expectations, auth bypass mechanism

---

## Step 3 — Write project-specific skill overrides

Create `.claude/context/conventions/` inside the project (not inside the plugin) and write one file per skill. The plugin's skill files are never modified — this keeps the plugin safe for global installation shared across multiple projects. Each conventions file is the authoritative project-specific override for that skill; the plugin loads it at runtime.

For **existing projects**, populate each file with concrete details discovered in step 1. For **new projects**, write a brief note that conventions are yet to be established and list any technology choices already known.

Files to write and what to capture in each:

**`.claude/context/conventions/spring-boot-patterns.md`**
- Any shared Command/CQRS abstraction in use (BOM library, internal module, or none — just plain `@Service`)
- Project-specific exception types and what HTTP status each maps to
- REST client interceptors or helper classes in use (logging, auth injection)
- How JWT roles/claims are extracted and mapped to Spring Security authorities (custom converter class name and location, claim key configured in `application.yml`)
- BOM libraries providing utility classes (list the artifact IDs and what they provide)

**`.claude/context/conventions/jooq-conventions.md`**
- DSL field name convention (`dsl` vs `dslContext` vs something else)
- Generated class prefix/naming strategy (e.g., `BH` prefix via a custom `GeneratorStrategy`)
- Location of generated sources relative to module root
- Pagination abstraction in use (class names and module)
- How table constants are imported (static import style)
- Whether generated sources are committed or produced at build time

**`.claude/context/conventions/postgres-migrations.md`**
- Migration tool (Flyway or Liquibase) and key config (`locations`, `table`, `out-of-order`, etc.)
- File naming convention with a concrete example from the repo
- Schema organisation strategy (one Postgres schema per domain, single `public` schema, etc.) with the actual schema names and what each owns
- Soft-delete convention (column name, type, default, partial index pattern)
- Enum type declaration pattern and any associated casts

**`.claude/context/conventions/testcontainers-testing.md`**
- Base integration test class name and package
- Container class name and Postgres image version
- Active test profile name(s) and what each enables/disables
- HTTP testing library in use (RestAssured, MockMvc, etc.)
- Test JWT / auth bypass mechanism (class name and how tokens are generated per role)
- Shared test data pattern (`@Sql`, fixture classes, `@BeforeAll` inserts, etc.)

---

## Step 4 — Wire into CLAUDE.md

If the project has no `CLAUDE.md`, create one from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template`. If one exists, add `@`-imports for the four context files if they aren't already referenced (e.g. `@.claude/context/ARCHITECTURE.md`), without disturbing existing content.

---

## Step 5 — Initialize workflow state

Create `.claude/workflow/state.json` if it doesn't exist:

```json
{
  "phase": "idle",
  "spec_ref": null,
  "design_doc": null,
  "design_approved": false,
  "design_hash": null,
  "code_reviewed": false
}
```

---

Report a short summary of:
- Whether this was treated as a new or existing project
- What was written (context docs, skill updates)
- Anything you were unsure about (ambiguous layering, conflicting patterns, conventions you couldn't confirm) so the user can correct generated content by hand
