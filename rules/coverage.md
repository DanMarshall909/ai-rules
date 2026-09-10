# Coverage & Dead Code

When reviewing coverage, mutation results, compatibility paths, or dead code,
use the `coverage-and-mutation` skill.

- Aim for 100% coverage of core code through externally observable behavior.
- An uncovered line has never executed; a covered line has not necessarily been
  checked by an assertion.
- Remove code that has no useful caller or contract instead of covering it for
  its own sake.
- Establish coverage before mutation testing, and calibrate the mutation harness
  with a fault you have watched the relevant test reject.
