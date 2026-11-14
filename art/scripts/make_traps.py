"""Gera as 5 armadilhas (TRAP_) em L1..L5 com silhueta estrutural por nivel.

Fonte das formas: docs/direcao-visual-e-silhuetas.md §2.1 (regra por tipo), TrapKit.luau
(cotas), VisualTheme.TRAPS (altura por tipo, cor). Pegada <= 4.8 x 4.8 studs, base 4.6 x 0.3.
Patente: mastro + 1/2/3 chevrons (>= 0,6 stud) no canto frontal-esquerdo; no piche (1,2 stud
de altura) os chevrons vao numa placa frontal para nao romper a classe de altura.

Uso headless (a esteira chama assim):
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_traps.py
Saidas: art/export/trap_<tipo>_l<n>.glb, art/forge/lote_traps_import.yaml (gerado),
        art/renders/traps/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 1500  # docs/ferramentas.md §4.2 (prop/armadilha) = orcamento prop_estatico do perfil
BASE_TOP = 0.3
LEVELS = (1, 2, 3, 4, 5)  # P2 autorizada: L4/L5 (doc §2.1)


def base(lvl):
    p = [L.box((4.6, 4.6, 0.3), (0, 0, 0.15), "stone", bevel=0.04)]
    if lvl >= 2:
        cap = "iron" if lvl == 2 else "gold"
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(L.box((0.62, 0.62, 0.38), (sx * 1.96, sy * 1.96, 0.19), cap))
    if lvl >= 3:
        p.append(L.box((2.4, 0.12, 0.14), (0.4, -2.31, 0.17), "gold"))
    if lvl >= 4:  # filigrana dourada nas bordas visiveis
        p.append(L.box((0.12, 3.6, 0.14), (-2.26, 0.0, 0.17), "goldBright"))
        p.append(L.box((3.6, 0.12, 0.08), (0.0, 2.25, 0.17), "gold"))
    if lvl >= 5:
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(L.ico(0.14, (sx * 1.96, sy * 1.96, 0.42), "goldBright"))
    return p


# ---------------------------------------------------------------- arqueiro (~5.2)
def archer(lvl):
    p = base(lvl)
    post_h = 3.3 if lvl < 3 else 2.75
    top = BASE_TOP + post_h
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(L.box((0.34, 0.34, post_h), (sx * 1.0, sy * 1.0, BASE_TOP + post_h / 2), "wood"))
    for sy in (-1.09, 1.09):  # X de travamento frente/tras
        for ang in (0.62, -0.62):
            p.append(L.box((2.35, 0.12, 0.18), (0, sy, BASE_TOP + post_h * 0.42), "woodDark", rot=(0, ang, 0)))
    p.append(L.box((2.95, 2.95, 0.26), (0, 0, top + 0.13), "woodLight", bevel=0.03))
    deck = top + 0.26
    if lvl == 1:
        for sy in (-1.38, 1.38):
            p.append(L.box((2.9, 0.14, 0.14), (0, sy, deck + 0.55), "woodDark"))
        for sx in (-1.38, 1.38):
            p.append(L.box((0.14, 2.9, 0.14), (sx, 0, deck + 0.55), "woodDark"))
        for sx in (-1.38, 1.38):
            for sy in (-1.38, 1.38):
                p.append(L.box((0.16, 0.16, 0.62), (sx, sy, deck + 0.31), "wood"))
    else:
        # parapeito: tabuas + chapas de ferro (L2) / ferragem continua (L3)
        for sy in (-1.4, 1.4):
            p.append(L.box((2.95, 0.16, 0.62), (0, sy, deck + 0.31), "wood"))
        for sx in (-1.4, 1.4):
            p.append(L.box((0.16, 2.95, 0.62), (sx, 0, deck + 0.31), "wood"))
        for x in (-0.8, 0.8):
            p.append(L.box((0.62, 0.08, 0.5), (x, -1.5, deck + 0.32), "iron"))
        p.append(L.box((0.08, 0.62, 0.5), (-1.5, 0.0, deck + 0.32), "iron"))
        if lvl >= 3:
            p.append(L.box((3.05, 0.1, 0.12), (0, -1.5, deck + 0.64), "ironDark"))
            p.append(L.box((0.1, 3.05, 0.12), (-1.5, 0, deck + 0.64), "ironDark"))
    # arqueiro: corpo verde (cor do tipo), cabeca, arco
    p.append(L.box((0.6, 0.48, 0.8), (0, 0.15, deck + 0.4), "archer", bevel=0.05))
    p.append(L.ball(0.27, (0, 0.15, deck + 1.07), "parchment", seg=8, rings=5))
    p.append(L.spike(0.32, 0.32, (0, 0.15, deck + 1.18), "archerDark", verts=6, rot_z=0))
    p.append(L.box((0.1, 0.1, 1.15), (0.42, -0.22, deck + 0.75), "woodDark", rot=(0.25, 0, 0)))
    if lvl >= 2:  # 2o arco: besta montada no parapeito frontal
        p.append(L.box((0.18, 0.9, 0.18), (-0.7, -1.55, deck + 0.75), "woodDark"))
        p.append(L.box((1.0, 0.12, 0.12), (-0.7, -1.85, deck + 0.78), "iron", rot=(0, 0, 0)))
    if lvl >= 3:
        # telhado pontiagudo coroado (4 colunas + piramide + remate dourado)
        roof_z = deck + 1.22
        for sx in (-1.3, 1.3):
            for sy in (-1.3, 1.3):
                p.append(L.box((0.14, 0.14, roof_z - deck), (sx, sy, deck + (roof_z - deck) / 2), "woodDark"))
        p.append(L.cyl(2.25, 0.62, (0, 0, roof_z), "roof", verts=4, r2=0.0, rot_z=math.pi / 4))
        p.append(L.ball(0.12, (0, 0, roof_z + 0.66), "gold", seg=6, rings=4))
        # estandarte lateral (lado -X, voltado a camera)
        p.append(L.box((0.1, 0.1, 2.3), (-1.62, 0.9, deck + 0.6), "ironDark"))
        p.append(L.box((0.08, 0.9, 1.1), (-1.62, 0.42, deck + 1.1), "danger"))
        p.append(L.box((0.09, 0.4, 0.4), (-1.66, 0.42, deck + 1.1), "gold", rot=(math.pi / 4, 0, 0)))
    else:
        # flamula curta para fechar a classe de altura (~5.2)
        p.append(L.box((0.08, 0.08, 1.0), (1.38, 1.38, deck + 0.7), "ironDark"))
        p.append(L.box((0.06, 0.5, 0.3), (1.38, 1.1, deck + 1.05), "archer"))
    if lvl >= 4:  # vigia blindada + engrenagem mestra + crista elevada
        deck_ = BASE_TOP + 2.75 + 0.26
        p.append(L.box((3.0, 0.1, 0.56), (0, -1.53, deck_ + 0.32), "iron"))
        p += L.gear(0.45, 0.12, (1.2, 0.0, BASE_TOP + 1.9), "iron" if lvl == 4 else "gold", axis="x", hub="gold" if lvl == 4 else "neonAmber")
        p.append(L.spike(0.13, 0.3, (0, 0, deck_ + 1.22 + 0.62), "gold", verts=4))
    if lvl >= 5:  # guarita dupla: 2a guarita sobre o canto traseiro + beiral de filigrana
        deck_ = BASE_TOP + 2.75 + 0.26
        p.append(L.box((0.9, 0.9, 0.7), (1.0, 1.0, deck_ + 0.35), "iron"))
        p.append(L.cyl(0.75, 0.5, (1.0, 1.0, deck_ + 0.7), "roof", verts=4, r2=0.0, rot_z=math.pi / 4))
        for sy in (-1.6, 1.6):
            p.append(L.box((3.2, 0.08, 0.1), (0, sy, deck_ + 1.25), "goldBright"))
        for sx in (-1.6, 1.6):
            p.append(L.box((0.08, 3.2, 0.1), (sx, 0, deck_ + 1.25), "goldBright"))
    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- piche (~1.2)
def tar(lvl):
    p = base(lvl)
    p.append(L.cyl(2.05, 0.5, (0, 0, BASE_TOP), "stoneDark", verts=12))
    p.append(L.cyl(1.78, 0.06, (0, 0, BASE_TOP + 0.5), "ink", verts=12))
    rim = "stoneDark" if lvl == 1 else "iron"
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        p.append(L.box((1.08, 0.34, 0.26), (1.92 * math.cos(a), 1.92 * math.sin(a), BASE_TOP + 0.58), rim, rot=(0, 0, a + math.pi / 2)))
    br = 0.2 if lvl < 3 else 0.3
    for i, (x, y) in enumerate(((-0.7, -0.4), (0.5, 0.35), (0.1, -0.9), (-0.3, 0.8))[: 3 if lvl < 3 else 4]):
        p.append(L.ball(br * (1.0 - 0.15 * i), (x, y, BASE_TOP + 0.56), "tarGlow", seg=6, rings=4, squash=(1, 1, 0.7)))
    if lvl >= 2:  # aro de ferro com rebites
        p.append(L.cyl(2.13, 0.16, (0, 0, BASE_TOP + 0.14), "iron", verts=12))
        for k in range(8):
            a = 2 * math.pi * k / 8 + 0.2
            p.append(L.box((0.14, 0.14, 0.14), (2.17 * math.cos(a), 2.17 * math.sin(a), BASE_TOP + 0.22), "ironDark", rot=(0, 0, a)))
    if lvl >= 3:  # borda de caldeirao coroada
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.26
            p.append(L.spike(0.13, 0.26, (1.92 * math.cos(a), 1.92 * math.sin(a), BASE_TOP + 0.66), "gold"))
    if lvl >= 4:  # grade de engrenagem submersa
        p += L.gear(1.0, 0.08, (0, 0, BASE_TOP + 0.58), "ironDark" if lvl == 4 else "gold", teeth=8, hub="gold" if lvl == 4 else "neonAmber")
    if lvl >= 5:  # filigrana no aro
        p += L.ring(2.2, (0, 0, BASE_TOP + 0.4), "goldBright", n=12, seg=(0.08, 0.1))
    # placa frontal com a patente (chevrons em fila, sem mastro: classe de altura 1.2)
    p.append(L.box((2.6, 0.3, 0.52), (0, -2.1, BASE_TOP + 0.26), "woodDark"))
    return p + L.rank_row(lvl, y=-2.33, z=BASE_TOP + 0.3)


# ---------------------------------------------------------------- gelo (~4.4)
def frost(lvl):
    p = base(lvl)
    p.append(L.box((4.1, 4.1, 0.1), (0, 0, BASE_TOP + 0.05), "iceLight"))
    p.append(L.cyl(0.95, 0.32, (0, 0, BASE_TOP + 0.08), "stoneDark", verts=8))
    z0 = BASE_TOP + 0.38
    p.append(L.crystal(0.55, 3.0, (0, 0, z0), "ice", verts=4, r2=0.34, spin=math.pi / 4))
    p.append(L.crystal(0.34, 0.72, (0, 0, z0 + 3.0), "iceLight", verts=4, spin=math.pi / 4))
    if lvl >= 2:  # trio de cristais + cinta metalica
        for sx in (-1, 1):
            p.append(L.crystal(0.34, 2.0, (sx * 0.95, 0.1, z0), "ice", tilt=(0, sx * 0.28), verts=5))
        p.append(L.cyl(0.66, 0.22, (0, 0, z0 + 1.15), "iron", verts=8))
        p.append(L.cyl(0.69, 0.08, (0, 0, z0 + 1.22), "ironDark", verts=8))
    if lvl >= 3:  # coroa de prismas + anel basal brilhante
        for k in range(6):
            a = 2 * math.pi * k / 6
            p.append(L.crystal(0.13, 0.75, (0.48 * math.cos(a), 0.48 * math.sin(a), z0 + 2.45), "iceGlow", tilt=(-0.45 * math.sin(a), 0.45 * math.cos(a)), verts=4))
        for k in range(12):
            a = 2 * math.pi * (k + 0.5) / 12
            p.append(L.box((0.62, 0.22, 0.12), (1.6 * math.cos(a), 1.6 * math.sin(a), BASE_TOP + 0.14), "iceGlow", rot=(0, 0, a + math.pi / 2)))
    if lvl >= 4:  # giroscopio runico em torno do cristal
        p += L.ring(1.1, (0, 0, z0 + 1.9), "gold", n=12, tilt=(0.5, 0.0), seg=(0.12, 0.1))
        p.append(L.ico(0.16, (0, -1.0, z0 + 1.45), "iceGlow"))
    if lvl >= 5:
        p += L.ring(0.95, (0, 0, z0 + 1.9), "goldBright", n=12, tilt=(0.0, -0.55), seg=(0.1, 0.1))
        p += L.gear(0.5, 0.1, (0, 0, z0 + 0.05), "gold", teeth=8, hub="neonAmber")
    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- canhao (~3.2)
def cannon(lvl):
    p = base(lvl)
    p.append(L.box((1.5, 2.9, 0.55), (0, 0.15, BASE_TOP + 0.62), "wood", bevel=0.04))
    for sx in (-1, 1):
        p.append(L.box((0.26, 2.3, 0.95), (sx * 0.62, 0.25, BASE_TOP + 1.2), "woodDark"))
        p.append(L.cyl_axis(0.68, 0.3, (sx * 1.0, -0.55, BASE_TOP + 0.68), "woodDark", axis="x", verts=12))
        p.append(L.cyl_axis(0.24, 0.34, (sx * 1.0, -0.55, BASE_TOP + 0.68), "iron", axis="x", verts=6))
        p.append(L.cyl_axis(0.42, 0.26, (sx * 0.95, 1.15, BASE_TOP + 0.42), "woodDark", axis="x", verts=8))
    tilt = 0.22
    c = (0.0, -0.3, BASE_TOP + 1.95)
    d = (0.0, -math.cos(tilt), math.sin(tilt))

    def along(t):
        return (c[0] + d[0] * t, c[1] + d[1] * t, c[2] + d[2] * t)

    barrel = "iron" if lvl == 1 else "steel"
    p.append(L.cyl_axis(0.44, 2.9, c, barrel, axis="y", verts=12, r2=0.36, tilt=tilt))
    p.append(L.cyl_axis(0.5, 0.36, along(1.32), "ironDark", axis="y", verts=12, tilt=tilt))
    p.append(L.ball(0.42, along(-1.5), barrel, seg=10, rings=5))
    if lvl >= 2:  # carruagem com placas de ferro + cano reforcado
        for sx in (-1, 1):
            p.append(L.box((0.06, 1.4, 0.55), (sx * 0.77, 0.0, BASE_TOP + 1.22), "iron"))
        for t in (-0.9, -0.2):
            p.append(L.cyl_axis(0.5, 0.16, along(t), "ironDark", axis="y", verts=12, tilt=tilt))
    if lvl >= 3:  # duplo anel de bronze + mira elevada
        for t in (0.55, 0.85):
            p.append(L.cyl_axis(0.49, 0.14, along(t), "bronze", axis="y", verts=12, tilt=tilt))
        sight = along(-0.6)
        p.append(L.box((0.1, 0.1, 0.62), (sight[0], sight[1], sight[2] + 0.62), "bronze"))
        p.append(L.cyl_axis(0.16, 0.06, (sight[0], sight[1], sight[2] + 0.98), "gold", axis="y", verts=8))
    if lvl >= 4:  # culatra com engrenagens de recarga
        for sx in (-1, 1):
            p += L.gear(0.42, 0.1, (sx * 0.82, 0.95, BASE_TOP + 1.35), "iron" if lvl == 4 else "gold", axis="x", hub="gold" if lvl == 4 else "neonAmber")
    if lvl >= 5:  # filigrana dourada no cano
        for t in (-1.15, 1.32):
            p.append(L.cyl_axis(0.52, 0.12, along(t), "goldBright", axis="y", verts=12, tilt=tilt))
    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- catapulta (~4.8)
def catapult(lvl):
    p = base(lvl)
    for sx in (-1, 1):
        p.append(L.box((0.36, 3.8, 0.45), (sx * 1.05, 0, BASE_TOP + 0.8), "wood"))
    for sy in (-1.6, 1.6):
        p.append(L.box((2.5, 0.36, 0.4), (0, sy, BASE_TOP + 0.82), "woodDark"))
    for sx in (-1, 1):
        for sy in (-1.15, 1.15):
            p.append(L.cyl_axis(0.6, 0.3, (sx * 1.38, sy, BASE_TOP + 0.6), "woodDark", axis="x", verts=10))
            if lvl >= 2:
                p.append(L.cyl_axis(0.2, 0.34, (sx * 1.4, sy, BASE_TOP + 0.6), "iron", axis="x", verts=6))
    pivot = (0.0, -0.3, BASE_TOP + 2.1)
    for sx in (-1, 1):
        p.append(L.box((0.3, 0.3, 1.5), (sx * 0.82, pivot[1], BASE_TOP + 1.35), "wood"))
        p.append(L.box((0.22, 1.4, 0.22), (sx * 0.82, pivot[1] + 0.4, BASE_TOP + 1.45), "woodDark", rot=(0.8, 0, 0)))
    p.append(L.cyl_axis(0.12, 1.95, pivot, "iron", axis="x", verts=8))
    a = math.radians(55)
    d = (0.0, math.cos(a), math.sin(a))
    arm_len = 2.85
    mid = (0.0, pivot[1] + d[1] * (arm_len / 2 - 0.35), pivot[2] + d[2] * (arm_len / 2 - 0.35))
    p.append(L.box((0.3, arm_len, 0.3), mid, "wood", rot=(a, 0, 0)))
    tip = (0.0, pivot[1] + d[1] * 2.35, pivot[2] + d[2] * 2.35)
    p.append(L.cyl(0.46, 0.4, (tip[0], tip[1], tip[2] - 0.05), "woodDark", verts=8, r2=0.58))
    p.append(L.ball(0.3, (tip[0], tip[1], tip[2] + 0.32), "stoneLight", seg=8, rings=5))
    cw_z = pivot[2] - 0.62
    if lvl == 1:
        p.append(L.box((0.75, 0.75, 0.7), (0, pivot[1] - 0.32, cw_z), "stoneDark", bevel=0.05))
    else:  # chassi ferrado + contrapeso duplo
        for sx in (-1, 1):
            p.append(L.box((0.55, 0.7, 0.7), (sx * 0.36, pivot[1] - 0.32, cw_z), "ironDark", bevel=0.04))
        for sx in (-1, 1):
            for sy in (-1.6, 1.6):
                p.append(L.box((0.44, 0.44, 0.52), (sx * 1.05, sy, BASE_TOP + 0.82), "iron"))
    p.append(L.box((0.08, 0.5, 0.3), (0, tip[1] - 0.25, tip[2] - 0.35), "catapult"))
    if lvl >= 3:  # arco frontal coroado + trava de ferro
        for sx in (-1, 1):
            p.append(L.box((0.26, 0.26, 2.2), (sx * 0.95, -1.75, BASE_TOP + 1.95), "woodDark"))
        p.append(L.box((2.3, 0.3, 0.3), (0, -1.75, BASE_TOP + 3.0), "ironDark"))
        for x in (-0.7, 0.0, 0.7):
            p.append(L.spike(0.16, 0.45 if x == 0 else 0.32, (x, -1.75, BASE_TOP + 3.12), "gold"))
        p.append(L.box((0.42, 0.42, 0.24), (0, 0.55, BASE_TOP + 1.1), "iron"))
        p.append(L.box((0.12, 0.12, 0.7), (0, 0.55, BASE_TOP + 1.5), "ironDark"))
        p.append(L.box((0.06, 0.6, 0.4), (-0.18, mid[1], mid[2]), "catapult"))
    if lvl >= 4:  # catraca mestra lateral
        p += L.gear(0.55, 0.12, (1.05, pivot[1], pivot[2]), "iron" if lvl == 4 else "gold", axis="x", teeth=10, hub="gold" if lvl == 4 else "neonAmber")
    if lvl >= 5:  # acabamento dourado + nucleo energizado na concha
        for sx in (-1, 1):
            p.append(L.box((0.1, 3.6, 0.08), (sx * 1.05, 0, BASE_TOP + 1.05), "goldBright"))
        p.append(L.ico(0.16, (tip[0], tip[1], tip[2] + 0.5), "neonAmber"))
    return p + L.rank_mast(lvl)


BUILDERS = {"archer": archer, "tar": tar, "frost": frost, "cannon": cannon, "catapult": catapult}


def specs():
    out = []
    for k, (kind, fn) in enumerate(BUILDERS.items()):
        for lvl in LEVELS:
            # seeds de L1-L3 iguais a versao anterior (indice k*3+lvl-1); L4/L5 em faixa propria
            seed = L.SEED_BASE + (k * 3 + lvl - 1) * 101 if lvl <= 3 else L.SEED_BASE + 5000 + k * 10 + lvl
            out.append(
                {
                    "id": f"trap.{kind}.l{lvl}.01",
                    "name": f"TRAP_{kind}_l{lvl}",
                    "glb": f"trap_{kind}_l{lvl}.glb",
                    "tipo": "prop_estatico",
                    "limite": LIMITE,
                    "tags": ["muralha", "trap", kind, f"l{lvl}"],
                    "seed": seed,
                    "build": (lambda f=fn, n=lvl: f(n)),
                }
            )
    return out


L.run_group("traps", specs(), "armadilhas L1-L5 modeladas por script (art/scripts/make_traps.py)")
