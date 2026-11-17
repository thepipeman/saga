---
name: review
description: Standalone code review of a branch, PR, or the working tree against this project's conventions. It writes a short report (verdict, mental model, impact, findings by severity, guardrail candidates, rule proposals) to .claude/code-review/. It's separate from the design/implement/finish workflow and never touches its state.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, WebFetch, AskUserQuestion, Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git symbolic-ref:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(mkdir:*), Bash(./gradlew dependencyCheckAnalyze), Bash(./mvnw dependency-check:check)
argument-hint: "[<branch> | <PR number>] [--req <path|url>]"
---

You are reviewing a change as a reviewer who didn't write it. The review checks the change against this project's conventions and its requirements. It is high-value on functionality, correctness, scalability, and code quality, and as short as that allows.

This command stands alone. It never reads or writes `.claude/workflow/state.json`, doesn't need `/design` or `/implement` to have run, and doesn't unlock `/finish`. It reviews code and writes a report; it never edits code, conventions, or docs, and never posts to the PR.

## Step 1 — Resolve the target

Parse `$ARGUMENTS`:

- **A number:** a PR. Read its title, description, and diff with `gh pr view <n>` and `gh pr diff <n>`. The slug is `pr-<n>`.
- **A branch name:** diff it against the default branch from their merge base. The slug is the branch name with `/` replaced by `-`.
- **Nothing:** the current branch against the default branch from their merge base, plus any uncommitted changes. The slug is the current branch name, as above. If you're on the default branch, review only the uncommitted changes and use the slug `working-tree`.
- **`--req <path|url>`:** the requirement source, used in step 3.

Get the default branch from `git symbolic-ref refs/remotes/origin/HEAD`, falling back to `main`. If the diff is empty, say so and stop.

## Step 2 — Load the rules

Read `.claude/context/REVIEW.md`. It's the rulebook: severities, the convention map, cross-cutting checks, the dependency check, guardrails, and the report format.

Then read only the conventions files that its **Convention map** links to paths in the diff, and only the context docs you need. That usually means `DOMAIN.md` for business rules and `ARCHITECTURE.md` for blast radius. Don't read the rest. Every file loaded costs tokens on every review.

If `REVIEW.md` doesn't exist (`/init-context` hasn't been run), still do the review:

- Use `${CLAUDE_PLUGIN_ROOT}/templates/REVIEW.md.template` for the severities, cross-cutting checks, and report format.
- Use the `## Review checklist` of each saga skill matching the changed code, plus any `.claude/context/conventions/<skill>.md` that exists.
- Say in the report's **Unverified** section that no project review guide was found.

## Step 3 — Find the requirement source

Take the first that's available:

1. `--req`: read the file, or fetch the URL.
2. The PR description and the documents it links.
3. The requirement-docs location named in `REVIEW.md`.
4. A saga spec in `.claude/instructions/` or a design doc in `.claude/design-drafts/` that matches the change.

If a link can't be opened (for example, it needs a login), ask the user to paste the relevant part, or carry on without it and note that under **Unverified**. With no source at all, check correctness only against the code and `DOMAIN.md`. Put the questions about intended behavior under **Unverified** rather than claiming anything is correct.

## Step 4 — Review

Read the changed code with enough of its surroundings to judge it: callers (use Grep for usages of changed methods and types), the transaction it runs in, and the tests that cover it. Then apply the checklist items from the conventions files you loaded, `REVIEW.md`'s cross-cutting checks, and the requirement source.

- **Only report what you can point to.** Every finding names a location and a concrete failure: what input or state leads to what wrong outcome. A suspicion you couldn't confirm goes under **Unverified**, not into the findings.
- **Use the item's severity.** Change it only with a one-line reason in the finding.
- **Skip rules an existing guardrail test already enforces** (`REVIEW.md` → Guardrails).
- **Dependency check:** run the command in `REVIEW.md` only if build or dependency files changed (`build.gradle*`, `settings.gradle*`, `gradle/libs.versions.toml`, `pom.xml`). If it's "None", skip it silently. If it fails to run, note that under **Unverified**. Never claim the change has no vulnerabilities.
- **Guardrail candidates:** structural rules this change shows are worth enforcing as a test. Check the `[guardrail]` checklist items first. One bullet each, no test code.
- **Rule and convention proposals:** a pattern used consistently but not recorded, a checklist item that should be added, dropped, or re-rated, or a context doc or conventions file this change makes wrong.

## Step 5 — Write the report

Run `mkdir -p .claude/code-review`. Write `.claude/code-review/<slug>-review.md` in the format from `REVIEW.md`'s **Report** section, and leave out any section with nothing to say. Start the file with one line naming the target (branch and base, or PR number and title) and the requirement source used.

If a report for this slug already exists, overwrite it. It describes the change as it stands now, not a history of reviews.

Write for a reader who hasn't seen the diff: plain, short sentences, findings only, no praise, and no retelling of the diff.

## Step 6 — Report back

In chat, give:

- the verdict and the number of findings per severity
- each **High** finding's title and location
- the path to the report file

Nothing else. Everything else is in the file.
