#!/bin/bash
# token-guard: Re-inject project context after session compaction
# Hook event: PostCompact
#
# Reads context from (in priority order):
#   1. .claude/context.md  — custom context file in project root
#   2. CLAUDE.md           — first 50 lines of project CLAUDE.md

INPUT=$(cat)

CWD=$(echo "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('cwd', ''))
" 2>/dev/null)

CONTEXT=""

# Priority 1: custom context file
if [ -n "$CWD" ] && [ -f "$CWD/.claude/context.md" ]; then
    CONTEXT=$(cat "$CWD/.claude/context.md" 2>/dev/null)
fi

# Priority 2: first 50 lines of project CLAUDE.md
if [ -z "$CONTEXT" ] && [ -n "$CWD" ] && [ -f "$CWD/CLAUDE.md" ]; then
    CONTEXT=$(head -50 "$CWD/CLAUDE.md" 2>/dev/null)
fi

if [ -n "$CONTEXT" ]; then
    python3 -c "
import json, sys
context = sys.argv[1]
msg = f'[System: The session was compacted. Project context re-injected for reference:]\n\n{context}\n\n[Continue the work based on this context.]'
print(json.dumps({'type': 'text', 'text': msg}))
" "$CONTEXT"
fi

exit 0
