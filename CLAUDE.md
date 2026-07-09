# AI Rules

Claude Code entry point. Claude resolves `@` imports, so the rule files are
pulled in directly rather than inlined.

Other agents (Codex, OpenCode, Cursor, Cline) have no import syntax — they read
`AGENTS.md`, which is generated from these same rule files by
`scripts/build-agents.sh` and is self-contained.

@rules/breaks.md
@rules/tdd.md
@rules/coverage.md
@rules/git.md
@rules/issues.md
@rules/reflection.md
