#!/usr/bin/env bash
# Gate unico do projeto: build + formato + tipos + oraculo + contratos + benchmark + contexto.
# Uso: bash scripts/check.sh   (ou ./scripts/check.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/env.sh

echo "== versoes (fonte x docs) =="
VERSIONS="$(python3 scripts/check-versions.py --values)"
read -r SCHEMA_VERSION CONTENT_VERSION SIM_VERSION SIM_HASH <<< "$VERSIONS"
echo "  schema=$SCHEMA_VERSION content=$CONTENT_VERSION sim=$SIM_VERSION hash=$SIM_HASH"

mkdir -p build

echo "== rojo build =="
rojo build default.project.json -o build/place.rbxl

echo "== stylua =="
stylua --check sim src

echo "== luau-lsp analyze =="
luau-lsp analyze --platform=standard sim src/shared/sim src/shared/data src/shared/analytics src/shared/visual src/shared/build src/shared/dropin src/shared/raid src/server/analytics/AnalyticsService.luau src/server/analytics/AnalyticsDataStoreSink.luau src/server/data src/server/walls/WallService.luau src/server/Main.server.luau

echo "== invariantes =="
luau sim/invariants.luau

echo "== acceptance (motor v$SIM_VERSION) =="
luau sim/acceptance.luau

echo "== contrato de perfil (schema v$SCHEMA_VERSION + sessao) =="
luau sim/profile-contract.luau

echo "== contrato de analytics =="
luau sim/analytics-contract.luau

echo "== contrato de muralha (S3, content v$CONTENT_VERSION) =="
luau sim/walls-contract.luau

echo "== contrato de conteudo (S3.4, content v$CONTENT_VERSION) =="
luau sim/content-contract.luau

echo "== contrato de build (S4) =="
luau sim/build-contract.luau

echo "== contrato visual (S8) =="
luau sim/visual-contract.luau

echo "== contrato de drop-in (S5) =="
luau sim/dropin-contract.luau

echo "== contrato de raid (S6) =="
luau sim/raid-contract.luau

echo "== migracao neutra (kit GAP-010) =="
luau tools/expansion-test/neutral-migration.luau

echo "== benchmark (poc) =="
luau sim/poc.luau | grep -E "hash=|por batalha|seeds="

echo "== sourcemap =="
rojo sourcemap default.project.json -o sourcemap.json

echo "== contexto =="
python3 skills/context-recovery/scan_repo.py --root . --check

echo "== gaps =="
if [ ! -f docs/gaps.md ] || ! grep -q "GAP:" CONTINUAR.md; then
	echo "FALHA: CONTINUAR.md precisa da linha GAP: e docs/gaps.md precisa existir"
	exit 1
fi

echo "OK: check passou"
