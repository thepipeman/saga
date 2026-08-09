---
name: init-context
description: Bootstrap reusable context documents and customize plugin skills for this project. For existing codebases it reads actual patterns and updates the skills to match; for new projects it keeps the generic skill baselines. Run once when adopting this workflow, or re-run with --refresh after major refactors.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Bash(git log:*), Bash(find:*), Bash(mkdir:*), AskUserQuestion
argument-hint: "[--refresh]"
---

You are bootstrapping this project for the saga plugin. The goal is twofold: (1) generate reusable context documents for future sessions, and (2) customise the plugin's generic skill baselines to reflect this project's actual conventions, so the design and implementation phases produce code that fits the codebase from day one.

If `--refresh` was NOT passed and `.claude/context/` already contains these files, ask the user to confirm before overwriting rather than silently regenerating.

---

## Step 0 — Detect project type

Check whether source code already exists:

- Look for `src/` directories, `pom.xml`, `build.gradle` / `build.gradle.kts`, and non-trivial source files (`.java`, `.kt`, `.ts`, `.py`, etc.).
- **If no source code found:** this is a **new project**. Skip steps 1–2 and go straight to step 0b, then step 3. Skills stay at their generic baselines — add a note in each skill's `## Codebase conventions` section that says "New project — conventions to be established." Then proceed to steps 4–5.
- **If source code found:** this is an **existing project**. Complete all steps.

---

## Step 0b — Establish the persistence stack

saga ships two mutually-exclusive persistence skills — `spring-data-jpa` and `jooq-conventions`. The code-executor loads one or the other, so this has to be settled before anything else is written; leaving it ambiguous means generated repository code will drift between the two.

**For existing projects,** detect it rather than asking. Check the build file for `spring-boot-starter-data-jpa` vs `jooq` / `spring-boot-starter-jooq`, and confirm against actual repository code (`extends JpaRepository` / `@Entity` vs `DSLContext`). Only fall back to `AskUserQuestion` if the signals genuinely conflict — e.g. both dependencies are present and both patterns appear in source. In that case ask which is primary and whether the secondary is a deliberate carve-out (typically jOOQ for reporting queries inside a JPA project).

**For new projects,** ask via `AskUserQuestion`:

> "Which persistence stack will this project use?"
> - **Spring Data JPA** — entity-mapped repositories, Hibernate. The default for CRUD-shaped domain services.
> - **jOOQ** — generated type-safe SQL DSL against the migration-managed schema. Better for query-heavy or reporting-shaped services.
> - **Both** — JPA as primary, jOOQ for specific complex queries. Say which modules get which.

Record the answer in `.claude/context/PATTERNS.md` under a `## Persistence stack` heading — that's where the code-executor looks for it.

### Platform baseline

saga's skills assume **Java 25 and Spring Boot 4.x** unconditionally. Read the actual versions from the build file (`java.version` / the toolchain block, and the Spring Boot parent POM or Gradle plugin version) and record them in `PATTERNS.md` under a `## Platform` heading.

If either is below the baseline, **say so directly in the final report as something that needs fixing** — don't quietly write conventions files that downgrade the skills to match. Generated code will target Java 25 / Boot 4 regardless, so a project on Boot 3.x will produce code that doesn't compile, and the user needs to know that before running `/design` rather than discovering it in a failed build. Whether to upgrade the project or hold off on adopting saga there is their call, not something to paper over.

---

## Step 1 — Explore the codebase (existing projects)

Use Glob/Grep/Read (read-only — do not modify source) to determine:

- **Module/service boundaries** — how the project is split (Maven/Gradle modules, packages, microservices), and how they communicate (REST, messaging, shared libs)
- **Layering convention** — controller → service → repository, or equivalent; where business rules live vs. persistence logic
- **Transaction boundaries** — where `@Transactional` is applied; whether it's at the class or method level; any rules about not spanning external calls
- **Persistence stack** — per step 0b. If JPA: entity base classes / `@MappedSuperclass` in use, id generation strategy, whether auditing is enabled, the `spring.jpa.open-in-view` and `ddl-auto` settings actually configured, and whether the static metamodel is generated. If jOOQ: how codegen is triggered and whether generated sources are committed. Either way: migration tool (Flyway/Liquibase), its naming convention and config
- **Platform versions** — Java and Spring Boot, per step 0b. Record both explicitly and flag anything below Java 25 / Boot 4
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

