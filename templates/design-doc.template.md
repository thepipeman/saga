# Design: <title>

- **Spec:** <path or ticket id>
- **High-level design:** <path/url from the spec, or "none">
- **Status:** draft — AI-generated, pending human review

<!-- Every section below is always present. A section this change doesn't touch says
     "No changes." on one line — never delete the heading, never pad it.

     On a re-run, rewrite this doc in place: it describes only the current design.
     Remove superseded decisions rather than appending revisions — unless a rejected
     option is a live constraint, in which case state it as a constraint where it applies. -->

## Summary

<!-- 2–4 sentences: what this change builds and why.
     Then the scope, taken from the spec:
     **In scope:** <the stage/part of the high-level design this delivers>
     **Out of scope:** <adjacent parts deferred to other tasks — one line each> -->

## Process flow

<!-- A diagram when this change introduces a new flow or alters an existing one — that's
     the reviewer's mental model. Mermaid; sequenceDiagram for cross-service or async
     flows, flowchart TD for state machines/branching. Draw only the in-scope part;
     show out-of-scope collaborators as a single stubbed participant.
     Follow with 1–3 bullets for rules the diagram can't show (fail-fast vs. retry,
     terminal states). No new or changed flow → "No changes." -->

## Critical changes and blast radius

<!-- Only changes a reviewer must look at: new/changed public contracts, new classes that
     carry logic, behavior changes to existing code. Not every file touched, not DTOs or
     wiring that follow mechanically.

     | Change | Where | Impact |
     |---|---|---|
     | New | `orders` › `CheckoutService` | Owns the CART → PENDING_PAYMENT transition |
     | Changed | `orders` › `OrderController` | Adds `POST /v2/orders` — new public contract |

     `Where` is module › class (no full package paths). State the package once below the
     table only if a new package is introduced.

     **Blast radius:** who else is affected — callers, consumers of a changed contract,
     shared config, migrations on hot tables. One bullet each.

     **Flags:** call out explicitly, one bullet each, only those that apply:
     - an external call reachable inside a @Transactional method (and how it's avoided)
     - idempotency-sensitive paths
     - a breaking or versioned contract change -->

## Data model changes

<!-- High-level only: what data exists and its type. No DDL, no migration walkthrough.

     | Table / entity | Field | Type | Note |
     |---|---|---|---|
     | `orders` (new) | `status` | `text` | enum-backed, indexed |

     One line after the table for anything a reviewer must decide: required index,
     backward-compatibility of the migration, N+1-prone association, jOOQ codegen impact.
     erDiagram only for new tables with relationships between them. -->

## Security implications

<!-- Auth/authz, data sensitivity, audit logging, enumeration or replay surface.
     Bullets, one concern each. "No changes." if the change touches none of these. -->

## Test plan

<!-- One line per scenario: Given <state>, When <action>, Then <outcome>. No explanation
     beyond that line. Tag each with its source:
     - [spec] — from the spec's test scenarios (all of them, verbatim in meaning)
     - [recommended] — added by the design, only within the spec's scope, only for real
       business or technical risk the spec missed -->

## Recommended split

<!-- Only when the spec's scope is larger than one reviewable deliverable — e.g. it bundles
     the core flow with several integrations, or a cluster of edge cases deserves its own
     review. List the suggested tasks in delivery order, one line each with the scenarios
     each would own. Otherwise: "None — scope fits one deliverable." -->

## Recommended implementation model

<!-- sonnet (default) / opus / haiku, plus a one-line reason specific to this spec.
     Advisory only — /implement surfaces it and asks before switching. -->

## Open questions

<!-- Anything genuinely ambiguous that needs a human decision before implementation.
     "None." if there are none. -->

---

**Review checklist (human, before running /implement):**

- [ ] Scope matches the stage/task I intended — nothing out of scope designed in
- [ ] Critical changes and blast radius match my expectation
- [ ] No external call inside a transaction; idempotent paths are identified
- [ ] Data model changes are backward-compatible
- [ ] Security implications are complete, not just present
- [ ] Test plan covers the spec's scenarios; recommended additions are worth it
- [ ] Open questions are resolved, not silently assumed away
