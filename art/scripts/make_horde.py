"""Gera os troncos/capuzes/carapacas esculpidos AA da horda (CMD_runner, CMD_brute, CMD_swarm,
CMD_shieldbearer, CMD_pyromancer, CMD_sapper, CMD_wisp, CMD_drake) para Forge3D 0.9.0 spec@6.

Desenho hibrido articulado: a malha Open Cloud contem o torso, armadura em camadas,
ombreiras/raizes de asas e cabeca/capuz/chifres, para que o HordeKit.luau articule membros e
satelites a 60 Hz em torno do pivo. Sem matiz na faixa 30..55 deg (lei cromatica do GDD).

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

import bmesh
import bpy

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 3400
SUAVIZACAO_HORDE = {
    "modo": "hard_surface",
    "angulo_graus": 48,
    "weighted_normals": True,
    "corrective_smooth": False,
}
SCALE = {
    "runner": 0.85,
    "brute": 1.35,
    "swarm": 0.65,
    "shieldbearer": 1.12,
    "pyromancer": 0.95,
    "sapper": 0.88,
    "wisp": 0.72,
    "drake": 1.18,
}  # VisualTheme.ENEMIES[*].scale


class Rb:
    """Constroi em coordenadas Roblox escaladas por scale*1.8 (frente -Z -> Blender -Y)."""

    def __init__(self, kind):
        self.k = SCALE[kind] * 1.8

    def p(self, x, y, z):
        return (-x * self.k, z * self.k, y * self.k)

    def box(self, size, pos, color, rot_bl=(0.0, 0.0, 0.0), bevel=0.0):
        return L.box(
            (size[0] * self.k, size[2] * self.k, size[1] * self.k),
            self.p(*pos),
            color,
            bevel=bevel * self.k if bevel > 0 else 0.0,
            rot=rot_bl,
        )

    def taper_plate(self, w0, d0, w1, d1, h, base_pos, color, bevel=0.0):
        cx, cy, cz = self.p(*base_pos)
        hw0, hd0 = w0 * self.k * 0.5, d0 * self.k * 0.5
        hw1, hd1 = w1 * self.k * 0.5, d1 * self.k * 0.5
        hh = h * self.k
        pts = (
            (-hw0, -hd0, 0.0),
            (hw0, -hd0, 0.0),
            (hw0, hd0, 0.0),
            (-hw0, hd0, 0.0),
            (-hw1, -hd1, hh),
            (hw1, -hd1, hh),
            (hw1, hd1, hh),
            (-hw1, hd1, hh),
        )
        bm = bmesh.new()
        vs = [bm.verts.new((cx + px, cy + py, cz + pz)) for px, py, pz in pts]
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            bm.faces.new([vs[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        me = bpy.data.meshes.new("rb_taper")
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new("rb_taper", me)
        bpy.context.collection.objects.link(obj)
        if bevel > 0.0:
            return L._finish(obj, color, bevel=bevel * self.k)
        return L.paint(obj, color)

    def ball(self, diam, pos, color, seg=18, rings=12, squash=(1.0, 1.0, 1.0)):
        return L.ball(
            diam / 2 * self.k,
            self.p(*pos),
            color,
            seg=seg,
            rings=rings,
            squash=(squash[0], squash[2], squash[1]),
        )

    def ico(self, rad, pos, color, squash=(1.0, 1.0, 1.0), subdiv=2):
        return L.ico(
            rad * self.k,
            self.p(*pos),
            color,
            squash=(squash[0], squash[2], squash[1]),
            subdiv=subdiv,
        )

    def cyl(self, r, h, base, color, verts=18, r2=None, rot_z=0.0):
        return L.cyl(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            rot_z=rot_z,
        )

    def crystal(self, r, h, base, color, tilt=(0.0, 0.0), verts=6, r2=0.0, spin=0.0):
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

    def torus(
        self,
        r_major,
        r_minor,
        pos,
        color,
        major_seg=18,
        minor_seg=6,
        rot=(0.0, 0.0, 0.0),
        squash=(1.0, 1.0, 1.0),
    ):
        return L.torus(
            r_major * self.k,
            r_minor * self.k,
            self.p(*pos),
            color,
            major_seg=major_seg,
            minor_seg=minor_seg,
            rot=rot,
            squash=(squash[0], squash[2], squash[1]),
        )

    def capsule_seg(self, p0, p1, r0, r1, color, verts=12, cap_ends=False):
        return L.capsule_seg(
            self.p(*p0),
            self.p(*p1),
            r0 * self.k,
            r1 * self.k,
            color,
            verts=verts,
            cap_ends=cap_ends,
        )


def runner():
    """Spectral Stalker Wraith: manto em camadas, tassets, costelas arcanas, ombreiras e capuz cornudo."""
    r = Rb("runner")
    p = []

    # Saia conica + pontas esfarrapadas + tassets laterais + cinto chanfrado com gema runica
    p.append(r.cyl(0.80, 0.88, (0, 0.25, 0), "tealDark", r2=0.48))
    for k in range(10):
        a = 2 * math.pi * k / 10
        p.append(
            r.crystal(
                0.15,
                0.68,
                (0.64 * math.cos(a), 0.56, 0.64 * math.sin(a)),
                "teal" if k % 2 == 0 else "tealDark",
                tilt=(-math.pi + 0.34 * math.sin(a), 0.34 * math.cos(a)),
                verts=5,
            )
        )
    for sx in (-1, 1):
        p.append(r.taper_plate(0.32, 0.42, 0.24, 0.34, 0.56, (sx * 0.52, 0.52, -0.02), "ironDark", bevel=0.02))

    p.append(r.cyl(0.54, 0.22, (0, 0.94, 0), "ironDark", r2=0.50))
    p.append(r.torus(0.53, 0.055, (0, 1.04, 0), "tealSwarm", major_seg=18, minor_seg=6))
    p.append(r.box((0.26, 0.20, 0.14), (0, 1.04, -0.52), "steel", bevel=0.02))
    p.append(r.ico(0.08, (0, 1.04, -0.59), "eyeNeon", subdiv=1))

    # Torso + peitoral em camadas + costelas espectrais + ombreiras cortantes
    p.append(r.ico(0.56, (0, 1.46, -0.02), "teal", squash=(1.05, 1.15, 0.80)))
    p.append(r.ico(0.45, (0, 1.38, 0.20), "tealDark", squash=(0.88, 1.02, 0.68)))
    for dy, dz, sz in ((1.18, 0.34, 0.42), (1.46, 0.38, 0.48), (1.74, 0.34, 0.44), (1.98, 0.26, 0.36)):
        p.append(r.crystal(0.12, sz, (0, dy, dz), "ironDark", tilt=(-1.05, 0.0), verts=5))
    for idx, ry in enumerate((1.24, 1.46, 1.68)):
        w = 0.36 + idx * 0.05
        for sx in (-1, 1):
            p.append(r.capsule_seg((sx * 0.08, ry, -0.34), (sx * w, ry + 0.06, -0.18), 0.06, 0.04, "tealSwarm", verts=10))
    for sx in (-1, 1):
        p.append(r.ico(0.32, (sx * 0.56, 1.78, 0.0), "ironDark", squash=(1.0, 0.72, 1.08), subdiv=1))
        p.append(r.crystal(0.12, 0.42, (sx * 0.66, 1.88, 0.04), "steel", tilt=(-0.2, -sx * 0.85), verts=5))

    # Gola gorjal + capuz pontiagudo + mascara de ferro + olhos neon + chifres curvos
    p.append(r.cyl(0.64, 0.32, (0, 1.82, 0.02), "tealDark", r2=0.45))
    p.append(r.torus(0.48, 0.06, (0, 1.96, -0.02), "iron", major_seg=18, minor_seg=5))
    p.append(r.ball(0.94, (0, 2.28, -0.02), "teal", seg=16, rings=10, squash=(0.95, 1.05, 1.12)))
    p.append(r.torus(0.38, 0.058, (0, 2.22, -0.28), "tealDark", major_seg=16, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(r.crystal(0.40, 0.90, (0, 2.40, 0.16), "tealDark", tilt=(-0.92, 0.0), verts=8))
    p.append(r.ball(0.60, (0, 2.24, -0.28), "ironDark", seg=14, rings=8, squash=(0.92, 0.88, 0.72)))
    p.append(r.box((0.36, 0.24, 0.14), (0, 2.10, -0.52), "steel", bevel=0.015))
    for sx in (-1, 1):
        p.append(r.ico(0.12, (sx * 0.16, 2.24, -0.56), "eyeNeon", squash=(1.35, 0.68, 0.72), subdiv=1))
        p.append(r.capsule_seg((sx * 0.22, 2.52, -0.02), (sx * 0.42, 2.84, 0.22), 0.11, 0.06, "iron", verts=10))
        p.append(r.capsule_seg((sx * 0.42, 2.84, 0.22), (sx * 0.56, 3.16, 0.48), 0.06, 0.015, "steel", verts=10))

    return p


def brute():
    """Horned Rift Juggernaut: cintura blindada, placas de peitoral em camadas, ombreiras c/ espinhos e elmo."""
    b = Rb("brute")
    p = []

    p.append(b.cyl(0.66, 0.36, (0, 0.70, 0), "tealBruteDark", r2=0.60))
    p.append(b.torus(0.64, 0.075, (0, 0.86, 0), "iron", major_seg=18, minor_seg=6))
    p.append(b.box((0.38, 0.28, 0.16), (0, 0.88, -0.56), "steel", bevel=0.02))
    p.append(b.ico(0.22, (0, 0.88, -0.62), "tealSwarm", squash=(0.95, 0.85, 0.48), subdiv=1))
    for sx in (-1, 1):
        p.append(b.taper_plate(0.42, 0.46, 0.30, 0.34, 0.62, (sx * 0.54, 0.26, 0.0), "ironDark", bevel=0.025))
        p.append(b.crystal(0.20, 0.58, (sx * 0.60, 0.84, -0.08), "steel", tilt=(-math.pi, -sx * 0.28), verts=5))

    # Tronco musculoso + peitoral duplo chanfrado + nucleo da fenda + crista dorsal
    p.append(b.ico(0.76, (0, 1.38, 0.0), "tealBrute", squash=(1.18, 1.06, 0.84)))
    p.append(b.ico(0.50, (0, 1.56, 0.22), "tealBruteDark", squash=(1.05, 0.84, 0.72)))
    for sx in (-1, 1):
        p.append(b.ico(0.38, (sx * 0.34, 1.52, -0.34), "ironDark", squash=(0.92, 0.82, 0.54), subdiv=1))
        p.append(b.ico(0.28, (sx * 0.32, 1.54, -0.44), "steel", squash=(1.02, 0.78, 0.42), subdiv=1))
    p.append(b.torus(0.22, 0.05, (0, 1.38, -0.48), "ironDark", major_seg=14, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(b.crystal(0.12, 0.32, (0, 1.36, -0.52), "eyeNeon", tilt=(1.40, 0.0), verts=6))
    for k in range(4):
        p.append(b.crystal(0.14, 0.44, (0, 1.12 + k * 0.25, 0.48), "ironDark", tilt=(-1.05, 0.0), verts=5))

    # Ombreiras em 2 camadas + friso torus + chifres de ombro
    for sx in (-1, 1):
        p.append(b.ball(0.74, (sx * 0.78, 1.72, -0.02), "iron", seg=16, rings=10, squash=(1.05, 0.78, 1.02)))
        p.append(b.torus(0.38, 0.055, (sx * 0.78, 1.66, -0.02), "ironDark", major_seg=16, minor_seg=6, rot=(0.0, sx * 0.4, 0.0)))
        p.append(b.torus(0.32, 0.045, (sx * 0.82, 1.80, -0.02), "steel", major_seg=14, minor_seg=5, rot=(0.0, sx * 0.45, 0.0)))
        p.append(b.capsule_seg((sx * 0.80, 1.92, 0.0), (sx * 1.06, 2.38, 0.06), 0.12, 0.02, "steel", verts=10))
        p.append(b.crystal(0.11, 0.46, (sx * 0.96, 1.74, 0.14), "ironDark", tilt=(-0.38, -sx * 0.78), verts=5))

    # Elmo blindado + viseira + mandibula com presas + chifres curvos
    p.append(b.ico(0.46, (0, 2.12, -0.18), "tealBruteDark", squash=(0.96, 0.94, 1.04)))
    p.append(b.box((0.54, 0.24, 0.36), (0, 2.26, -0.30), "iron", bevel=0.025))
    p.append(b.crystal(0.11, 0.34, (0, 2.40, -0.22), "steel", tilt=(-0.35, 0.0), verts=4))
    p.append(b.ico(0.34, (0, 1.92, -0.30), "ironDark", squash=(0.88, 0.58, 0.78), subdiv=1))
    for sx in (-1, 1):
        p.append(b.ico(0.105, (sx * 0.16, 2.15, -0.52), "eyeNeon", squash=(1.35, 0.65, 0.65), subdiv=1))
        p.append(b.crystal(0.06, 0.24, (sx * 0.14, 1.92, -0.50), "white", tilt=(0.35, -sx * 0.14), verts=5))
        p.append(b.capsule_seg((sx * 0.26, 2.24, -0.14), (sx * 0.54, 2.46, -0.28), 0.13, 0.08, "ironDark", verts=10))
        p.append(b.capsule_seg((sx * 0.54, 2.46, -0.28), (sx * 0.68, 2.74, -0.52), 0.08, 0.02, "white", verts=10))

    return p


def swarm():
    """Phantom Skull Wisp: cranio espectral facetado, coroa de cristais, halo duplo e fios de ectoplasma."""
    w = Rb("swarm")
    p = []

    p.append(w.ball(0.84, (0, 1.38, -0.02), "tealSwarm", seg=16, rings=10, squash=(0.98, 1.04, 0.98)))
    p.append(w.ico(0.48, (0, 1.02, -0.14), "tealSwarmDark", squash=(0.84, 0.76, 0.84), subdiv=1))
    p.append(w.ball(0.64, (0, 1.38, -0.40), "ironDark", seg=14, rings=8, squash=(0.96, 0.68, 0.66)))
    p.append(w.torus(0.68, 0.055, (0, 1.04, 0.06), "arcaneViolet", major_seg=18, minor_seg=6, rot=(0.24, 0.0, 0.0)))
    p.append(w.torus(0.56, 0.042, (0, 1.72, 0.14), "arcaneCyan", major_seg=18, minor_seg=5, rot=(-0.38, 0.25, 0.0)))
    for sx in (-1, 1):
        p.append(w.ico(0.145, (sx * 0.22, 1.40, -0.66), "eyeNeon", squash=(1.25, 0.72, 0.68), subdiv=1))
        p.append(w.crystal(0.055, 0.18, (sx * 0.12, 1.04, -0.48), "white", tilt=(math.pi, 0.0), verts=4))
        p.append(w.ico(0.16, (sx * 0.56, 1.38, 0.02), "tealDark", squash=(0.75, 1.1, 0.9), subdiv=1))
        p.append(w.capsule_seg((sx * 0.30, 1.66, 0.0), (sx * 0.56, 2.02, 0.18), 0.13, 0.07, "tealDark", verts=10))
        p.append(w.capsule_seg((sx * 0.56, 2.02, 0.18), (sx * 0.72, 2.34, 0.40), 0.07, 0.015, "eyeNeon", verts=10))

    for k in range(5):
        p.append(
            w.crystal(
                0.12,
                0.48 - k * 0.05,
                (0, 1.82 - k * 0.22, 0.26 + k * 0.14),
                "arcaneCyan" if k % 2 == 0 else "tealSwarm",
                tilt=(-0.70 - k * 0.18, 0.0),
                verts=5,
            )
        )
    for k in range(6):
        a = 2 * math.pi * k / 6
        px, pz = 0.34 * math.cos(a), 0.34 * math.sin(a)
        p.append(w.capsule_seg((px, 0.86, pz), (px * 1.35, 0.36, pz * 1.35 + 0.18), 0.10, 0.02, "tealSwarmDark", verts=8))

    return p


def shieldbearer():
    """Escudeiro Bastiao: elmo com crista dupla, gorjal, ombreiras escalonadas e escudo-torre chanfrado."""
    s = Rb("shieldbearer")
    p = []

    p.append(s.cyl(0.64, 0.34, (0, 0.68, 0), "ironDark", r2=0.58))
    p.append(s.torus(0.62, 0.065, (0, 0.84, 0), "steel", major_seg=18, minor_seg=6))
    p.append(s.ico(0.24, (0, 0.86, -0.52), "teal", squash=(1.1, 0.8, 0.45), subdiv=1))
    for sx in (-1, 1):
        p.append(s.taper_plate(0.40, 0.42, 0.30, 0.32, 0.54, (sx * 0.52, 0.30, 0.0), "iron", bevel=0.02))

    # Peitoral em placas + gorjal alto + espinhos dorsais
    p.append(s.ico(0.68, (0, 1.36, 0.02), "iron", squash=(1.12, 1.05, 0.82)))
    p.append(s.ico(0.56, (0, 1.44, -0.22), "steel", squash=(1.02, 0.88, 0.55)))
    p.append(s.torus(0.48, 0.07, (0, 1.82, -0.02), "ironDark", major_seg=18, minor_seg=6))
    p.append(s.torus(0.42, 0.045, (0, 1.92, -0.04), "steel", major_seg=16, minor_seg=5))
    p.append(s.crystal(0.16, 0.44, (0, 1.32, -0.56), "teal", tilt=(1.42, 0.0), verts=5))
    for k in range(4):
        p.append(s.crystal(0.11, 0.36, (0, 1.12 + k * 0.24, 0.44), "ironDark", tilt=(-1.05, 0.0), verts=5))

    # Escudo-torre chanfrado com moldura de aco, rebites, umbo e runa
    sh_x, sh_y, sh_z = 0.22, 1.24, -0.56
    p.append(s.box((0.92, 1.22, 0.16), (sh_x, sh_y, sh_z - 0.02), "ironDark", bevel=0.04))
    p.append(s.box((1.04, 1.34, 0.10), (sh_x, sh_y, sh_z + 0.02), "steel", bevel=0.03))
    p.append(s.taper_plate(0.42, 0.14, 0.92, 0.16, 0.34, (sh_x, sh_y - 0.82, sh_z), "steel", bevel=0.02))
    p.append(s.torus(0.25, 0.05, (sh_x, sh_y, sh_z - 0.10), "teal", major_seg=16, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(s.crystal(0.14, 0.34, (sh_x, sh_y, sh_z - 0.12), "tealSwarm", tilt=(1.55, 0.0), verts=6))
    for rx in (-0.38, 0.38):
        for ry in (-0.48, 0.0, 0.48):
            p.append(s.ico(0.045, (sh_x + rx, sh_y + ry, sh_z - 0.08), "white", subdiv=0))

    # Ombreiras blindadas com camadas e aro torus
    for sx in (-1, 1):
        p.append(s.ball(0.68, (sx * 0.72, 1.66, 0.0), "iron", seg=14, rings=9, squash=(1.08, 0.82, 0.98)))
        p.append(s.torus(0.32, 0.05, (sx * 0.74, 1.60, 0.0), "steel", major_seg=14, minor_seg=5, rot=(0.0, sx * 0.35, 0.0)))
        p.append(s.crystal(0.11, 0.46, (sx * 0.80, 1.88, 0.02), "steel", tilt=(0.0, -sx * 0.55), verts=5))

    # Elmo fechado com viseira luminosa e crista alta de 5 laminas
    p.append(s.ball(0.86, (0, 2.16, -0.06), "iron", seg=16, rings=10, squash=(0.96, 1.02, 1.06)))
    p.append(s.box((0.52, 0.22, 0.24), (0, 2.26, -0.34), "steel", bevel=0.02))
    p.append(s.ico(0.38, (0, 2.12, -0.34), "ironDark", squash=(1.05, 0.55, 0.48), subdiv=1))
    p.append(s.ico(0.18, (0, 2.14, -0.48), "eyeNeon", squash=(1.85, 0.36, 0.35), subdiv=1))
    for k in range(5):
        p.append(
            s.crystal(
                0.11,
                0.48 - k * 0.04,
                (0, 2.52 - k * 0.07, -0.10 + k * 0.16),
                "teal" if k % 2 == 0 else "steel",
                tilt=(-0.32 - k * 0.28, 0.0),
                verts=5,
            )
        )

    return p


def pyromancer():
    """Piroforjador: manto fluido, fornalha peitoral, braseiros de ombro, halo runico e chifres (sem 30..55 deg)."""
    y = Rb("pyromancer")
    p = []

    # Manto + cinto com braseiros de cintura (emberDeep / danger / crimsonBright -> fora de 30..55 deg)
    p.append(y.cyl(0.74, 0.84, (0, 0.28, 0), "stoneDark", r2=0.46))
    p.append(y.torus(0.50, 0.055, (0, 1.04, 0), "emberDeep", major_seg=18, minor_seg=6))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(
            y.crystal(
                0.15,
                0.56,
                (0.58 * math.cos(a), 0.54, 0.58 * math.sin(a)),
                "tealDark" if k % 2 == 0 else "ironDark",
                tilt=(-math.pi + 0.30 * math.sin(a), 0.30 * math.cos(a)),
                verts=5,
            )
        )

    # Fornalha peitoral com gaiola de ferro
    p.append(y.cyl(0.48, 0.20, (0, 0.96, 0), "ironDark", r2=0.46))
    p.append(y.ico(0.54, (0, 1.44, 0.02), "stoneDark", squash=(1.05, 1.12, 0.82)))
    p.append(y.ball(0.44, (0, 1.44, -0.30), "emberDeep", seg=14, rings=8, squash=(0.95, 1.10, 0.65)))
    p.append(y.torus(0.28, 0.05, (0, 1.44, -0.36), "ironDark", major_seg=16, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    for sx in (-1, 1):
        p.append(y.capsule_seg((sx * 0.24, 1.24, -0.34), (sx * 0.18, 1.64, -0.36), 0.045, 0.035, "ironDark", verts=8))
        # Braseiros montados nos ombros
        p.append(y.cyl(0.22, 0.24, (sx * 0.68, 1.72, 0.06), "ironDark", verts=12, r2=0.28))
        p.append(y.torus(0.26, 0.045, (sx * 0.68, 1.96, 0.06), "steel", major_seg=14, minor_seg=5))
        p.append(y.ico(0.17, (sx * 0.68, 1.98, 0.06), "emberDeep", subdiv=1))
        p.append(y.crystal(0.09, 0.28, (sx * 0.68, 2.08, 0.06), "danger", verts=5))

    # Colar runico flutuante torus + cristais orbitais
    p.append(y.torus(0.74, 0.045, (0, 1.92, 0.02), "crimsonBright", major_seg=18, minor_seg=6, rot=(0.15, 0.0, 0.0)))
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        p.append(
            y.crystal(
                0.095,
                0.38,
                (0.74 * math.cos(a), 1.92 + 0.05 * (k % 2), 0.66 * math.sin(a)),
                "emberDeep" if k % 2 == 0 else "tealSwarm",
                tilt=(-0.28 * math.sin(a), -0.28 * math.cos(a)),
                verts=5,
            )
        )

    # Gola alta + capuz de brasa + coroa de chifres
    p.append(y.cyl(0.58, 0.28, (0, 1.80, 0.04), "ironDark", r2=0.44))
    p.append(y.ball(0.88, (0, 2.24, -0.02), "stoneDark", seg=16, rings=10, squash=(0.96, 1.04, 1.12)))
    p.append(y.crystal(0.38, 0.84, (0, 2.38, 0.14), "crimsonCloth", tilt=(-0.88, 0.0), verts=8))
    p.append(y.ball(0.56, (0, 2.20, -0.28), "ironDark", seg=12, rings=8, squash=(0.92, 0.86, 0.72)))
    for sx in (-1, 1):
        p.append(y.ico(0.11, (sx * 0.15, 2.22, -0.54), "emberDeep", squash=(1.3, 0.65, 0.68), subdiv=1))
        p.append(y.capsule_seg((sx * 0.22, 2.48, -0.02), (sx * 0.42, 2.80, 0.18), 0.10, 0.055, "danger", verts=10))
        p.append(y.capsule_seg((sx * 0.42, 2.80, 0.18), (sx * 0.54, 3.10, 0.42), 0.055, 0.015, "emberDeep", verts=10))

    return p


def sapper():
    """Zapador: colete tatico, bandoleira de bombas, barril de polvora c/ valvula e oculos de demolicao."""
    z = Rb("sapper")
    p = []

    p.append(z.cyl(0.56, 0.28, (0, 0.74, 0), "ironDark", r2=0.52))
    p.append(z.torus(0.54, 0.055, (0, 0.88, 0), "steel", major_seg=18, minor_seg=5))
    p.append(z.ico(0.56, (0, 1.32, 0.0), "tealDark", squash=(1.04, 1.06, 0.82)))
    p.append(z.ico(0.46, (0, 1.36, -0.20), "iron", squash=(0.94, 0.92, 0.56)))
    # Bolsas laterais de cintura
    for sx in (-1, 1):
        p.append(z.box((0.20, 0.24, 0.22), (sx * 0.56, 0.92, -0.08), "furBrown", bevel=0.02))

    # Bandoleira diagonal de 5 granadas cilindricas cintadas
    p.append(z.box((0.96, 0.10, 0.10), (0, 1.32, -0.40), "furBrown", rot_bl=(0.0, 0.62, 0.0)))
    for k in range(5):
        t = (k - 2.0) / 2.0
        px, py, pz = t * 0.36, 1.38 - t * 0.25, -0.46
        p.append(z.capsule_seg((px - 0.04, py - 0.06, pz), (px + 0.04, py + 0.08, pz), 0.08, 0.08, "danger" if k % 2 == 0 else "steel", verts=10))
        p.append(z.ico(0.04, (px + 0.04, py + 0.09, pz - 0.02), "emberDeep", subdiv=0))

    # Caldeira/barril de polvora nas costas com aros torus de aco, valvula e pavio aceso
    p.append(z.cyl(0.44, 0.88, (0, 1.00, 0.50), "woodDark", verts=18, r2=0.41))
    for hy in (1.18, 1.44, 1.70):
        p.append(z.torus(0.44, 0.048, (0, hy, 0.50), "steel", major_seg=18, minor_seg=5))
    p.append(z.torus(0.16, 0.035, (0.44, 1.44, 0.50), "crimsonBright", major_seg=12, minor_seg=4, rot=(0.0, math.pi / 2, 0.0)))
    p.append(z.capsule_seg((0, 1.88, 0.50), (0, 2.20, 0.62), 0.05, 0.03, "ironDark", verts=8))
    p.append(z.ico(0.12, (0, 2.24, 0.64), "emberDeep", subdiv=1))

    for sx in (-1, 1):
        p.append(z.ico(0.32, (sx * 0.62, 1.62, 0.0), "ironDark", squash=(0.95, 0.75, 0.92), subdiv=1))
        p.append(z.torus(0.24, 0.04, (sx * 0.62, 1.60, 0.0), "steel", major_seg=12, minor_seg=4, rot=(0.0, sx * 0.4, 0.0)))

    # Capuz + respirador + oculos de demolicao (steel/crimsonBright torus + lentes eyeNeon)
    p.append(z.ball(0.84, (0, 2.08, -0.04), "tealDark", seg=16, rings=10, squash=(0.96, 1.0, 1.02)))
    p.append(z.ball(0.56, (0, 2.04, -0.26), "ironDark", seg=12, rings=8, squash=(0.94, 0.82, 0.72)))
    p.append(z.cyl(0.16, 0.18, (0, 1.88, -0.46), "steel", verts=10))
    for sx in (-1, 1):
        p.append(z.torus(0.145, 0.042, (sx * 0.18, 2.10, -0.49), "steel", major_seg=14, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
        p.append(z.ico(0.11, (sx * 0.18, 2.10, -0.54), "eyeNeon", squash=(0.95, 0.95, 0.55), subdiv=1))
        p.append(z.crystal(0.08, 0.36, (sx * 0.34, 2.34, 0.06), "iron", tilt=(-0.45, -sx * 0.60), verts=5))

    return p


def wisp():
    """Arcane Wisp: nucleo aninhado, capuzes flutuantes, 3 aneis runicos torus com gemas e cauda 3-pontas."""
    w = Rb("wisp")
    p = []

    p.append(w.ball(1.10, (0, 1.38, -0.04), "arcaneCyan", seg=16, rings=10, squash=(0.95, 1.08, 1.02)))
    p.append(w.ball(0.72, (0, 1.38, -0.14), "eyeNeon", seg=16, rings=10, squash=(0.92, 1.04, 0.95)))
    p.append(w.ico(0.44, (0, 1.36, -0.34), "tealDark", squash=(1.05, 0.78, 0.48), subdiv=1))
    for sx in (-1, 1):
        p.append(w.ico(0.115, (sx * 0.16, 1.40, -0.58), "iceGlow", squash=(1.35, 0.72, 0.68), subdiv=1))
        p.append(w.crystal(0.18, 0.76, (sx * 0.62, 1.18, 0.06), "obsidianLight", tilt=(-0.2, -sx * 0.35), verts=5))
        p.append(w.crystal(0.13, 0.56, (sx * 0.42, 1.54, 0.22), "tealDark", tilt=(-0.35, -sx * 0.25), verts=5))

    # 3 aneis runicos torus inclinados (arcaneViolet / arcaneCyan / iceGlow) com gemas orbitais
    p.append(w.torus(0.94, 0.055, (0, 1.38, 0.0), "arcaneViolet", major_seg=22, minor_seg=6, rot=(0.55, 0.45, 0.0)))
    p.append(w.torus(0.84, 0.052, (0, 1.38, 0.0), "arcaneCyan", major_seg=22, minor_seg=6, rot=(-0.60, -0.40, 0.30)))
    p.append(w.torus(0.68, 0.042, (0, 1.38, 0.0), "iceGlow", major_seg=20, minor_seg=5, rot=(0.18, -0.75, 0.20)))

    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.4
        col = "iceGlow" if k % 2 == 0 else "arcaneViolet"
        px, py, pz = 0.80 * math.cos(a), 1.38 + 0.24 * math.sin(2 * a), 0.80 * math.sin(a)
        p.append(w.crystal(0.12, 0.44, (px, py, pz), col, tilt=(-0.25 * math.sin(a), 0.25 * math.cos(a)), verts=6))
        p.append(w.ico(0.08, (px * 1.12, py, pz * 1.12), "eyeNeon", subdiv=0))

    # Cauda espectral 3-pontas para tras (+Z Roblox / +Y Blender) + gota inferior de pivo
    p.append(w.capsule_seg((0, 1.32, 0.18), (0, 1.16, 0.72), 0.32, 0.18, "teal", verts=12))
    p.append(w.capsule_seg((0, 1.16, 0.72), (0, 1.26, 1.28), 0.18, 0.03, "arcaneCyan", verts=12))
    for sx in (-1, 1):
        p.append(w.capsule_seg((sx * 0.22, 1.10, 0.22), (sx * 0.42, 0.84, 0.76), 0.16, 0.08, "tealDark", verts=10))
        p.append(w.capsule_seg((sx * 0.42, 0.84, 0.76), (sx * 0.18, 0.62, 1.18), 0.08, 0.015, "eyeNeon", verts=10))
    p.append(w.capsule_seg((0, 0.88, 0.02), (0, 0.42, 0.28), 0.18, 0.03, "tealDark", verts=10))

    return p


def drake():
    """Armored Rift Drake: peitoral escamado, raizes/laminas de asas esculpidas, pescoco S, chifres e presas."""
    d = Rb("drake")
    p = []

    # Torso draconico + escamas ventrais em camadas (crimson/wyvernScale -> fora de 30..55 deg)
    p.append(d.ball(1.18, (0, 1.14, 0.04), "obsidian", seg=18, rings=12, squash=(0.94, 0.90, 1.32)))
    for idx, (py, pz, rad) in enumerate(((0.76, -0.26, 0.30), (0.98, -0.38, 0.36), (1.24, -0.44, 0.40), (1.48, -0.46, 0.35))):
        col = "crimsonCloth" if idx % 2 == 0 else "wyvernScale"
        p.append(d.ico(rad, (0, py, pz), col, squash=(1.10, 0.68, 0.62), subdiv=1))
        for sx in (-1, 1):
            p.append(d.ico(rad * 0.62, (sx * 0.30, py, pz + 0.14), "obsidianLight", squash=(0.82, 0.68, 0.58), subdiv=1))
    for sx in (-1, 1):
        p.append(d.ico(0.34, (sx * 0.48, 1.42, 0.08), "obsidianLight", squash=(0.75, 0.90, 1.10), subdiv=1))
        p.append(d.torus(0.30, 0.048, (sx * 0.50, 1.46, 0.10), "steel", major_seg=14, minor_seg=5, rot=(0.0, sx * 0.45, 0.0)))
        # Raizes e pinhoes de asa esculpidos dobrados para tras (enquadram WingL/WingR do HordeKit sem alterar altura)
        p.append(d.capsule_seg((sx * 0.46, 1.48, 0.14), (sx * 1.02, 1.88, 0.46), 0.16, 0.10, "obsidianLight", verts=12))
        p.append(d.capsule_seg((sx * 1.02, 1.88, 0.46), (sx * 1.42, 2.04, 0.88), 0.10, 0.04, "steel", verts=10))
        p.append(d.crystal(0.085, 0.36, (sx * 1.02, 1.92, 0.46), "crimsonBright", tilt=(-0.4, -sx * 0.5), verts=5))
        for fy, fz, flen in ((1.78, 0.44, 0.64), (1.68, 0.58, 0.58), (1.56, 0.70, 0.50), (1.44, 0.82, 0.42)):
            p.append(d.capsule_seg((sx * 0.92, fy, fz), (sx * 1.32, fy - 0.38, fz + flen * 0.65), 0.08, 0.02, "wyvernWing", verts=8))
            p.append(d.capsule_seg((sx * 0.74, fy - 0.06, fz - 0.04), (sx * 1.12, fy - 0.36, fz + flen * 0.48), 0.06, 0.02, "crimsonCloth", verts=8))

    # Colar blindado de aco + pescoco sinuoso com placas de escamas
    p.append(d.torus(0.36, 0.055, (0, 1.62, -0.30), "steel", major_seg=18, minor_seg=6, rot=(0.62, 0.0, 0.0)))
    p.append(d.capsule_seg((0, 1.46, -0.24), (0, 1.86, -0.46), 0.36, 0.28, "obsidian", verts=14))
    p.append(d.capsule_seg((0, 1.86, -0.46), (0, 2.22, -0.58), 0.28, 0.24, "crimsonCloth", verts=14))
    for py, pz in ((1.68, -0.44), (1.96, -0.56), (2.14, -0.62)):
        p.append(d.ico(0.20, (0, py, pz), "wyvernScale", squash=(1.1, 0.55, 0.55), subdiv=1))

    # Cranio draconico voltado para -Y Blender (-Z Roblox) + presas + olhos brasa + chifres duplos
    p.append(d.ball(0.68, (0, 2.30, -0.74), "obsidian", seg=14, rings=8, squash=(0.88, 0.80, 1.14)))
    p.append(d.capsule_seg((0, 2.30, -0.84), (0, 2.24, -1.36), 0.23, 0.12, "crimsonCloth", verts=10))
    p.append(d.capsule_seg((0, 2.12, -0.82), (0, 2.10, -1.26), 0.18, 0.09, "obsidianLight", verts=10))
    p.append(d.crystal(0.06, 0.22, (0, 2.36, -1.26), "steel", tilt=(0.95, 0.0), verts=4))
    p.append(d.ico(0.14, (0, 2.20, -1.04), "emberDeep", squash=(0.85, 0.45, 1.25), subdiv=1))
    for sx in (-1, 1):
        p.append(d.ico(0.09, (sx * 0.20, 2.36, -0.96), "danger", squash=(1.2, 0.7, 0.8), subdiv=1))
        p.append(d.crystal(0.045, 0.14, (sx * 0.10, 2.22, -1.22), "white", tilt=(math.pi, 0.0), verts=4))
        p.append(d.capsule_seg((sx * 0.20, 2.46, -0.66), (sx * 0.36, 2.74, -0.32), 0.10, 0.055, "obsidianLight", verts=10))
        p.append(d.capsule_seg((sx * 0.36, 2.74, -0.32), (sx * 0.46, 2.98, 0.04), 0.055, 0.015, "white", verts=10))
        p.append(d.crystal(0.075, 0.28, (sx * 0.26, 2.24, -0.64), "steel", tilt=(-0.6, -sx * 0.65), verts=5))

    # Crista dorsal ao longo das costas e pescoco
    for sy, sz, h in ((1.02, 0.56, 0.36), (1.32, 0.36, 0.40), (1.68, -0.06, 0.36), (2.04, -0.34, 0.32), (2.40, -0.54, 0.28)):
        p.append(d.crystal(0.09, h, (0, sy, sz), "crimsonBright", tilt=(-0.82, 0.0), verts=5))

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
        ("wisp", wisp),
        ("drake", drake),
    ):
        out.append(
            {
                "id": f"horde.{kind}.01",
                "name": f"CMD_{kind}",
                "glb": f"horde_{kind}.glb",
                "tipo": "prop_estatico",
                "limite": LIMITE,
                "hero_pbr": False,
                "quantidade_cena": 6,
                "suavizacao_normais": SUAVIZACAO_HORDE,
                "tags": ["muralha", "horde", kind],
                "build": fn,
            }
        )
    return out


L.run_group("horde", specs(), "torso/capuz esculpido AA da horda hibrida (art/scripts/make_horde.py)", hero_pbr=False)
