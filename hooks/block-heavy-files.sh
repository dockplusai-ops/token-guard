#!/bin/bash
# token-guard: Block reads of large/irrelevant files to save context tokens
# Hook event: PreToolUse (Read tool)

INPUT=$(cat)

TOOL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)

if [ "$TOOL" != "Read" ]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
inp = d.get('tool_input', {})
print(inp.get('file_path', inp.get('path', inp.get('file', ''))))
" 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

BASENAME=$(basename "$FILE_PATH")
REASON=""

# Blocked filenames (exact match)
case "$BASENAME" in
    package-lock.json)  REASON="package-lock.json is too large (100k+ tokens). Use package.json instead." ;;
    yarn.lock)          REASON="yarn.lock is too large. Check package.json instead." ;;
    pnpm-lock.yaml)     REASON="pnpm-lock.yaml is too large. Check package.json instead." ;;
    Gemfile.lock)       REASON="Gemfile.lock is too large. Check Gemfile instead." ;;
    composer.lock)      REASON="composer.lock is too large. Check composer.json instead." ;;
    Cargo.lock)         REASON="Cargo.lock is too large. Check Cargo.toml instead." ;;
    poetry.lock)        REASON="poetry.lock is too large. Check pyproject.toml instead." ;;
    .DS_Store)          REASON=".DS_Store is a macOS system file with no useful content." ;;
    Thumbs.db)          REASON="Thumbs.db is a Windows system file with no useful content." ;;
esac

# Blocked path patterns
if [ -z "$REASON" ]; then
    case "$FILE_PATH" in
        */node_modules/*)   REASON="File is inside node_modules. Install dependencies and use imports instead." ;;
        */dist/*)           REASON="File is a build artifact in dist/. Read the original source instead." ;;
        */.next/*)          REASON="File is a build artifact in .next/. Read the original source instead." ;;
        */build/*)          REASON="File is a build artifact. Read the original source instead." ;;
        */.git/objects/*)   REASON="Git object file is binary and not human-readable." ;;
        */vendor/*)         REASON="File is inside vendor/. Read the original source instead." ;;
        *.min.js)           REASON="Minified JS file. Read the non-minified source instead." ;;
        *.min.css)          REASON="Minified CSS file. Read the non-minified source instead." ;;
        *.map)              REASON="Source map file. Read the original source instead." ;;
        *.pyc)              REASON="Compiled Python bytecode. Read the .py source instead." ;;
        __pycache__/*)      REASON="Python cache directory. Read the .py source instead." ;;
    esac
fi

# Check file size if not already blocked by name
if [ -z "$REASON" ] && [ -f "$FILE_PATH" ]; then
    FILE_SIZE=$(wc -c < "$FILE_PATH" 2>/dev/null || echo 0)
    # Block files > 200KB (~50k tokens)
    if [ "$FILE_SIZE" -gt 204800 ]; then
        SIZE_KB=$((FILE_SIZE / 1024))
        REASON="File is too large (${SIZE_KB}KB, ~$((SIZE_KB / 4))k tokens). Use offset/limit to read specific lines, or use grep to find the relevant section."
    fi
fi

if [ -n "$REASON" ]; then
    python3 -c "
import json, sys
reason = sys.argv[1]
print(json.dumps({'decision': 'block', 'reason': reason}))
" "$REASON"
    exit 0
fi

exit 0
