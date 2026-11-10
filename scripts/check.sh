#!/usr/bin/env bash
# Gate unico do projeto: build + formato + tipos + oraculo + contratos + benchmark + contexto.
# Uso: bash scripts/check.sh   (ou ./scripts/check.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/env.sh

mkdir -p build

echo "== rojo build =="
rojo build default.project.json -o build/place.rbxl

echo "== stylua =="
stylua --check sim src/shared/sim src/shared/data src/shared/analytics src/server/data src/server/ProfileBoot.server.luau

echo "== luau-lsp analyze =="
luau-lsp analyze --platform=standard sim src/shared/sim src/shared/data src/shared/analytics

echo "== invariantes =="
luau sim/invariants.luau

echo "== P0 acceptance =="
luau sim/acceptance.luau

echo "== contrato de perfil (schema v1 + sessao) =="
luau sim/profile-contract.luau

echo "== contrato de analytics =="
luau sim/analytics-contract.luau

echo "== benchmark (poc) =="
luau sim/poc.luau | grep -E "hash=|por batalha|seeds="

echo "== sourcemap =="
rojo sourcemap default.project.json -o sourcemap.json

echo "== contexto =="
python3 skills/context-recovery/scan_repo.py --root . --check

echo "OK: check passou"
