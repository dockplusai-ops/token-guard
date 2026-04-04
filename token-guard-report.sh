#!/bin/bash
# token-guard: Show token usage report from logs
# Usage: bash token-guard-report.sh [days]
# Example: bash token-guard-report.sh 30

DAYS="${1:-7}"
LOG_FILE="$HOME/.claude/token-guard/usage.jsonl"

if [ ! -f "$LOG_FILE" ]; then
    echo "No usage log found yet. Data will appear after the next Claude Code session."
    exit 0
fi

python3 -c "
import json, sys
from datetime import datetime, timedelta, timezone
from collections import defaultdict

days = int(sys.argv[1])
log_file = sys.argv[2]
cutoff = datetime.now(timezone.utc) - timedelta(days=days)

entries = []
with open(log_file) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            e = json.loads(line)
            ts = datetime.fromisoformat(e['ts'].replace('Z', '+00:00'))
            if ts >= cutoff:
                entries.append(e)
        except Exception:
            pass

if not entries:
    print(f'No data found for the last {days} days.')
    sys.exit(0)

total_input  = sum(e.get('input_tokens', 0) for e in entries)
total_output = sum(e.get('output_tokens', 0) for e in entries)
total_cost   = sum(e.get('est_cost_usd', 0) for e in entries)
sessions     = len(set(e.get('session_id', '') for e in entries))

print(f'=== Token Guard Report — Last {days} days ===')
print(f'Sessions:        {sessions}')
print(f'Input tokens:    {total_input:>12,}')
print(f'Output tokens:   {total_output:>12,}')
print(f'Estimated cost:  \${total_cost:.4f} USD')
print()

by_project = defaultdict(lambda: {'input': 0, 'output': 0, 'cost': 0, 'sessions': set()})
for e in entries:
    p = e.get('project', 'unknown')
    by_project[p]['input']  += e.get('input_tokens', 0)
    by_project[p]['output'] += e.get('output_tokens', 0)
    by_project[p]['cost']   += e.get('est_cost_usd', 0)
    by_project[p]['sessions'].add(e.get('session_id', ''))

print('By project:')
print(f'  {\"Project\":<25} {\"Input\":>10} {\"Output\":>10} {\"Cost\":>10}')
print(f'  {\"-\"*25} {\"-\"*10} {\"-\"*10} {\"-\"*10}')
for proj, data in sorted(by_project.items(), key=lambda x: -x[1]['cost']):
    print(f'  {proj:<25} {data[\"input\"]:>10,} {data[\"output\"]:>10,}  \${data[\"cost\"]:>8.4f}')
" "$DAYS" "$LOG_FILE"
