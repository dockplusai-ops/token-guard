#!/bin/bash
# token-guard installer
# Installs hooks into ~/.claude/settings.json

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$REPO_DIR/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "Installing token-guard hooks..."

# Make hooks executable
chmod +x "$HOOKS_DIR"/*.sh
chmod +x "$REPO_DIR/token-guard-report.sh"

# Create ~/.claude if it doesn't exist
mkdir -p "$HOME/.claude"

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

# Inject hooks into settings.json
python3 - "$HOOKS_DIR" "$SETTINGS" << 'PYEOF'
import json, sys, os

hooks_dir = sys.argv[1]
settings_path = sys.argv[2]

try:
    with open(settings_path) as f:
        settings = json.load(f)
except Exception:
    settings = {}

hooks = settings.get('hooks', {})

def add_hook(hooks, event, matcher, command, timeout=5, async_=False):
    entries = hooks.get(event, [])
    # Remove existing token-guard entry for this event
    entries = [h for h in entries if 'token-guard' not in str(h)]
    hook = {
        'matcher': matcher,
        'hooks': [{
            'type': 'command',
            'command': command,
            'timeout': timeout,
        }]
    }
    if async_:
        hook['hooks'][0]['async'] = True
    entries.append(hook)
    hooks[event] = entries

add_hook(hooks, 'PreToolUse',         'Read', os.path.join(hooks_dir, 'block-heavy-files.sh'))
add_hook(hooks, 'UserPromptSubmit',   '',     os.path.join(hooks_dir, 'context-warning.sh'))
add_hook(hooks, 'PostCompact',        '',     os.path.join(hooks_dir, 'post-compact-reinject.sh'))
add_hook(hooks, 'Stop',               '',     os.path.join(hooks_dir, 'cost-logger.sh'), async_=True)

settings['hooks'] = hooks
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print('  ✅ PreToolUse  → block-heavy-files.sh')
print('  ✅ UserPromptSubmit → context-warning.sh (>50% context)')
print('  ✅ PostCompact → post-compact-reinject.sh')
print('  ✅ Stop        → cost-logger.sh (async)')
PYEOF

echo ""
echo "✅ token-guard installed successfully!"
echo ""
echo "Usage:"
echo "  bash $REPO_DIR/token-guard-report.sh        # last 7 days"
echo "  bash $REPO_DIR/token-guard-report.sh 30     # last 30 days"
echo ""
echo "To uninstall, run: bash $REPO_DIR/uninstall.sh"
