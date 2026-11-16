"""Gera o portal da fenda (PROP_rift_portal) e os 5 portais monumentais da campanha
(PORTAL_act1..PORTAL_act5) para a esteira Blender -> Forge3D -> Open Cloud.

Frente no Blender = -Y (simetrico em -Y/+Y para vista dupla Build e Raid), largura ao longo de X,
base normalizada em Z=0, altura ~13-14.6 studs, limite <= 3600 tris por malha (alvo 2100..3400).

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_portal.py
Saidas: art/export/*.glb, art/forge/lote_portal_import.yaml (gerado),
        art/renders/portal/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 3600  # alvo 2100..3400 tris por portal
NORMALS_SPEC = {
    "modo": "hard_surface",
    "angulo_graus": 46,
    "weighted_normals": True,
    "corrective_smooth": False,
}


def _vortex_lens(
    p,
    center_z: float,
    outer_col: str,
    mid_col: str,
    inner_col: str,
    core_col: str,
    ring_col: str | None = None,
    rx: float = 3.35,
    rz: float = 1.22,
):
    """Lente eliptica suave em camadas (seg=24, rings=14) + anel toroidal de energia."""
    p.append(L.ball(rx, (0, 0, center_z), outer_col, seg=24, rings=14, squash=(0.94, 0.05, rz)))
    p.append(L.ball(rx * 0.77, (0, 0, center_z), mid_col, seg=14, rings=7, squash=(0.91, 0.11, rz * 0.97)))
    p.append(L.ball(rx * 0.53, (0, 0, center_z), inner_col, seg=10, rings=5, squash=(0.88, 0.20, rz * 0.93)))
    p.append(L.ico(rx * 0.27, (0, 0, center_z), core_col, squash=(0.84, 0.44, rz), subdiv=1))
    # Em local torus antes de Rx(90): X=largura, Y->Z=altura, Z->-Y=espessura frontal/traseira
    p.append(
        L.torus(
            rx * 0.89,
            0.13,
            (0, 0, center_z),
            ring_col or inner_col,
            major_seg=20,
            minor_seg=6,
            rot=(math.pi / 2, 0.0, 0.0),
            squash=(0.98, rz * 1.03, 1.25),
        )
    )


def _altar_steps(p, base_w, base_d, col1, col2, col3, dais_col):
    """Altar monumental chanfrado com degraus frontais/traseiros e disco ritual de 20 lados."""
    p.append(L.box((base_w, base_d, 0.54), (0, 0, 0.27), col1, bevel=0.07))
    p.append(L.box((base_w - 1.6, base_d - 0.9, 0.44), (0, 0, 0.74), col2, bevel=0.06))
    for sy in (-1, 1):
        p.append(L.box((5.8, 0.72, 0.30), (0, sy * (base_d * 0.5 + 0.24), 0.15), col1))
        p.append(L.box((4.8, 0.60, 0.28), (0, sy * (base_d * 0.5 - 0.16), 0.42), col3))
    p.append(L.cyl(3.35, 0.22, (0, 0, 0.92), dais_col, verts=20, r2=3.12))


def portal():
    """PROP_rift_portal — arco de obsidiana arcana em camadas + aneis toroidais de vortice + cristais."""
    p = []

    # 1. Altar escalonado chanfrado de obsidiana + disco ritual arcano
    _altar_steps(p, 12.6, 4.5, "obsidian", "obsidianLight", "stoneDark", "tealDark")

    # 2. Aglomerados de cristais arcanos flanqueando o altar
    for sx in (-1, 1):
        p.append(L.crystal(0.54, 2.35, (sx * 5.25, -0.95, 0.48), "tealSwarm", tilt=(0.15, sx * 0.26), verts=6))
        p.append(L.crystal(0.44, 1.85, (sx * 5.45, 0.95, 0.48), "arcaneCyan", tilt=(-0.15, sx * 0.28), verts=6))
        p.append(L.crystal(0.36, 1.50, (sx * 4.82, -1.68, 0.46), "eyeNeon", tilt=(0.24, sx * 0.15), verts=5))
        p.append(L.crystal(0.34, 1.42, (sx * 4.82, 1.68, 0.46), "arcaneViolet", tilt=(-0.22, sx * 0.15), verts=5))
        p.append(L.box((1.15, 0.95, 0.62), (sx * 5.80, -1.95, 0.34), "obsidian", bevel=0.05, rot=(0.12, sx * 0.18, 0.3)))
        p.append(L.box((1.05, 0.88, 0.56), (sx * 5.75, 1.95, 0.30), "obsidianLight", rot=(-0.12, sx * 0.16, -0.25)))

    # 3. Colunas afuniladas de 24 lados em obsidiana com aneis runicos e espiras gemeas
    for sx in (-1, 1):
        x = sx * 4.15
        p.append(L.cyl(1.50, 1.15, (x, 0, 0.88), "obsidian", verts=24, r2=1.28))
        p.append(L.cyl(1.34, 0.20, (x, 0, 1.98), "tealSwarm", verts=18, r2=1.30))
        p.append(L.cyl(1.22, 5.30, (x, 0, 2.16), "obsidianLight", verts=24, r2=0.98))
        for z in (3.85, 5.85):
            rz = 1.16 - (z - 3.85) * 0.045
            p.append(L.cyl(rz, 0.18, (x, 0, z), "arcaneCyan", verts=16, r2=rz * 0.98))
            for sy in (-1, 1):
                p.append(
                    L.crystal(
                        0.20,
                        0.72,
                        (x, sy * (rz * 0.90), z - 0.22),
                        "eyeNeon",
                        tilt=(-sy * 0.12, 0.0),
                        verts=4,
                    )
                )
        p.append(L.cyl(1.00, 0.76, (x, 0, 7.42), "obsidian", verts=24, r2=1.38))
        p.append(L.crystal(0.58, 2.70, (x + sx * 0.26, 0, 8.18), "obsidian", tilt=(0.0, sx * 0.28), verts=6))
        p.append(L.crystal(0.42, 1.98, (x + sx * 0.74, 0, 8.06), "obsidianLight", tilt=(0.0, sx * 0.52), verts=5))
        p.append(L.ico(0.42, (x + sx * 0.48, 0, 9.55), "eyeNeon", squash=(0.82, 0.82, 1.38), subdiv=1))

    # 4. Arco arcano de obsidiana em camadas (9 aduelas chanfradas + crista dorsal + pedra-chave)
    n_arch = 9
    for k in range(n_arch):
        theta = 0.16 + (math.pi - 0.32) * k / (n_arch - 1)
        vx = 4.12 * math.cos(theta)
        vz = 7.25 + 3.86 * math.sin(theta)
        ry = math.pi / 2 - theta
        is_key = k == n_arch // 2
        col = "arcaneViolet" if is_key else ("obsidian" if k % 2 == 0 else "obsidianLight")
        p.append(L.box((1.42, 2.04, 1.14), (vx, 0, vz), col, bevel=0.06, rot=(0.0, ry, 0.0)))
        if k % 2 == 1:
            ox = 4.62 * math.cos(theta)
            oz = 7.25 + 4.35 * math.sin(theta)
            p.append(L.box((0.96, 1.42, 0.52), (ox, 0, oz), "obsidian", rot=(0.0, ry, 0.0)))

    p.append(L.crystal(0.76, 2.35, (0, 0, 10.75), "obsidian", verts=6, spin=math.pi / 6))
    for sy in (-1, 1):
        p.append(L.ico(0.48, (0, sy * 0.92, 11.12), "eyeNeon", squash=(0.74, 0.45, 1.35), subdiv=1))

    # 5. Lente de vortice + segundo anel toroidal cruzado de energia arcana
    _vortex_lens(p, 5.20, "tealDark", "teal", "tealSwarm", "eyeNeon", ring_col="arcaneCyan", rx=3.46, rz=1.24)
    p.append(
        L.torus(
            2.72,
            0.095,
            (0, 0, 5.20),
            "arcaneViolet",
            major_seg=18,
            minor_seg=5,
            rot=(math.pi / 2 + 0.16, 0.14, 0.0),
            squash=(0.96, 1.22, 1.30),
        )
    )

    return p


def portal_act1():
    """Ato 1 — Cinzas da Fronteira: bigorna-chave forjada, pilares espinhados chanfrados, correntes toroidais e brasa."""
    p = []

    # 1. Plataforma escalonada de ferro e pedra chamuscada
    _altar_steps(p, 12.8, 4.6, "ironDark", "stoneDark", "iron", "tarDeep")

    # 2. Braseiros laterais redondos (verts=14) com chamas em camadas
    for sx in (-1, 1):
        bx = sx * 5.45
        p.append(L.cyl(0.70, 0.74, (bx, 0, 0.54), "ironDark", verts=14, r2=0.90))
        p.append(L.cyl(0.94, 0.20, (bx, 0, 1.24), "bronze", verts=14, r2=0.98))
        p.append(L.crystal(0.48, 1.28, (bx, 0, 1.36), "emberDeep", verts=6))
        p.append(L.crystal(0.32, 0.96, (bx, -0.16, 1.44), "ember", tilt=(0.18, 0.0), verts=5))
        p.append(L.crystal(0.24, 0.78, (bx, 0.16, 1.48), "neonAmber", tilt=(-0.18, 0.0), verts=5))

    # 3. Colunas afuniladas (verts=20) revestidas por colares blindados chanfrados e espigoes
    for sx in (-1, 1):
        x = sx * 4.25
        p.append(L.box((2.20, 2.60, 1.18), (x, 0, 1.48), "ironDark", bevel=0.07))
        p.append(L.cyl(1.18, 5.50, (x, 0, 2.05), "iron", verts=20, r2=0.98))
        for z in (3.55, 5.95):
            p.append(L.box((1.92, 2.30, 0.42), (x, 0, z), "ironDark", bevel=0.05))
            p.append(L.crystal(0.30, 1.18, (x + sx * 0.90, 0, z), "steel", tilt=(0.0, sx * 1.15), verts=5))
            for sy in (-1, 1):
                p.append(L.box((0.56, 0.18, 0.24), (x, sy * 1.14, z), "emberDeep"))
        # Ombreira de cerco chanfrada + chifres de aco
        p.append(L.box((2.38, 2.48, 1.16), (x + sx * 0.15, 0, 8.05), "ironDark", bevel=0.07))
        p.append(L.crystal(0.54, 2.65, (x + sx * 0.36, 0, 8.52), "steel", tilt=(0.0, sx * 0.24), verts=5))
        p.append(L.crystal(0.36, 1.75, (x + sx * 0.94, 0, 8.20), "iron", tilt=(0.0, sx * 0.58), verts=5))

    # 4. Arco blindado chanfrado + Pedra-Chave em Bigorna de Guerra (forged war-anvil keystone)
    for ax, az, ry in ((-3.22, 8.78, 0.42), (-1.70, 9.68, 0.20), (1.70, 9.68, -0.20), (3.22, 8.78, -0.42)):
        p.append(L.box((2.15, 2.12, 1.18), (ax, 0, az), "iron", bevel=0.06, rot=(0.0, ry, 0.0)))
        p.append(L.box((0.52, 2.26, 0.34), (ax, 0, az + 0.48), "bronze", rot=(0.0, ry, 0.0)))

    # Bigorna de Guerra central no apice (base, cintura acinturada, mesa larga + chifre lateral de bigorna)
    p.append(L.box((2.10, 2.34, 0.62), (0, 0, 9.88), "ironDark", bevel=0.06))
    p.append(L.box((1.48, 1.96, 0.68), (0, 0, 10.48), "ironDark", bevel=0.05))
    p.append(L.box((3.05, 2.12, 0.76), (0, 0, 11.12), "steel", bevel=0.06))
    for sx in (-1, 1):
        p.append(L.crystal(0.42, 1.18, (sx * 1.48, 0, 11.14), "steel", tilt=(0.0, sx * 1.42), verts=5))
    p.append(L.crystal(0.52, 1.95, (0, 0, 11.48), "ironDark", verts=6))
    for sy in (-1, 1):
        p.append(L.box((0.86, 0.22, 0.86), (0, sy * 1.08, 10.48), "neonAmber", rot=(0.0, math.pi / 4, 0.0)))

    # Correntes de cerco em elos toroidais suaves pendendo do arco
    for sx in (-1, 1):
        for k in range(3):
            cz = 8.20 - k * 0.74
            rot = (math.pi / 2, 0.0, 0.0) if k % 2 == 0 else (0.0, math.pi / 2, 0.0)
            p.append(
                L.torus(
                    0.28,
                    0.07,
                    (sx * 3.16, 0, cz),
                    "ironDark" if k % 2 == 0 else "steel",
                    major_seg=10,
                    minor_seg=4,
                    rot=rot,
                    squash=(0.78, 1.25, 1.0),
                )
            )

    # 5. Nucleo flamejante em brasa + linguas de fogo
    _vortex_lens(p, 5.15, "emberDeep", "amber", "ember", "neonAmber", ring_col="amberBright", rx=3.18, rz=1.18)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.18
        p.append(
            L.crystal(
                0.22,
                0.82,
                (2.58 * math.cos(a), 0.0, 5.15 + 3.18 * math.sin(a)),
                "neonAmber" if k % 2 == 0 else "emberDeep",
                tilt=(0.0, -a + math.pi / 2),
                verts=4,
            )
        )

    return p


def portal_act2():
    """Ato 2 — Forjas de Escoria: tambores serrilhados de basalto com fendas de lava, cadinhos suaves e coroa vulcanica."""
    p = []

    # 1. Base de basalto vulcanico chanfrado + piscina de magma incandescente
    _altar_steps(p, 12.8, 4.8, "tarDeep", "obsidian", "stoneDark", "danger")

    # 2. Cadinhos gemeos suaves de magma (bojo esferico + aro toroidal + domo borbulhante)
    for sx in (-1, 1):
        cx = sx * 5.48
        p.append(L.cyl(0.95, 0.65, (cx, 0, 0.54), "obsidian", verts=14, r2=1.18))
        p.append(L.ball(1.20, (cx, 0, 1.65), "ironDark", seg=10, rings=5, squash=(1.0, 1.0, 0.82)))
        p.append(L.torus(1.14, 0.11, (cx, 0, 2.26), "bronze", major_seg=12, minor_seg=4))
        p.append(L.cyl(1.02, 0.24, (cx, 0, 2.22), "danger", verts=12, r2=0.92))
        p.append(L.crystal(0.42, 1.32, (cx, 0, 2.46), "emberDeep", verts=5))
        p.append(L.ico(0.28, (cx + sx * 0.22, -0.18, 2.72), "amberBright", subdiv=1))

    # 3. Colunas em tambores serrilhados de basalto (verts=20) com fendas brilhantes de lava
    for sx in (-1, 1):
        x = sx * 4.22
        p.append(L.cyl(1.54, 1.15, (x, 0, 0.88), "tarDeep", verts=20, r2=1.34))
        for idx, z in enumerate((2.05, 4.65)):
            r1 = 1.30 - idx * 0.12
            r2 = r1 - 0.08
            p.append(L.cyl(r1, 2.30, (x, 0, z), "obsidian" if idx % 2 == 0 else "stoneDark", verts=20, r2=r2))
            # Fenda horizontal incandescente de lava + fissuras verticais
            p.append(L.cyl(r2 * 0.97, 0.28, (x, 0, z + 2.30), "danger" if idx % 2 == 0 else "emberDeep", verts=14))
            for sy in (-1, 1):
                p.append(L.box((0.20, 0.16, 1.65), (x + sx * 0.18, sy * (r1 * 0.88), z + 1.15), "amberBright"))
            # Esporas serrilhadas de basalto
            p.append(L.crystal(0.46, 1.62, (x + sx * 1.04, 0, z + 0.95), "tarDeep", tilt=(0.0, sx * 0.72), verts=5))

        p.append(L.crystal(0.68, 2.95, (x + sx * 0.22, 0, 7.45), "tarDeep", tilt=(0.0, sx * 0.22), verts=6))
        p.append(L.crystal(0.44, 2.10, (x + sx * 0.85, 0, 7.35), "obsidian", tilt=(0.0, sx * 0.52), verts=5))
        p.append(L.crystal(0.32, 1.38, (x + sx * 0.35, 0, 9.55), "emberDeep", tilt=(0.0, sx * 0.18), verts=4))

    # 4. Coroa vulcanica megalitica com fendas de magma e cratera central
    n_arch = 7
    for k in range(n_arch):
        theta = 0.20 + (math.pi - 0.40) * k / (n_arch - 1)
        vx = 4.08 * math.cos(theta)
        vz = 7.55 + 3.65 * math.sin(theta)
        ry = math.pi / 2 - theta
        col = "tarDeep" if k % 2 == 0 else "obsidian"
        p.append(L.box((1.65, 2.15, 1.24), (vx, 0, vz), col, bevel=0.06, rot=(0.0, ry, 0.0)))
        if k % 2 == 1:
            p.append(L.box((0.28, 2.24, 1.30), (vx, 0, vz), "emberDeep", rot=(0.0, ry, 0.0)))

    # Cratera da coroa vulcanica no apice
    p.append(L.cyl(1.15, 1.05, (0, 0, 10.65), "tarDeep", verts=14, r2=0.88))
    p.append(L.crystal(0.76, 2.45, (0, 0, 11.15), "obsidian", verts=6))
    for sx in (-1, 1):
        p.append(L.crystal(0.46, 1.75, (sx * 0.95, 0, 10.95), "emberDeep", tilt=(0.0, sx * 0.32), verts=5))
    for sy in (-1, 1):
        p.append(L.ico(0.46, (0, sy * 0.94, 11.20), "amberBright", squash=(0.85, 0.48, 1.20), subdiv=1))

    # 5. Nucleo de magma fundido
    _vortex_lens(p, 5.20, "tarDeep", "danger", "emberDeep", "amberBright", ring_col="ember", rx=3.32, rz=1.20)

    return p


def portal_act3():
    """Ato 3 — Geada do Desfiladeiro: espiras facetadas de 6 lados, aneis crio-toroidais suaves e nodos runicos."""
    p = []

    # 1. Altar glacial chanfrado + disco espelhado de gelo
    _altar_steps(p, 12.6, 4.5, "stone", "whiteStoneDark", "steel", "ice")

    # 2. Aglomerados de cristais de gelo de 6 faces nas extremidades
    for sx in (-1, 1):
        p.append(L.crystal(0.58, 2.75, (sx * 5.25, -0.85, 0.48), "ice", tilt=(0.14, sx * 0.28), verts=6))
        p.append(L.crystal(0.48, 2.20, (sx * 5.55, 0.85, 0.48), "iceLight", tilt=(-0.14, sx * 0.34), verts=6))
        p.append(L.crystal(0.36, 1.60, (sx * 4.82, -1.65, 0.46), "iceGlow", tilt=(0.24, sx * 0.16), verts=6))
        p.append(L.crystal(0.34, 1.50, (sx * 4.82, 1.65, 0.46), "arcaneCyan", tilt=(-0.24, sx * 0.16), verts=6))

    # 3. Colunas glaciais suaves (verts=20) com aneis crio-toroidais e espiras boreais de 6 lados
    for sx in (-1, 1):
        x = sx * 4.20
        p.append(L.cyl(1.44, 1.08, (x, 0, 0.88), "steel", verts=20, r2=1.24))
        p.append(L.cyl(1.18, 5.55, (x, 0, 1.92), "whiteStoneDark", verts=20, r2=0.92))
        p.append(L.cyl(1.16, 0.20, (x, 0, 3.25), "arcaneCyan", verts=18, r2=1.14))
        p.append(L.torus(1.08, 0.09, (x, 0, 5.35), "iceGlow", major_seg=16, minor_seg=5))
        for sy in (-1, 1):
            p.append(L.ico(0.24, (x, sy * 1.14, 5.35), "arcaneCyan", squash=(0.9, 0.65, 1.25), subdiv=1))
        # Altas espiras boreais facetadas de 6 lados (ate ~13.8 studs)
        p.append(L.crystal(0.70, 5.45, (x + sx * 0.18, 0, 7.35), "iceLight", tilt=(0.0, sx * 0.08), verts=6))
        p.append(L.crystal(0.50, 3.70, (x + sx * 0.80, 0, 7.25), "ice", tilt=(0.0, sx * 0.26), verts=6))
        p.append(L.crystal(0.36, 2.35, (x - sx * 0.34, 0, 7.65), "iceGlow", tilt=(0.0, -sx * 0.06), verts=6))

    # 4. Arco ogival pontiagudo com nodos runicos brilhantes + diamante boreal de 6 faces
    arch_left = [(-3.45, 7.95, 0.52), (-2.15, 9.45, 0.68), (-0.95, 10.65, 0.82)]
    for ax, az, ry in arch_left:
        for sx in (-1, 1):
            p.append(L.box((1.65, 1.86, 0.98), (sx * abs(ax), 0, az), "steel", bevel=0.06, rot=(0.0, -sx * ry, 0.0)))
            p.append(L.crystal(0.34, 1.32, (sx * abs(ax), 0, az + 0.42), "iceLight", tilt=(0.0, sx * 0.22), verts=6))
            for sy in (-1, 1):
                p.append(L.ico(0.26, (sx * abs(ax), sy * 0.98, az), "iceGlow", squash=(0.85, 0.55, 1.15), subdiv=1))

    # Cristal central em diamante duplo de 6 faces
    p.append(L.crystal(0.76, 2.65, (0, 0, 11.15), "iceGlow", verts=6))
    p.append(L.crystal(0.58, 1.55, (0, 0, 11.20), "arcaneCyan", tilt=(math.pi, 0.0), verts=6))

    # 5. Lente boreal + segundo anel crio-toroidal inclinado
    _vortex_lens(p, 5.30, "tealDark", "ice", "iceLight", "iceGlow", ring_col="arcaneCyan", rx=3.35, rz=1.26)
    p.append(
        L.torus(
            2.65,
            0.09,
            (0, 0, 5.30),
            "iceGlow",
            major_seg=20,
            minor_seg=5,
            rot=(math.pi / 2 - 0.14, -0.12, 0.0),
            squash=(0.96, 1.24, 1.30),
        )
    )

    return p


def portal_act4():
    """Ato 4 — Polvora e Trincheira: engrenagens rotativas de latao, tubulacoes de vapor rebitadas, chamines e luzes de alerta."""
    p = []

    # 1. Plataforma fortificada com borda chanfrada de latao/bronze
    _altar_steps(p, 12.8, 4.6, "ironDark", "iron", "brass", "bronze")

    # 2. Chamines gemeas suaves (verts=16) + tubulacoes de vapor rebitadas ligadas aos pilares
    for sx in (-1, 1):
        cx = sx * 5.42
        p.append(L.box((1.72, 2.12, 1.42), (cx, 0, 1.22), "ironDark", bevel=0.06))
        p.append(L.cyl(0.68, 8.85, (cx, 0, 1.90), "ironDark", verts=16, r2=0.56))
        for bz in (4.2, 8.6):
            p.append(L.cyl(0.75, 0.28, (cx, 0, bz), "brass", verts=14, r2=0.75))
        p.append(L.cyl(0.80, 0.58, (cx, 0, 10.72), "steel", verts=16, r2=0.64))
        # Tubulacao horizontal de vapor + flange de latao conectando chamine ao pilar
        p.append(L.cyl_axis(0.26, 1.35, (sx * 4.76, 0, 5.25), "iron", axis="x", verts=12))
        p.append(L.cyl_axis(0.35, 0.20, (sx * 4.76, 0, 5.25), "brass", axis="x", verts=12))

    # 3. Colunas blindadas de casamata (verts=20) com placas de latao e luzes de alerta (-Y/+Y)
    for sx in (-1, 1):
        x = sx * 4.10
        p.append(L.box((2.14, 2.68, 1.25), (x, 0, 1.54), "ironDark", bevel=0.06))
        p.append(L.cyl(1.16, 5.65, (x, 0, 2.12), "iron", verts=20, r2=1.02))
        for z in (3.55, 6.35):
            p.append(L.box((1.90, 2.40, 0.38), (x, 0, z), "brass"))
        p.append(L.box((2.18, 2.52, 1.05), (x, 0, 8.18), "ironDark"))
        # Luzes de alerta engaioladas em latao na frente e atras
        for sy in (-1, 1):
            p.append(L.cyl_axis(0.36, 0.22, (x, sy * 1.22, 4.95), "brass", axis="y", verts=8))
            p.append(L.ico(0.28, (x, sy * 1.38, 4.95), "danger", squash=(1.0, 0.65, 1.0), subdiv=1))
            p.append(L.ico(0.18, (x, sy * 1.48, 4.95), "amberBright", squash=(1.0, 0.55, 1.0), subdiv=1))

    # 4. Arco industrial rebitado chanfrado + trem de engrenagens rotativas de latao no apice
    n_arch = 5
    for k in range(n_arch):
        theta = 0.22 + (math.pi - 0.44) * k / (n_arch - 1)
        vx = 3.96 * math.cos(theta)
        vz = 7.75 + 3.18 * math.sin(theta)
        ry = math.pi / 2 - theta
        col = "iron" if k % 2 == 0 else "brass"
        p.append(L.box((1.95, 2.16, 1.12), (vx, 0, vz), col, bevel=0.05, rot=(0.0, ry, 0.0)))

    # Coroa industrial + engrenagem mestre de latao (verts=18) + 2 pinhoes laterais
    p.append(L.box((2.75, 2.28, 1.24), (0, 0, 11.10), "ironDark", bevel=0.06))
    p.append(L.cyl_axis(1.38, 2.46, (0, 0, 11.48), "brass", axis="y", verts=18))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(
            L.box(
                (0.34, 2.38, 0.38),
                (1.54 * math.cos(a), 0, 11.48 + 1.54 * math.sin(a)),
                "goldBright",
                rot=(0.0, -a, 0.0),
            )
        )
    for sx in (-1, 1):
        gx, gz = sx * 2.02, 10.75
        p.append(L.cyl_axis(0.70, 2.32, (gx, 0, gz), "bronze", axis="y", verts=12))
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.25
            p.append(L.box((0.24, 2.24, 0.26), (gx + 0.80 * math.cos(a), 0, gz + 0.80 * math.sin(a)), "brass", rot=(0.0, -a, 0.0)))

    for sy in (-1, 1):
        p.append(L.ico(0.46, (0, sy * 1.28, 11.48), "amberBright", squash=(1.0, 0.45, 1.0), subdiv=1))

    # 5. Nucleo de polvora e enxofre dourado
    _vortex_lens(p, 5.20, "tarDeep", "bronze", "brass", "amberBright", ring_col="goldBright", rx=3.16, rz=1.18)

    return p


def portal_act5():
    """Ato 5 — A Fenda Profunda: obeliscos flutuantes de obsidiana e aneis toroidais de contencao arcaneViolet/eyeNeon."""
    p = []

    # 1. Altar abissal de 3 degraus chanfrados
    p.append(L.box((13.4, 5.0, 0.56), (0, 0, 0.28), "obsidian", bevel=0.08))
    p.append(L.box((11.6, 3.9, 0.46), (0, 0, 0.78), "obsidianLight", bevel=0.06))
    p.append(L.box((9.8, 3.1, 0.38), (0, 0, 1.18), "stoneDark", bevel=0.05))
    for sy in (-1, 1):
        p.append(L.box((6.2, 0.74, 0.30), (0, sy * 2.72, 0.15), "obsidian"))
    p.append(L.cyl(3.28, 0.22, (0, 0, 1.32), "tealDark", verts=20, r2=3.06))

    # 2. Obeliscos flutuantes de obsidiana nas extremidades (pedestal terrestre + gap de levitacao + obelisco suspenso)
    for sx in (-1, 1):
        ox = sx * 5.65
        # Pedestal ancorado com cristal emissor antigravidade
        p.append(L.box((1.82, 2.18, 0.92), (ox, 0, 0.96), "obsidian", bevel=0.06))
        p.append(L.torus(0.76, 0.08, (ox, 0, 1.52), "arcaneViolet", major_seg=12, minor_seg=4))
        p.append(L.crystal(0.36, 0.62, (ox, 0, 1.48), "eyeNeon", verts=6))
        # Obelisco flutuante suspenso no ar (Z = 2.55 .. 11.45, com ponta inferior conica invertida)
        p.append(L.crystal(0.66, 0.95, (ox, 0, 3.50), "obsidian", tilt=(math.pi, 0.0), verts=4, spin=math.pi / 4))
        p.append(L.cyl(0.92, 5.85, (ox, 0, 3.50), "obsidian", verts=4, r2=0.54, rot_z=math.pi / 4, bevel=0.04))
        p.append(L.crystal(0.54, 1.95, (ox, 0, 9.35), "obsidianLight", verts=4, spin=math.pi / 4))
        p.append(L.torus(0.92, 0.075, (ox, 0, 5.2), "arcaneViolet", major_seg=12, minor_seg=4))
        p.append(L.box((1.22, 1.22, 0.24), (ox, 0, 7.5), "eyeNeon"))
        p.append(L.ico(0.34, (ox, 0, 11.55), "eyeNeon", squash=(0.78, 0.78, 1.38), subdiv=1))

    # 3. Colunas monoliticas suaves (verts=24) em obsidiana com condutos arcanos violeta/neon
    for sx in (-1, 1):
        x = sx * 3.88
        p.append(L.box((2.18, 2.68, 1.32), (x, 0, 1.92), "obsidian", bevel=0.07))
        p.append(L.cyl(1.18, 6.25, (x, 0, 2.55), "obsidianLight", verts=24, r2=0.98))
        for sy in (-1, 1):
            p.append(L.box((0.40, 0.20, 5.55), (x, sy * 1.08, 5.68), "arcaneViolet"))
            p.append(L.box((0.18, 0.24, 4.75), (x, sy * 1.14, 5.68), "eyeNeon"))
        p.append(L.box((2.28, 2.58, 0.98), (x, 0, 9.15), "obsidian", bevel=0.06))

    # 4. Lintel monumental escalonado em obsidiana + coroa abissal
    p.append(L.box((9.85, 2.48, 1.25), (0, 0, 10.15), "obsidian", bevel=0.07))
    p.append(L.box((7.45, 2.16, 0.96), (0, 0, 11.18), "obsidianLight", bevel=0.06))
    p.append(L.box((4.48, 1.86, 0.86), (0, 0, 12.02), "obsidian", bevel=0.06))
    p.append(L.crystal(0.76, 2.20, (0, 0, 12.38), "arcaneViolet", verts=6))
    for sx in (-1, 1):
        p.append(L.crystal(0.56, 2.45, (sx * 4.25, 0, 10.55), "obsidian", tilt=(0.0, sx * 0.24), verts=6))
    for sy in (-1, 1):
        p.append(L.box((1.90, 0.24, 0.42), (0, sy * 1.12, 11.18), "arcaneViolet"))
        p.append(L.ico(0.58, (0, sy * 1.05, 12.05), "eyeNeon", squash=(0.74, 0.42, 1.38), subdiv=1))

    # 5. Portal abissal + aneis toroidais de contencao entrecruzados (arcaneViolet / eyeNeon)
    _vortex_lens(p, 5.55, "obsidian", "arcaneViolet", "tealSwarm", "eyeNeon", ring_col="arcaneViolet", rx=3.18, rz=1.24)
    p.append(
        L.torus(
            2.95,
            0.10,
            (0, 0, 5.55),
            "eyeNeon",
            major_seg=20,
            minor_seg=5,
            rot=(math.pi / 2 + 0.24, 0.22, 0.0),
            squash=(0.95, 1.20, 1.28),
        )
    )
    p.append(
        L.torus(
            2.58,
            0.09,
            (0, 0, 5.55),
            "arcaneViolet",
            major_seg=20,
            minor_seg=5,
            rot=(math.pi / 2 - 0.24, -0.22, 0.0),
            squash=(0.95, 1.18, 1.32),
        )
    )

    return p


L.run_group(
    "portal",
    [
        {
            "id": "prop.rift_portal.01",
            "name": "PROP_rift_portal",
            "glb": "prop_rift_portal.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "center_xy": True,
            "suavizacao_normais": NORMALS_SPEC,
            "tags": ["muralha", "portal", "rift"],
            "build": portal,
        },
        {
            "id": "portal.act1_iron.01",
            "name": "PORTAL_act1",
            "glb": "portal_act1_iron.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "center_xy": True,
            "suavizacao_normais": NORMALS_SPEC,
            "tags": ["muralha", "portal", "campaign", "act1"],
            "build": portal_act1,
        },
        {
            "id": "portal.act2_slag.01",
            "name": "PORTAL_act2",
            "glb": "portal_act2_slag.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "center_xy": True,
            "suavizacao_normais": NORMALS_SPEC,
            "tags": ["muralha", "portal", "campaign", "act2"],
            "build": portal_act2,
        },
        {
            "id": "portal.act3_frost.01",
            "name": "PORTAL_act3",
            "glb": "portal_act3_frost.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "center_xy": True,
            "suavizacao_normais": NORMALS_SPEC,
            "tags": ["muralha", "portal", "campaign", "act3"],
            "build": portal_act3,
        },
        {
            "id": "portal.act4_powder.01",
            "name": "PORTAL_act4",
            "glb": "portal_act4_powder.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "center_xy": True,
            "suavizacao_normais": NORMALS_SPEC,
            "tags": ["muralha", "portal", "campaign", "act4"],
            "build": portal_act4,
        },
        {
            "id": "portal.act5_rift.01",
            "name": "PORTAL_act5",
            "glb": "portal_act5_rift.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "center_xy": True,
            "suavizacao_normais": NORMALS_SPEC,
            "tags": ["muralha", "portal", "campaign", "act5"],
            "build": portal_act5,
        },
    ],
    "portal da fenda + 5 portais monumentais da campanha (art/scripts/make_portal.py)",
)
