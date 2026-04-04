#!/bin/bash
# token-guard: Log token usage per session to ~/.claude/token-guard/usage.jsonl
# Hook event: Stop (async)

INPUT=$(cat)

LOG_DIR="$HOME/.claude/token-guard"
LOG_FILE="$LOG_DIR/usage.jsonl"
mkdir -p "$LOG_DIR"

python3 -c "
import json, sys, os, datetime, timezone

data = json.load(sys.stdin)

session_id = data.get('session_id', '')
cwd        = data.get('cwd', '')
project    = os.path.basename(cwd) if cwd else 'unknown'

usage         = data.get('usage', {})
input_tokens  = usage.get('input_tokens', 0)
output_tokens = usage.get('output_tokens', 0)
cache_read    = usage.get('cache_read_input_tokens', 0)
cache_write   = usage.get('cache_creation_input_tokens', 0)
total_tokens  = input_tokens + output_tokens

# Cost estimate based on Claude Sonnet pricing
INPUT_PRICE   = 3.00  / 1_000_000   # \$3/M input tokens
OUTPUT_PRICE  = 15.00 / 1_000_000   # \$15/M output tokens
CACHE_R_PRICE = 0.30  / 1_000_000   # \$0.30/M cache read tokens
est_cost = (
    input_tokens  * INPUT_PRICE +
    output_tokens * OUTPUT_PRICE +
    cache_read    * CACHE_R_PRICE
)

entry = {
    'ts':            datetime.datetime.utcnow().isoformat() + 'Z',
    'session_id':    session_id,
    'project':       project,
    'cwd':           cwd,
    'input_tokens':  input_tokens,
    'output_tokens': output_tokens,
    'cache_read':    cache_read,
    'cache_write':   cache_write,
    'total_tokens':  total_tokens,
    'est_cost_usd':  round(est_cost, 6),
}

log_file = sys.argv[1]
with open(log_file, 'a') as f:
    f.write(json.dumps(entry) + '\n')
" "$LOG_FILE" 2>/dev/null

exit 0
