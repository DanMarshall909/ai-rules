# Coverage & Dead Code

When reviewing coverage, mutation results, compatibility paths, or dead code,
use the `coverage-and-mutation` skill.

- Aim for 100% coverage of core code through externally observable behavior.
- An uncovered line did not execute in the measured run (assuming sound
  instrumentation); a covered line was not necessarily checked by an assertion.
- Remove code that has no useful caller or contract instead of covering it for
  its own sake.
- Establish coverage before mutation testing, and calibrate the mutation harness
  with a fault you have watched the relevant test reject.
