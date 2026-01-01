---
name: devlog
description: Write a development log entry summarizing completed coding work. Use when the user asks to write a devlog, document what was done, create a summary of changes, or after finishing a significant coding task.
---

# Devlog

Write a development log entry to `docs/devlog/` summarizing the coding work just completed.

## File Naming

Use the format: `YYYY-MM-DD-short-description.md`

- Date is today's date
- Short description is 1-3 words derived from the main topic (lowercase, hyphenated)
- Examples: `2026-01-01-auth-flow.md`, `2026-01-01-camera-service.md`

## Template

```markdown
# [Brief Title]

**Date:** YYYY-MM-DD

## Summary

1-2 sentence overview of what was accomplished.

## Changes

- List key files created or modified
- Group related changes together
- Note any architectural decisions made

## Technical Details

Explain implementation details worth remembering:
- Patterns used
- Trade-offs made
- Why certain approaches were chosen

## Next Steps

Optional section for follow-up work identified during implementation.
```

## Guidelines

1. **Be concise** - Focus on what matters for future reference
2. **Capture the "why"** - Implementation details fade; reasoning is valuable
3. **Link to code** - Reference file paths when helpful
4. **Skip the obvious** - Don't document trivial changes
