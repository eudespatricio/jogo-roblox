"""Gera o portal da fenda (PROP_rift_portal): arco gotico/arcano em obsidiana esculpida,
colunas octogonais com runas, chifres/espiras de obsidiana e lente de vortice eliptica em
tons frios (obsidian, ironDark, stoneDark, teal, tealSwarm, eyeNeon — zero amarelo/ember).

Frente no Blender = -Y (simetrico em -Y/+Y para vista dupla Build e Raid), largura ao longo de X.

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_portal.py
Saidas: art/export/prop_rift_portal.glb, art/forge/lote_portal_import.yaml (gerado),
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
        # Pedestal + colarinho runico
        p.append(L.cyl(1.48, 1.12, (x, 0, 0.88), "ironDark", verts=8, r2=1.28))
        p.append(L.cyl(1.34, 0.22, (x, 0, 1.98), "tealSwarm", verts=8, r2=1.30))
        # Fuste octogonal afunilado
        p.append(L.cyl(1.22, 5.30, (x, 0, 2.18), "stoneDark", verts=8, r2=1.00))
        # Aneis e fragmentos de runas nas duas faces (-Y e +Y)
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
        # Capitel octogonal alargado
        p.append(L.cyl(1.02, 0.72, (x, 0, 7.46), "ironDark", verts=8, r2=1.36))
        # Espiras curvas em chifre de obsidiana + orbe arcano frio (zero amarelo!)
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

    # Crista central do arco + gema runica bi-facial
    p.append(L.crystal(0.72, 2.25, (0, 0, 10.72), "ironDark", verts=4, spin=math.pi / 4))
    for sy in (-1, 1):
        p.append(L.ico(0.50, (0, sy * 0.88, 11.12), "eyeNeon", squash=(0.74, 0.45, 1.35)))

    # 5. Lente de vortice eliptica em camadas (cada anel interno mais espesso em Y para nao ser coberto!)
    p.append(L.ball(3.48, (0, 0, 5.20), "tealDark", seg=14, rings=7, squash=(0.94, 0.05, 1.24)))
    p.append(L.ball(2.74, (0, 0, 5.20), "teal", seg=12, rings=6, squash=(0.91, 0.10, 1.20)))
    p.append(L.ball(1.92, (0, 0, 5.20), "tealSwarm", seg=10, rings=6, squash=(0.88, 0.19, 1.16)))
    p.append(L.ico(0.95, (0, 0, 5.20), "eyeNeon", squash=(0.84, 0.42, 1.24)))

    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.25
        sx = 2.75 * math.cos(a)
        sz = 5.20 + 3.45 * math.sin(a)
        col = "eyeNeon" if k % 2 == 0 else "tealSwarm"
        for sy in (-1, 1):
            p.append(L.box((0.88, 0.12, 0.26), (sx, sy * 0.24, sz), col, rot=(0.0, -a + 0.24, 0.0)))

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
        }
    ],
    "portal da fenda gotico-arcano esculpido (art/scripts/make_portal.py)",
)
