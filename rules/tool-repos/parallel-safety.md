# Assume Parallel Invocation

A tool an agent drives is run by several agents at once — separate worktrees,
separate sessions, the same machine and often the same second. Anything the tool
writes outside its own process is shared state, and shared state written by two
runs at once is corrupt state.

Treat as shared until proved otherwise: caches, indexes, build intermediates,
log and report files, lock files, temporary directories on a fixed path,
anything appended to, and anything named after the tool rather than the run.

Two ways to be safe, in order of preference:

1. **Scope it to the invocation.** A path that includes the run's own identity
   cannot be contended. This is almost always cheaper than coordinating.
2. **Make the write atomic.** Write to a temporary file and rename, or append a
   whole record in one call. Read-modify-write of a shared file is the shape
   that loses data, and it loses it silently.

The reason this is worth a rule: concurrency bugs here do not fail loudly. Two
runs interleave into one truncated log, or one clobbers the other's output, and
what the agent reads back is plausible — just wrong. It reproduces only under
load, which is exactly when nobody is watching.

## Testing it

Assert the property, not the timing: run the operation from several processes
at once and check every record survives. A test that runs the tool twice in
sequence proves nothing about the case that breaks.
