# Global Agent Rules

## Git Workflow

Use these git aliases (defined in your `~/.config/git/config`):
- `git st` for status
- `git co` for checkout
- `git cm` for commit
- `git a` for add --all
- `git p` for push
- `git lg` for fancy log graph

**Allowed git operations**: status, log, diff, add, commit, push, stash, blame
**Deny/Catastrophic**: rebase -i, merge, force push, reset --hard, branch -D

## Tool Preferences

Prefer these tools over alternatives. Use `which <tool>` to check availability and fallback to originals if not installed:
- **Directory listing**: Use `eza -la` or `eza --tree --level=2 --ignore-glob=node_modules` (fallback: `ls`)
- **File search**: Use `fd --max-depth` (fallback: `find`)
- **Content search**: Use `rg --smart-case` (fallback: `grep`)
- **File deletion**: Use `trash` (fallback: `rm -i`)
- **Fuzzy finder**: Use `fzf`

### All Agents (Build, Plan, Explore)
- Directory listings: prefer `eza` with `--color=always -a` flags
- File finding: prefer `fd` over `find`
- Grep operations: prefer `rg` over `grep`

## Code Style

- Follow existing patterns in the codebase
- Match the project's indentation, naming conventions, and formatting
- Run lint/typecheck before marking work complete
- Write tests for new functionality

## Available Skills

- **git**: Git workflows - commits, PRs, atomic splits, hunk staging
- **caveman**: Ultra-compressed communication - 75% fewer tokens, full accuracy
- **review**: Epistemic standards for code review/debugging

## Response Style

- Be concise; avoid unnecessary preamble/explanations
- Answer directly with minimal verbosity
- Use code references with file:line_number format when pointing to code
