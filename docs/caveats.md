# Key Caveats & Gotchas

---

## Technical Constraints

- **Skills system** (`/mnt/skills/`) is specific to the claude.ai interface — Claude Code CLI is unaware of it. Conversation logging in Claude Code requires a shell wrapper, git hook, or small script.
- **Keyboard shortcuts on Flutter Web** are viable using the `Shortcuts`/`Actions` pattern.
- **MCP is CI-side only** — in-app navigation/form control uses JSON action dispatching to stay App Store compatible.
- **Drift over alternatives** because it provides identical query/schema code across all platforms (native SQLite + WASM).

## Wiki Generation
- Git hooks were attempted for auto-regeneration but failed due to Claude CLI path issues in the hook's shell environment
- Solution: CLAUDE.md instruction tells Claude to regenerate wiki before every commit instead
- This means commits should be done through Claude Code to ensure the wiki stays current

## Agent Teams Constraints

- **Agent teams are experimental** — known limitations around session resumption, nested teams, and shutdown behavior.
- **Agent Teams is CLI-only** — must run from terminal with `claude` command while CD'd into the project directory. Does not work from the VS Code extension.
- **Max effort** is Opus 4.6 only — using it on other models returns an error.
- **Effort is set at spawn/call time**, not mid-task — TPM must embed effort guidance in the task prompt itself.
- **Worktree-per-task** — each agent works in a git worktree on its own branch (e.g., `swe1/TASK-001`). SWEs open PRs, peer review each other, and author merges after approval.
- **5-6 tasks per teammate** is the recommended sweet spot.
- **TPM delegation question:** Can the TPM handle tasks itself, or does it always delegate? Does it have to wait for a SWE to complete a task before continuing? (Needs testing)
- **Thought logging is embedded in agent prompts** — not a separate task or hook. Each agent definition file has the logging instruction built in. It fires as part of the agent's workflow, not as an external enforcement mechanism.

## Claude Hooks

`PostToolUse`, etc. allow running commands before/after Claude actions — different from `CLAUDE.md` prompts. Configured in `~/.claude/CLAUDE.md` or `settings.json`. Example:
```json
"hooks": {
  "PostToolUse": [{
    "matcher": "Write(*)",
    "hooks": [{ "type": "command", "command": "npm run lint --silent" }]
  }]
}
```

---

> Raw ideas that were previously here have been incorporated into `docs/requirements.md` and `docs/progress.md`.
