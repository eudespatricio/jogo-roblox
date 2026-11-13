#!/usr/bin/env bash
# Diagnostico completo de tipos Roblox (sourcemap + globalTypes + src/ inteiro).
# Uso na retomada S8.2 / fechamento de GAP-017 (AUD-11).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/env.sh

bash scripts/fetch-roblox-types.sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze \
	--platform=roblox \
	--sourcemap=sourcemap.json \
	--definitions=.tools/globalTypes.d.luau \
	src
