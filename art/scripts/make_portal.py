"""Gera o portal da fenda (PROP_rift_portal) e os 5 portais monumentais da campanha
(PORTAL_act1..PORTAL_act5) para a esteira Blender -> Forge3D 0.9.0 (stylized_pbr hero) -> Open Cloud.

Frente no Blender = -Y (simetrico em -Y/+Y para vista dupla Build e Raid), largura ao longo de X,
base normalizada em Z=0, altura ~13-14.6 studs, alvo 8.000-11.500 tris por malha (LIMITE = 12000).

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_portal.py
Saidas: art/export/*.glb, art/forge/lote_portal_import.yaml (gerado, spec@6 hero PBR),
        art/renders/portal/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 12000  # alvo AA hero 8.000-11.500 tris por portal (teto 12.000)
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
    """Lente eliptica suave em camadas de alta densidade + aneis toroidais e nodos de contencao."""
    r_col = ring_col or inner_col
    p.append(L.ball(rx, (0, 0, center_z), outer_col, seg=26, rings=14, squash=(0.94, 0.05, rz)))
    p.append(L.ball(rx * 0.78, (0, 0, center_z), mid_col, seg=18, rings=10, squash=(0.91, 0.11, rz * 0.97)))
    p.append(L.ball(rx * 0.54, (0, 0, center_z), inner_col, seg=14, rings=8, squash=(0.88, 0.20, rz * 0.93)))
    p.append(L.ico(rx * 0.28, (0, 0, center_z), core_col, squash=(0.84, 0.44, rz), subdiv=2))
    # Anel toroidal primario de contencao
    p.append(
        L.torus(
            rx * 0.90,
            0.135,
            (0, 0, center_z),
            r_col,
            major_seg=26,
            minor_seg=8,
            rot=(math.pi / 2, 0.0, 0.0),
            squash=(0.98, rz * 1.03, 1.25),
        )
    )
    # Segundo anel harmonico interno
    p.append(
        L.torus(
            rx * 0.66,
            0.085,
            (0, 0, center_z),
            core_col,
            major_seg=20,
            minor_seg=6,
            rot=(math.pi / 2, 0.0, 0.0),
            squash=(0.96, rz * 0.98, 1.40),
        )
    )
    # 8 garras/nodos energeticos radiais ancorando o vortice
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        nx = rx * 0.88 * math.cos(a)
        nz = center_z + rx * 0.88 * rz * math.sin(a)
        p.append(
            L.box(
                (0.28, 0.38, 0.22),
                (nx, 0.0, nz),
                outer_col,
                rot=(0.0, -a, 0.0),
            )
        )
        for sy in (-1, 1):
            p.append(
                L.ball(
                    0.11,
                    (nx, sy * 0.20, nz),
                    core_col if k % 2 == 0 else r_col,
                    seg=6,
                    rings=4,
                )
            )


def _altar_steps(p, base_w, base_d, col1, col2, col3, dais_col, rune_col=None):
    """Altar monumental esculpido em 3 patamares chanfrados, escadarias em blocos, guarda-corpos e disco ritual."""
    r_col = rune_col or dais_col
    # Plinto ciclópico em 3 camadas chanfradas
    p.append(L.box((base_w, base_d, 0.42), (0, 0, 0.21), col1, bevel=0.07))
    p.append(L.box((base_w - 1.10, base_d - 0.64, 0.36), (0, 0, 0.58), col2, bevel=0.06))
    p.append(L.box((base_w - 2.30, base_d - 1.32, 0.30), (0, 0, 0.90), col3, bevel=0.05))

    # Ladrilhos de cantaria nas extremidades laterais do altar
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(
                L.box(
                    (1.12, 0.88, 0.68),
                    (sx * (base_w * 0.5 - 0.62), sy * (base_d * 0.5 - 0.48), 0.38),
                    col3,
                    bevel=0.05,
                )
            )
            p.append(
                L.cyl(
                    0.36,
                    0.82,
                    (sx * (base_w * 0.5 - 0.62), sy * (base_d * 0.5 - 0.48), 0.12),
                    col1,
                    verts=10,
                    r2=0.30,
                )
            )
            p.append(
                L.torus(
                    0.34,
                    0.05,
                    (sx * (base_w * 0.5 - 0.62), sy * (base_d * 0.5 - 0.48), 0.86),
                    r_col,
                    major_seg=10,
                    minor_seg=4,
                )
            )

    # Escadarias monumentais frontais (-Y) e traseiras (+Y) com degraus individuais e muretas laterais
    for sy in (-1, 1):
        for step_idx, (sw, sd, sh, dy, dz, scol) in enumerate(
            (
                (6.2, 0.62, 0.24, base_d * 0.5 + 0.36, 0.12, col1),
                (5.4, 0.58, 0.26, base_d * 0.5 + 0.02, 0.35, col2),
                (4.6, 0.52, 0.26, base_d * 0.5 - 0.32, 0.60, col3),
            )
        ):
            p.append(L.box((sw, sd, sh), (0, sy * dy, dz), scol, bevel=0.04))
            # Juntas de blocos esculpidos sobre o degrau
            for bx in (-1.85, -0.62, 0.62, 1.85):
                p.append(
                    L.box(
                        (0.96, sd * 0.86, 0.08),
                        (bx, sy * dy, dz + sh * 0.5 + 0.02),
                        col3 if step_idx % 2 == 0 else col2,
                    )
                )
        # Muretas (stringers) flanqueando os degraus com pinaculos runicos
        for sx in (-1, 1):
            p.append(
                L.box(
                    (0.56, 1.42, 0.62),
                    (sx * 3.18, sy * (base_d * 0.5 + 0.04), 0.34),
                    col1,
                    bevel=0.05,
                )
            )
            p.append(
                L.crystal(
                    0.22,
                    0.58,
                    (sx * 3.18, sy * (base_d * 0.5 + 0.32), 0.64),
                    r_col,
                    verts=5,
                )
            )
        # Runas entalhadas luminosas nos espelhos dos degraus
        for rx in (-2.05, -1.02, 0.0, 1.02, 2.05):
            p.append(L.box((0.62, 0.18, 0.11), (rx, sy * (base_d * 0.5 + 0.42), 0.26), r_col))
            p.append(L.box((0.48, 0.16, 0.10), (rx * 0.84, sy * (base_d * 0.5 + 0.08), 0.50), r_col))

    # Disco ritual central escalonado com anel toroidal gravado e 8 tabletes runicos
    p.append(L.cyl(3.48, 0.20, (0, 0, 0.96), dais_col, verts=22, r2=3.26))
    p.append(L.cyl(2.86, 0.14, (0, 0, 1.12), col2, verts=20, r2=2.72))
    p.append(L.torus(3.22, 0.075, (0, 0, 1.14), r_col, major_seg=22, minor_seg=5))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(
            L.box(
                (0.46, 0.24, 0.12),
                (2.96 * math.cos(a), 2.96 * math.sin(a), 1.18),
                r_col,
                rot=(0.0, 0.0, a),
            )
        )


def _pillar_rune_carvings(p, x: float, r_col: float, z_vals: tuple[float, ...], frame_col: str, glow_col: str):
    """Entalhes runicos esculpidos em baixo-relevo nas faces -Y/+Y e flancos externos das colunas."""
    sx = 1.0 if x >= 0 else -1.0
    for z in z_vals:
        for sy in (-1, 1):
            y_pos = sy * (r_col + 0.04)
            p.append(L.box((0.58, 0.16, 0.76), (x, y_pos, z), frame_col, bevel=0.035))
            p.append(L.box((0.22, 0.20, 0.52), (x, y_pos + sy * 0.02, z), glow_col))
            p.append(L.box((0.40, 0.20, 0.14), (x, y_pos + sy * 0.02, z + 0.12), glow_col))
            p.append(L.box((0.36, 0.20, 0.12), (x, y_pos + sy * 0.02, z - 0.14), glow_col))
        # Cartucho runico tambem no flanco externo (sx)
        x_flank = x + sx * (r_col + 0.04)
        p.append(L.box((0.16, 0.56, 0.72), (x_flank, 0.0, z), frame_col, bevel=0.035))
        p.append(L.box((0.20, 0.20, 0.48), (x_flank + sx * 0.02, 0.0, z), glow_col))
        p.append(L.box((0.20, 0.38, 0.14), (x_flank + sx * 0.02, 0.0, z), glow_col))


def _hanging_chain(p, x0: float, y0: float, z0: float, n_links: int, col1: str, col2: str, step_z: float = 0.52, tip_col: str | None = None):
    """Corrente monumental de elos toroidais alternados pendendo de (x0, y0, z0)."""
    for k in range(n_links):
        cz = z0 - k * step_z
        rot = (math.pi / 2, 0.0, 0.0) if k % 2 == 0 else (0.0, math.pi / 2, 0.0)
        p.append(
            L.torus(
                0.24,
                0.062,
                (x0, y0, cz),
                col1 if k % 2 == 0 else col2,
                major_seg=10,
                minor_seg=4,
                rot=rot,
                squash=(0.78, 1.25, 1.0),
            )
        )
    if tip_col:
        end_z = z0 - n_links * step_z - 0.18
        p.append(L.crystal(0.24, 0.68, (x0, y0, end_z + 0.34), tip_col, tilt=(math.pi, 0.0), verts=5))


def portal():
    """PROP_rift_portal — arco de obsidiana arcana em camadas + aneis toroidais de vortice + cristais."""
    p = []

    # 1. Altar escalonado chanfrado de obsidiana + disco ritual arcano + runas de degrau
    _altar_steps(p, 12.6, 4.5, "obsidian", "obsidianLight", "stoneDark", "tealDark", rune_col="arcaneCyan")

    # 2. Aglomerados densos de cristais arcanos e obeliscos ancorados flanqueando o altar
    for sx in (-1, 1):
        p.append(L.crystal(0.56, 2.55, (sx * 5.25, -0.95, 0.48), "tealSwarm", tilt=(0.15, sx * 0.26), verts=6))
        p.append(L.crystal(0.46, 2.05, (sx * 5.45, 0.95, 0.48), "arcaneCyan", tilt=(-0.15, sx * 0.28), verts=6))
        p.append(L.crystal(0.38, 1.65, (sx * 4.82, -1.68, 0.46), "eyeNeon", tilt=(0.24, sx * 0.15), verts=5))
        p.append(L.crystal(0.36, 1.55, (sx * 4.82, 1.68, 0.46), "arcaneViolet", tilt=(-0.22, sx * 0.15), verts=5))
        p.append(L.crystal(0.32, 1.40, (sx * 5.75, 0.0, 0.52), "teal", tilt=(0.0, sx * 0.38), verts=5))
        for sy in (-1, 1):
            p.append(
                L.box(
                    (1.18, 0.96, 0.64),
                    (sx * 5.78, sy * 1.92, 0.34),
                    "obsidian" if sy < 0 else "obsidianLight",
                    bevel=0.05,
                    rot=(0.12 * sy, sx * 0.18, 0.28 * sy),
                )
            )
            p.append(
                L.torus(
                    0.48,
                    0.06,
                    (sx * 5.28, sy * 0.95, 1.05),
                    "arcaneViolet",
                    major_seg=12,
                    minor_seg=4,
                    rot=(0.18 * sy, sx * 0.22, 0.0),
                )
            )

    # 3. Colunas afuniladas de 24 lados em obsidiana com aneis runicos, caneluras, entalhes e espiras gemeas
    for sx in (-1, 1):
        x = sx * 4.15
        p.append(L.cyl(1.56, 1.18, (x, 0, 0.88), "obsidian", verts=24, r2=1.32))
        p.append(L.torus(1.38, 0.085, (x, 0, 1.96), "tealSwarm", major_seg=18, minor_seg=5))
        p.append(L.cyl(1.24, 5.35, (x, 0, 2.12), "obsidianLight", verts=24, r2=1.00))
        # Nervuras verticais de obsidiana ao redor do fuste
        for k in range(4):
            ang = 2 * math.pi * k / 4 + math.pi / 4
            rx_rib = x + 1.12 * math.cos(ang)
            ry_rib = 1.12 * math.sin(ang)
            p.append(L.box((0.18, 0.22, 4.95), (rx_rib, ry_rib, 4.78), "obsidian", rot=(0.0, 0.0, ang)))
        _pillar_rune_carvings(p, x, 1.14, (2.95, 4.75, 6.55), "obsidian", "arcaneCyan")
        for z in (3.85, 5.75):
            rz = 1.18 - (z - 3.60) * 0.042
            p.append(L.torus(rz + 0.06, 0.075, (x, 0, z), "arcaneCyan", major_seg=18, minor_seg=5))
            for sy in (-1, 1):
                p.append(
                    L.crystal(
                        0.22,
                        0.76,
                        (x, sy * (rz * 0.92), z - 0.22),
                        "eyeNeon",
                        tilt=(-sy * 0.14, 0.0),
                        verts=5,
                    )
                )
        # Capitel escalonado + espiras gemeas + orbe runico suspenso
        p.append(L.cyl(1.04, 0.80, (x, 0, 7.42), "obsidian", verts=24, r2=1.42))
        p.append(L.torus(1.36, 0.08, (x, 0, 8.15), "arcaneViolet", major_seg=18, minor_seg=5))
        p.append(L.crystal(0.60, 2.75, (x + sx * 0.26, 0, 8.18), "obsidian", tilt=(0.0, sx * 0.28), verts=6))
        p.append(L.crystal(0.44, 2.02, (x + sx * 0.76, 0, 8.06), "obsidianLight", tilt=(0.0, sx * 0.52), verts=5))
        p.append(L.crystal(0.32, 1.48, (x - sx * 0.25, 0, 8.22), "arcaneCyan", tilt=(0.0, -sx * 0.16), verts=5))
        p.append(L.ico(0.44, (x + sx * 0.48, 0, 9.58), "eyeNeon", squash=(0.82, 0.82, 1.38), subdiv=1))
        _hanging_chain(p, x - sx * 0.92, 0.0, 7.85, 4, "obsidian", "arcaneViolet", step_z=0.50, tip_col="arcaneCyan")

    # 4. Arco arcano de obsidiana em camadas (11 aduelas chanfradas + crista dorsal + entalhes runicos + pedra-chave)
    n_arch = 11
    for k in range(n_arch):
        theta = 0.15 + (math.pi - 0.30) * k / (n_arch - 1)
        vx = 4.12 * math.cos(theta)
        vz = 7.25 + 3.86 * math.sin(theta)
        ry = math.pi / 2 - theta
        is_key = k == n_arch // 2
        col = "arcaneViolet" if is_key else ("obsidian" if k % 2 == 0 else "obsidianLight")
        p.append(L.box((1.22, 2.06, 1.16), (vx, 0, vz), col, bevel=0.06, rot=(0.0, ry, 0.0)))
        for sy in (-1, 1):
            p.append(
                L.box(
                    (0.46, 0.16, 0.38),
                    (vx, sy * 1.06, vz),
                    "eyeNeon" if is_key else "arcaneCyan",
                    rot=(0.0, ry, 0.0),
                )
            )
        if k % 2 == 1:
            ox = 4.64 * math.cos(theta)
            oz = 7.25 + 4.36 * math.sin(theta)
            p.append(L.box((0.86, 1.46, 0.54), (ox, 0, oz), "obsidian", bevel=0.04, rot=(0.0, ry, 0.0)))
            p.append(L.crystal(0.30, 1.15, (ox, 0, oz + 0.18), "arcaneViolet", tilt=(0.0, ry), verts=5))

    # Coroa da pedra-chave com cristal mestre e halo duplo
    p.append(L.crystal(0.78, 2.40, (0, 0, 10.75), "obsidian", verts=6, spin=math.pi / 6))
    p.append(L.torus(0.92, 0.075, (0, 0, 11.45), "arcaneCyan", major_seg=16, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    for sx in (-1, 1):
        p.append(L.crystal(0.38, 1.48, (sx * 0.82, 0, 11.05), "tealSwarm", tilt=(0.0, sx * 0.34), verts=5))
    for sy in (-1, 1):
        p.append(L.ico(0.48, (0, sy * 0.94, 11.12), "eyeNeon", squash=(0.74, 0.45, 1.35), subdiv=1))

    # 5. Lente de vortice + aneis toroidais cruzados de energia arcana
    _vortex_lens(p, 5.20, "tealDark", "teal", "tealSwarm", "eyeNeon", ring_col="arcaneCyan", rx=3.46, rz=1.24)
    p.append(
        L.torus(
            2.76,
            0.095,
            (0, 0, 5.20),
            "arcaneViolet",
            major_seg=20,
            minor_seg=6,
            rot=(math.pi / 2 + 0.16, 0.14, 0.0),
            squash=(0.96, 1.22, 1.30),
        )
    )

    return p


def portal_act1():
    """Ato 1 — Cinzas da Fronteira: bigorna-chave forjada, pilares espinhados chanfrados, correntes toroidais e brasa."""
    p = []

    # 1. Plataforma escalonada de ferro e pedra chamuscada
    _altar_steps(p, 12.8, 4.6, "ironDark", "stoneDark", "iron", "tarDeep", rune_col="emberDeep")

    # 2. Braseiros pesados de cerco nas laterais (verts=16) com garras, aros de bronze, brasas e chamas esculpidas
    for sx in (-1, 1):
        bx = sx * 5.45
        p.append(L.cyl(0.84, 0.36, (bx, 0, 0.42), "stoneDark", verts=16, r2=0.76))
        p.append(L.cyl(0.72, 0.74, (bx, 0, 0.72), "ironDark", verts=16, r2=0.96))
        p.append(L.torus(0.96, 0.075, (bx, 0, 1.38), "bronze", major_seg=16, minor_seg=5))
        p.append(L.torus(0.78, 0.06, (bx, 0, 0.92), "iron", major_seg=14, minor_seg=4))
        for k in range(4):
            ca, sa = math.cos(k * math.pi / 2 + math.pi / 4), math.sin(k * math.pi / 2 + math.pi / 4)
            p.append(
                L.box(
                    (0.22, 0.28, 0.78),
                    (bx + 0.84 * ca, 0.84 * sa, 1.02),
                    "bronze",
                    rot=(0.0, 0.0, k * math.pi / 2 + math.pi / 4),
                )
            )
        p.append(L.ico(0.68, (bx, 0, 1.44), "danger", squash=(1.05, 1.05, 0.42), subdiv=1))
        p.append(L.crystal(0.48, 1.35, (bx, 0, 1.46), "emberDeep", verts=6))
        p.append(L.crystal(0.34, 1.04, (bx, -0.18, 1.50), "ember", tilt=(0.18, 0.0), verts=5))
        p.append(L.crystal(0.26, 0.86, (bx, 0.18, 1.54), "neonAmber", tilt=(-0.18, 0.0), verts=5))

    # 3. Colunas afuniladas (verts=22) revestidas por colares blindados chanfrados, rebites, entalhes em brasa e espigoes
    for sx in (-1, 1):
        x = sx * 4.25
        p.append(L.box((2.24, 2.64, 1.18), (x, 0, 1.48), "ironDark", bevel=0.07))
        p.append(L.cyl(1.20, 5.55, (x, 0, 2.05), "iron", verts=22, r2=1.00))
        _pillar_rune_carvings(p, x, 1.10, (2.75, 4.55, 6.35), "ironDark", "ember")
        for z in (3.55, 5.45):
            p.append(L.box((1.96, 2.34, 0.44), (x, 0, z), "ironDark", bevel=0.05))
            p.append(L.crystal(0.32, 1.24, (x + sx * 0.92, 0, z), "steel", tilt=(0.0, sx * 1.15), verts=5))
            p.append(L.crystal(0.24, 0.88, (x - sx * 0.86, 0, z), "iron", tilt=(0.0, -sx * 1.10), verts=5))
            for sy in (-1, 1):
                p.append(L.box((0.58, 0.18, 0.24), (x, sy * 1.16, z), "emberDeep"))
                for rx in (-0.64, -0.22, 0.22, 0.64):
                    p.append(L.ball(0.085, (x + rx, sy * 1.18, z), "bronze", seg=6, rings=3))
        # Ombreira de cerco chanfrada + chifres de aco
        p.append(L.box((2.40, 2.52, 1.18), (x + sx * 0.15, 0, 8.05), "ironDark", bevel=0.07))
        p.append(L.crystal(0.56, 2.68, (x + sx * 0.36, 0, 8.52), "steel", tilt=(0.0, sx * 0.24), verts=5))
        p.append(L.crystal(0.38, 1.80, (x + sx * 0.94, 0, 8.20), "iron", tilt=(0.0, sx * 0.58), verts=5))
        p.append(L.crystal(0.30, 1.35, (x - sx * 0.32, 0, 8.40), "bronze", tilt=(0.0, -sx * 0.20), verts=5))

    # 4. Arco blindado chanfrado (6 aduelas forjadas) + nervuras cravadas + Pedra-Chave em Bigorna de Guerra
    arch_segs = (
        (-3.45, 8.52, 0.48),
        (-2.60, 9.18, 0.34),
        (-1.68, 9.68, 0.18),
        (1.68, 9.68, -0.18),
        (2.60, 9.18, -0.34),
        (3.45, 8.52, -0.48),
    )
    for idx, (ax, az, ry) in enumerate(arch_segs):
        p.append(L.box((1.42, 2.14, 1.18), (ax, 0, az), "iron" if idx % 2 == 0 else "ironDark", bevel=0.06, rot=(0.0, ry, 0.0)))
        p.append(L.box((0.46, 2.28, 0.36), (ax, 0, az + 0.48), "bronze", rot=(0.0, ry, 0.0)))
        p.append(L.crystal(0.24, 0.92, (ax, 0, az + 0.64), "steel", tilt=(0.0, ry), verts=5))
        for sy in (-1, 1):
            p.append(L.box((0.62, 0.16, 0.32), (ax, sy * 1.09, az), "emberDeep", rot=(0.0, ry, 0.0)))

    # Bigorna de Guerra central no apice (base, cintura acinturada, mesa larga + chifre lateral de bigorna)
    p.append(L.box((2.16, 2.38, 0.64), (0, 0, 9.88), "ironDark", bevel=0.06))
    p.append(L.box((1.52, 2.00, 0.70), (0, 0, 10.48), "ironDark", bevel=0.05))
    p.append(L.box((3.10, 2.16, 0.78), (0, 0, 11.12), "steel", bevel=0.06))
    p.append(L.torus(0.96, 0.08, (0, 0, 11.52), "bronze", major_seg=16, minor_seg=5))
    for sx in (-1, 1):
        p.append(L.crystal(0.44, 1.24, (sx * 1.50, 0, 11.14), "steel", tilt=(0.0, sx * 1.42), verts=5))
        p.append(L.crystal(0.32, 1.15, (sx * 0.88, 0, 11.46), "emberDeep", tilt=(0.0, sx * 0.28), verts=5))
    p.append(L.crystal(0.54, 1.98, (0, 0, 11.48), "ironDark", verts=6))
    for sy in (-1, 1):
        p.append(L.box((0.88, 0.24, 0.88), (0, sy * 1.10, 10.48), "neonAmber", rot=(0.0, math.pi / 4, 0.0)))

    # Correntes de cerco em elos toroidais suaves pendendo do arco e dos pilares
    for sx in (-1, 1):
        _hanging_chain(p, sx * 3.16, 0.0, 8.22, 4, "ironDark", "steel", step_z=0.52, tip_col="bronze")
        _hanging_chain(p, sx * 2.12, 0.0, 9.10, 3, "steel", "bronze", step_z=0.50, tip_col="ironDark")

    # 5. Nucleo flamejante em brasa + linguas de fogo
    _vortex_lens(p, 5.15, "emberDeep", "amber", "ember", "neonAmber", ring_col="amberBright", rx=3.18, rz=1.18)
    for k in range(10):
        a = 2 * math.pi * k / 10 + 0.18
        p.append(
            L.crystal(
                0.22,
                0.86,
                (2.60 * math.cos(a), 0.0, 5.15 + 3.18 * math.sin(a)),
                "neonAmber" if k % 2 == 0 else "emberDeep",
                tilt=(0.0, -a + math.pi / 2),
                verts=5,
            )
        )

    return p


def portal_act2():
    """Ato 2 — Forjas de Escoria: tambores serrilhados de basalto com fendas de lava, cadinhos suaves e coroa vulcanica."""
    p = []

    # 1. Base de basalto vulcanico chanfrado + piscina de magma incandescente
    _altar_steps(p, 12.8, 4.8, "tarDeep", "obsidian", "stoneDark", "danger", rune_col="amberBright")

    # 2. Cadinhos gemeos de magma em alta definicao (bojo esferico + aros toroidais + garras de escoria + domo borbulhante)
    for sx in (-1, 1):
        cx = sx * 5.48
        p.append(L.cyl(1.02, 0.68, (cx, 0, 0.48), "obsidian", verts=14, r2=1.22))
        p.append(L.ball(1.24, (cx, 0, 1.65), "ironDark", seg=12, rings=7, squash=(1.0, 1.0, 0.84)))
        p.append(L.torus(1.16, 0.115, (cx, 0, 2.26), "bronze", major_seg=14, minor_seg=4))
        p.append(L.torus(1.22, 0.075, (cx, 0, 1.58), "iron", major_seg=14, minor_seg=4))
        p.append(L.cyl(1.04, 0.26, (cx, 0, 2.22), "danger", verts=14, r2=0.94))
        p.append(L.ico(0.62, (cx, 0, 2.38), "emberDeep", squash=(1.1, 1.1, 0.45), subdiv=1))
        p.append(L.crystal(0.44, 1.38, (cx, 0, 2.46), "emberDeep", verts=5))
        p.append(L.ico(0.32, (cx + sx * 0.22, -0.18, 2.74), "amberBright", subdiv=1))
        for k in range(4):
            ca, sa = math.cos(k * math.pi / 2 + 0.35), math.sin(k * math.pi / 2 + 0.35)
            p.append(
                L.box(
                    (0.28, 0.26, 0.92),
                    (cx + 1.12 * ca, 1.12 * sa, 1.68),
                    "bronze",
                    rot=(0.0, 0.0, k * math.pi / 2 + 0.35),
                )
            )

    # 3. Colunas em 3 tambores serrilhados de basalto (verts=20) com aneis de lava e entalhes de brasa
    for sx in (-1, 1):
        x = sx * 4.22
        p.append(L.cyl(1.58, 1.15, (x, 0, 0.88), "tarDeep", verts=20, r2=1.36))
        _pillar_rune_carvings(p, x, 1.20, (2.65, 4.35, 6.05), "tarDeep", "emberDeep")
        for idx, z in enumerate((2.00, 3.80, 5.55)):
            r1 = 1.34 - idx * 0.09
            r2 = r1 - 0.06
            p.append(L.cyl(r1, 1.68, (x, 0, z), "obsidian" if idx % 2 == 0 else "stoneDark", verts=20, r2=r2))
            # Fenda horizontal incandescente de lava + anel de magma
            p.append(L.torus(r2 * 0.98, 0.09, (x, 0, z + 1.68), "danger" if idx % 2 == 0 else "emberDeep", major_seg=16, minor_seg=4))
            for sy in (-1, 1):
                p.append(L.box((0.22, 0.18, 1.28), (x + sx * 0.18, sy * (r1 * 0.88), z + 0.84), "amberBright"))
            # Esporas serrilhadas de basalto
            p.append(L.crystal(0.46, 1.62, (x + sx * 1.04, 0, z + 0.72), "tarDeep", tilt=(0.0, sx * 0.72), verts=5))
            p.append(L.crystal(0.32, 1.12, (x - sx * 0.92, 0, z + 0.82), "obsidian", tilt=(0.0, -sx * 0.58), verts=5))

        p.append(L.crystal(0.70, 2.98, (x + sx * 0.22, 0, 7.45), "tarDeep", tilt=(0.0, sx * 0.22), verts=6))
        p.append(L.crystal(0.46, 2.15, (x + sx * 0.85, 0, 7.35), "obsidian", tilt=(0.0, sx * 0.52), verts=5))
        p.append(L.crystal(0.34, 1.44, (x + sx * 0.35, 0, 9.55), "emberDeep", tilt=(0.0, sx * 0.18), verts=5))
        _hanging_chain(p, x - sx * 0.88, 0.0, 7.65, 3, "tarDeep", "bronze", step_z=0.50, tip_col="emberDeep")

    # 4. Coroa vulcanica megalitica (9 aduelas chanfradas) com fendas de magma, dentes de obsidiana e cratera central
    n_arch = 9
    for k in range(n_arch):
        theta = 0.18 + (math.pi - 0.36) * k / (n_arch - 1)
        vx = 4.08 * math.cos(theta)
        vz = 7.55 + 3.65 * math.sin(theta)
        ry = math.pi / 2 - theta
        col = "tarDeep" if k % 2 == 0 else "obsidian"
        p.append(L.box((1.38, 2.18, 1.24), (vx, 0, vz), col, bevel=0.06, rot=(0.0, ry, 0.0)))
        for sy in (-1, 1):
            p.append(
                L.box(
                    (0.44, 0.18, 0.46),
                    (vx, sy * 1.10, vz),
                    "amberBright" if k % 2 == 0 else "emberDeep",
                    rot=(0.0, ry, 0.0),
                )
            )
        if k % 2 == 1:
            p.append(L.box((0.28, 2.26, 1.32), (vx, 0, vz), "emberDeep", rot=(0.0, ry, 0.0)))
            ox = 4.64 * math.cos(theta)
            oz = 7.55 + 4.20 * math.sin(theta)
            p.append(L.crystal(0.36, 1.24, (ox, 0, oz), "obsidian", tilt=(0.0, ry), verts=5))

    # Cratera da coroa vulcanica no apice
    p.append(L.cyl(1.22, 1.08, (0, 0, 10.65), "tarDeep", verts=18, r2=0.90))
    p.append(L.torus(0.96, 0.09, (0, 0, 11.42), "danger", major_seg=16, minor_seg=5))
    p.append(L.crystal(0.78, 2.48, (0, 0, 11.15), "obsidian", verts=6))
    for sx in (-1, 1):
        p.append(L.crystal(0.48, 1.78, (sx * 0.96, 0, 10.95), "emberDeep", tilt=(0.0, sx * 0.32), verts=5))
        p.append(L.crystal(0.34, 1.28, (sx * 1.55, 0, 10.65), "amberBright", tilt=(0.0, sx * 0.52), verts=5))
    for sy in (-1, 1):
        p.append(L.ico(0.48, (0, sy * 0.96, 11.20), "amberBright", squash=(0.85, 0.48, 1.20), subdiv=1))

    # 5. Nucleo de magma fundido + anel de escoria cruzado
    _vortex_lens(p, 5.20, "tarDeep", "danger", "emberDeep", "amberBright", ring_col="ember", rx=3.32, rz=1.20)
    p.append(
        L.torus(
            2.68,
            0.088,
            (0, 0, 5.20),
            "emberDeep",
            major_seg=20,
            minor_seg=6,
            rot=(math.pi / 2 - 0.16, 0.14, 0.0),
            squash=(0.96, 1.20, 1.28),
        )
    )

    return p


def portal_act3():
    """Ato 3 — Geada do Desfiladeiro: espiras facetadas, aneis crio-toroidais suaves, estalactites e nodos runicos."""
    p = []

    # 1. Altar glacial chanfrado + disco espelhado de gelo
    _altar_steps(p, 12.6, 4.5, "stone", "whiteStoneDark", "steel", "ice", rune_col="iceGlow")

    # 2. Aglomerados densos de cristais de gelo facetados e pilones criogenicos nas extremidades
    for sx in (-1, 1):
        p.append(L.crystal(0.60, 2.80, (sx * 5.25, -0.85, 0.48), "ice", tilt=(0.14, sx * 0.28), verts=6))
        p.append(L.crystal(0.50, 2.25, (sx * 5.55, 0.85, 0.48), "iceLight", tilt=(-0.14, sx * 0.34), verts=6))
        p.append(L.crystal(0.38, 1.68, (sx * 4.82, -1.65, 0.46), "iceGlow", tilt=(0.24, sx * 0.16), verts=6))
        p.append(L.crystal(0.36, 1.58, (sx * 4.82, 1.65, 0.46), "arcaneCyan", tilt=(-0.24, sx * 0.16), verts=6))
        p.append(L.crystal(0.42, 1.95, (sx * 5.82, 0.0, 0.48), "iceLight", tilt=(0.0, sx * 0.42), verts=6))
        p.append(L.torus(0.62, 0.065, (sx * 5.28, 0.0, 1.25), "iceGlow", major_seg=14, minor_seg=4, rot=(0.0, sx * 0.24, 0.0)))
        for sy in (-1, 1):
            p.append(L.ico(0.28, (sx * 5.15, sy * 1.25, 1.45), "arcaneCyan", squash=(0.8, 0.8, 1.3), subdiv=1))

    # 3. Colunas glaciais suaves (verts=24) com entalhes runicos de gelo, aneis crio-toroidais e espiras boreais
    for sx in (-1, 1):
        x = sx * 4.20
        p.append(L.cyl(1.48, 1.12, (x, 0, 0.88), "steel", verts=24, r2=1.26))
        p.append(L.cyl(1.20, 5.58, (x, 0, 1.92), "whiteStoneDark", verts=24, r2=0.94))
        for k in range(4):
            ang = 2 * math.pi * k / 4 + math.pi / 4
            p.append(
                L.box(
                    (0.16, 0.22, 5.10),
                    (x + 1.08 * math.cos(ang), 1.08 * math.sin(ang), 4.68),
                    "steel",
                    rot=(0.0, 0.0, ang),
                )
            )
        _pillar_rune_carvings(p, x, 1.10, (2.55, 3.95, 5.35, 6.65), "steel", "iceGlow")
        for z in (3.20, 4.65, 6.05):
            r_ring = 1.16 - (z - 3.20) * 0.035
            p.append(L.torus(r_ring, 0.085, (x, 0, z), "iceGlow" if z != 4.65 else "arcaneCyan", major_seg=18, minor_seg=5))
            for sy in (-1, 1):
                p.append(L.ico(0.24, (x, sy * (r_ring + 0.06), z), "arcaneCyan", squash=(0.9, 0.65, 1.25), subdiv=1))
        # Capitel glacial com barba de estalactites + altas espiras boreais facetadas (ate ~13.8 studs)
        p.append(L.cyl(1.02, 0.72, (x, 0, 7.32), "steel", verts=22, r2=1.36))
        for k in range(6):
            ang = 2 * math.pi * k / 6 + 0.3
            p.append(
                L.crystal(
                    0.18,
                    0.92,
                    (x + 1.18 * math.cos(ang), 1.18 * math.sin(ang), 7.28),
                    "iceLight",
                    tilt=(math.pi, 0.0),
                    verts=5,
                )
            )
        p.append(L.crystal(0.70, 5.45, (x + sx * 0.18, 0, 7.35), "iceLight", tilt=(0.0, sx * 0.08), verts=6))
        p.append(L.crystal(0.50, 3.75, (x + sx * 0.80, 0, 7.25), "ice", tilt=(0.0, sx * 0.26), verts=6))
        p.append(L.crystal(0.38, 2.40, (x - sx * 0.34, 0, 7.65), "iceGlow", tilt=(0.0, -sx * 0.06), verts=6))
        p.append(L.crystal(0.32, 1.95, (x + sx * 0.48, 0.45, 7.45), "arcaneCyan", tilt=(-0.14, sx * 0.18), verts=5))
        p.append(L.crystal(0.32, 1.95, (x + sx * 0.48, -0.45, 7.45), "arcaneCyan", tilt=(0.14, sx * 0.18), verts=5))
        _hanging_chain(p, x - sx * 0.88, 0.0, 7.55, 3, "steel", "iceLight", step_z=0.50, tip_col="iceGlow")

    # 4. Arco ogival pontiagudo (5 pares de aduelas chanfradas) com nodos runicos, estalactites + estrela boreal
    arch_left = [
        (-3.65, 7.75, 0.46),
        (-2.85, 8.65, 0.56),
        (-2.05, 9.52, 0.68),
        (-1.28, 10.28, 0.78),
        (-0.58, 10.88, 0.88),
    ]
    for idx, (ax, az, ry) in enumerate(arch_left):
        for sx in (-1, 1):
            p.append(
                L.box(
                    (1.22, 1.92, 1.02),
                    (sx * abs(ax), 0, az),
                    "steel" if idx % 2 == 0 else "whiteStoneDark",
                    bevel=0.06,
                    rot=(0.0, -sx * ry, 0.0),
                )
            )
            p.append(L.crystal(0.34, 1.38, (sx * abs(ax), 0, az + 0.44), "iceLight", tilt=(0.0, sx * 0.22), verts=6))
            p.append(L.crystal(0.24, 0.94, (sx * abs(ax) * 0.92, 0, az - 0.38), "ice", tilt=(math.pi, -sx * 0.18), verts=5))
            for sy in (-1, 1):
                p.append(L.ico(0.24, (sx * abs(ax), sy * 1.00, az), "iceGlow", squash=(0.85, 0.55, 1.15), subdiv=1))

    # Cristal central em diamante duplo de 6 faces + halo criogenico
    p.append(L.crystal(0.78, 2.68, (0, 0, 11.15), "iceGlow", verts=6))
    p.append(L.crystal(0.60, 1.58, (0, 0, 11.20), "arcaneCyan", tilt=(math.pi, 0.0), verts=6))
    p.append(L.torus(0.95, 0.075, (0, 0, 11.65), "iceLight", major_seg=18, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    for sy in (-1, 1):
        p.append(L.ico(0.42, (0, sy * 0.88, 11.45), "arcaneCyan", squash=(0.78, 0.48, 1.25), subdiv=1))

    # 5. Lente boreal + segundo anel crio-toroidal inclinado
    _vortex_lens(p, 5.30, "tealDark", "ice", "iceLight", "iceGlow", ring_col="arcaneCyan", rx=3.35, rz=1.26)
    p.append(
        L.torus(
            2.68,
            0.092,
            (0, 0, 5.30),
            "iceGlow",
            major_seg=20,
            minor_seg=6,
            rot=(math.pi / 2 - 0.14, -0.12, 0.0),
            squash=(0.96, 1.24, 1.30),
        )
    )

    return p


def portal_act4():
    """Ato 4 — Polvora e Trincheira: engrenagens rotativas de latao, tubulacoes de vapor rebitadas, chamines e luzes de alerta."""
    p = []

    # 1. Plataforma fortificada com borda chanfrada de latao/bronze
    _altar_steps(p, 12.8, 4.6, "ironDark", "iron", "brass", "bronze", rune_col="goldBright")

    # 2. Chamines gemeas (verts=16) + coletores de vapor, valvulas e tubulacoes rebitadas ligadas aos pilares
    for sx in (-1, 1):
        cx = sx * 5.42
        p.append(L.box((1.76, 2.16, 1.44), (cx, 0, 1.22), "ironDark", bevel=0.06))
        p.append(L.cyl(0.70, 8.88, (cx, 0, 1.90), "ironDark", verts=16, r2=0.58))
        for bz in (3.6, 6.2, 8.8):
            p.append(L.cyl(0.76, 0.24, (cx, 0, bz), "brass", verts=14, r2=0.76))
        p.append(L.cyl(0.84, 0.62, (cx, 0, 10.72), "steel", verts=16, r2=0.66))
        p.append(L.torus(0.82, 0.07, (cx, 0, 11.28), "brass", major_seg=12, minor_seg=4))
        # Tubulacoes horizontais de vapor + flanges de latao conectando chamine ao pilar
        for pz, pr, pcol in ((4.25, 0.26, "iron"), (6.85, 0.22, "bronze")):
            p.append(L.cyl_axis(pr, 1.38, (sx * 4.76, 0, pz), pcol, axis="x", verts=10))
            p.append(L.cyl_axis(pr + 0.09, 0.20, (sx * 4.76, 0, pz), "brass", axis="x", verts=10))
        # Volante de valvula de pressao nas faces -Y/+Y da base da chamine
        for sy in (-1, 1):
            p.append(L.torus(0.34, 0.05, (cx, sy * 1.16, 1.45), "goldBright", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))

    # 3. Colunas blindadas de casamata (verts=20) com placas de latao, rebites, manometros e luzes de alerta (-Y/+Y)
    for sx in (-1, 1):
        x = sx * 4.10
        p.append(L.box((2.18, 2.70, 1.26), (x, 0, 1.54), "ironDark", bevel=0.06))
        p.append(L.cyl(1.18, 5.68, (x, 0, 2.12), "iron", verts=20, r2=1.04))
        _pillar_rune_carvings(p, x, 1.10, (2.75, 4.35, 7.15), "brass", "amberBright")
        for z in (3.55, 6.25):
            p.append(L.box((1.92, 2.42, 0.38), (x, 0, z), "brass"))
            for sy in (-1, 1):
                for rx in (-0.64, -0.22, 0.22, 0.64):
                    p.append(L.ball(0.085, (x + rx, sy * 1.24, z), "goldBright", seg=6, rings=3))
        p.append(L.box((2.22, 2.56, 1.08), (x, 0, 8.18), "ironDark", bevel=0.06))
        # Luzes de alerta engaioladas em latao + aro toroidal de manometro na frente e atras
        for sy in (-1, 1):
            p.append(L.cyl_axis(0.38, 0.24, (x, sy * 1.22, 4.95), "brass", axis="y", verts=10))
            p.append(L.torus(0.38, 0.055, (x, sy * 1.32, 4.95), "goldBright", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
            p.append(L.ico(0.28, (x, sy * 1.38, 4.95), "danger", squash=(1.0, 0.65, 1.0), subdiv=1))
            p.append(L.ico(0.18, (x, sy * 1.48, 4.95), "amberBright", squash=(1.0, 0.55, 1.0), subdiv=1))
        _hanging_chain(p, x - sx * 0.90, 0.0, 7.80, 3, "ironDark", "brass", step_z=0.50, tip_col="bronze")

    # 4. Arco industrial rebitado chanfrado (7 aduelas) + trem de engrenagens rotativas de latao no apice
    n_arch = 7
    for k in range(n_arch):
        theta = 0.20 + (math.pi - 0.40) * k / (n_arch - 1)
        vx = 3.96 * math.cos(theta)
        vz = 7.75 + 3.18 * math.sin(theta)
        ry = math.pi / 2 - theta
        col = "iron" if k % 2 == 0 else "brass"
        p.append(L.box((1.55, 2.18, 1.14), (vx, 0, vz), col, bevel=0.05, rot=(0.0, ry, 0.0)))
        for sy in (-1, 1):
            p.append(
                L.box(
                    (0.52, 0.18, 0.36),
                    (vx, sy * 1.10, vz),
                    "goldBright" if k % 2 == 0 else "bronze",
                    rot=(0.0, ry, 0.0),
                )
            )

    # Coroa industrial + engrenagem mestre de latao (verts=20, 10 dentes) + 2 pinhoes laterais
    p.append(L.box((2.82, 2.32, 1.26), (0, 0, 11.10), "ironDark", bevel=0.06))
    p.append(L.cyl_axis(1.40, 2.48, (0, 0, 11.48), "brass", axis="y", verts=20))
    p.append(L.torus(1.18, 0.09, (0, -1.24, 11.48), "goldBright", major_seg=16, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(L.torus(1.18, 0.09, (0, 1.24, 11.48), "goldBright", major_seg=16, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    for k in range(10):
        a = 2 * math.pi * k / 10
        p.append(
            L.box(
                (0.28, 2.38, 0.34),
                (1.54 * math.cos(a), 0, 11.48 + 1.54 * math.sin(a)),
                "goldBright",
                rot=(0.0, -a, 0.0),
            )
        )
    for sx in (-1, 1):
        gx, gz = sx * 2.04, 10.75
        p.append(L.cyl_axis(0.72, 2.34, (gx, 0, gz), "bronze", axis="y", verts=14))
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.25
            p.append(
                L.box(
                    (0.22, 2.24, 0.26),
                    (gx + 0.82 * math.cos(a), 0, gz + 0.82 * math.sin(a)),
                    "brass",
                    rot=(0.0, -a, 0.0),
                )
            )
    for sy in (-1, 1):
        p.append(L.ico(0.46, (0, sy * 1.28, 11.48), "amberBright", squash=(1.0, 0.45, 1.0), subdiv=1))

    # 5. Nucleo de polvora e enxofre dourado + anel giroscopico de latao
    _vortex_lens(p, 5.20, "tarDeep", "bronze", "brass", "amberBright", ring_col="goldBright", rx=3.16, rz=1.18)
    p.append(
        L.torus(
            2.62,
            0.088,
            (0, 0, 5.20),
            "brass",
            major_seg=20,
            minor_seg=6,
            rot=(math.pi / 2 + 0.14, -0.14, 0.0),
            squash=(0.96, 1.18, 1.26),
        )
    )

    return p


def portal_act5():
    """Ato 5 — A Fenda Profunda: obeliscos flutuantes de obsidiana e aneis toroidais de contencao arcaneViolet/eyeNeon."""
    p = []

    # 1. Altar abissal monumental + degraus runicos + circulo de contencao
    _altar_steps(p, 13.4, 5.0, "obsidian", "obsidianLight", "stoneDark", "tealDark", rune_col="arcaneViolet")
    p.append(L.box((9.8, 3.1, 0.34), (0, 0, 1.18), "obsidian", bevel=0.05))
    p.append(L.cyl(3.28, 0.22, (0, 0, 1.32), "tealDark", verts=22, r2=3.06))
    p.append(L.torus(3.08, 0.08, (0, 0, 1.48), "eyeNeon", major_seg=22, minor_seg=5))

    # 2. Obeliscos flutuantes de obsidiana nas extremidades (pedestal terrestre + aneis antigravidade + obelisco suspenso)
    for sx in (-1, 1):
        ox = sx * 5.65
        # Pedestal ancorado com cristal emissor antigravidade e aneis duplos
        p.append(L.box((1.88, 2.24, 0.96), (ox, 0, 0.96), "obsidian", bevel=0.06))
        p.append(L.torus(0.84, 0.085, (ox, 0, 1.54), "arcaneViolet", major_seg=16, minor_seg=5))
        p.append(L.torus(0.62, 0.065, (ox, 0, 1.98), "eyeNeon", major_seg=14, minor_seg=4))
        p.append(L.crystal(0.38, 0.72, (ox, 0, 1.48), "eyeNeon", verts=6))
        # Obelisco flutuante suspenso no ar (Z = 2.55 .. 11.55, com ponta inferior conica invertida)
        p.append(L.crystal(0.68, 1.02, (ox, 0, 3.50), "obsidian", tilt=(math.pi, 0.0), verts=6, spin=math.pi / 6))
        p.append(L.cyl(0.94, 5.85, (ox, 0, 3.50), "obsidian", verts=6, r2=0.56, rot_z=math.pi / 6, bevel=0.04))
        p.append(L.crystal(0.56, 1.98, (ox, 0, 9.35), "obsidianLight", verts=6, spin=math.pi / 6))
        for rz_ring, r_col in ((4.8, "arcaneViolet"), (6.8, "eyeNeon")):
            p.append(L.torus(0.92 - (rz_ring - 4.8) * 0.06, 0.075, (ox, 0, rz_ring), r_col, major_seg=14, minor_seg=4))
        p.append(L.box((1.24, 1.24, 0.26), (ox, 0, 7.5), "eyeNeon"))
        p.append(L.ico(0.36, (ox, 0, 11.58), "eyeNeon", squash=(0.78, 0.78, 1.38), subdiv=1))

    # 3. Colunas monoliticas suaves (verts=24) em obsidiana com condutos arcanos violeta/neon, aneis e entalhes
    for sx in (-1, 1):
        x = sx * 3.88
        p.append(L.box((2.22, 2.72, 1.34), (x, 0, 1.92), "obsidian", bevel=0.07))
        p.append(L.cyl(1.22, 6.28, (x, 0, 2.55), "obsidianLight", verts=24, r2=1.00))
        _pillar_rune_carvings(p, x, 1.14, (3.45, 5.65, 7.85), "obsidian", "eyeNeon")
        for z_band in (4.55, 6.75):
            p.append(L.torus(1.18, 0.08, (x, 0, z_band), "arcaneViolet", major_seg=18, minor_seg=5))
        for sy in (-1, 1):
            p.append(L.box((0.42, 0.22, 5.58), (x, sy * 1.10, 5.68), "arcaneViolet"))
            p.append(L.box((0.20, 0.26, 4.78), (x, sy * 1.16, 5.68), "eyeNeon"))
        p.append(L.box((2.32, 2.62, 1.02), (x, 0, 9.15), "obsidian", bevel=0.06))
        _hanging_chain(p, x - sx * 0.88, 0.0, 8.55, 4, "obsidian", "arcaneViolet", step_z=0.52, tip_col="eyeNeon")

    # 4. Lintel monumental escalonado em obsidiana + aduelas abissais internas + coroa abissal
    for k in range(7):
        theta = 0.22 + (math.pi - 0.44) * k / 6
        vx = 3.76 * math.cos(theta)
        vz = 7.45 + 2.45 * math.sin(theta)
        ry = math.pi / 2 - theta
        p.append(
            L.box(
                (1.18, 1.88, 0.88),
                (vx, 0, vz),
                "obsidianLight" if k % 2 == 0 else "obsidian",
                bevel=0.05,
                rot=(0.0, ry, 0.0),
            )
        )
    p.append(L.box((9.88, 2.52, 1.26), (0, 0, 10.15), "obsidian", bevel=0.07))
    p.append(L.box((7.48, 2.20, 0.98), (0, 0, 11.18), "obsidianLight", bevel=0.06))
    p.append(L.box((4.52, 1.90, 0.88), (0, 0, 12.02), "obsidian", bevel=0.06))
    p.append(L.crystal(0.78, 2.22, (0, 0, 12.38), "arcaneViolet", verts=6))
    p.append(L.torus(1.08, 0.085, (0, 0, 12.85), "eyeNeon", major_seg=18, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    for sx in (-1, 1):
        p.append(L.crystal(0.58, 2.48, (sx * 4.25, 0, 10.55), "obsidian", tilt=(0.0, sx * 0.24), verts=6))
        p.append(L.crystal(0.40, 1.62, (sx * 2.45, 0, 11.45), "arcaneViolet", tilt=(0.0, sx * 0.16), verts=5))
        p.append(L.crystal(0.34, 1.38, (sx * 1.25, 0, 12.18), "tealSwarm", tilt=(0.0, sx * 0.12), verts=5))
    for sy in (-1, 1):
        p.append(L.box((1.92, 0.24, 0.44), (0, sy * 1.14, 11.18), "arcaneViolet"))
        for rx in (-2.95, -1.45, 1.45, 2.95):
            p.append(L.box((0.64, 0.22, 0.48), (rx, sy * 1.28, 10.15), "eyeNeon"))
        p.append(L.ico(0.58, (0, sy * 1.06, 12.05), "eyeNeon", squash=(0.74, 0.42, 1.38), subdiv=1))

    # 5. Portal abissal + aneis toroidais de contencao entrecruzados (arcaneViolet / eyeNeon)
    _vortex_lens(p, 5.55, "obsidian", "arcaneViolet", "tealSwarm", "eyeNeon", ring_col="arcaneViolet", rx=3.18, rz=1.24)
    p.append(
        L.torus(
            2.95,
            0.10,
            (0, 0, 5.55),
            "eyeNeon",
            major_seg=20,
            minor_seg=6,
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
            minor_seg=6,
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
            "qualidade": "hero",
            "limite": LIMITE,
            "hero_pbr": True,
            "quantidade_cena": 1,
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
            "qualidade": "hero",
            "limite": LIMITE,
            "hero_pbr": True,
            "quantidade_cena": 0,
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
            "qualidade": "hero",
            "limite": LIMITE,
            "hero_pbr": True,
            "quantidade_cena": 0,
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
            "qualidade": "hero",
            "limite": LIMITE,
            "hero_pbr": True,
            "quantidade_cena": 0,
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
            "qualidade": "hero",
            "limite": LIMITE,
            "hero_pbr": True,
            "quantidade_cena": 0,
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
            "qualidade": "hero",
            "limite": LIMITE,
            "hero_pbr": True,
            "quantidade_cena": 0,
            "center_xy": True,
            "suavizacao_normais": NORMALS_SPEC,
            "tags": ["muralha", "portal", "campaign", "act5"],
            "build": portal_act5,
        },
    ],
    "portal da fenda + 5 portais monumentais da campanha (art/scripts/make_portal.py)",
    hero_pbr=True,
)
