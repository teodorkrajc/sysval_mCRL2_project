# AI usage log

Every AI contribution: date, tool, what it did, which files. Required for the report's AI declaration.

| Date | Tool | What | Files |
| --- | --- | --- | --- |
| 2026-10-08 | Claude Code (Claude Opus 5.5) | Tested which mCRL2 data features work on 202607.0 (no recursion over FSet; struct `<` exists; three-party comm accepted). Wrote model draft 1: sorts, constants, location and pool helpers, action declarations, component skeletons, `init`. Updated conventions (pool as sorted List, MAXPOOL = 5, model path) and noted known pitfalls. | `TouchpointTowers/TouchpointTowers_spec.mcrl2`, `docs/AGENTS.md`, `docs/design.md`, `.gitignore`, `docs/ai-usage.md` |
