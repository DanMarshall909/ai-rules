# Criterion-based agent assignment

Read before delegating implementation or selecting a higher-cost implementation
agent. This does not change the independent completion-review requirement.

## Assign agent capability from criterion evidence

When the host supports delegation or model selection, choose from evidence
rather than task prestige or apparent code size. Before assigning a higher-cost
or highest-capability implementation agent, map every delegated acceptance
criterion using these fields:

| Field | Required evidence |
|---|---|
| Criterion | The exact observable outcome or invariant being assigned. |
| Landed proof | Independently accepted behaviour, code, tests, revision and review that prove the same criterion. |
| Novel boundary | Any unproved decision, state transition, persistence shape, authority boundary, interface or foundational primitive. |
| Assignment | `Tracer` for a named novel boundary; otherwise `Followup` with the lowest-cost qualified agent. |

Apply the map as follows:

- A criterion with an unproved boundary is a tracer even when its code looks
  small. Assign a sufficiently capable agent and make that smallest coherent
  end-to-end slice the reference implementation.
- A criterion fully mapped to landed proof is a followup. Use the least
  resource-intensive available agent that has the required reasoning ability,
  tools, context and permissions; do not repeat the tracer merely because the
  feature is important, broad, on the critical path or crosses layers.
- For mixed work, carve out the smallest tracer that proves the novel boundary
  and leave every fully mapped criterion as a separately bounded followup.
- Dependency or code reuse alone does not prove followup status. If the mapping
  is uncertain, investigate first; unresolved novelty remains a tracer rather
  than an assumed followup.

Project policy may name concrete models, require a stronger tier or prohibit
delegation. Independent completion review retains the capability and separation
requirements in `references/completion-review.md`; this assignment rule does not
lower them.
