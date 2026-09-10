---
name: document-service
description: Generates docs/about-this-service — a concise technical and business overview of the service, plus one doc per feature with a high-level sample flow and gotchas. Standalone, not part of the design/implement/finish pipeline.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Bash(find:*), Bash(git log:*), AskUserQuestion
argument-hint: "[--refresh]"
---

You are documenting this service for humans — new contributors, reviewers, and stakeholders who need to understand what it does and how it fits together without reading the whole codebase. This is official, human-maintained documentation, not an AI-generated draft: it lives in `docs/about-this-service/`, separate from `.claude/design-drafts/` and `.claude/implementation-notes/`.

If `--refresh` was NOT passed and `docs/about-this-service/` already has content, ask the user to confirm before overwriting rather than silently regenerating.

## Step 1 — Gather context

Read `.claude/context/ARCHITECTURE.md`, `PATTERNS.md`, `DOMAIN.md`, and `TESTING.md` if present — `/init-context` writes these and they're the fastest path to accurate module boundaries and domain vocabulary. If they're missing, say so and fall back to exploring the codebase directly with Glob/Grep/Read: entry points (controllers, message consumers, scheduled jobs), module/package boundaries, and README/docs for business framing.

Establish, from whatever evidence exists:

- **Business purpose** — what problem the service solves and who consumes it (other services, end users, internal teams)
- **NFRs actually evidenced in the codebase or context docs** — things like auth requirements, rate limits, retry/timeout config, SLAs mentioned in comments or config. Don't invent NFRs nothing in the repo supports; if none are evidenced, say so rather than padding with generic claims.
- **High-level architecture** — module/service boundaries and how requests flow through them (reuse `ARCHITECTURE.md` if present)

## Step 2 — Identify features

From module/controller boundaries and domain vocabulary, propose a short list of the service's high-level features or capabilities — the natural grain a stakeholder would recognize (e.g. "Order checkout", "Refund processing"), not one entry per endpoint or class. Show the proposed list to the user and let them adjust it before you write anything — getting the slice wrong means regenerating everything downstream.

## Step 3 — Write the base overview

Write `docs/about-this-service/README.md` covering:

- What the service does and why, in a few sentences
- NFRs from Step 1, or an explicit note that none are evidenced yet
- High-level architecture, with a `graph LR` or `flowchart TD` Mermaid diagram of module/service boundaries where that clarifies more than prose
- A **Features** list linking to each per-feature doc written in Step 4

Be explicit and concise — this is a reference, not an exhaustive spec. No filler, no restating the obvious.

## Step 4 — Write one doc per feature

For each feature confirmed in Step 2, write `docs/about-this-service/<feature-slug>.md`:

- **What it does and why it exists** — a few sentences
- **Sample flow** — one or two high-level Mermaid diagrams (`sequenceDiagram` for multi-actor interactions, `flowchart TD` for branching/state logic) showing the main path through the system. Show the common case, not every branch.
- **Gotchas** — non-obvious constraints, edge cases, or footguns a developer or stakeholder should know before touching this feature: idempotency requirements, eventual consistency, deprecated-but-still-live code paths, surprising coupling to another feature. If there's genuinely nothing non-obvious, write "No notable gotchas" rather than padding the section.

`git log` is the best source for this last section specifically — a fix commit explaining why a retry was removed, or why an apparently redundant guard exists, is a gotcha the code itself won't tell you. `git log --oneline -20 -- <feature paths>` is usually enough; `git log -S"<symbol>"` when one specific oddity needs explaining. Use it for gotchas, not for the other sections.

Each feature doc should be readable in a couple of minutes — this is oriented material, not a full spec.

## These docs describe the service as it is now

Everything written here is present tense, describing the current service. Nothing describes how it got that way. No "recently migrated to…", "the old endpoint used to…", "as of the last release", no release notes, no summary of what changed since the previous run of this command — the project's changelog and git history own that, and a stakeholder reading `docs/about-this-service/` wants to know how the thing works today.

This applies to what you find in `git log` above: it's evidence for what's true now, and the gotcha gets written as a live constraint ("this endpoint is not idempotent — the client must not retry it"), never as the story of the commit that established it. The narrow exception is a deprecated-but-still-live path a reader would otherwise use by mistake; name it as currently-deprecated with what to use instead, which is a present-tense fact about the code, not history.

On `--refresh`, strip any such content already present in the existing docs rather than preserving it, and say what you removed in the final report.

## Notes

- Read-only against source; writes only under `docs/about-this-service/`.
- Re-run with `--refresh` after significant feature changes to keep this current — review the diff before accepting it, the same as `/init-context --refresh`.

Report a short summary of what was written (base overview + feature docs list) and any gaps flagged along the way (missing context docs, NFRs that couldn't be confirmed from the codebase).
