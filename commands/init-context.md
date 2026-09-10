---
name: init-context
description: Bootstrap reusable context documents and customize plugin skills for this project. For existing codebases it reads actual patterns and updates the skills to match; for new projects it keeps the generic skill baselines. Run once when adopting this workflow, or re-run with --refresh after major refactors.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Bash(find:*), Bash(mkdir:*), AskUserQuestion
argument-hint: "[--refresh]"
---

You are bootstrapping this project for the saga plugin. The goal is twofold: (1) generate reusable context documents for future sessions, and (2) customise the plugin's generic skill baselines to reflect this project's actual conventions, so the design and implementation phases produce code that fits the codebase from day one.

If `--refresh` was NOT passed and `.claude/context/` already contains these files, ask the user to confirm before overwriting rather than silently regenerating.

---

## Output rules — apply to everything this command writes

These documents set up the local harness: a stable, reusable context that `/design` and `/implement` load on every future run. Their content is **how this project is built and what its rules are** — domain, standards, patterns, conventions. Nothing else. Two runs against the same codebase should produce substantively the same documents; if a sentence would differ only because it was written on a different day or by a different run, it doesn't belong.

**Write:**

- Conventions and rules, in the present tense, as they hold in the code today
- Domain vocabulary and what each core concept means to the business
- One concrete, representative example per convention, with a file path pointing at the real thing

**Never write:**

- **Change history.** No "recently migrated to…", "was previously…", "as of the latest refactor…", no digest of `git log`, and no account of what this `/init-context` run itself did. History lives in git; a context doc that carries it goes stale immediately and misleads every later session. The only exception is a live constraint a reader would otherwise undo — a deliberate workaround still in force, or a deviation the code depends on — and that's stated as a present-tense rule, not as a story about a change.
- **File inventories.** Never enumerate the migration files, entity classes, controllers, endpoints, or any other directory listing — with or without a line of explanation each. Listing every file under `db/migration` and describing what each one did teaches nothing that opening the folder wouldn't, burns context on every future run, and is wrong the moment someone adds a file. Give the naming convention plus one example and point at the directory.
- **Narration about the exploration** — "I looked at…", "this appears to be…", notes on how the analysis was performed.
- **Generic technology explanation.** How Spring, JPA, jOOQ, or Flyway work in general is already in the skills. Write only what is specific to this project.
- **Speculation or aspiration** — planned refactors, what the code should eventually do. Record what holds now; anything you couldn't confirm goes in the final report to the user, not into the documents as a hedge.

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

Create `.claude/context/` (if absent) and write the following, under the output rules above. Use `${CLAUDE_PLUGIN_ROOT}/templates/ARCHITECTURE.md.template` as a starting structure for `ARCHITECTURE.md`; match its header style for the others. Keep each document under ~150 lines — link to specific source files rather than reproducing large code blocks.

Each document uses exactly the headings listed below, in this order, and no others. Fixed headings are what make the output deterministic across runs and refreshes — if a section has nothing to say for this project, write "None" under it rather than dropping it or inventing a replacement.

- **`ARCHITECTURE.md`** — per the template: `## Services / modules`, `## Request flow`, `## Data stores`, `## Cross-cutting concerns`, `## Known deviations from the pattern above`
- **`PATTERNS.md`** — `## Platform`, `## Persistence stack` (both required, per step 0b), then `## Layering`, `## Transaction boundaries`, `## Error handling`, `## REST clients`, `## Security`, `## Naming conventions` — the things a new contributor would learn by osmosis
- **`DOMAIN.md`** — `## Glossary` (core entity or concept → what it means to the business, one line each), then `## Business rules` (the invariants that constrain code, tied to the concept they govern)
- **`TESTING.md`** — `## Structure` (base classes, container setup, profiles), `## Conventions` (naming, fixtures, what gets tested at which level), `## Auth in tests`, `## Running tests`

### Which lists are allowed

The ban on inventories is about *reproducing a directory*, not about all lists. A **bounded structural list** is fine and often the clearest form: the modules in the build, the Postgres schemas and what each owns, the core domain concepts, the test profiles. These are small, stable, and each entry carries meaning a reader can't get from a filename.

A **file listing** is not: migrations, entity classes, controllers, endpoints, DTOs, test classes. These grow without bound, go stale on the next commit, and each entry restates its own filename. The test is whether the list would need editing because someone added a routine file — if yes, replace it with the convention plus one example and a pointer to the directory.

---

## Step 3 — Write project-specific skill overrides

Create `.claude/context/conventions/` inside the project (not inside the plugin) and write one file per skill. The plugin's skill files are never modified — this keeps the plugin safe for global installation shared across multiple projects. Each conventions file is the authoritative project-specific override for that skill; the plugin loads it at runtime.

