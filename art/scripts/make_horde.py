"""Gera os troncos/capuzes/carapacas esculpidos da horda (CMD_runner, CMD_brute, CMD_swarm,
CMD_shieldbearer, CMD_pyromancer, CMD_sapper).

Desenho hibrido articulado: a malha Open Cloud contem APENAS o torso, armadura/manto,
ombros/ombreiras e cabeca/capuz/chifres (sem pernas nem bracos estaticos), para que o
HordeKit.luau articule pernas, bracos, cutelo, escudo e satelites a 60 Hz em torno do pivo.
Zero caixas retangulares na silhueta: esferas, icosaedros, cones e cristais faceteados.

Mapeamento Roblox -> Blender (frente -Z no Studio = -Y no Blender): (x, y, z) -> (-x, z, y).

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_horde.py
Saidas: art/export/horde_<tipo>.glb, art/forge/lote_horde_import.yaml (gerado),
        art/renders/horde/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 1500
SCALE = {
    "runner": 0.85,
    "brute": 1.35,
    "swarm": 0.65,
    "shieldbearer": 1.12,
    "pyromancer": 0.95,
    "sapper": 0.88,
}  # VisualTheme.ENEMIES[*].scale


class Rb:
    """Constroi em coordenadas Roblox escaladas por scale*1.8 (frente -Z -> Blender -Y)."""

    def __init__(self, kind):
        self.k = SCALE[kind] * 1.8

    def p(self, x, y, z):
        return (-x * self.k, z * self.k, y * self.k)

    def ball(self, diam, pos, color, seg=10, rings=6, squash=(1.0, 1.0, 1.0)):
        return L.ball(
            diam / 2 * self.k,
            self.p(*pos),
            color,
            seg=seg,
            rings=rings,
            squash=(squash[0], squash[2], squash[1]),
        )

    def ico(self, rad, pos, color, squash=(1.0, 1.0, 1.0)):
        return L.ico(
            rad * self.k,
            self.p(*pos),
            color,
            squash=(squash[0], squash[2], squash[1]),
        )

    def cyl(self, r, h, base, color, verts=8, r2=None, rot_z=0.0):
        return L.cyl(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            rot_z=rot_z,
        )

    def crystal(self, r, h, base, color, tilt=(0.0, 0.0), verts=5, r2=0.0, spin=0.0):
        return L.crystal(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            tilt=tilt,
            verts=verts,
            r2=r2 * self.k,
            spin=spin,
        )


def runner():
    """Spectral Stalker Wraith: manto esfarrapado, costelas arcanas, capuz de ceifador e chifres."""
    r = Rb("runner")
    p = []

    # Saia conica de espectro + 8 pontas esfarrapadas (pernas articulam por baixo)
    p.append(r.cyl(0.80, 0.88, (0, 0.25, 0), "tealDark", verts=8, r2=0.48))
    for k in range(8):
        a = 2 * math.pi * k / 8
        rx = 0.64 * math.cos(a)
        rz = 0.64 * math.sin(a)
        p.append(
            r.crystal(
                0.17,
                0.68,
                (rx, 0.58, rz),
                "teal" if k % 2 == 0 else "tealDark",
                tilt=(-math.pi + 0.34 * math.sin(a), 0.34 * math.cos(a)),
                verts=4,
            )
        )

    # Cinto runico + torso em V afunilado + costelas espectrais
    p.append(r.cyl(0.54, 0.22, (0, 0.94, 0), "ironDark", verts=8, r2=0.50))
    p.append(r.ico(0.56, (0, 1.46, -0.02), "teal", squash=(1.05, 1.15, 0.80)))
    p.append(r.ico(0.45, (0, 1.38, 0.20), "tealDark", squash=(0.88, 1.02, 0.68)))
    # Crista dorsal (lombada espectral apontada para +Y Blender = tras)
    for dy, dz, sz in ((1.22, 0.34, 0.42), (1.56, 0.38, 0.50), (1.88, 0.30, 0.38)):
        p.append(r.crystal(0.13, sz, (0, dy, dz), "tealDark", tilt=(-1.05, 0.0), verts=4))
    # Costelas arcanas na frente (-Z Roblox / -Y Blender)
    for idx, ry in enumerate((1.24, 1.46, 1.68)):
        w = 0.36 + idx * 0.06
        for sx in (-1, 1):
            p.append(
                r.crystal(
                    0.085,
                    0.38,
                    (sx * 0.12, ry, -0.36),
                    "tealSwarm",
                    tilt=(1.15, sx * 0.85),
                    verts=4,
                )
            )
            p.append(r.ico(0.095, (sx * w, ry + 0.04, -0.24), "tealSwarm", squash=(0.8, 0.6, 0.8)))

    # Gola do manto + capuz pontiagudo de ceifador inclinado para tras (+Y) e aba na frente
    p.append(r.cyl(0.64, 0.32, (0, 1.82, 0.02), "tealDark", verts=8, r2=0.45))
    p.append(r.ball(0.94, (0, 2.28, -0.02), "teal", seg=10, rings=6, squash=(0.95, 1.05, 1.12)))
    p.append(r.crystal(0.42, 0.88, (0, 2.40, 0.16), "tealDark", tilt=(-0.92, 0.0), verts=6))
    # Face sombria + visor brilhante bem legivel na frente (-Z Roblox / -Y Blender)
    p.append(r.ball(0.62, (0, 2.24, -0.28), "ironDark", seg=8, rings=5, squash=(0.92, 0.88, 0.72)))
    for sx in (-1, 1):
        p.append(r.ico(0.12, (sx * 0.16, 2.24, -0.56), "eyeNeon", squash=(1.35, 0.68, 0.72)))
        # Chifres abrindo para fora (-sx no ry de Blender!) e varridos para tras (-0.65 rad)
        p.append(
            r.crystal(
                0.13,
                0.86,
                (sx * 0.24, 2.58, -0.02),
                "iron",
                tilt=(-0.62, -sx * 0.48),
                verts=5,
            )
        )

    return p


def brute():
    """Horned Rift Juggernaut: cintura blindada, tronco massivo, ombreiras com espinhos e cranio com chifres."""
    b = Rb("brute")
    p = []

    # Cintura blindada + placa ventral + saiote/tassets laterais
    p.append(b.cyl(0.66, 0.36, (0, 0.70, 0), "tealBruteDark", verts=8, r2=0.60))
    p.append(b.ico(0.26, (0, 0.88, -0.58), "tealSwarm", squash=(0.95, 0.85, 0.48)))
    for sx in (-1, 1):
        p.append(
            b.crystal(
                0.24,
                0.62,
                (sx * 0.56, 0.84, 0.0),
                "ironDark",
                tilt=(-math.pi, -sx * 0.28),
                verts=4,
            )
        )

    # Tronco musculoso em V + peitoral de obsidiana + nucleo da fenda no esterno
    p.append(b.ico(0.76, (0, 1.38, 0.0), "tealBrute", squash=(1.18, 1.06, 0.84)))
    p.append(b.ico(0.50, (0, 1.56, 0.22), "tealBruteDark", squash=(1.05, 0.84, 0.72)))
    for sx in (-1, 1):
        p.append(b.ico(0.38, (sx * 0.34, 1.52, -0.34), "ironDark", squash=(0.92, 0.82, 0.54)))
    p.append(b.crystal(0.20, 0.54, (0, 1.34, -0.56), "eyeNeon", tilt=(1.40, 0.0), verts=6))
    for k in range(3):
        p.append(b.crystal(0.14, 0.44, (0, 1.18 + k * 0.28, 0.48), "ironDark", tilt=(-1.05, 0.0), verts=4))

    # Ombreiras curvadas com espinhos abrindo para fora (-sx no ry)
    for sx in (-1, 1):
        p.append(b.ball(0.74, (sx * 0.78, 1.72, -0.02), "iron", seg=10, rings=6, squash=(1.05, 0.78, 1.02)))
        p.append(b.ico(0.34, (sx * 0.84, 1.66, -0.02), "tealBruteDark", squash=(0.96, 0.65, 0.96)))
        p.append(
            b.crystal(
                0.15,
                0.68,
                (sx * 0.82, 1.96, 0.02),
                "ironDark",
                tilt=(0.0, -sx * 0.48),
                verts=5,
            )
        )
        p.append(
            b.crystal(
                0.11,
                0.48,
                (sx * 0.96, 1.76, 0.14),
                "steel",
                tilt=(-0.38, -sx * 0.78),
                verts=4,
            )
        )

    # Elmo/cranio corcunda + mandibula com presas + chifres curvos abrindo para fora e frente
    p.append(b.ico(0.46, (0, 2.12, -0.18), "tealBruteDark", squash=(0.96, 0.94, 1.04)))
    p.append(b.ico(0.34, (0, 1.92, -0.30), "ironDark", squash=(0.88, 0.58, 0.78)))
    for sx in (-1, 1):
        p.append(b.ico(0.105, (sx * 0.16, 2.15, -0.52), "eyeNeon", squash=(1.35, 0.65, 0.65)))
        p.append(b.crystal(0.06, 0.24, (sx * 0.14, 1.92, -0.50), "steel", tilt=(0.35, -sx * 0.14), verts=4))
        p.append(
            b.crystal(
                0.16,
                0.86,
                (sx * 0.28, 2.28, -0.12),
                "ironDark",
                tilt=(0.50, -sx * 0.72),
                verts=5,
            )
        )

    return p


def swarm():
    """Phantom Skull Wisp: cranio espectral com chifres, crista neon e fios de ectoplasma."""
    w = Rb("swarm")
    p = []

    # Nucleo craniano facetado + bochechas e queixo escuro
    p.append(w.ico(0.76, (0, 1.38, -0.02), "tealSwarm", squash=(0.98, 1.04, 0.98)))
    p.append(w.ico(0.50, (0, 1.02, -0.14), "tealSwarmDark", squash=(0.84, 0.76, 0.84)))
    # Orbitas escuras + olhos brilhantes
    p.append(w.ball(0.66, (0, 1.38, -0.42), "ironDark", seg=8, rings=5, squash=(0.96, 0.68, 0.66)))
    for sx in (-1, 1):
        p.append(w.ico(0.145, (sx * 0.22, 1.40, -0.66), "eyeNeon", squash=(1.25, 0.72, 0.68)))
        # Chifres abrindo para fora (-sx no ry)
        p.append(
            w.crystal(
                0.16,
                0.95,
                (sx * 0.34, 1.72, 0.02),
                "tealDark",
                tilt=(-0.58, -sx * 0.56),
                verts=5,
            )
        )

    # Crista dorsal brilhante + pontas de ectoplasma inferiores
    for k in range(3):
        p.append(
            w.crystal(
                0.14,
                0.52 - k * 0.09,
                (0, 1.80 - k * 0.28, 0.28 + k * 0.18),
                "eyeNeon" if k == 0 else "tealSwarm",
                tilt=(-0.72 - k * 0.22, 0.0),
                verts=4,
            )
        )
    for k in range(6):
        a = 2 * math.pi * k / 6
        p.append(
            w.crystal(
                0.16,
                0.68,
                (0.36 * math.cos(a), 0.82, 0.36 * math.sin(a)),
                "tealSwarmDark",
                tilt=(-math.pi + 0.24 * math.sin(a), 0.24 * math.cos(a)),
                verts=4,
            )
        )

    return p


def shieldbearer():
    """Escudeiro: elmo pesado com crista, ombreiras blindadas e motivo frontal de escudo-torre."""
    s = Rb("shieldbearer")
    p = []

    # Cintura e saiote blindado
    p.append(s.cyl(0.64, 0.34, (0, 0.68, 0), "ironDark", verts=8, r2=0.58))
    p.append(s.ico(0.24, (0, 0.86, -0.52), "teal", squash=(1.1, 0.8, 0.45)))
    for sx in (-1, 1):
        p.append(
            s.crystal(0.20, 0.56, (sx * 0.52, 0.80, 0.0), "iron", tilt=(-math.pi, -sx * 0.25), verts=4)
        )

    # Peitoral de obsidiana/aco + detalhes turquesa + crista dorsal
    p.append(s.ico(0.68, (0, 1.36, 0.02), "iron", squash=(1.12, 1.05, 0.82)))
    p.append(s.ico(0.56, (0, 1.44, -0.22), "steel", squash=(1.02, 0.88, 0.55)))
    p.append(s.crystal(0.16, 0.44, (0, 1.32, -0.56), "teal", tilt=(1.42, 0.0), verts=4))
    for k in range(3):
        p.append(s.crystal(0.11, 0.36, (0, 1.18 + k * 0.26, 0.44), "ironDark", tilt=(-1.05, 0.0), verts=4))

    # Motivo de escudo-torre acoplado a frente-esquerda (-Z / -X) com borda de aco e runa
    p.append(L.box((0.92 * s.k, 0.16 * s.k, 1.28 * s.k), s.p(0.22, 1.24, -0.58), "ironDark"))
    p.append(L.box((1.02 * s.k, 0.10 * s.k, 1.38 * s.k), s.p(0.22, 1.24, -0.54), "steel"))
    p.append(s.crystal(0.16, 0.36, (0.22, 1.24, -0.68), "tealSwarm", tilt=(1.55, 0.0), verts=4))

    # Ombreiras pesadas com friso turquesa
    for sx in (-1, 1):
        p.append(s.ball(0.68, (sx * 0.72, 1.66, 0.0), "iron", seg=10, rings=6, squash=(1.08, 0.82, 0.98)))
        p.append(s.ico(0.32, (sx * 0.78, 1.62, 0.0), "tealDark", squash=(0.95, 0.68, 0.95)))
        p.append(s.crystal(0.11, 0.44, (sx * 0.80, 1.88, 0.02), "steel", tilt=(0.0, -sx * 0.55), verts=4))

    # Elmo fechado com visor luminoso e crista alta
    p.append(s.ball(0.86, (0, 2.16, -0.06), "iron", seg=10, rings=6, squash=(0.96, 1.02, 1.06)))
    p.append(s.ico(0.38, (0, 2.12, -0.34), "ironDark", squash=(1.05, 0.55, 0.48)))
    p.append(s.ico(0.18, (0, 2.14, -0.48), "eyeNeon", squash=(1.85, 0.36, 0.35)))
    for k in range(4):
        p.append(
            s.crystal(
                0.11,
                0.48 - k * 0.05,
                (0, 2.52 - k * 0.08, -0.10 + k * 0.18),
                "teal" if k % 2 == 0 else "steel",
                tilt=(-0.35 - k * 0.30, 0.0),
                verts=4,
            )
        )

    return p


def pyromancer():
    """Piroforjador: capuz com chifres de brasa, colar runico flutuante e nucleo incandescente."""
    y = Rb("pyromancer")
    p = []

    # Tunica de ardosia escura e pontas com acento turquesa/ambar
    p.append(y.cyl(0.74, 0.84, (0, 0.28, 0), "stoneDark", verts=8, r2=0.46))
    for k in range(6):
        a = 2 * math.pi * k / 6
        p.append(
            y.crystal(
                0.16,
                0.56,
                (0.58 * math.cos(a), 0.54, 0.58 * math.sin(a)),
                "tealDark" if k % 2 == 0 else "ironDark",
                tilt=(-math.pi + 0.30 * math.sin(a), 0.30 * math.cos(a)),
                verts=4,
            )
        )

    # Torso esguio em ardosia + nucleo de brasa exposto no peito (-Z)
    p.append(y.cyl(0.48, 0.20, (0, 0.96, 0), "ironDark", verts=8, r2=0.46))
    p.append(y.ico(0.54, (0, 1.44, 0.02), "stoneDark", squash=(1.05, 1.12, 0.82)))
    p.append(y.ico(0.28, (0, 1.44, -0.36), "amberBright", squash=(0.95, 1.10, 0.62)))
    p.append(y.crystal(0.14, 0.36, (0, 1.44, -0.46), "ember", tilt=(1.48, 0.0), verts=5))
    for sx in (-1, 1):
        p.append(y.crystal(0.08, 0.38, (sx * 0.26, 1.38, -0.34), "ironDark", tilt=(1.1, sx * 0.65), verts=4))

    # Colar runico flutuante ao redor dos ombros (ambar e turquesa alternados)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        rx = 0.70 * math.cos(a)
        rz = 0.62 * math.sin(a)
        p.append(
            y.crystal(
                0.10,
                0.40,
                (rx, 1.88 + 0.06 * (k % 2), rz),
                "amberBright" if k % 2 == 0 else "tealSwarm",
                tilt=(-0.28 * math.sin(a), -0.28 * math.cos(a)),
                verts=4,
            )
        )

    # Gola alta + capuz pontiagudo de brasa + chifres incandescentes
    p.append(y.cyl(0.58, 0.28, (0, 1.80, 0.04), "ironDark", verts=8, r2=0.44))
    p.append(y.ball(0.88, (0, 2.24, -0.02), "stoneDark", seg=10, rings=6, squash=(0.96, 1.04, 1.12)))
    p.append(y.crystal(0.38, 0.84, (0, 2.38, 0.14), "ember", tilt=(-0.88, 0.0), verts=6))
    p.append(y.ball(0.58, (0, 2.20, -0.28), "ironDark", seg=8, rings=5, squash=(0.92, 0.86, 0.72)))
    for sx in (-1, 1):
        p.append(y.ico(0.11, (sx * 0.15, 2.22, -0.54), "amberBright", squash=(1.3, 0.65, 0.68)))
        p.append(
            y.crystal(0.12, 0.82, (sx * 0.24, 2.52, -0.02), "danger", tilt=(-0.55, -sx * 0.48), verts=5)
        )

    return p


def sapper():
    """Zapador: capuz com oculos de demolicao, mochila de polvora nas costas (+Z) e bandoleira."""
    z = Rb("sapper")
    p = []

    # Cinto tatico com bolsas + torso agil
    p.append(z.cyl(0.56, 0.28, (0, 0.74, 0), "ironDark", verts=8, r2=0.52))
    p.append(z.ico(0.56, (0, 1.32, 0.0), "tealDark", squash=(1.04, 1.06, 0.82)))
    p.append(z.ico(0.46, (0, 1.36, -0.20), "iron", squash=(0.94, 0.92, 0.56)))

    # Bandoleira diagonal de cargas explosivas na frente (-Z)
    for k in range(4):
        t = (k - 1.5) / 1.5
        p.append(
            z.ico(
                0.13,
                (t * 0.34, 1.38 - t * 0.24, -0.44),
                "bronze" if k % 2 == 0 else "danger",
                squash=(0.9, 1.25, 0.85),
            )
        )

    # Mochila de polvora / barril explosivo amarrado nas costas (+Z Roblox / +Y Blender)
    p.append(z.cyl(0.42, 0.84, (0, 1.02, 0.50), "woodDark", verts=10, r2=0.40))
    p.append(z.cyl(0.45, 0.14, (0, 1.18, 0.50), "bronze", verts=10, r2=0.45))
    p.append(z.cyl(0.45, 0.14, (0, 1.58, 0.50), "bronze", verts=10, r2=0.45))
    p.append(z.crystal(0.12, 0.42, (0, 1.84, 0.50), "amberBright", tilt=(-0.22, 0.0), verts=5))

    # Ombreiras leves
    for sx in (-1, 1):
        p.append(z.ico(0.32, (sx * 0.62, 1.62, 0.0), "ironDark", squash=(0.95, 0.75, 0.92)))

    # Capuz justo com oculos luminosos duplos na frente (-Z)
    p.append(z.ball(0.84, (0, 2.08, -0.04), "tealDark", seg=10, rings=6, squash=(0.96, 1.0, 1.02)))
    p.append(z.ball(0.56, (0, 2.04, -0.26), "ironDark", seg=8, rings=5, squash=(0.94, 0.82, 0.72)))
    for sx in (-1, 1):
        p.append(z.ico(0.18, (sx * 0.18, 2.08, -0.48), "bronze", squash=(0.95, 0.95, 0.65)))
        p.append(z.ico(0.12, (sx * 0.18, 2.08, -0.56), "eyeNeon", squash=(0.95, 0.95, 0.55)))
        p.append(z.crystal(0.08, 0.36, (sx * 0.34, 2.34, 0.06), "iron", tilt=(-0.45, -sx * 0.60), verts=4))

    return p


def specs():
    out = []
    for kind, fn in (
        ("runner", runner),
        ("brute", brute),
        ("swarm", swarm),
        ("shieldbearer", shieldbearer),
        ("pyromancer", pyromancer),
        ("sapper", sapper),
    ):
        out.append(
            {
                "id": f"horde.{kind}.01",
                "name": f"CMD_{kind}",
                "glb": f"horde_{kind}.glb",
                "tipo": "prop_estatico",
                "limite": LIMITE,
                "tags": ["muralha", "horde", kind],
                "build": fn,
            }
        )
    return out


L.run_group("horde", specs(), "torso/capuz esculpido da horda hibrida (art/scripts/make_horde.py)")
