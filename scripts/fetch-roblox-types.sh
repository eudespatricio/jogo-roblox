#!/usr/bin/env bash
# Baixa (ou reutiliza em cache) globalTypes.d.luau oficial do luau-lsp para .tools/.
# .tools/ ja e ignorado pelo .gitignore e regenerado em maquinas limpas e no CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT/.tools/globalTypes.d.luau"
URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

mkdir -p "$ROOT/.tools"

if [ "${1:-}" != "--force" ] && [ -s "$TARGET" ]; then
	SIZE="$(wc -c < "$TARGET")"
	if [ "$SIZE" -ge 500000 ] && head -n 1 "$TARGET" | grep -q "^--#METADATA#"; then
		exit 0
	fi
fi

TMP="$(mktemp)"
curl -fsSL "$URL" -o "$TMP"
if ! head -n 1 "$TMP" | grep -q "^--#METADATA#"; then
	rm -f "$TMP"
	echo "FALHA: globalTypes.d.luau invalido ou corrompido" >&2
	exit 1
fi
mv "$TMP" "$TARGET"
chmod 644 "$TARGET"
