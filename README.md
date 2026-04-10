# ai-rules

Lean, agent-agnostic coding rules. Works with Claude Code, Cursor, Windsurf, Cline, and any AI coding assistant that reads markdown rule files.

## Structure

```
AGENTS.md          ← main entry point (@imports the rules below)
rules/
  breaks.md        ← 30-min + 2-hour break reminders with goal check-in
  tdd.md           ← Red→Green→Refactor→Coverage cycle
  git.md           ← pull --rebase, backup before force-push
  issues.md        ← docs/issues/[open|resolved]/[area]/ tracking
```

## Usage

**Claude Code** — add to your project `CLAUDE.md`:
```
@https://raw.githubusercontent.com/DanMarshall909/ai-rules/main/AGENTS.md
```

**Cursor** — add to `.cursor/rules/ai-rules.mdc`:
```
@ai-rules/AGENTS.md
```

**Copy** — paste `AGENTS.md` content directly into your project's AI rules file.
