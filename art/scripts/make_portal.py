"""Gera o portal da fenda (PROP_rift_portal) e os 5 portais monumentais da campanha
(PORTAL_act1..PORTAL_act5) para a esteira Blender -> Forge3D -> Open Cloud.

Frente no Blender = -Y (simetrico em -Y/+Y para vista dupla Build e Raid), largura ao longo de X,
base normalizada em Z=0, altura ~13-14 studs, limite <= 2000 tris por malha.

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

LIMITE = 2000  # modulo_cenario/PROP grande (docs/ferramentas.md §4.2)


def _vortex_lens(p, center_z: float, outer_col: str, mid_col: str, inner_col: str, core_col: str, rx=3.35, rz=1.22):
    """Lente eliptica em camadas (cada anel interno mais espesso em Y para nao ser coberto)."""
    p.append(L.ball(rx, (0, 0, center_z), outer_col, seg=14, rings=7, squash=(0.94, 0.05, rz)))
    p.append(L.ball(rx * 0.79, (0, 0, center_z), mid_col, seg=12, rings=6, squash=(0.91, 0.10, rz * 0.97)))
    p.append(L.ball(rx * 0.55, (0, 0, center_z), inner_col, seg=10, rings=6, squash=(0.88, 0.19, rz * 0.94)))
    p.append(L.ico(rx * 0.27, (0, 0, center_z), core_col, squash=(0.84, 0.42, rz)))


def portal():
    p = []

    # 1. Altar escalonado de obsidiana chanfrada + disco ritual central
    p.append(L.box((12.4, 4.4, 0.55), (0, 0, 0.275), "ironDark", bevel=0.09))
    p.append(L.box((10.8, 3.4, 0.42), (0, 0, 0.72), "stoneDark", bevel=0.07))
    p.append(L.cyl(3.4, 0.22, (0, 0, 0.88), "tealDark", verts=12, r2=3.15))

    # 2. Cristais arcanos laterais + fragmentos de obsidiana ao redor do altar
    for sx in (-1, 1):
        p.append(L.crystal(0.50, 2.15, (sx * 5.25, -0.95, 0.48), "tealSwarm", tilt=(0.14, sx * 0.25), verts=5))
        p.append(L.crystal(0.40, 1.65, (sx * 5.45, 0.95, 0.48), "teal", tilt=(-0.14, sx * 0.28), verts=5))
        p.append(L.crystal(0.32, 1.35, (sx * 4.85, -1.65, 0.46), "eyeNeon", tilt=(0.24, sx * 0.14), verts=4))
        p.append(L.crystal(0.30, 1.25, (sx * 4.85, 1.65, 0.46), "tealSwarm", tilt=(-0.22, sx * 0.14), verts=4))
        p.append(L.ico(0.62, (sx * 5.85, -2.05, 0.34), "ironDark", squash=(1.25, 1.0, 0.68)))
        p.append(L.ico(0.52, (sx * 5.75, 2.05, 0.30), "stoneDark", squash=(1.15, 0.95, 0.65)))

    # 3. Colunas octogonais afuniladas com runas e twin spires/chifres de obsidiana
    for sx in (-1, 1):
        x = sx * 4.15
        p.append(L.cyl(1.48, 1.12, (x, 0, 0.88), "ironDark", verts=8, r2=1.28))
        p.append(L.cyl(1.34, 0.22, (x, 0, 1.98), "tealSwarm", verts=8, r2=1.30))
        p.append(L.cyl(1.22, 5.30, (x, 0, 2.18), "stoneDark", verts=8, r2=1.00))
        for z in (3.45, 4.95, 6.45):
            rz = 1.15 - (z - 3.45) * 0.045
            p.append(L.cyl(rz, 0.18, (x, 0, z), "tealSwarm", verts=8, r2=rz * 0.98, rot_z=math.pi / 8))
            for sy in (-1, 1):
                p.append(
                    L.crystal(
                        0.20,
                        0.68,
                        (x, sy * (rz * 0.90), z - 0.22),
                        "eyeNeon",
                        tilt=(-sy * 0.10, 0.0),
                        verts=4,
                    )
                )
        p.append(L.cyl(1.02, 0.72, (x, 0, 7.46), "ironDark", verts=8, r2=1.36))
        p.append(L.crystal(0.58, 2.65, (x + sx * 0.25, 0, 8.22), "ironDark", tilt=(0.0, sx * 0.28), verts=6))
        p.append(L.crystal(0.42, 1.95, (x + sx * 0.72, 0, 8.10), "stoneDark", tilt=(0.0, sx * 0.52), verts=5))
        p.append(L.ico(0.42, (x + sx * 0.48, 0, 9.55), "eyeNeon", squash=(0.82, 0.82, 1.38)))

    # 4. Arco gotico curvo (9 aduelas esculpidas + crista de obsidiana e gema central)
    n_arch = 9
    for k in range(n_arch):
        theta = 0.16 + (math.pi - 0.32) * k / (n_arch - 1)
        vx = 4.12 * math.cos(theta)
        vz = 7.25 + 3.85 * math.sin(theta)
        ry = math.pi / 2 - theta
        col = "stoneDark" if k % 2 == 0 else "stone"
        p.append(L.box((1.44, 2.02, 1.12), (vx, 0, vz), col, bevel=0.07, rot=(0.0, ry, 0.0)))

    p.append(L.crystal(0.72, 2.25, (0, 0, 10.72), "ironDark", verts=4, spin=math.pi / 4))
    for sy in (-1, 1):
        p.append(L.ico(0.50, (0, sy * 0.88, 11.12), "eyeNeon", squash=(0.74, 0.45, 1.35)))

    # 5. Lente de vortice eliptica em camadas
    _vortex_lens(p, 5.20, "tealDark", "teal", "tealSwarm", "eyeNeon", rx=3.48, rz=1.24)

    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.25
        sx = 2.75 * math.cos(a)
        sz = 5.20 + 3.45 * math.sin(a)
        col = "eyeNeon" if k % 2 == 0 else "tealSwarm"
        for sy in (-1, 1):
            p.append(L.box((0.88, 0.12, 0.26), (sx, sy * 0.24, sz), col, rot=(0.0, -a + 0.24, 0.0)))

    return p


def portal_act1():
    """Ato 1 — Cinzas da Fronteira: portao de guerra em ferro cravejado, bigorna-chave, correntes e brasa."""
    p = []

    # 1. Plataforma escalonada de ferro e pedra chamuscada
    p.append(L.box((12.8, 4.6, 0.58), (0, 0, 0.29), "ironDark", bevel=0.08))
    p.append(L.box((11.0, 3.6, 0.44), (0, 0, 0.78), "stoneDark", bevel=0.06))
    p.append(L.cyl(3.25, 0.20, (0, 0, 0.94), "tarDeep", verts=10, r2=3.05))

    # 2. Braseiros laterais com chamas em ambar
    for sx in (-1, 1):
        bx = sx * 5.45
        p.append(L.cyl(0.68, 0.72, (bx, 0, 0.56), "ironDark", verts=6, r2=0.88))
        p.append(L.cyl(0.84, 0.22, (bx, 0, 1.24), "iron", verts=6, r2=0.92))
        p.append(L.crystal(0.46, 1.15, (bx, 0, 1.38), "ember", verts=5))
        p.append(L.crystal(0.28, 0.80, (bx, -0.18, 1.44), "neonAmber", tilt=(0.18, 0.0), verts=4))

    # 3. Pilares blindados com pontas de ferro e ombreiras de cerco
    for sx in (-1, 1):
        x = sx * 4.25
        p.append(L.box((2.15, 2.55, 1.20), (x, 0, 1.54), "ironDark", bevel=0.07))
        p.append(L.box((1.62, 2.05, 5.45), (x, 0, 4.78), "iron", bevel=0.06))
        for z in (2.95, 4.75, 6.55):
            p.append(L.box((1.88, 2.26, 0.34), (x, 0, z), "ironDark", bevel=0.04))
            p.append(L.crystal(0.26, 1.05, (x + sx * 0.85, 0, z), "steel", tilt=(0.0, sx * 1.12), verts=4))
            for sy in (-1, 1):
                p.append(L.box((0.52, 0.16, 0.24), (x, sy * 1.12, z), "amber"))
        # Ombreira de cerco + chifres de ferro
        p.append(L.box((2.35, 2.45, 1.15), (x + sx * 0.15, 0, 8.05), "ironDark", bevel=0.07))
        p.append(L.crystal(0.55, 2.65, (x + sx * 0.35, 0, 8.52), "steel", tilt=(0.0, sx * 0.24), verts=4, spin=math.pi / 4))
        p.append(L.crystal(0.36, 1.75, (x + sx * 0.92, 0, 8.20), "ironDark", tilt=(0.0, sx * 0.58), verts=4))

    # 4. Arco angular em trelica de ferro + pedra-chave em bigorna + correntes
    arch_specs = [
        (-3.20, 8.75, 0.42),
        (-1.65, 9.65, 0.20),
        (1.65, 9.65, -0.20),
        (3.20, 8.75, -0.42),
    ]
    for ax, az, ry in arch_specs:
        p.append(L.box((2.15, 2.10, 1.18), (ax, 0, az), "iron", bevel=0.06, rot=(0.0, ry, 0.0)))
        p.append(L.box((0.46, 2.24, 0.32), (ax, 0, az + 0.48), "amber", rot=(0.0, ry, 0.0)))

    # Bigorna-chave central + espigoes da coroa
    p.append(L.box((1.95, 2.28, 1.35), (0, 0, 10.15), "ironDark", bevel=0.07))
    p.append(L.box((2.65, 1.85, 0.72), (0, 0, 11.08), "iron", bevel=0.06))
    p.append(L.crystal(0.58, 2.15, (0, 0, 11.35), "steel", verts=4, spin=math.pi / 4))
    for sy in (-1, 1):
        p.append(L.box((0.88, 0.22, 0.88), (0, sy * 1.14, 10.18), "neonAmber", rot=(0.0, math.pi / 4, 0.0)))

    # Correntes internas pendendo do arco
    for sx in (-1, 1):
        for k in range(4):
            cz = 8.10 - k * 0.75
            rot_z = math.pi / 4 if k % 2 == 0 else -math.pi / 4
            p.append(L.box((0.28, 0.28, 0.62), (sx * 3.12, 0, cz), "ironDark", rot=(0.0, 0.0, rot_z)))

    # 5. Nucleo flamejante em ambar
    _vortex_lens(p, 5.15, "amber", "ember", "neonAmber", "amberBright", rx=3.18, rz=1.18)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.15
        for sy in (-1, 1):
            p.append(
                L.box(
                    (0.85, 0.14, 0.24),
                    (2.45 * math.cos(a), sy * 0.24, 5.15 + 3.05 * math.sin(a)),
                    "neonAmber",
                    rot=(0.0, -a + 0.2, 0.0),
                )
            )

    return p


def portal_act2():
    """Ato 2 — Forjas de Escoria: monolito de basalto serrilhado, cadinhos de magma e nucleo fundido."""
    p = []

    # 1. Base de basalto vulcanico + piscina de escoria incandescente
    p.append(L.box((12.8, 4.8, 0.58), (0, 0, 0.29), "tarDeep", bevel=0.08))
    p.append(L.box((10.8, 3.6, 0.45), (0, 0, 0.76), "stoneDark", bevel=0.07))
    p.append(L.cyl(3.25, 0.22, (0, 0, 0.92), "danger", verts=10, r2=3.0))

    # 2. Cadinhos gemeos de magma flanqueando o altar
    for sx in (-1, 1):
        cx = sx * 5.45
        p.append(L.cyl(1.02, 0.95, (cx, 0, 0.55), "stoneDark", verts=8, r2=0.86))
        p.append(L.cyl(1.12, 0.92, (cx, 0, 1.48), "ironDark", verts=8, r2=1.24))
        p.append(L.cyl(1.28, 0.24, (cx, 0, 2.38), "tarGlow", verts=8, r2=1.18))
        p.append(L.ico(0.88, (cx, 0, 2.65), "danger", squash=(1.0, 1.0, 0.65)))
        p.append(L.crystal(0.42, 1.35, (cx, 0, 2.88), "ember", verts=5))

    # 3. Pilares serrilhados de basalto em tambores com fendas de magma
    for sx in (-1, 1):
        x = sx * 4.22
        p.append(L.cyl(1.52, 1.15, (x, 0, 0.90), "tarDeep", verts=7, r2=1.32))
        for idx, z in enumerate((2.05, 3.55, 5.05, 6.55)):
            r1 = 1.28 - idx * 0.08
            r2 = r1 - 0.08
            p.append(L.cyl(r1, 1.28, (x, 0, z), "stoneDark", verts=7, r2=r2, rot_z=idx * 0.25))
            p.append(L.cyl(r2 * 0.96, 0.24, (x, 0, z + 1.24), "danger", verts=7, r2=r2 * 0.94))
            # Esporas serrilhadas laterais de basalto
            p.append(L.crystal(0.42, 1.45, (x + sx * 1.02, 0, z + 0.55), "tarDeep", tilt=(0.0, sx * 0.68), verts=5))
        # Chifres vulcanicos no topo dos pilares
        p.append(L.crystal(0.68, 2.95, (x + sx * 0.22, 0, 7.85), "tarDeep", tilt=(0.0, sx * 0.22), verts=5))
        p.append(L.crystal(0.44, 2.10, (x + sx * 0.85, 0, 7.72), "stoneDark", tilt=(0.0, sx * 0.52), verts=5))
        p.append(L.crystal(0.32, 1.35, (x + sx * 0.35, 0, 9.65), "ember", tilt=(0.0, sx * 0.18), verts=4))

    # 4. Coroa megalitica vulcanica com fenda de lava central
    for k in range(7):
        theta = 0.22 + (math.pi - 0.44) * k / 6
        vx = 4.05 * math.cos(theta)
        vz = 7.55 + 3.65 * math.sin(theta)
        ry = math.pi / 2 - theta
        col = "tarDeep" if k % 2 == 0 else "stoneDark"
        p.append(L.box((1.65, 2.15, 1.25), (vx, 0, vz), col, bevel=0.06, rot=(0.0, ry, 0.0)))
    p.append(L.crystal(0.78, 2.55, (0, 0, 11.05), "tarDeep", verts=5))
    for sy in (-1, 1):
        p.append(L.crystal(0.34, 1.25, (0, sy * 0.88, 11.15), "ember", tilt=(-sy * 0.22, 0.0), verts=4))

    # 5. Nucleo fundido
    _vortex_lens(p, 5.20, "tarDeep", "danger", "ember", "amberBright", rx=3.30, rz=1.20)
    for k in range(8):
        a = 2 * math.pi * k / 8
        for sy in (-1, 1):
            p.append(
                L.crystal(
                    0.22,
                    0.82,
                    (2.55 * math.cos(a), sy * 0.25, 5.20 + 3.15 * math.sin(a)),
                    "ember" if k % 2 == 0 else "danger",
                    tilt=(0.0, -a + math.pi / 2),
                    verts=4,
                )
            )

    return p


def portal_act3():
    """Ato 3 — Geada do Desfiladeiro: arco alto de espiras cristalinas de gelo e runas boreais."""
    p = []

    # 1. Altar glacial + disco de gelo espelhado
    p.append(L.box((12.4, 4.4, 0.55), (0, 0, 0.275), "stone", bevel=0.08))
    p.append(L.box((10.8, 3.4, 0.42), (0, 0, 0.72), "steel", bevel=0.06))
    p.append(L.cyl(3.30, 0.20, (0, 0, 0.88), "ice", verts=12, r2=3.10))

    # 2. Aglomerados de cristais de gelo nas extremidades do altar
    for sx in (-1, 1):
        p.append(L.crystal(0.58, 2.65, (sx * 5.25, -0.85, 0.48), "ice", tilt=(0.14, sx * 0.28), verts=5))
        p.append(L.crystal(0.46, 2.15, (sx * 5.55, 0.85, 0.48), "iceLight", tilt=(-0.14, sx * 0.34), verts=5))
        p.append(L.crystal(0.36, 1.55, (sx * 4.80, -1.65, 0.46), "iceGlow", tilt=(0.24, sx * 0.16), verts=4))
        p.append(L.crystal(0.34, 1.45, (sx * 4.80, 1.65, 0.46), "iceLight", tilt=(-0.24, sx * 0.16), verts=4))

    # 3. Pilares glaciais com contrafortes de cristal e altas espiras
    for sx in (-1, 1):
        x = sx * 4.20
        p.append(L.cyl(1.42, 1.05, (x, 0, 0.88), "steel", verts=6, r2=1.24))
        p.append(L.cyl(1.18, 5.55, (x, 0, 1.90), "stone", verts=6, r2=0.92))
        for z in (3.20, 4.85, 6.50):
            p.append(L.cyl(1.12, 0.20, (x, 0, z), "iceGlow", verts=6, r2=1.08))
            for sy in (-1, 1):
                p.append(L.crystal(0.24, 0.92, (x, sy * 0.96, z - 0.15), "iceLight", tilt=(-sy * 0.15, 0.0), verts=4))
        # Espiras altas assimetricas de gelo (ate ~13.8 studs)
        p.append(L.crystal(0.68, 5.45, (x + sx * 0.18, 0, 7.35), "iceLight", tilt=(0.0, sx * 0.08), verts=5))
        p.append(L.crystal(0.48, 3.65, (x + sx * 0.78, 0, 7.25), "ice", tilt=(0.0, sx * 0.26), verts=5))
        p.append(L.crystal(0.32, 2.25, (x - sx * 0.35, 0, 7.65), "iceGlow", tilt=(0.0, -sx * 0.06), verts=4))

    # 4. Arco ogival pontiagudo de gelo + prisma central suspenso
    arch_left = [(-3.45, 7.95, 0.52), (-2.15, 9.45, 0.68), (-0.95, 10.65, 0.82)]
    for ax, az, ry in arch_left:
        for sx in (-1, 1):
            p.append(L.box((1.65, 1.85, 0.98), (sx * abs(ax), 0, az), "steel", bevel=0.06, rot=(0.0, -sx * ry, 0.0)))
            p.append(L.crystal(0.32, 1.25, (sx * abs(ax), 0, az + 0.38), "iceLight", tilt=(0.0, sx * 0.22), verts=4))

    # Cristal central em diamante no apice
    p.append(L.crystal(0.75, 2.65, (0, 0, 11.15), "iceGlow", verts=4, spin=math.pi / 4))
    p.append(L.crystal(0.55, 1.55, (0, 0, 11.20), "ice", tilt=(math.pi, 0.0), verts=4, spin=math.pi / 4))

    # 5. Lente boreal
    _vortex_lens(p, 5.30, "tealDark", "ice", "iceLight", "iceGlow", rx=3.35, rz=1.26)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        for sy in (-1, 1):
            p.append(
                L.crystal(
                    0.18,
                    0.75,
                    (2.55 * math.cos(a), sy * 0.22, 5.30 + 3.25 * math.sin(a)),
                    "iceGlow",
                    tilt=(0.0, -a + math.pi / 2),
                    verts=4,
                )
            )

    return p


def portal_act4():
    """Ato 4 — Polvora e Trincheira: bunker blindado em bronze e gunmetal, chamines e arco rebitado."""
    p = []

    # 1. Plataforma fortificada com borda de bronze
    p.append(L.box((12.8, 4.6, 0.58), (0, 0, 0.29), "ironDark", bevel=0.08))
    p.append(L.box((11.2, 3.6, 0.44), (0, 0, 0.78), "iron", bevel=0.06))
    p.append(L.cyl(3.25, 0.20, (0, 0, 0.94), "bronze", verts=10, r2=3.05))

    # 2. Chamines gemeas de artilharia nos flancos externos
    for sx in (-1, 1):
        cx = sx * 5.35
        p.append(L.box((1.65, 2.05, 1.45), (cx, 0, 1.25), "ironDark"))
        p.append(L.cyl(0.68, 8.85, (cx, 0, 1.95), "ironDark", verts=8, r2=0.58))
        for bz in (4.2, 7.2, 9.8):
            p.append(L.cyl(0.74, 0.28, (cx, 0, bz), "bronze", verts=8, r2=0.74))
        p.append(L.cyl(0.78, 0.55, (cx, 0, 10.75), "steel", verts=8, r2=0.64))

    # 3. Pilares blindados de casamata com rebites e placas de bronze
    for sx in (-1, 1):
        x = sx * 4.10
        p.append(L.box((2.10, 2.65, 1.25), (x, 0, 1.56), "ironDark"))
        p.append(L.box((1.68, 2.20, 5.65), (x, 0, 4.95), "iron"))
        for z in (2.85, 4.75, 6.65):
            p.append(L.box((1.84, 2.38, 0.34), (x, 0, z), "bronze"))
            if z != 4.75:
                for sy in (-1, 1):
                    p.append(L.box((0.24, 0.16, 0.24), (x, sy * 1.16, z + 0.72), "steel"))
        p.append(L.box((2.12, 2.48, 1.05), (x, 0, 8.18), "ironDark"))

    # 4. Arco industrial rebitado + engrenagem frontal em bronze no apice
    for k in range(7):
        theta = 0.20 + (math.pi - 0.40) * k / 6
        vx = 3.95 * math.cos(theta)
        vz = 7.75 + 3.15 * math.sin(theta)
        ry = math.pi / 2 - theta
        col = "iron" if k % 2 == 0 else "bronze"
        p.append(L.box((1.55, 2.15, 1.08), (vx, 0, vz), col, rot=(0.0, ry, 0.0)))

    # Coroa industrial + roda dentada em bronze enfrentando -Y/+Y
    p.append(L.box((2.60, 2.30, 1.25), (0, 0, 11.15), "ironDark"))
    p.append(L.cyl_axis(1.32, 2.48, (0, 0, 11.45), "bronze", axis="y", verts=10))
    for k in range(8):
        a = 2 * math.pi * k / 8
        tx = 1.48 * math.cos(a)
        tz = 11.45 + 1.48 * math.sin(a)
        p.append(L.box((0.36, 2.40, 0.38), (tx, 0, tz), "goldBright", rot=(0.0, -a, 0.0)))
    for sy in (-1, 1):
        p.append(L.ico(0.48, (0, sy * 1.26, 11.45), "amberBright", squash=(0.95, 0.45, 0.95)))

    # 5. Nucleo de polvora e enxofre dourado
    _vortex_lens(p, 5.20, "tarDeep", "bronze", "goldBright", "amberBright", rx=3.15, rz=1.18)

    return p


def portal_act5():
    """Ato 5 — A Fenda Profunda: monolito monumental com obeliscos guardioes e lintel abissal."""
    p = []

    # 1. Altar monumental de 3 degraus
    p.append(L.box((13.4, 5.0, 0.58), (0, 0, 0.29), "ironDark", bevel=0.08))
    p.append(L.box((11.6, 3.8, 0.48), (0, 0, 0.80), "stoneDark", bevel=0.07))
    p.append(L.box((9.8, 3.0, 0.36), (0, 0, 1.20), "stone", bevel=0.05))
    p.append(L.cyl(3.25, 0.20, (0, 0, 1.32), "tealDark", verts=12, r2=3.05))

    # 2. Obeliscos guardioes escalonados nas extremidades (inspirados no concept do Ato 5)
    for sx in (-1, 1):
        ox = sx * 5.60
        p.append(L.box((1.75, 2.15, 1.25), (ox, 0, 1.15), "ironDark", bevel=0.06))
        p.append(L.cyl(0.98, 7.25, (ox, 0, 1.78), "stoneDark", verts=4, r2=0.56, rot_z=math.pi / 4))
        p.append(L.crystal(0.56, 2.15, (ox, 0, 9.02), "ironDark", verts=4, spin=math.pi / 4))
        for rz in (3.4, 5.6, 7.6):
            s = 1.48 - (rz - 3.4) * 0.12
            p.append(L.box((s, s, 0.24), (ox, 0, rz), "tealSwarm"))
        p.append(L.ico(0.32, (ox, 0, 11.05), "eyeNeon", squash=(0.75, 0.75, 1.35)))

    # 3. Pilares principais macicos com canais de fenda esmeralda
    for sx in (-1, 1):
        x = sx * 3.88
        p.append(L.box((2.15, 2.65, 1.35), (x, 0, 1.95), "ironDark", bevel=0.07))
        p.append(L.box((1.72, 2.18, 6.25), (x, 0, 5.70), "stoneDark", bevel=0.06))
        for sy in (-1, 1):
            p.append(L.box((0.36, 0.18, 5.45), (x, sy * 1.10, 5.70), "teal"))
            p.append(L.box((0.18, 0.22, 4.65), (x, sy * 1.14, 5.70), "eyeNeon"))
        p.append(L.box((2.25, 2.55, 0.95), (x, 0, 9.15), "ironDark", bevel=0.06))

    # 4. Lintel monumental em arco escalonado + coroa de obsidiana e olho espectral
    p.append(L.box((9.85, 2.45, 1.25), (0, 0, 10.15), "ironDark", bevel=0.07))
    p.append(L.box((7.45, 2.15, 0.95), (0, 0, 11.18), "stoneDark", bevel=0.06))
    p.append(L.box((4.45, 1.85, 0.85), (0, 0, 12.02), "ironDark", bevel=0.06))
    p.append(L.crystal(0.75, 2.15, (0, 0, 12.38), "stoneDark", verts=4, spin=math.pi / 4))
    for sx in (-1, 1):
        p.append(L.crystal(0.55, 2.45, (sx * 4.25, 0, 10.55), "ironDark", tilt=(0.0, sx * 0.24), verts=4, spin=math.pi / 4))
    for sy in (-1, 1):
        p.append(L.box((1.85, 0.24, 0.42), (0, sy * 1.12, 11.18), "tealSwarm"))
        p.append(L.ico(0.58, (0, sy * 1.05, 12.05), "eyeNeon", squash=(0.74, 0.42, 1.38)))

    # 5. Portal abissal profundo
    _vortex_lens(p, 5.55, "tealDark", "teal", "tealSwarm", "eyeNeon", rx=3.18, rz=1.24)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.3
        for sy in (-1, 1):
            p.append(
                L.box(
                    (0.78, 0.14, 0.24),
                    (2.42 * math.cos(a), sy * 0.24, 5.55 + 3.05 * math.sin(a)),
                    "eyeNeon" if k % 2 == 0 else "tealSwarm",
                    rot=(0.0, -a + 0.25, 0.0),
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
            "tags": ["muralha", "portal", "rift"],
            "build": portal,
        },
        {
            "id": "portal.act1_iron.01",
            "name": "PORTAL_act1",
            "glb": "portal_act1_iron.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "tags": ["muralha", "portal", "campaign", "act1"],
            "build": portal_act1,
        },
        {
            "id": "portal.act2_slag.01",
            "name": "PORTAL_act2",
            "glb": "portal_act2_slag.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "tags": ["muralha", "portal", "campaign", "act2"],
            "build": portal_act2,
        },
        {
            "id": "portal.act3_frost.01",
            "name": "PORTAL_act3",
            "glb": "portal_act3_frost.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "tags": ["muralha", "portal", "campaign", "act3"],
            "build": portal_act3,
        },
        {
            "id": "portal.act4_powder.01",
            "name": "PORTAL_act4",
            "glb": "portal_act4_powder.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "tags": ["muralha", "portal", "campaign", "act4"],
            "build": portal_act4,
        },
        {
            "id": "portal.act5_rift.01",
            "name": "PORTAL_act5",
            "glb": "portal_act5_rift.glb",
            "tipo": "modulo_cenario",
            "limite": LIMITE,
            "tags": ["muralha", "portal", "campaign", "act5"],
            "build": portal_act5,
        },
    ],
    "portal da fenda + 5 portais monumentais da campanha (art/scripts/make_portal.py)",
)
