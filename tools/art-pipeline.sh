#!/usr/bin/env bash
# Esteira de arte da MURALHA: Blender (script) -> Forge3D (validate/run/verify) -> renders + lineup.
#
#   bash tools/art-pipeline.sh                 # todos os grupos: wall, traps, horde, bosses, portal, props, fauna
#   bash tools/art-pipeline.sh --only traps    # um grupo (repetivel: --only wall --only horde)
#   bash tools/art-pipeline.sh --skip-blender  # so Forge3D + lineup sobre os GLB ja exportados
#
# Sai != 0 se qualquer item reprovar (QC local ou Forge3D) ou se o verify falhar.
# NUNCA faz upload (nenhum `forge3d upload-*`); a publicacao e so no destino local do Forge3D.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BLENDER="${BLENDER:-/home/eudespatricio/.gemini/antigravity/bin/blender}"
FORGE3D="${FORGE3D:-$HOME/.local/bin/forge3d}"
SAIDA="$HOME/.local/state/forge3d/saida"
LOGDIR="$ROOT/art/renders/_logs"   # art/renders/ e ignorado no git
ALL_GROUPS=(wall traps horde bosses portal props fauna)
GROUPS_SEL=()
SKIP_BLENDER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) GROUPS_SEL+=("${2:?--only exige um grupo: wall|traps|horde|bosses|portal|props|fauna}"); shift 2 ;;
    --skip-blender) SKIP_BLENDER=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done