Write the conventions file only for the persistence stack chosen in step 0b — `spring-data-jpa.md` **or** `jooq-conventions.md`, not both. Writing both leaves the code-executor with two competing repository conventions, which is the exact ambiguity step 0b exists to remove. (If step 0b established a deliberate JPA-primary/jOOQ-secondary split, write both and state the module boundary at the top of each.)

Files to write and what to capture in each:

**`.claude/context/conventions/spring-boot-patterns.md`**
- Any shared Command/CQRS abstraction in use (BOM library, internal module, or none — just plain `@Service`)
- Project-specific exception types and what HTTP status each maps to
- REST client interceptors or helper classes in use (logging, auth injection)
- How JWT roles/claims are extracted and mapped to Spring Security authorities (custom converter class name and location, claim key configured in `application.yml`)
- BOM libraries providing utility classes (list the artifact IDs and what they provide)

**`.claude/context/conventions/spring-data-jpa.md`** (JPA projects only)
- Entity base class / `@MappedSuperclass` in use and what it provides (id, auditing, versioning)
- Id generation strategy actually used, and for sequences the `allocationSize` convention and how it matches the migration
- Whether auditing is enabled, the `AuditorAware` implementation's class name, and where the audit columns live
- Repository base interface convention (`JpaRepository` vs `ListCrudRepository` vs a project-specific base)
- Whether the static metamodel is generated, and whether `Specification` factories live in a shared class
- Actual `spring.jpa.*` settings in `application.yml` — especially `open-in-view`, `ddl-auto`, batch sizes — and flag any that contradict this skill's baseline so the deviation is a recorded decision rather than a surprise
- DTO/projection convention: constructor expressions, interface projections, or a mapper library (and which one)