For **existing projects**, populate each file with concrete details discovered in step 1 — the same output rules apply here as to the context docs: conventions and one example each, no inventories, no history. For **new projects**, write a brief note that conventions are yet to be established and list any technology choices already known.

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
- File naming convention, illustrated with one existing filename — never a listing of the migrations themselves
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

## Step 3b — Check each file as you write it

Writing is where the output rules get violated, so the check belongs at the moment of writing, not after. Before each `Write` in steps 2 and 3, run the drafted content past the list below and cut anything that matches.

**Do not re-read the files from disk to do this.** You wrote them in this session — their content is already in context, and a second `Read` of your own output buys nothing for real tokens.

Cut on sight:

- Any past-tense or comparative sentence about the code: "recently", "previously", "used to", "was migrated", "has been replaced", "unlike the older", "as of". Either the fact holds now and gets stated in the present tense, or it goes.
- Any list where the entries are filenames from one directory — migrations above all, but also entity/controller/DTO/test-class rollcalls. Replace with convention + one example + directory path, per the list rules in step 2.
- Any sentence describing this `/init-context` run: what was detected, generated, updated, or chosen. That belongs in the final report to the user, not in a file that future sessions load.
- Any paragraph explaining how a framework works generally, with nothing project-specific in it.
- Any heading not in the fixed set from step 2.

On `--refresh`, the same list applies to whatever you carry forward from the existing documents — that content genuinely does need reading, but read each file once in step 2 as part of refreshing it, not a second time here. A refresh that carefully preserves history someone accumulated in `ARCHITECTURE.md` last quarter has done the opposite of its job — strip it, and note in the report what you removed so the user can object.

---

## Step 4 — Wire into CLAUDE.md

If the project has no `CLAUDE.md`, create one from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template`. If one exists, add a pointer to the four context files if one isn't already present (see the template's `## Context` section for the wording) — a plain reference, not an `@`-import. The four docs are read directly by `/design`, `/implement`, and `/document-service` when they need them; `@`-importing them into `CLAUDE.md` would load all four into every session regardless of task, which is wasted context on anything that isn't one of those three. Don't disturb existing content while adding this.

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

### Also document quiet-output commands in CLAUDE.md

Independent of the permission-scope answer above (this writes to `CLAUDE.md`,
not `.claude/settings.json`) — if a build tool was detected, add a `## Common
commands` section to the project's `CLAUDE.md` with the same commands from the
table above, plus their quiet-output flags. The point isn't permission friction
this time, it's that a routine `./gradlew test` dumps hundreds of lines into
whatever session runs it; a documented quiet invocation keeps that noise out of
context on every future turn that reaches for it instead of guessing:

| Tool | Command |
|---|---|
| Gradle | `./gradlew test --console=plain -q` |
| Maven | `./mvnw test -q` |
| Node | project's actual test command with its runner's quiet/dot-reporter flag (e.g. `--reporter=dot` for Vitest, `--silent` for Jest) — check `package.json` scripts rather than guessing |
| Go | `go test ./... -count=1` — Go's default test output is already terse; no extra flag needed |

Skip this for new projects, same as the build-command table above — there's
nothing to detect yet. Append the section to `CLAUDE.md` rather than
overwriting existing content.

### On Bash beyond the table above

The build-command table covers the predictable, high-frequency cases; it deliberately doesn't try to cover everything, since safe Bash usage past that varies too much per project to guess upfront. Once a few `/design` → `/implement` cycles have run, point the user at the `fewer-permission-prompts` skill (a Claude Code built-in, not part of this plugin): it scans actual session transcripts for repeated read-only Bash/MCP calls and backfills `permissions.allow` with exactly what's been prompted for, never touches `permissions.deny`/`ask`, and refuses to allowlist anything that grants arbitrary code execution. Mention this to the user now so they know it exists for later — don't invoke it as part of this step.

---

Report a short summary of:
- Whether this was treated as a new or existing project
- What was written (context docs, skill updates), and on `--refresh`, anything step 3b stripped out of pre-existing content
- What was decided for permission friction (step 6): the scope chosen, exactly what was added to `.claude/settings.json`, what was deliberately skipped and why (e.g. "skipped `./gradlew *` — arbitrary execution"; "skipped `cat`/`git status` — already auto-allowed"), and a plain note that scoped Edit/Write means those calls stop being individually confirmed
- Whether a `## Common commands` section was added to `CLAUDE.md`, and what it lists
- Anything you were unsure about (ambiguous layering, conflicting patterns, conventions you couldn't confirm) so the user can correct generated content by hand
