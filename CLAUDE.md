# CLAUDE.md — token-guard

## Proposito

Conjunto de hooks automaticos para Claude Code que reduzem desperdicio de tokens e estouro de contexto sem intervencao manual. Bloqueia leitura de arquivos pesados (lockfiles, builds, minificados, > 200 KB), avisa quando o contexto enche, reinjeta contexto apos compaction e loga uso/custo por sessao.

## Stack

- Bash (hooks scripts)
- Python 3 (ja exigido pelo Claude Code)
- Claude Code hooks API (PreToolUse, UserPromptSubmit, PostCompact, Stop)

## Estrutura

```
token-guard/
├── hooks/
│   ├── block-heavy-files.sh       # PreToolUse — bloqueia reads pesados
│   ├── context-warning.sh         # UserPromptSubmit — alerta de contexto
│   ├── post-compact-reinject.sh   # PostCompact — reinjeta contexto
│   └── cost-logger.sh             # Stop (async) — loga uso em JSONL
├── install.sh                     # Registra hooks em ~/.claude/settings.json
├── uninstall.sh                   # Remove registros
├── token-guard-report.sh          # Relatorio de uso (default 7 dias)
└── README.md
```

## Comandos

```bash
bash install.sh              # Instalar hooks (ajusta ~/.claude/settings.json)
bash uninstall.sh            # Remover

bash token-guard-report.sh   # Relatorio dos ultimos 7 dias
bash token-guard-report.sh 30 # Ultimos 30 dias
```

## Hooks (resumo)

| Hook | Evento | Comportamento |
|------|--------|---------------|
| block-heavy-files | PreToolUse | Bloqueia reads (`{"decision":"block"}`) com mensagem explicativa |
| context-warning | UserPromptSubmit | Injeta aviso quando uso ≥ 50% (warning), 70% (high), 85% (critical) |
| post-compact-reinject | PostCompact | Le `.claude/context.md` ou primeiras 50 linhas de `CLAUDE.md` |
| cost-logger | Stop (async) | Append em `~/.claude/token-guard/usage.jsonl` |

## Configuracao opcional

Cada projeto pode definir `.claude/context.md` com conteudo a ser reinjetado apos compaction (substitui o fallback de `CLAUDE.md`).

## Onde fica

- Logs: `~/.claude/token-guard/usage.jsonl`
- Settings registrados em: `~/.claude/settings.json`

## Notas

- Sem daemons, sem API keys — tudo via hooks bash sincronos (exceto cost-logger).
- Heavy file rules: lockfiles, `node_modules/`, `dist/`, `.next/`, `build/`, `vendor/`, `*.min.{js,css}`, `*.map`, `__pycache__/`, qualquer arquivo > 200 KB (~50k tokens).
- Limite de re-injecao apos compact: 50 linhas para evitar reflar o contexto.
