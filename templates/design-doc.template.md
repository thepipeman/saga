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

<!-- Map to acceptance criteria from the spec. -->

## Open questions

<!-- Anything genuinely ambiguous that needs a human decision before implementation. -->

---

**Review checklist (human, before running /approve-design):**

- [ ] Affected modules match my expectation of blast radius
- [ ] Transaction boundaries are correct, especially around external calls
- [ ] Migration approach is backward-compatible
- [ ] Security/compliance considerations are complete, not just present
- [ ] Open questions are actually resolved, not silently assumed away
