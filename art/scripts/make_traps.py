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

LIMITE = 1850  # teto Forge3D; alvo esculpido 950..1750 tris por armadilha
BASE_TOP = 0.3
LEVELS = (1, 2, 3, 4, 5)  # P2 autorizada: L4/L5 (doc §2.1)


def base(lvl):
    """Plinto chanfrado de pedra/ouro com pegada <= 4.8 x 4.8 studs."""
    p = [L.box((4.6, 4.6, 0.30), (0, 0, 0.15), "stone", bevel=0.04)]
    if lvl >= 2:
        cap = "iron" if lvl == 2 else "gold"
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(L.box((0.62, 0.62, 0.38), (sx * 1.95, sy * 1.95, 0.19), cap))
    if lvl >= 3:
        p.append(L.box((2.4, 0.12, 0.14), (0.35, -2.28, 0.17), "gold"))
    if lvl >= 4:  # filigrana dourada nas bordas visiveis
        p.append(L.box((0.12, 3.3, 0.14), (-2.25, 0.0, 0.17), "goldBright"))
        p.append(L.box((3.3, 0.12, 0.10), (0.0, 2.25, 0.17), "gold"))
    if lvl >= 5:
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(L.spike(0.14, 0.24, (sx * 1.95, sy * 1.95, 0.38), "goldBright", verts=4))
    return p


def _gear_light(r, thick, center, color, axis="z", teeth=5, hub=None):
    """Engrenagem leve (~116 tris) mantendo silhueta mecanica dentro do orcamento."""
    cx, cy, cz = center
    parts = []
    if axis == "z":
        parts.append(L.cyl(r, thick, (cx, cy, cz - thick / 2), color, verts=12))
    else:
        parts.append(L.cyl_axis(r, thick, center, color, axis="x", verts=12))
    tooth = (r * 0.36, r * 0.34, thick * 0.9)
    for k in range(teeth):
        a = 2 * math.pi * (k + 0.5) / teeth
        if axis == "z":
            pos = (cx + (r + tooth[1] * 0.3) * math.cos(a), cy + (r + tooth[1] * 0.3) * math.sin(a), cz)
            rot = (0, 0, a)
            size = (tooth[1], tooth[0], tooth[2])
        else:
            pos = (cx, cy + (r + tooth[1] * 0.3) * math.cos(a), cz + (r + tooth[1] * 0.3) * math.sin(a))
            rot = (a, 0, 0)
            size = (tooth[2], tooth[1], tooth[0])
        parts.append(L.box(size, pos, color, rot=rot))
    if hub:
        if axis == "z":
            parts.append(L.cyl(r * 0.35, thick * 1.4, (cx, cy, cz - thick * 0.7), hub, verts=8))
        else:
            parts.append(L.cyl_axis(r * 0.35, thick * 1.4, center, hub, axis="x", verts=8))
    return parts