[[ ${#GROUPS_SEL[@]} -eq 0 ]] && GROUPS_SEL=("${ALL_GROUPS[@]}")
for g in "${GROUPS_SEL[@]}"; do
  [[ " ${ALL_GROUPS[*]} " == *" $g "* ]] || { echo "grupo invalido: $g" >&2; exit 2; }
done

[[ -x "$BLENDER" ]] || { echo "blender nao encontrado: $BLENDER" >&2; exit 2; }
[[ -x "$FORGE3D" ]] || { echo "forge3d nao encontrado: $FORGE3D" >&2; exit 2; }
mkdir -p "$LOGDIR"

script_of() {
  case "$1" in
    wall) echo art/scripts/make_wall_bastion.py ;;
    traps) echo art/scripts/make_traps.py ;;
    horde) echo art/scripts/make_horde.py ;;
    bosses) echo art/scripts/make_bosses.py ;;
    portal) echo art/scripts/make_portal.py ;;
    props) echo art/scripts/make_props.py ;;
    fauna) echo art/scripts/make_fauna.py ;;
  esac
}
# a muralha manteve o lote/destino historicos (lote_muralha_import.yaml -> saida/muralha_import)
lote_of() { [[ $1 == wall ]] && echo art/forge/lote_muralha_import.yaml || echo "art/forge/lote_${1}_import.yaml"; }
dest_of() { [[ $1 == wall ]] && echo "$SAIDA/muralha_import" || echo "$SAIDA/muralha_$1"; }
renders_of() {
  if [[ $1 == wall ]]; then ls art/renders/wall_bastion_l*.png 2>/dev/null | sort || true
  else ls art/renders/"$1"/*.png 2>/dev/null | sort || true; fi
}

# ---------------------------------------------------------------- 1. Blender (grupos em paralelo)
if [[ $SKIP_BLENDER -eq 0 ]]; then
  pids=()
  for g in "${GROUPS_SEL[@]}"; do
    echo "[blender] $g -> $(script_of "$g")"
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$(script_of "$g")" \
      >"$LOGDIR/blender_$g.log" 2>&1 &
    pids+=("$!:$g")
  done
  fail=0
  for entry in "${pids[@]}"; do
    pid="${entry%%:*}"; g="${entry#*:}"
    if ! wait "$pid"; then
      echo "[blender] $g FALHOU (ver $LOGDIR/blender_$g.log)" >&2
      grep -E "Traceback|Error|reprovado" "$LOGDIR/blender_$g.log" | tail -5 >&2 || true
      fail=1
    fi
  done
  [[ $fail -eq 0 ]] || exit 1
  for g in "${GROUPS_SEL[@]}"; do
    { grep '^ART_REPORT ' "$LOGDIR/blender_$g.log" || true; } | sed 's/^ART_REPORT //' >"$LOGDIR/report_$g.json"
  done
fi

# ---------------------------------------------------------------- 2. Forge3D validate -> run -> verify
status=0
summary=()
for g in "${GROUPS_SEL[@]}"; do
  lote="$(lote_of "$g")"
  [[ -f "$lote" ]] || { echo "[forge3d] lote ausente: $lote (rode sem --skip-blender)" >&2; exit 1; }
  echo "[forge3d] validate $lote"
  "$FORGE3D" validate "$lote" --json >"$LOGDIR/validate_$g.json" || {
    echo "[forge3d] validate FALHOU: $g" >&2; cat "$LOGDIR/validate_$g.json" >&2; exit 1; }
  echo "[forge3d] run $lote"
  rc=0
  "$FORGE3D" run "$lote" --json >"$LOGDIR/run_$g.json" || rc=$?
  line="$(python3 - "$LOGDIR/run_$g.json" "$rc" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
itens = d.get("itens", [])
ok_estados = {"publicado", "cache_hit"}  # cache_hit: GLB identico ja publicado (verify confere)
bad = [f"{i['id']}:{i.get('estado')}/{i.get('qc')}" for i in itens
       if i.get("qc") != "aprovado" or i.get("estado") not in ok_estados]
r = d.get("resumo", {})
tri = max((i.get("triangulos") or 0) for i in itens) if itens else 0
estados = sorted({i.get("estado") for i in itens})
print(f"{len(itens) - len(bad)}/{len(itens)} publicado reprovados={r.get('reprovados', 0)} "
      f"falhas={r.get('falhas', 0)} tris_max={tri} estados={','.join(map(str, estados))} rc={sys.argv[2]}"
      + (f" BAD={';'.join(bad)}" if bad else ""))
sys.exit(1 if bad or r.get("reprovados", 0) or r.get("falhas", 0) or int(sys.argv[2]) else 0)
PY
)" || status=1
  echo "[forge3d] $g: $line"
  summary+=("$g: $line")
  echo "[forge3d] verify $(dest_of "$g")"
  if ! "$FORGE3D" verify "$(dest_of "$g")" --json >"$LOGDIR/verify_$g.json"; then
    echo "[forge3d] verify FALHOU: $g (ver $LOGDIR/verify_$g.json)" >&2
    status=1
  fi
done

# ---------------------------------------------------------------- 3. lineup (ImageMagick montage)
lineups=()
if command -v montage >/dev/null 2>&1; then
  for g in "${GROUPS_SEL[@]}"; do
    mapfile -t pngs < <(renders_of "$g")
    [[ ${#pngs[@]} -gt 0 ]] || continue
    tile="5x"; geo="256x256+4+4"
    [[ $g == horde ]] && tile="3x2" && geo="320x320+4+4"
    [[ $g == bosses ]] && tile="5x1" && geo="320x320+4+4"
    [[ $g == portal ]] && tile="1x1" && geo="320x320+4+4"
    [[ $g == wall ]] && tile="3x" && geo="480x270+4+4"
    [[ $g == props ]] && tile="3x2" && geo="320x320+4+4"
    [[ $g == fauna ]] && tile="3x3" && geo="320x320+4+4"
    out="art/renders/lineup_$g.png"
    montage -quiet -label '%t' -pointsize 14 "${pngs[@]}" -tile "$tile" -geometry "$geo" \
      -background '#1d2128' -fill '#f5e6c8' "$out" 2>/dev/null
    lineups+=("$out")
  done
  if [[ ${#lineups[@]} -gt 1 ]]; then
    montage -quiet "${lineups[@]}" -tile 1x -geometry +0+8 -background '#1d2128' \
      art/renders/lineup_all.png 2>/dev/null
    lineups+=("art/renders/lineup_all.png")
  fi
else
  echo "[lineup] ImageMagick ausente: renders individuais em art/renders/<grupo>/" >&2
fi

echo "== esteira de arte =="
printf '  %s\n' "${summary[@]}"
printf '  lineup: %s\n' "${lineups[@]}"
[[ $status -eq 0 ]] && echo "OK: todos os itens publicados, 0 reprovados" || echo "FALHA: ver $LOGDIR" >&2
exit $status
