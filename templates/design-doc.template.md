# Design: <title>

- **Spec reference:** <path or ticket id>
- **Status:** draft
- **Author:** design-architect (AI-generated, pending human review)

## Summary

<!-- What's being built and why, a few sentences. -->

## Affected modules/services

<!-- Name them specifically. -->

## Data model changes

<!-- New/changed tables, jOOQ codegen implications, migration approach.
     Include an erDiagram if new tables or FK relationships are introduced. -->

## API/contract changes

<!-- Request/response shapes, versioning implications.
     Include a sequenceDiagram for any endpoint touching more than one service or with non-trivial async behavior. -->

## Transaction boundaries

<!-- Where @Transactional applies. Explicitly flag anything spanning an external call, or touching idempotency-sensitive paths. -->

## Security / compliance considerations

<!-- Auth, data sensitivity, audit logging. Don't bury these in prose. -->

## Test plan

<!-- High-level scenarios only — actual test-writing is opt-in, decided later at /implement time.
     List only scenarios with real business value or high-value technical risk (auth, money,
     idempotency, data integrity, concurrency, security/compliance boundaries). Do not aim for
     coverage of every acceptance criterion or possible input — skip trivial CRUD, straightforward
     validation, and anything a reviewer would consider obvious. If nothing in this change clears
     that bar, say "No high-value scenarios — implementation is low-risk CRUD/plumbing" instead of
     padding the list.
     e.g. Given <state>, When <action>, Then <expected outcome>. -->

## Recommended implementation model

<!-- sonnet (default) / opus / haiku, plus a one-line reason specific to this spec.
     Advisory only — /implement will surface this and ask before doing anything with it. -->

## Open questions

<!-- Anything genuinely ambiguous that needs a human decision before implementation. -->

---

**Review checklist (human, before running /implement):**

- [ ] Affected modules match my expectation of blast radius
- [ ] Transaction boundaries are correct, especially around external calls
- [ ] Migration approach is backward-compatible
- [ ] Security/compliance considerations are complete, not just present
- [ ] Recommended implementation model matches my own read of the complexity
- [ ] Open questions are actually resolved, not silently assumed away