**`.claude/context/conventions/jooq-conventions.md`** (jOOQ projects only)
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
- Container class name and Postgres image version, and whether the container is wired via `@ServiceConnection` or `@DynamicPropertySource`
- Repository slice annotation in use (`@DataJpaTest` / `@JooqTest` / full `@SpringBootTest`) and how the embedded-database replacement is disabled
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
  "code_reviewed": false
}
```

---

## Step 6 — Reduce permission friction

Ask the user, via `AskUserQuestion`, whether to pre-approve some of saga's own repeat operations in `.claude/settings.json`. This trades away some per-call oversight for less friction, so always ask — never write anything here silently. Ask both of the following together, in one call:

**Scope:**

> "Seed `.claude/settings.json` so saga's workflow prompts less?"
> - **Yes, scoped writes (recommended)** — allow Edit/Write under the directories saga actually touches (source, docs, `.claude/`), plus a handful of exact, non-arbitrary build commands. `/implement` alone is typically dozens of Edit/Write calls — measured over 18 sessions on a real project, `Read` came up 106 times, `Edit` 64, `Write` 30, versus Bash commands that mostly appeared once or twice. File-tool prompts are where the actual friction is, not Bash.
> - **Read-only only** — pre-approve reading the project's files; every write still prompts individually
> - **Skip** — change nothing

**Read breadth** (only matters if the scope answer above wasn't Skip):

> - **Whole project, with secrets denied (recommended)** — allow `Read` broadly, with explicit `deny` entries for `.env`, `.env.*`, `secrets/**`, `*.pem`, `*.key`, `id_rsa*`, `**/credentials*.json`
> - **Specific directories only** — ask which ones and scope `Read` to exactly those

If the scope answer is **Skip**, stop here — don't touch `.claude/settings.json`.

### What to add

**Read** — per the read-breadth answer above.

**Edit/Write** (only if "scoped writes" was chosen) — scope to what saga actually writes; never blanket-allow `./**`, since the `deny` list above only covers `Read` and a wide write rule reaches straight past it:

```
"Edit(./<source-dir>/**)", "Write(./<source-dir>/**)"
"Edit(./docs/**)",         "Write(./docs/**)"
"Edit(./.claude/**)",      "Write(./.claude/**)"
```

Derive `<source-dir>` from the module/build layout detected in Step 1 (existing projects) — `src/`, `app/`, `lib/`, `cmd/`, or actual module names. Add each source root as its own entry rather than widening to a shared parent. For new projects (Step 1 was skipped, nothing to detect yet), ask the user directly which directory will hold source once it exists, or skip this part and note in the report that it's worth revisiting with `--refresh` once real structure exists.

**Build commands** (only if "scoped writes" was chosen, and only for a build tool actually detected/known) — exact, non-wildcard invocations only:

| Tool | Add |
|---|---|
| Gradle | `Bash(./gradlew compileJava)`, `Bash(./gradlew build *)`, `Bash(./gradlew test *)` |
| Maven | `Bash(./mvnw compile)`, `Bash(./mvnw test *)` |
| Node | exact scripts only — `Bash(npm run typecheck)`, `Bash(npm run lint)` |
| Go | `Bash(go build *)`, `Bash(go test *)` |

Skip entirely for new projects — there's no build tool to detect yet.

### Hard rules

1. **Never allowlist arbitrary code execution.** No `Bash(python3:*)`, `Bash(node:*)`, `Bash(bash:*)`, `Bash(npx:*)`, `Bash(sudo:*)`. No task-runner wildcards — `Bash(npm run *)`, `Bash(make *)`, `Bash(./gradlew *)` all let a script or build file run anything, so they're equivalent to a shell. Exact task names only, as in the table above.
2. **Don't add what Claude Code already auto-allows** — these never prompt, so an entry is just noise: `cat`, `ls`, `echo`, `head`, `tail`, `wc`, `grep`, `rg`, `find`, `sed`, `jq`, `which`, `date`, `lsof`, `ps`, `diff`, `sort`, `uniq`, `tree`, and all read-only `git`/`gh`/`docker` subcommands.
3. **`curl` is not worth allowlisting.** Flags precede the URL, so a host-scoped prefix pattern won't match real invocations, and an unscoped `Bash(curl *)` is unrestricted network egress. Let it prompt.
4. **Merge, never overwrite.** Preserve every existing key and `allow` entry, and the entire `deny` list. De-duplicate against both `.claude/settings.json` and `.claude/settings.local.json` so the same rule doesn't end up in both files.
5. **Project file, not local.** Write to `.claude/settings.json` so the allowlist is shared and reviewable in version control; leave `.claude/settings.local.json` alone.
6. **Show before writing.** Show the user the exact change (new file content, or a before/after of the relevant lines) before saving it.

### On Bash beyond the table above

The build-command table covers the predictable, high-frequency cases; it deliberately doesn't try to cover everything, since safe Bash usage past that varies too much per project to guess upfront. Once a few `/design` → `/implement` cycles have run, point the user at the `fewer-permission-prompts` skill (a Claude Code built-in, not part of this plugin): it scans actual session transcripts for repeated read-only Bash/MCP calls and backfills `permissions.allow` with exactly what's been prompted for, never touches `permissions.deny`/`ask`, and refuses to allowlist anything that grants arbitrary code execution. Mention this to the user now so they know it exists for later — don't invoke it as part of this step.

---

Report a short summary of:
- Whether this was treated as a new or existing project
- What was written (context docs, skill updates)
- What was decided for permission friction (step 6): the scope chosen, exactly what was added to `.claude/settings.json`, what was deliberately skipped and why (e.g. "skipped `./gradlew *` — arbitrary execution"; "skipped `cat`/`git status` — already auto-allowed"), and a plain note that scoped Edit/Write means those calls stop being individually confirmed
- Anything you were unsure about (ambiguous layering, conflicting patterns, conventions you couldn't confirm) so the user can correct generated content by hand
