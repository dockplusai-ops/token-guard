#!/bin/bash
# token-guard: Warn when context window usage exceeds 50%
# Hook event: UserPromptSubmit
# Injects a warning message into the session before Claude processes the prompt

INPUT=$(cat)

python3 -c "
import json, sys

data = json.load(sys.stdin)

ctx = data.get('context_window', {})
usage_pct = ctx.get('usage_percentage', 0)

# Try alternate field names
if not usage_pct:
    usage_pct = data.get('context_usage_percentage', 0)
if not usage_pct:
    tokens_used  = ctx.get('tokens_used', 0) or data.get('tokens_used', 0)
    tokens_total = ctx.get('tokens_total', 0) or data.get('tokens_total', 0)
    if tokens_total > 0:
        usage_pct = tokens_used / tokens_total

if usage_pct < 0.50:
    sys.exit(0)

tokens_used  = ctx.get('tokens_used', 0)
tokens_total = ctx.get('tokens_total', 0)
pct_int = int(usage_pct * 100)

if usage_pct >= 0.85:
    level   = 'CRITICAL'
    emoji   = '🔴'
    advice  = 'Context almost full. Finish the current task or open a new session (/new) to avoid context loss.'
elif usage_pct >= 0.70:
    level   = 'HIGH'
    emoji   = '🟠'
    advice  = 'Heavy context. Prefer short, direct responses. Consider starting a new session soon.'
else:
    level   = 'WARNING'
    emoji   = '🟡'
    advice  = 'Context above 50%. Keep responses concise to save tokens.'

token_info = f' ({tokens_used:,}/{tokens_total:,} tokens)' if tokens_total else ''

msg = f'[Token Guard {emoji} {level}: Context {pct_int}% used{token_info}. {advice}]'
print(json.dumps({'type': 'text', 'text': msg}))
" <<< "$INPUT"

exit 0
