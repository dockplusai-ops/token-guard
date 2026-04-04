#!/bin/bash
# token-guard uninstaller

SETTINGS="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
    echo "No settings.json found. Nothing to uninstall."
    exit 0
fi

python3 - "$SETTINGS" << 'PYEOF'
import json, sys

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

removed = 0
for event, entries in list(hooks.items()):
    filtered = [h for h in entries if 'token-guard' not in str(h)]
    if len(filtered) < len(entries):
        removed += len(entries) - len(filtered)
    if filtered:
        hooks[event] = filtered
    else:
        del hooks[event]

settings['hooks'] = hooks
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print(f'Removed {removed} token-guard hook(s).')
PYEOF

echo "✅ token-guard uninstalled."
