# The Output Is An API

The users of a tool an agent drives are programs. Whatever the tool prints is
parsed by something that cannot ask what was meant, so the output is an
interface, and changing it is a breaking change — even when it reads better.

- **Results on stdout, everything else on stderr.** Progress, warnings and
  timings mixed into stdout corrupt the payload of every caller that pipes it.
- **Failure is the exit code.** An error printed while exiting 0 is invisible to
  the only check a script reliably makes. Never report a failure by wording
  alone.
- **Deterministic by default.** Ordering, timestamps, absolute paths and
  parallel interleaving are the usual sources of output that differs run to run;
  a caller diffing two runs cannot tell that noise from a real change.
- **Non-interactive by default.** A prompt in an automated run is a hang, and a
  hang is the most expensive failure there is: nothing reports it.
- **Structured output is a mode, not a debug flag.** If agents are expected to
  parse it, it is specified and tested like an API.

The reason this needs stating: the tool is developed by watching it in a
terminal, where all five read as cosmetic preferences. They are only visibly
load-bearing from inside the caller, and the caller is not in the room.

## Changing it

Know who reads the output before changing it. Inside the repo that is the
callers you can grep for; past a release it is callers you cannot see, and the
change needs a flag or a version. Renaming a field "while we are in here" is the
same act as renaming a public method, minus the compiler.

A test that parses the tool's output with a hand-rolled reader will not catch
any of this: the reader is written to match what the code emits today, so it
agrees with whatever the code does next. Parse with the reader the real consumer
uses (see [[coverage]]).
