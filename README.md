# token-guard

Automatic Claude Code hooks to reduce token waste and context bloat — no manual intervention required.

## What it does

### 1. Block heavy files (`PreToolUse`)
Automatically blocks reads of files that waste context tokens:
- Lock files: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Gemfile.lock`, `Cargo.lock`, `poetry.lock`
- Build artifacts: `node_modules/`, `dist/`, `.next/`, `build/`, `vendor/`
- Compiled/minified: `*.min.js`, `*.min.css`, `*.map`, `*.pyc`, `__pycache__/`
- Any file larger than 200KB (~50k tokens)

Claude gets a clear message explaining why the file was blocked and what to read instead.

### 2. Context usage warning (`UserPromptSubmit`)
Injects a warning before every prompt when the context window is filling up:

| Usage | Level | Message |
|---|---|---|
| < 50% | — | Silent |
| 50–69% | 🟡 WARNING | Keep responses concise |
| 70–84% | 🟠 HIGH | Consider starting a new session |
| ≥ 85% | 🔴 CRITICAL | Open a new session now |

### 3. Context re-injection after compaction (`PostCompact`)
When Claude compacts the session (context limit reached), automatically re-injects project context from:
1. `.claude/context.md` in the project root (if it exists)
2. First 50 lines of `CLAUDE.md` in the project root (fallback)

### 4. Token usage logger (`Stop`, async)
Logs every session's token usage to `~/.claude/token-guard/usage.jsonl` for cost tracking.

## Installation

```bash
git clone https://github.com/dockplusai-ops/token-guard
cd token-guard
bash install.sh
```

That's it. All hooks are registered automatically in `~/.claude/settings.json`.

## Usage

```bash
# View usage report (last 7 days)
bash token-guard-report.sh

# View usage report (last 30 days)
bash token-guard-report.sh 30
```

Example output:
```
=== Token Guard Report — Last 7 days ===
Sessions:        12
Input tokens:    1,240,000
Output tokens:     310,000
Estimated cost:  $5.3650 USD

By project:
  Project                    Input     Output       Cost
  ------------------------- ---------- ---------- ----------
  portal-pregoes             480,000    120,000    $3.2400
  my-app                     760,000    190,000    $2.1250
```

## Custom context file

Create `.claude/context.md` in any project to customize what gets re-injected after compaction:

```markdown
## Stack
Next.js 15, Prisma, PostgreSQL, shadcn/ui

## Key conventions
- Always use server components by default
- API routes in /app/api/
- DB schema in prisma/schema.prisma

## Important files
- lib/db.ts — Prisma client
- lib/auth.ts — NextAuth config
```

## Uninstall

```bash
bash uninstall.sh
```

## How it works

token-guard uses [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — shell scripts that run automatically at specific lifecycle events. No background processes, no daemons, no API keys required.

| Hook | Event | Behavior |
|---|---|---|
| `block-heavy-files.sh` | `PreToolUse` | Blocks file reads, returns `{"decision": "block"}` |
| `context-warning.sh` | `UserPromptSubmit` | Injects warning text into session |
| `post-compact-reinject.sh` | `PostCompact` | Injects context text into session |
| `cost-logger.sh` | `Stop` (async) | Appends JSONL log entry |

## Requirements

- Claude Code (any recent version)
- Python 3 (already required by Claude Code)
- bash