def _spoked_wheel(r, thick, center, tire_color, hub_color, spokes=6, minor_seg=4):
    """Roda raiada 20-seg com aro torus, cubo central e raios diagonais."""
    cx, cy, cz = center
    rot_y = (0.0, math.pi / 2, 0.0)
    parts = [
        L.torus(r - 0.09, 0.09, center, tire_color, major_seg=20, minor_seg=minor_seg, rot=rot_y),
        L.cyl_axis(r * 0.26, thick * 1.15, center, hub_color, axis="x", verts=10),
    ]
    n_pairs = max(2, spokes // 2)
    spoke_len = (r - 0.14) * 2.0
    for k in range(n_pairs):
        ang = math.pi * k / n_pairs
        parts.append(L.box((thick * 0.45, 0.075, spoke_len), (cx, cy, cz), tire_color, rot=(ang, 0.0, 0.0)))
    return parts


# ---------------------------------------------------------------- arqueiro (~5.2)
def archer(lvl):
    p = base(lvl)
    post_h = 3.3 if lvl < 3 else 2.75
    top = BASE_TOP + post_h
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(L.box((0.34, 0.34, post_h), (sx * 1.0, sy * 1.0, BASE_TOP + post_h / 2), "wood", bevel=0.03))
    for sy in (-1.09, 1.09):  # X de travamento frente/tras
        for ang in (0.62, -0.62):
            p.append(L.box((2.35, 0.12, 0.18), (0, sy, BASE_TOP + post_h * 0.42), "woodDark", rot=(0, ang, 0)))
    p.append(L.box((2.95, 2.95, 0.26), (0, 0, top + 0.13), "woodLight", bevel=0.035))
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
        for sy in (-1.4, 1.4):
            p.append(L.box((2.95, 0.16, 0.62), (0, sy, deck + 0.31), "wood"))
        for sx in (-1.4, 1.4):
            p.append(L.box((0.16, 2.95, 0.62), (sx, 0, deck + 0.31), "wood"))
        for x in (-0.8, 0.8):
            p.append(L.box((0.62, 0.10, 0.50), (x, -1.5, deck + 0.32), "iron"))
        p.append(L.box((0.10, 0.62, 0.50), (-1.5, 0.0, deck + 0.32), "iron"))
        if lvl >= 3:
            p.append(L.box((3.05, 0.11, 0.12), (0, -1.5, deck + 0.64), "ironDark"))
            p.append(L.box((0.11, 3.05, 0.12), (-1.5, 0, deck + 0.64), "ironDark"))

    # Arqueiro detalhado: tunica, cinto, manto, capuz/elmo, arco recurvo e aljava
    p.append(L.cyl(0.30, 0.68, (0, 0.15, deck), "archer", verts=12, r2=0.22))
    p.append(L.cyl(0.28, 0.11, (0, 0.15, deck + 0.28), "woodDark", verts=12, r2=0.27))
    p.append(L.cyl(0.36, 0.44, (0, 0.24, deck + 0.32), "archerDark", verts=10, r2=0.18))
    p.append(L.cyl(0.09, 0.52, (0.24, 0.36, deck + 0.34), "woodDark", verts=8))
    p.append(L.ball(0.24, (0, 0.15, deck + 0.94), "parchment", seg=10, rings=6))
    p.append(L.cyl(0.30, 0.38, (0, 0.18, deck + 0.92), "archerDark", verts=10, r2=0.08))
    p.append(L.crystal(0.13, 0.30, (0, 0.28, deck + 1.18), "archerDark", tilt=(-0.72, 0.0), verts=6))
    p.append(L.capsule_seg((0.40, -0.18, deck + 0.78), (0.44, -0.02, deck + 1.24), 0.045, 0.03, "woodDark", verts=6))
    p.append(L.capsule_seg((0.40, -0.18, deck + 0.78), (0.44, -0.02, deck + 0.32), 0.045, 0.03, "woodDark", verts=6))
    p.append(L.capsule_seg((0.42, -0.18, deck + 0.78), (0.32, -0.58, deck + 0.80), 0.02, 0.02, "gold", verts=6))

    if lvl >= 2:  # besta/arbalesta montada no parapeito frontal
        p.append(L.box((0.18, 0.92, 0.18), (-0.7, -1.55, deck + 0.75), "woodDark"))
        p.append(L.capsule_seg((-0.7, -1.88, deck + 0.78), (-1.22, -1.68, deck + 0.78), 0.055, 0.035, "iron", verts=6))
        p.append(L.capsule_seg((-0.7, -1.88, deck + 0.78), (-0.18, -1.68, deck + 0.78), 0.055, 0.035, "iron", verts=6))
        p.append(L.capsule_seg((-0.7, -1.48, deck + 0.84), (-0.7, -2.06, deck + 0.82), 0.022, 0.012, "goldBright", verts=6))

    if lvl >= 3:
        # Telhado conico suave (20-seg) + anel torus de beiral + remate e estandarte
        roof_z = deck + 1.22
        for sx in (-1.3, 1.3):
            for sy in (-1.3, 1.3):
                p.append(L.box((0.14, 0.14, roof_z - deck), (sx, sy, deck + (roof_z - deck) / 2), "woodDark"))
        p.append(L.cyl(2.22, 0.66, (0, 0, roof_z), "roof", verts=20, r2=0.0))
        p.append(
            L.torus(
                1.98,
                0.075,
                (0, 0, roof_z + 0.04),
                "gold" if lvl >= 4 else "woodDark",
                major_seg=16,
                minor_seg=4,
            )
        )
        p.append(L.ball(0.13, (0, 0, roof_z + 0.70), "gold", seg=6, rings=4))
        p.append(L.cyl(0.055, 2.25, (-1.62, 0.9, deck - 0.52), "ironDark", verts=8))
        p.append(L.box((0.08, 0.9, 1.1), (-1.62, 0.42, deck + 1.1), "danger"))
        p.append(L.box((0.09, 0.4, 0.4), (-1.66, 0.42, deck + 1.1), "gold", rot=(math.pi / 4, 0, 0)))
    else:
        # Anel de reforco no chao para riqueza visual de L1-L2 mantendo altura ~5.2
        p.append(L.torus(1.45, 0.055, (0, 0, BASE_TOP + 0.06), "woodDark", major_seg=20, minor_seg=4))
        p.append(L.cyl(0.05, 1.0, (1.38, 1.38, deck + 0.2), "ironDark", verts=8))
        p.append(L.box((0.06, 0.5, 0.3), (1.38, 1.1, deck + 1.05), "archer"))

    if lvl >= 4:  # vigia blindada + engrenagem mestra + crista
        deck_ = BASE_TOP + 2.75 + 0.26
        p.append(L.box((3.0, 0.12, 0.56), (0, -1.53, deck_ + 0.32), "iron"))
        p += _gear_light(
            0.44,
            0.12,
            (1.2, 0.0, BASE_TOP + 1.9),
            "iron" if lvl == 4 else "gold",
            axis="x",
            teeth=5,
            hub="gold" if lvl == 4 else "neonAmber",
        )
        p.append(L.spike(0.12, 0.32, (0, 0, deck_ + 1.22 + 0.68), "gold", verts=6))

    if lvl >= 5:  # guarita secundaria + filigrana dourada no beiral
        deck_ = BASE_TOP + 2.75 + 0.26
        p.append(L.box((0.9, 0.9, 0.7), (1.0, 1.0, deck_ + 0.35), "iron"))
        p.append(L.cyl(0.74, 0.52, (1.0, 1.0, deck_ + 0.7), "roof", verts=12, r2=0.0))
        p.append(L.cyl(0.72, 0.08, (1.0, 1.0, deck_ + 0.68), "goldBright", verts=12))
        for sy in (-1.6, 1.6):
            p.append(L.box((3.2, 0.08, 0.10), (0, sy, deck_ + 1.25), "goldBright"))
    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- piche (~1.2)
def tar(lvl):
    p = base(lvl)
    p.append(L.cyl(2.02, 0.50, (0, 0, BASE_TOP), "stoneDark", verts=24, r2=2.10))
    p.append(L.cyl(1.86, 0.08, (0, 0, BASE_TOP + 0.48), "ink", verts=24))
    rim = "stoneDark" if lvl == 1 else "iron"
    p.append(L.torus(1.96, 0.14, (0, 0, BASE_TOP + 0.54), rim, major_seg=24, minor_seg=4))

    # Faixa de ferro e rebites ao redor da bacia
    p.append(L.cyl(2.13, 0.15, (0, 0, BASE_TOP + 0.16), "iron" if lvl >= 2 else "stone", verts=24))
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        p.append(L.spike(0.085, 0.10, (2.15 * math.cos(a), 2.15 * math.sin(a), BASE_TOP + 0.20), "ironDark", verts=4))

    # Bolhas de piche suaves (seg=16)
    bubbles = ((-0.68, -0.35, 0.26, 5), (0.54, 0.36, 0.24, 5), (0.05, 0.72, 0.19, 5))
    for x, y, br, rng_c in bubbles:
        p.append(L.ball(br, (x, y, BASE_TOP + 0.55), "tarGlow", seg=16, rings=rng_c, squash=(1.0, 1.0, 0.72)))

    if lvl >= 3:  # engrenagem submersa + aro de filigrana dourada
        p += _gear_light(
            0.92,
            0.08,
            (0, 0, BASE_TOP + 0.56),
            "ironDark" if lvl < 5 else "gold",
            teeth=5,
            hub="gold" if lvl < 5 else "neonAmber",
        )
        p.append(
            L.torus(
                2.16,
                0.055,
                (0, 0, BASE_TOP + 0.38),
                "goldBright" if lvl >= 5 else "gold",
                major_seg=18,
                minor_seg=4,
            )
        )
    if lvl >= 4:  # pontas da borda
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.26
            p.append(L.spike(0.12, 0.24, (1.94 * math.cos(a), 1.94 * math.sin(a), BASE_TOP + 0.65), "gold", verts=4))
    if lvl >= 5:
        p.append(L.torus(1.48, 0.045, (0, 0, BASE_TOP + 0.56), "goldBright", major_seg=16, minor_seg=4))

    # Placa frontal com a patente (chevrons em fila, sem mastro: classe de altura 1.2)
    p.append(L.box((2.6, 0.3, 0.52), (0, -2.1, BASE_TOP + 0.26), "woodDark"))
    return p + L.rank_row(lvl, y=-2.33, z=BASE_TOP + 0.3)


# ---------------------------------------------------------------- gelo (~4.4)
def frost(lvl):
    p = base(lvl)
    p.append(L.box((4.05, 4.05, 0.10), (0, 0, BASE_TOP + 0.05), "iceLight", bevel=0.03))
    # Plinto runico 16-seg + nos runicos
    p.append(L.cyl(1.22, 0.24, (0, 0, BASE_TOP + 0.08), "stoneDark", verts=16, r2=1.08))
    p.append(L.cyl(0.88, 0.22, (0, 0, BASE_TOP + 0.30), "obsidian" if lvl >= 3 else "iron", verts=16, r2=0.78))
    for k in range(8):
        a = 2 * math.pi * k / 8
        col = "arcaneCyan" if k % 2 == 0 else "iceGlow"
        if k % 2 == 0:
            p.append(L.ball(0.095, (1.16 * math.cos(a), 1.16 * math.sin(a), BASE_TOP + 0.24), col, seg=10, rings=6))
        else:
            p.append(L.ico(0.095, (1.16 * math.cos(a), 1.16 * math.sin(a), BASE_TOP + 0.24), col, subdiv=2))

    z0 = BASE_TOP + 0.48
    # Espirais de gelo 6-lados nitidos (verts=6 preserva arestas vivas contra threshold 46 deg)
    p.append(L.crystal(0.56, 2.95, (0, 0, z0), "ice", verts=6, r2=0.32, spin=math.pi / 6))
    p.append(L.crystal(0.32, 0.78, (0, 0, z0 + 2.95), "iceLight", verts=6, spin=math.pi / 6))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        p.append(
            L.crystal(
                0.28,
                1.65,
                (0.75 * math.cos(a), 0.75 * math.sin(a), z0 - 0.06),
                "ice",
                tilt=(-0.22 * math.sin(a), 0.22 * math.cos(a)),
                verts=6,
            )
        )

    if lvl >= 2:
        for sx in (-1, 1):
            p.append(L.crystal(0.32, 2.05, (sx * 1.02, -0.18, z0 - 0.05), "iceLight", tilt=(0.12, sx * 0.28), verts=6))
        p.append(L.cyl(0.68, 0.20, (0, 0, z0 + 1.12), "iron", verts=16))

    if lvl >= 3:  # anel de contencao torus + coroa de prismas 6-lados + nos runicos
        p.append(L.torus(1.12, 0.075, (0, 0, z0 + 1.65), "arcaneCyan", major_seg=14, minor_seg=4, rot=(0.42, 0.0, 0.0)))
        for k in range(3):
            a = 2 * math.pi * k / 3
            p.append(
                L.crystal(
                    0.13,
                    0.70,
                    (0.46 * math.cos(a), 0.46 * math.sin(a), z0 + 2.38),
                    "iceGlow",
                    tilt=(-0.45 * math.sin(a), 0.45 * math.cos(a)),
                    verts=6,
                )
            )
        for k in range(2):
            a = 2 * math.pi * k / 2 + math.pi / 4
            p.append(L.ico(0.14, (1.42 * math.cos(a), 1.42 * math.sin(a), BASE_TOP + 0.26), "arcaneCyan", subdiv=1))

    if lvl >= 4:  # segundo anel torus runico + nos brilhantes
        p.append(L.torus(1.00, 0.07, (0, 0, z0 + 1.85), "gold", major_seg=14, minor_seg=4, rot=(0.0, -0.52, 0.0)))
        p.append(L.ico(0.14, (0, -1.04, z0 + 1.48), "iceGlow", subdiv=1))
        p.append(L.ico(0.14, (0, 1.04, z0 + 1.82), "arcaneCyan", subdiv=1))

    if lvl >= 5:  # terceiro anel dourado brilhante
        p.append(L.torus(1.36, 0.05, (0, 0, z0 + 0.42), "goldBright", major_seg=14, minor_seg=4))

    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- canhao (~3.2)
def cannon(lvl):
    p = base(lvl)
    p.append(L.box((1.50, 2.85, 0.52), (0, 0.15, BASE_TOP + 0.62), "wood"))
    for sx in (-1, 1):
        p.append(L.box((0.26, 2.25, 0.92), (sx * 0.62, 0.25, BASE_TOP + 1.2), "woodDark"))
        p += _spoked_wheel(0.68, 0.28, (sx * 1.02, -0.55, BASE_TOP + 0.68), "woodDark", "iron", spokes=4, minor_seg=4)
        p.append(L.cyl_axis(0.42, 0.26, (sx * 0.95, 1.15, BASE_TOP + 0.42), "woodDark", axis="x", verts=10))

    tilt = 0.22
    c = (0.0, -0.3, BASE_TOP + 1.95)
    d = (0.0, -math.cos(tilt), math.sin(tilt))
    barrel_rot = (math.pi / 2 - tilt, 0.0, 0.0)

    def along(t):
        return (c[0] + d[0] * t, c[1] + d[1] * t, c[2] + d[2] * t)

    barrel = "iron" if lvl == 1 else "steel"
    # Cano conico 24-seg + boca alargada + cascavel + anel torus de reforco
    p.append(L.cyl_axis(0.44, 2.85, c, barrel, axis="y", verts=24, r2=0.35, tilt=tilt))
    p.append(L.cyl_axis(0.36, 0.32, along(1.30), "ironDark", axis="y", verts=24, r2=0.49, tilt=tilt))
    p.append(L.ball(0.42, along(-1.44), barrel, seg=8, rings=5))
    p.append(L.ball(0.20, along(-1.86), "ironDark" if lvl < 4 else "gold", seg=8, rings=4))
    p.append(L.torus(0.43, 0.06, along(-0.35), "ironDark", major_seg=16, minor_seg=4, rot=barrel_rot))

    if lvl >= 2:  # chapas de ferro na carruagem + segundo anel no cano
        for sx in (-1, 1):
            p.append(L.box((0.08, 1.4, 0.55), (sx * 0.77, 0.0, BASE_TOP + 1.22), "iron"))
        p.append(L.cyl_axis(0.45, 0.14, along(0.45), "bronze" if lvl >= 3 else "ironDark", axis="y", verts=16, tilt=tilt))

    if lvl >= 3:  # barris de polvora no rack lateral + mira de bronze
        p.append(L.box((0.95, 0.65, 0.16), (0.85, 1.35, BASE_TOP + 0.08), "woodDark"))
        for dx in (-0.24, 0.24):
            p.append(L.cyl(0.20, 0.54, (0.85 + dx, 1.35, BASE_TOP + 0.16), "wood", verts=10))
        sight = along(-0.6)
        p.append(L.box((0.10, 0.10, 0.58), (sight[0], sight[1], sight[2] + 0.60), "bronze"))
        p.append(L.cyl_axis(0.15, 0.08, (sight[0], sight[1], sight[2] + 0.94), "gold", axis="y", verts=8))

    if lvl >= 4:  # engrenagem lateral de recarga
        p += _gear_light(
            0.38,
            0.10,
            (-0.82, 0.95, BASE_TOP + 1.35),
            "iron" if lvl == 4 else "gold",
            axis="x",
            teeth=5,
            hub="gold" if lvl == 4 else "neonAmber",
        )

    if lvl >= 5:  # filigrana dourada na culatra e municao
        p.append(L.cyl_axis(0.48, 0.14, along(1.42), "goldBright", axis="y", verts=16, tilt=tilt))
        p.append(L.cyl_axis(0.46, 0.12, along(-1.05), "goldBright", axis="y", verts=16, tilt=tilt))

    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- catapulta (~4.8)
def catapult(lvl):
    p = base(lvl)
    for sx in (-1, 1):
        p.append(L.box((0.36, 3.8, 0.45), (sx * 1.05, 0, BASE_TOP + 0.8), "wood"))
    for sy in (-1.6, 1.6):
        p.append(L.box((2.5, 0.36, 0.40), (0, sy, BASE_TOP + 0.82), "woodDark"))

    # Rodas dianteiras raiadas (20-seg torus) e traseiras (16-seg)
    for sx in (-1, 1):
        p += _spoked_wheel(0.60, 0.28, (sx * 1.38, -1.15, BASE_TOP + 0.60), "woodDark", "iron", spokes=4, minor_seg=4)
        p.append(L.cyl_axis(0.56, 0.28, (sx * 1.38, 1.15, BASE_TOP + 0.56), "woodDark", axis="x", verts=16))

    pivot = (0.0, -0.3, BASE_TOP + 2.1)
    for sx in (-1, 1):
        p.append(L.box((0.30, 0.30, 1.5), (sx * 0.82, pivot[1], BASE_TOP + 1.35), "wood"))
        p.append(L.box((0.22, 1.4, 0.22), (sx * 0.82, pivot[1] + 0.4, BASE_TOP + 1.45), "woodDark", rot=(0.8, 0, 0)))
    p.append(L.cyl_axis(0.12, 1.95, pivot, "iron", axis="x", verts=10))

    # Madeixas de torcao em torus duplos torcidos ao redor do eixo
    for sx, tilt_x in ((-0.42, 0.35), (0.42, -0.35)):
        p.append(L.torus(0.26, 0.08, (sx, pivot[1], pivot[2]), "straw", major_seg=10, minor_seg=4, rot=(tilt_x, math.pi / 2, 0.0)))

    a = math.radians(55)
    d = (0.0, math.cos(a), math.sin(a))
    arm_len = 2.85
    mid = (0.0, pivot[1] + d[1] * (arm_len / 2 - 0.35), pivot[2] + d[2] * (arm_len / 2 - 0.35))
    p.append(L.box((0.30, arm_len, 0.30), mid, "wood", rot=(a, 0, 0)))
    # Concha ferrada + aro torus + pedregulho incandescente
    tip = (0.0, pivot[1] + d[1] * 2.35, pivot[2] + d[2] * 2.35)
    p.append(L.cyl(0.46, 0.38, (tip[0], tip[1], tip[2] - 0.05), "woodDark", verts=14, r2=0.58))
    p.append(L.torus(0.56, 0.06, (tip[0], tip[1], tip[2] + 0.30), "iron", major_seg=12, minor_seg=4))
    p.append(L.ico(0.31, (tip[0], tip[1], tip[2] + 0.34), "stoneLight", subdiv=1))
    p.append(L.ico(0.18, (tip[0] - 0.14, tip[1] - 0.12, tip[2] + 0.44), "ember", subdiv=1))

    cw_z = pivot[2] - 0.62
    if lvl == 1:
        p.append(L.box((0.75, 0.75, 0.7), (0, pivot[1] - 0.32, cw_z), "stoneDark", bevel=0.05))
    else:
        for sx in (-1, 1):
            p.append(L.box((0.55, 0.7, 0.7), (sx * 0.36, pivot[1] - 0.32, cw_z), "ironDark"))
        for sx in (-1, 1):
            for sy in (-1.6, 1.6):
                p.append(L.box((0.44, 0.44, 0.52), (sx * 1.05, sy, BASE_TOP + 0.82), "iron"))
    p.append(L.box((0.08, 0.5, 0.3), (0, tip[1] - 0.25, tip[2] - 0.35), "catapult"))

    if lvl >= 3:  # arco frontal coroado + guincho
        for sx in (-1, 1):
            p.append(L.box((0.26, 0.26, 2.2), (sx * 0.95, -1.75, BASE_TOP + 1.95), "woodDark"))
        p.append(L.box((2.3, 0.3, 0.3), (0, -1.75, BASE_TOP + 3.0), "ironDark"))
        for x in (-0.7, 0.0, 0.7):
            p.append(L.spike(0.15, 0.45 if x == 0 else 0.32, (x, -1.75, BASE_TOP + 3.12), "gold", verts=4))
        p.append(L.cyl(0.22, 0.24, (0, 0.55, BASE_TOP + 1.0), "iron", verts=10))

    if lvl >= 4:  # engrenagem de guincho lateral
        p += _gear_light(
            0.50,
            0.12,
            (1.05, pivot[1], pivot[2]),
            "iron" if lvl == 4 else "gold",
            axis="x",
            teeth=5,
            hub="gold" if lvl == 4 else "neonAmber",
        )

    if lvl >= 5:  # acabamento dourado + nucleo brasa na concha
        for sx in (-1, 1):
            p.append(L.box((0.1, 3.6, 0.08), (sx * 1.05, 0, BASE_TOP + 1.05), "goldBright"))
        p.append(L.ico(0.16, (tip[0], tip[1], tip[2] + 0.56), "neonAmber", subdiv=0))

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
