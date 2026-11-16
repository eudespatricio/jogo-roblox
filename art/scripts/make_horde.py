"""Gera os troncos/capuzes/carapacas esculpidos AA da horda (CMD_runner, CMD_brute, CMD_swarm,
CMD_shieldbearer, CMD_pyromancer, CMD_sapper, CMD_wisp, CMD_drake) para Forge3D 0.9.0 spec@6.

Desenho hibrido articulado: a malha Open Cloud contem o torso, armadura em camadas,
ombreiras/raizes de asas, cajados/escudos/barris e cabeca/capuz/chifres, para que o HordeKit.luau
articule membros e satelites a 60 Hz em torno do pivo. Sem matiz na faixa 30..55 deg (lei cromatica do GDD).

Mapeamento Roblox -> Blender (frente -Z no Studio = -Y no Blender, encara -X no mundo): (x, y, z) -> (-x, z, y).

Uso headless:
  FORGE_SKIP_RENDER=1 blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_horde.py
Saidas: art/export/horde_<tipo>.glb, art/forge/lote_horde_import.yaml (gerado),
        art/renders/horde/*.png (ignorado no git)
"""

from __future__ import annotations

import colorsys
import json
import math
import os
import sys

import bmesh
import bpy

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

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


def _assert_horde_color(color: str) -> None:
    r, g, b = L.PAL[color]
    h, s, _ = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    deg = h * 360.0
    if s > 0.18 and 30.0 <= deg <= 55.0:
        raise ValueError(f"Cor '{color}' ({deg:.1f} deg) viola a lei cromatica da horda (proibido 30..55 deg)")


class Rb:
    """Constroi em coordenadas Roblox escaladas por scale*1.8 (frente -Z -> Blender -Y)."""

    def __init__(self, kind: str):
        self.k = SCALE[kind] * 1.8

    def p(self, x: float, y: float, z: float) -> tuple[float, float, float]:
        return (-x * self.k, z * self.k, y * self.k)

    def box(self, size, pos, color: str, rot_bl=(0.0, 0.0, 0.0), bevel: float = 0.0, bevel_segs: int = 1):
        _assert_horde_color(color)
        return L.box(
            (size[0] * self.k, size[2] * self.k, size[1] * self.k),
            self.p(*pos),
            color,
            bevel=bevel * self.k if bevel > 0 else 0.0,
            rot=rot_bl,
            bevel_segs=bevel_segs,
        )

    def taper_plate(self, w0, d0, w1, d1, h, base_pos, color: str, bevel: float = 0.0):
        _assert_horde_color(color)
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

    def wing_panel(self, ring_pts, hub_pt, thickness: float, color: str):
        """Membrana solida manifold em coordenadas Rb (sem bordas abertas)."""
        _assert_horde_color(color)
        bm = bmesh.new()
        dz = thickness * self.k * 0.5
        bl_ring = [self.p(*pt) for pt in ring_pts]
        hx, hy, hz = self.p(*hub_pt)
        vt = [bm.verts.new((px, py + dz, pz)) for px, py, pz in bl_ring]
        vb = [bm.verts.new((px, py - dz, pz)) for px, py, pz in bl_ring]
        ht = bm.verts.new((hx, hy + dz, hz))
        hb = bm.verts.new((hx, hy - dz, hz))
        n = len(bl_ring)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((ht, vt[i], vt[j]))
            bm.faces.new((hb, vb[j], vb[i]))
            bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        me = bpy.data.meshes.new("rb_wing_panel")
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new("rb_wing_panel", me)
        bpy.context.collection.objects.link(obj)
        return L.paint(obj, color)

    def ball(self, diam, pos, color: str, seg=18, rings=12, squash=(1.0, 1.0, 1.0)):
        _assert_horde_color(color)
        return L.ball(
            diam / 2 * self.k,
            self.p(*pos),
            color,
            seg=seg,
            rings=rings,
            squash=(squash[0], squash[2], squash[1]),
        )

    def ico(self, rad, pos, color: str, squash=(1.0, 1.0, 1.0), subdiv=2):
        _assert_horde_color(color)
        return L.ico(
            rad * self.k,
            self.p(*pos),
            color,
            squash=(squash[0], squash[2], squash[1]),
            subdiv=subdiv,
        )

    def cyl(self, r, h, base, color: str, verts=18, r2=None, rot_z=0.0, bevel=0.0):
        _assert_horde_color(color)
        return L.cyl(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            rot_z=rot_z,
            bevel=bevel * self.k if bevel > 0 else 0.0,
        )

    def crystal(self, r, h, base, color: str, tilt=(0.0, 0.0), verts=6, r2=0.0, spin=0.0):
        _assert_horde_color(color)
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
        color: str,
        major_seg=18,
        minor_seg=6,
        rot=(0.0, 0.0, 0.0),
        squash=(1.0, 1.0, 1.0),
    ):
        _assert_horde_color(color)
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

    def capsule_seg(self, p0, p1, r0, r1, color: str, verts=12, cap_ends=False):
        _assert_horde_color(color)
        return L.capsule_seg(
            self.p(*p0),
            self.p(*p1),
            r0 * self.k,
            r1 * self.k,
            color,
            verts=verts,
            cap_ends=cap_ends,
        )


def swarm():
    """Phantom Skull Wisp (~1,650 tris): cranio espectral esculpido, mandibula dentada, coroa arcana, halos e ectoplasma."""
    w = Rb("swarm")
    p = []

    # Cranio espectral + mascara frontal + mandibula inferior esculpida
    p.append(w.ball(0.86, (0, 1.38, -0.04), "tealSwarm", seg=18, rings=11, squash=(0.98, 1.04, 0.98)))
    p.append(w.ico(0.48, (0, 1.02, -0.16), "tealSwarmDark", squash=(0.84, 0.76, 0.84), subdiv=1))
    p.append(w.ball(0.64, (0, 1.38, -0.40), "ironDark", seg=14, rings=9, squash=(0.96, 0.68, 0.66)))
    p.append(w.ico(0.11, (0, 1.62, -0.60), "arcaneCyan", squash=(0.75, 1.15, 0.60), subdiv=1))

    # Halos runicos cruzados com fragmentos orbitais
    p.append(w.torus(0.68, 0.055, (0, 1.04, 0.04), "arcaneViolet", major_seg=18, minor_seg=6, rot=(0.24, 0.0, 0.0)))
    p.append(w.torus(0.56, 0.044, (0, 1.72, -0.04), "arcaneCyan", major_seg=18, minor_seg=5, rot=(-0.32, 0.24, 0.0)))
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.45
        p.append(w.ico(0.065, (0.72 * math.cos(a), 1.06, 0.72 * math.sin(a)), "eyeNeon", subdiv=0))

    # Viseira dupla neon + arcadas zigomaticas + presas + chifres espectrais
    for sx in (-1, 1):
        p.append(w.ico(0.148, (sx * 0.22, 1.40, -0.66), "eyeNeon", squash=(1.28, 0.72, 0.68), subdiv=1))
        p.append(w.capsule_seg((sx * 0.10, 1.54, -0.58), (sx * 0.36, 1.48, -0.46), 0.055, 0.04, "steel", verts=8))
        p.append(w.crystal(0.055, 0.19, (sx * 0.13, 1.04, -0.50), "white", tilt=(math.pi, 0.0), verts=4))
        p.append(w.crystal(0.045, 0.15, (sx * 0.24, 1.08, -0.44), "white", tilt=(math.pi - 0.15, 0.0), verts=4))
        p.append(w.ico(0.16, (sx * 0.56, 1.38, -0.02), "tealDark", squash=(0.75, 1.1, 0.9), subdiv=1))
        p.append(w.capsule_seg((sx * 0.28, 1.66, -0.08), (sx * 0.52, 2.02, -0.02), 0.13, 0.07, "tealDark", verts=10))
        p.append(w.capsule_seg((sx * 0.52, 2.02, -0.02), (sx * 0.66, 2.34, 0.06), 0.07, 0.022, "eyeNeon", verts=10))

    # Coroa frontal/dorsal de cristais arcanos (equilibrada em -Z para orientacao G2)
    p.append(w.crystal(0.12, 0.44, (0, 1.88, -0.28), "eyeNeon", tilt=(0.35, 0.0), verts=6))
    for k in range(5):
        p.append(
            w.crystal(
                0.115,
                0.46 - k * 0.05,
                (0, 1.82 - k * 0.22, 0.12 + k * 0.13),
                "arcaneCyan" if k % 2 == 0 else "tealSwarm",
                tilt=(-0.62 - k * 0.18, 0.0),
                verts=5,
            )
        )
    # 7 tentaculos de ectoplasma inferiores
    for k in range(7):
        a = 2 * math.pi * k / 7
        px, pz = 0.34 * math.cos(a), 0.34 * math.sin(a)
        p.append(w.capsule_seg((px, 0.86, pz), (px * 1.32, 0.36, pz * 1.28 + 0.10), 0.095, 0.025, "tealSwarmDark", verts=8))

    return p


def runner():
    """Spectral Stalker Wraith (~3,100 tris): tabardo runico, adagas, manto em laminas, costelas e capuz cornudo."""
    r = Rb("runner")
    p = []

    # Saia conica + tabardo runico frontal mais baixo (-Z garante G2 personagem_humanoide limpo e altura ~4.95)
    p.append(r.cyl(0.78, 0.80, (0, 0.36, 0.04), "tealDark", verts=20, r2=0.48))
    p.append(r.taper_plate(0.38, 0.10, 0.28, 0.10, 0.94, (0, 0.02, -0.52), "teal", bevel=0.018))
    p.append(r.crystal(0.11, 0.16, (0, 0.18, -0.54), "arcaneCyan", tilt=(math.pi, 0.0), verts=5))
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.append(
            r.crystal(
                0.145,
                0.48,
                (0.63 * math.cos(a), 0.76, 0.63 * math.sin(a) + 0.04),
                "teal" if k % 2 == 0 else "tealDark",
                tilt=(-math.pi + 0.30 * math.sin(a), 0.30 * math.cos(a)),
                verts=6,
            )
        )
    for sx in (-1, 1):
        p.append(r.taper_plate(0.34, 0.44, 0.24, 0.34, 0.56, (sx * 0.52, 0.52, -0.02), "ironDark", bevel=0.022))
        p.append(r.taper_plate(0.28, 0.36, 0.20, 0.28, 0.34, (sx * 0.56, 0.74, -0.02), "steel", bevel=0.018))
        # Bolsas taticas e adagas de arremesso no cinto
        p.append(r.box((0.16, 0.22, 0.18), (sx * 0.48, 0.98, -0.24), "furBrown", bevel=0.018))
        p.append(r.capsule_seg((sx * 0.34, 1.10, -0.44), (sx * 0.44, 0.82, -0.48), 0.04, 0.018, "steel", verts=8))

    # Cinto blindado + fivela runica
    p.append(r.cyl(0.54, 0.22, (0, 0.94, 0), "ironDark", verts=18, r2=0.50))
    p.append(r.torus(0.53, 0.055, (0, 1.04, 0), "tealSwarm", major_seg=18, minor_seg=5))
    p.append(r.box((0.28, 0.22, 0.14), (0, 1.04, -0.52), "steel", bevel=0.02))
    p.append(r.ico(0.085, (0, 1.04, -0.59), "eyeNeon", subdiv=1))

    # Torso + peitoral em camadas + costelas espectrais + nucleo do esterno
    p.append(r.ico(0.56, (0, 1.46, -0.02), "teal", squash=(1.05, 1.15, 0.80), subdiv=2))
    p.append(r.ico(0.45, (0, 1.38, 0.20), "tealDark", squash=(0.88, 1.02, 0.68), subdiv=1))
    p.append(r.torus(0.16, 0.038, (0, 1.50, -0.40), "steel", major_seg=14, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(r.ico(0.09, (0, 1.50, -0.43), "arcaneCyan", subdiv=1))
    for dy, dz, sz in ((1.14, 0.34, 0.42), (1.38, 0.38, 0.48), (1.62, 0.36, 0.46), (1.86, 0.32, 0.42), (2.06, 0.24, 0.34)):
        p.append(r.crystal(0.12, sz, (0, dy, dz), "ironDark", tilt=(-1.05, 0.0), verts=6))
    for idx, ry in enumerate((1.20, 1.38, 1.56, 1.74)):
        w = 0.35 + idx * 0.045
        for sx in (-1, 1):
            p.append(r.capsule_seg((sx * 0.10, ry, -0.35), (sx * w, ry + 0.06, -0.16), 0.058, 0.038, "tealSwarm", verts=10))

    # Ombreiras laminadas em 2 camadas com aro e espinhos gemeos
    for sx in (-1, 1):
        p.append(r.ico(0.34, (sx * 0.56, 1.78, 0.0), "ironDark", squash=(1.04, 0.74, 1.08), subdiv=1))
        p.append(r.ico(0.27, (sx * 0.62, 1.66, -0.02), "iron", squash=(0.96, 0.68, 0.96), subdiv=1))
        p.append(r.torus(0.28, 0.04, (sx * 0.58, 1.74, 0.0), "steel", major_seg=14, minor_seg=5, rot=(0.0, sx * 0.42, 0.0)))
        p.append(r.crystal(0.12, 0.44, (sx * 0.66, 1.90, 0.04), "steel", tilt=(-0.2, -sx * 0.85), verts=6))
        p.append(r.crystal(0.085, 0.32, (sx * 0.72, 1.74, 0.14), "tealSwarm", tilt=(-0.45, -sx * 0.95), verts=5))

    # Gola gorjal + capuz pontiagudo + mascara de ferro + viseira neon + chifres triplos
    p.append(r.cyl(0.64, 0.32, (0, 1.82, 0.02), "tealDark", verts=16, r2=0.45))
    p.append(r.torus(0.48, 0.06, (0, 1.96, -0.02), "iron", major_seg=16, minor_seg=5))
    p.append(r.ball(0.94, (0, 2.28, -0.02), "teal", seg=16, rings=10, squash=(0.95, 1.05, 1.12)))
    p.append(r.torus(0.38, 0.058, (0, 2.22, -0.28), "tealDark", major_seg=18, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(r.crystal(0.40, 0.90, (0, 2.40, 0.16), "tealDark", tilt=(-0.92, 0.0), verts=8))
    p.append(r.ball(0.60, (0, 2.24, -0.28), "ironDark", seg=14, rings=9, squash=(0.92, 0.88, 0.72)))
    p.append(r.box((0.36, 0.24, 0.14), (0, 2.10, -0.52), "steel", bevel=0.018))
    for sx in (-1, 1):
        p.append(r.ico(0.125, (sx * 0.16, 2.24, -0.56), "eyeNeon", squash=(1.38, 0.68, 0.72), subdiv=1))
        p.append(r.torus(0.115, 0.03, (sx * 0.22, 2.52, -0.02), "steel", major_seg=10, minor_seg=4))
        p.append(r.capsule_seg((sx * 0.22, 2.52, -0.02), (sx * 0.42, 2.84, 0.20), 0.11, 0.065, "iron", verts=12))
        p.append(r.capsule_seg((sx * 0.42, 2.84, 0.20), (sx * 0.56, 3.16, 0.44), 0.065, 0.022, "steel", verts=12))

    return p


def wisp():
    """Arcane Wisp (~3,100 tris): nucleo duplo, coroa arcana frontal, 4 aneis giroscopicos e cauda 5-fluxos."""
    w = Rb("wisp")
    p = []

    # Nucleo arcano aninhado + mascara de obsidiana + viseira tripla luminosa
    p.append(w.ball(1.10, (0, 1.38, -0.04), "arcaneCyan", seg=22, rings=14, squash=(0.95, 1.08, 1.02)))
    p.append(w.ball(0.74, (0, 1.38, -0.16), "eyeNeon", seg=18, rings=12, squash=(0.92, 1.04, 0.95)))
    p.append(w.ico(0.45, (0, 1.36, -0.36), "obsidian", squash=(1.06, 0.80, 0.50), subdiv=1))
    p.append(w.ico(0.11, (0, 1.56, -0.54), "eyeNeon", squash=(0.82, 1.22, 0.65), subdiv=1))
    for sx in (-1, 1):
        p.append(w.ico(0.12, (sx * 0.17, 1.40, -0.58), "iceGlow", squash=(1.38, 0.72, 0.68), subdiv=1))
        p.append(w.crystal(0.18, 0.78, (sx * 0.62, 1.18, -0.02), "obsidianLight", tilt=(-0.15, -sx * 0.35), verts=6))
        p.append(w.crystal(0.14, 0.58, (sx * 0.46, 1.52, -0.06), "tealDark", tilt=(0.15, -sx * 0.28), verts=6))
        p.append(w.crystal(0.11, 0.46, (sx * 0.54, 1.36, 0.22), "arcaneViolet", tilt=(-0.38, -sx * 0.42), verts=5))

    # Coroa superior de 5 cristais voltados para a frente (-Z garante G2 criatura limpo)
    for k in (-2, -1, 0, 1, 2):
        p.append(
            w.crystal(
                0.105 - abs(k) * 0.012,
                0.44 - abs(k) * 0.05,
                (k * 0.16, 1.80 - abs(k) * 0.05, -0.24 - (2 - abs(k)) * 0.05),
                "iceGlow" if k % 2 == 0 else "arcaneCyan",
                tilt=(0.28, -k * 0.22),
                verts=6,
            )
        )

    # 4 aneis giroscopicos runicos com engastes e prismas orbitais
    p.append(w.torus(0.95, 0.055, (0, 1.38, -0.02), "arcaneViolet", major_seg=24, minor_seg=8, rot=(0.55, 0.45, 0.0)))
    p.append(w.torus(0.85, 0.052, (0, 1.38, -0.02), "arcaneCyan", major_seg=24, minor_seg=8, rot=(-0.60, -0.40, 0.30)))
    p.append(w.torus(0.72, 0.044, (0, 1.38, -0.04), "iceGlow", major_seg=22, minor_seg=6, rot=(0.18, -0.75, 0.20)))
    p.append(w.torus(0.62, 0.038, (0, 1.38, -0.04), "obsidianLight", major_seg=20, minor_seg=6, rot=(1.15, 0.20, 0.0)))
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.35
        col = "iceGlow" if k % 2 == 0 else "arcaneViolet"
        px, py, pz = 0.84 * math.cos(a), 1.38 + 0.22 * math.sin(2 * a), 0.80 * math.sin(a) - 0.04
        p.append(w.crystal(0.115, 0.42, (px, py, pz), col, tilt=(-0.25 * math.sin(a), 0.25 * math.cos(a)), verts=6))
        p.append(w.ico(0.075, (px * 1.12, py, pz * 1.12), "eyeNeon", subdiv=0))
        if k % 2 == 0:
            p.append(w.ico(0.085, (px * 0.96, py, pz * 0.96), "obsidian", subdiv=1))

    # Cauda espectral espiralada de 5 fluxos
    p.append(w.capsule_seg((0, 1.32, 0.16), (0, 1.16, 0.72), 0.32, 0.18, "teal", verts=14))
    p.append(w.capsule_seg((0, 1.16, 0.72), (0, 1.24, 1.28), 0.18, 0.032, "arcaneCyan", verts=12))
    for sx in (-1, 1):
        p.append(w.capsule_seg((sx * 0.22, 1.10, 0.20), (sx * 0.44, 0.84, 0.76), 0.16, 0.08, "tealDark", verts=12))
        p.append(w.capsule_seg((sx * 0.44, 0.84, 0.76), (sx * 0.20, 0.62, 1.18), 0.08, 0.024, "eyeNeon", verts=10))
        p.append(w.capsule_seg((sx * 0.16, 0.96, -0.08), (sx * 0.30, 0.56, 0.36), 0.11, 0.026, "arcaneViolet", verts=10))
    p.append(w.capsule_seg((0, 0.88, 0.02), (0, 0.42, 0.24), 0.18, 0.03, "tealDark", verts=12))

    return p


def brute():
    """Horned Rift Juggernaut (~4,400 tris): ombreiras pesadas 3-camadas, cintos/correntes, reator peitoral e elmo."""
    b = Rb("brute")
    p = []

    # Cintura blindada + cinturao rebitado + avental de placas frontal (-Z garante G2 limpo e preserva altura ~6.1)
    p.append(b.cyl(0.66, 0.36, (0, 0.70, 0.02), "tealBruteDark", verts=18, r2=0.60))
    p.append(b.torus(0.64, 0.078, (0, 0.86, 0.02), "iron", major_seg=18, minor_seg=6))
    p.append(b.torus(0.62, 0.048, (0, 0.74, 0.02), "steel", major_seg=16, minor_seg=5))
    p.append(b.box((0.40, 0.30, 0.18), (0, 0.88, -0.56), "steel", bevel=0.025))
    p.append(b.ico(0.22, (0, 0.88, -0.63), "tealSwarm", squash=(0.95, 0.85, 0.48), subdiv=1))
    # Fauld / guarda frontal escalonada
    p.append(b.taper_plate(0.42, 0.12, 0.32, 0.10, 0.56, (0, 0.22, -0.54), "ironDark", bevel=0.02))
    p.append(b.taper_plate(0.34, 0.12, 0.26, 0.10, 0.36, (0, 0.42, -0.56), "steel", bevel=0.018))

    for sx in (-1, 1):
        p.append(b.taper_plate(0.42, 0.46, 0.30, 0.34, 0.52, (sx * 0.54, 0.36, 0.02), "ironDark", bevel=0.025))
        p.append(b.taper_plate(0.36, 0.38, 0.26, 0.30, 0.34, (sx * 0.58, 0.58, 0.02), "iron", bevel=0.02))
        p.append(b.crystal(0.19, 0.48, (sx * 0.62, 0.86, -0.06), "steel", tilt=(-math.pi, -sx * 0.28), verts=5))
        for ci in range(2):
            p.append(
                b.torus(
                    0.075,
                    0.024,
                    (sx * 0.42, 0.72 - ci * 0.14, -0.44),
                    "steel",
                    major_seg=8,
                    minor_seg=4,
                    rot=(0.0, (ci % 2) * 1.4, 0.0),
                )
            )

    # Tronco musculoso + placas peitorais rebitadas + correntes cruzadas + reator da fenda + espinhos dorsais
    p.append(b.ico(0.76, (0, 1.38, 0.0), "tealBrute", squash=(1.18, 1.06, 0.84), subdiv=2))
    p.append(b.ico(0.52, (0, 1.56, 0.22), "tealBruteDark", squash=(1.05, 0.86, 0.72), subdiv=1))
    for sx in (-1, 1):
        p.append(b.ico(0.40, (sx * 0.34, 1.52, -0.34), "ironDark", squash=(0.94, 0.84, 0.54), subdiv=1))
        p.append(b.ico(0.30, (sx * 0.32, 1.54, -0.44), "steel", squash=(1.02, 0.78, 0.42), subdiv=1))
        p.append(b.capsule_seg((sx * 0.58, 1.82, -0.22), (0, 1.38, -0.48), 0.052, 0.045, "iron", verts=8))
        p.append(b.capsule_seg((sx * 0.54, 1.78, 0.28), (0, 1.34, 0.44), 0.052, 0.045, "iron", verts=8))
        for ry in (1.38, 1.66):
            p.append(b.ico(0.045, (sx * 0.46, ry, -0.44), "white", subdiv=0))
    p.append(b.torus(0.24, 0.055, (0, 1.38, -0.48), "ironDark", major_seg=16, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(b.torus(0.17, 0.035, (0, 1.38, -0.52), "steel", major_seg=12, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(b.crystal(0.13, 0.34, (0, 1.36, -0.53), "eyeNeon", tilt=(1.42, 0.0), verts=6))
    for k in range(5):
        p.append(b.crystal(0.135, 0.46, (0, 1.06 + k * 0.23, 0.46 - k * 0.02), "ironDark", tilt=(-1.05, 0.0), verts=5))

    # Ombreiras colossais em 3 camadas com aros torus, rebites e 3 chifres por ombro
    for sx in (-1, 1):
        p.append(b.ball(0.76, (sx * 0.78, 1.72, -0.02), "iron", seg=16, rings=10, squash=(1.06, 0.80, 1.02)))
        p.append(b.ball(0.62, (sx * 0.88, 1.54, -0.02), "ironDark", seg=12, rings=8, squash=(1.02, 0.72, 0.96)))
        p.append(b.ico(0.34, (sx * 0.72, 1.90, -0.02), "steel", squash=(0.95, 0.65, 0.92), subdiv=1))
        p.append(b.torus(0.39, 0.055, (sx * 0.78, 1.66, -0.02), "ironDark", major_seg=16, minor_seg=5, rot=(0.0, sx * 0.4, 0.0)))
        p.append(b.torus(0.33, 0.045, (sx * 0.82, 1.80, -0.02), "steel", major_seg=14, minor_seg=5, rot=(0.0, sx * 0.45, 0.0)))
        for ang in (-0.65, 0.0, 0.65):
            p.append(b.ico(0.045, (sx * 0.98, 1.66 + 0.14 * math.sin(ang), 0.26 * math.cos(ang)), "white", subdiv=0))
        p.append(b.capsule_seg((sx * 0.80, 1.92, 0.0), (sx * 1.06, 2.38, 0.06), 0.125, 0.025, "steel", verts=10))
        p.append(b.crystal(0.115, 0.48, (sx * 0.98, 1.74, 0.14), "ironDark", tilt=(-0.38, -sx * 0.78), verts=5))
        p.append(b.crystal(0.095, 0.38, (sx * 0.96, 1.68, -0.22), "steel", tilt=(0.35, -sx * 0.82), verts=5))

    # Elmo blindado + gorjal + viseira + queixeira com 4 presas + chifres anelados
    p.append(b.torus(0.46, 0.065, (0, 1.92, -0.10), "ironDark", major_seg=16, minor_seg=5))
    p.append(b.ball(0.94, (0, 2.14, -0.18), "tealBruteDark", seg=16, rings=10, squash=(0.98, 0.95, 1.04)))
    p.append(b.box((0.56, 0.24, 0.38), (0, 2.28, -0.30), "iron", bevel=0.028))
    p.append(b.crystal(0.12, 0.38, (0, 2.42, -0.22), "steel", tilt=(-0.35, 0.0), verts=5))
    p.append(b.ico(0.35, (0, 1.92, -0.30), "ironDark", squash=(0.90, 0.60, 0.78), subdiv=1))
    for sx in (-1, 1):
        p.append(b.ico(0.11, (sx * 0.16, 2.15, -0.53), "eyeNeon", squash=(1.38, 0.65, 0.65), subdiv=1))
        p.append(b.crystal(0.062, 0.25, (sx * 0.14, 1.92, -0.50), "white", tilt=(0.35, -sx * 0.14), verts=5))
        p.append(b.crystal(0.048, 0.18, (sx * 0.25, 1.94, -0.44), "white", tilt=(0.30, -sx * 0.25), verts=4))
        p.append(b.torus(0.13, 0.034, (sx * 0.28, 2.26, -0.15), "steel", major_seg=10, minor_seg=4))
        p.append(b.capsule_seg((sx * 0.26, 2.24, -0.14), (sx * 0.54, 2.46, -0.28), 0.135, 0.085, "ironDark", verts=12))
        p.append(b.capsule_seg((sx * 0.54, 2.46, -0.28), (sx * 0.68, 2.74, -0.52), 0.085, 0.024, "white", verts=12))

    return p


def shieldbearer():
    """Escudeiro Bastiao (~4,350 tris): escudo-torre rebitado, ombreiras 3-camadas, gorjal e elmo de crista."""
    s = Rb("shieldbearer")
    p = []

    # Cintura em placas + cinto rebitado + tassets duplos + tabardo frontal
    p.append(s.cyl(0.64, 0.34, (0, 0.68, 0.02), "ironDark", verts=20, r2=0.58))
    p.append(s.torus(0.62, 0.068, (0, 0.84, 0.02), "steel", major_seg=20, minor_seg=6))
    p.append(s.ico(0.24, (0, 0.86, -0.50), "teal", squash=(1.1, 0.8, 0.45), subdiv=1))
    p.append(s.taper_plate(0.36, 0.10, 0.28, 0.10, 0.50, (0, 0.34, -0.44), "tealDark", bevel=0.018))
    for sx in (-1, 1):
        p.append(s.taper_plate(0.40, 0.42, 0.30, 0.32, 0.52, (sx * 0.52, 0.34, 0.0), "iron", bevel=0.022))
        p.append(s.taper_plate(0.34, 0.36, 0.26, 0.28, 0.32, (sx * 0.56, 0.58, 0.0), "steel", bevel=0.018))

    # Peitoral canelado em placas + gorjal duplo + espinhos dorsais
    p.append(s.ico(0.68, (0, 1.36, 0.02), "iron", squash=(1.12, 1.05, 0.82), subdiv=2))
    p.append(s.ico(0.56, (0, 1.44, -0.22), "steel", squash=(1.02, 0.88, 0.55), subdiv=2))
    p.append(s.torus(0.49, 0.072, (0, 1.82, -0.02), "ironDark", major_seg=20, minor_seg=6))
    p.append(s.torus(0.43, 0.048, (0, 1.92, -0.04), "steel", major_seg=18, minor_seg=6))
    for k in range(5):
        p.append(s.crystal(0.115, 0.38, (0, 1.06 + k * 0.21, 0.44), "ironDark", tilt=(-1.05, 0.0), verts=6))

    # Escudo-torre pavise pesado rebitado com nervuras em cruz, cantoneiras, umbo duplo e runa
    sh_x, sh_y, sh_z = 0.22, 1.24, -0.56
    p.append(s.box((0.94, 1.24, 0.16), (sh_x, sh_y, sh_z - 0.02), "ironDark", bevel=0.04, bevel_segs=2))
    p.append(s.box((1.06, 1.36, 0.10), (sh_x, sh_y, sh_z + 0.02), "steel", bevel=0.03, bevel_segs=2))
    p.append(s.taper_plate(0.42, 0.14, 0.94, 0.16, 0.34, (sh_x, sh_y - 0.84, sh_z), "steel", bevel=0.022))
    p.append(s.taper_plate(0.94, 0.16, 0.64, 0.14, 0.22, (sh_x, sh_y + 0.64, sh_z), "steel", bevel=0.02))
    p.append(s.box((0.12, 1.48, 0.08), (sh_x, sh_y - 0.04, sh_z - 0.08), "steel", bevel=0.015))
    p.append(s.box((0.96, 0.12, 0.08), (sh_x, sh_y, sh_z - 0.08), "steel", bevel=0.015))
    p.append(s.torus(0.28, 0.055, (sh_x, sh_y, sh_z - 0.10), "teal", major_seg=20, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(s.torus(0.18, 0.038, (sh_x, sh_y, sh_z - 0.13), "steel", major_seg=16, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(s.crystal(0.15, 0.36, (sh_x, sh_y, sh_z - 0.13), "tealSwarm", tilt=(1.55, 0.0), verts=8))
    p.append(s.ico(0.08, (sh_x, sh_y, sh_z - 0.26), "eyeNeon", subdiv=1))
    for rx in (-0.42, 0.42):
        for ry in (-0.54, -0.27, 0.0, 0.27, 0.54):
            p.append(s.ico(0.046, (sh_x + rx, sh_y + ry, sh_z - 0.09), "white", subdiv=0))
    for rx in (-0.22, 0.22):
        for ry in (-0.64, 0.64):
            p.append(s.ico(0.046, (sh_x + rx, sh_y + ry, sh_z - 0.09), "tealSwarm", subdiv=0))

    # Ombreiras blindadas em 3 camadas + guarda-pescoco (haute-piece) + rebites
    for sx in (-1, 1):
        p.append(s.ball(0.70, (sx * 0.72, 1.68, 0.0), "iron", seg=16, rings=10, squash=(1.08, 0.82, 0.98)))
        p.append(s.ball(0.58, (sx * 0.80, 1.50, 0.0), "ironDark", seg=14, rings=8, squash=(1.02, 0.72, 0.92)))
        p.append(s.torus(0.34, 0.052, (sx * 0.74, 1.60, 0.0), "steel", major_seg=16, minor_seg=5, rot=(0.0, sx * 0.35, 0.0)))
        p.append(s.taper_plate(0.10, 0.46, 0.08, 0.36, 0.36, (sx * 0.54, 1.84, 0.0), "steel", bevel=0.015))
        p.append(s.crystal(0.115, 0.46, (sx * 0.82, 1.88, 0.02), "steel", tilt=(0.0, -sx * 0.55), verts=6))
        for ry_off in (-0.12, 0.12):
            p.append(s.ico(0.044, (sx * 0.92, 1.62 + ry_off, -0.18), "white", subdiv=0))

    # Elmo barbuta fechado com protetores faciais, viseira T neon e crista de 7 laminas
    p.append(s.ball(0.88, (0, 2.16, -0.06), "iron", seg=18, rings=11, squash=(0.96, 1.02, 1.06)))
    p.append(s.box((0.54, 0.22, 0.26), (0, 2.26, -0.34), "steel", bevel=0.022))
    p.append(s.ico(0.38, (0, 2.12, -0.34), "ironDark", squash=(1.05, 0.55, 0.48), subdiv=1))
    p.append(s.ico(0.19, (0, 2.14, -0.49), "eyeNeon", squash=(1.88, 0.38, 0.36), subdiv=1))
    p.append(s.torus(0.42, 0.038, (0, 2.38, 0.02), "steel", major_seg=16, minor_seg=5, rot=(0.0, math.pi / 2, 0.0)))
    for k in range(7):
        p.append(
            s.crystal(
                0.105,
                0.50 - k * 0.035,
                (0, 2.54 - k * 0.06, -0.16 + k * 0.13),
                "teal" if k % 2 == 0 else "steel",
                tilt=(-0.22 - k * 0.24, 0.0),
                verts=6,
            )
        )

    return p


def sapper():
    """Zapador (~4,400 tris): avental balistico, bandoleira 6-bombas, barril de aduelas c/ valvula/pavio e oculos."""
    z = Rb("sapper")
    p = []

    # Cintura tatica + avental frontal balistico (-Z garante G2 limpo e preserva altura)
    p.append(z.cyl(0.56, 0.28, (0, 0.78, 0.02), "ironDark", verts=18, r2=0.52))
    p.append(z.torus(0.54, 0.058, (0, 0.90, 0.02), "steel", major_seg=18, minor_seg=5))
    p.append(z.taper_plate(0.44, 0.10, 0.36, 0.10, 0.34, (0, 0.68, -0.46), "iron", bevel=0.02))
    p.append(z.box((0.24, 0.18, 0.14), (0, 0.92, -0.50), "crimsonBright", bevel=0.018))
    p.append(z.ico(0.56, (0, 1.32, 0.0), "tealDark", squash=(1.04, 1.06, 0.82), subdiv=2))
    p.append(z.ico(0.46, (0, 1.36, -0.20), "iron", squash=(0.94, 0.92, 0.56), subdiv=1))

    # Bolsas laterais de cintura com abas e tiras
    for sx in (-1, 1):
        p.append(z.box((0.22, 0.26, 0.24), (sx * 0.56, 0.92, -0.08), "furBrown", bevel=0.022))
        p.append(z.box((0.24, 0.08, 0.26), (sx * 0.56, 1.05, -0.08), "woodDark", bevel=0.015))
        p.append(z.ico(0.042, (sx * 0.66, 0.96, -0.10), "steel", subdiv=0))

    # Correias cruzadas + bandoleira de 6 granadas de demolicao cintadas
    p.append(z.box((0.98, 0.11, 0.10), (0, 1.32, -0.40), "furBrown", rot_bl=(0.0, 0.62, 0.0), bevel=0.015))
    p.append(z.box((0.94, 0.09, 0.09), (0, 1.34, -0.38), "woodDark", rot_bl=(0.0, -0.58, 0.0), bevel=0.012))
    for k in range(6):
        t = (k - 2.5) / 2.5
        px, py, pz = t * 0.38, 1.40 - t * 0.27, -0.47
        p.append(z.capsule_seg((px - 0.04, py - 0.06, pz), (px + 0.04, py + 0.08, pz), 0.082, 0.082, "danger" if k % 2 == 0 else "steel", verts=10))
        p.append(z.torus(0.084, 0.022, (px, py + 0.01, pz), "ironDark", major_seg=8, minor_seg=4))
        p.append(z.ico(0.042, (px + 0.04, py + 0.10, pz - 0.02), "emberDeep", subdiv=0))

    # Barril principal de polvora nas costas com aduelas esculpidas, 4 aros, manometro/valvula, cargas laterais e pavio
    kx, ky, kz = 0.0, 0.98, 0.50
    p.append(z.cyl(0.44, 0.90, (kx, ky, kz), "woodDark", verts=18, r2=0.42))
    p.append(z.cyl(0.39, 0.05, (kx, ky + 0.88, kz), "furBrown", verts=14))
    for st in range(8):
        a = 2 * math.pi * st / 8
        p.append(
            z.capsule_seg(
                (kx + 0.43 * math.cos(a), ky + 0.06, kz + 0.43 * math.sin(a)),
                (kx + 0.41 * math.cos(a), ky + 0.84, kz + 0.41 * math.sin(a)),
                0.032,
                0.030,
                "furBrown" if st % 2 == 0 else "woodDark",
                verts=6,
            )
        )
    for hy in (1.08, 1.30, 1.54, 1.78):
        p.append(z.torus(0.445, 0.046, (kx, hy, kz), "steel", major_seg=16, minor_seg=4))
    # Suporte de madeira + 2 cargas auxiliares laterais + valvula de pressao
    for sx in (-1, 1):
        p.append(z.capsule_seg((sx * 0.34, 1.72, 0.14), (sx * 0.28, 1.76, 0.42), 0.048, 0.042, "furBrown", verts=8))
        p.append(z.cyl(0.14, 0.52, (sx * 0.48, 1.12, 0.44), "ironDark", verts=12, r2=0.13))
        p.append(z.torus(0.145, 0.028, (sx * 0.48, 1.38, 0.44), "crimsonBright", major_seg=12, minor_seg=4))
    p.append(z.torus(0.16, 0.036, (0.45, 1.48, kz), "crimsonBright", major_seg=14, minor_seg=5, rot=(0.0, math.pi / 2, 0.0)))
    p.append(z.capsule_seg((0.36, 1.48, kz), (0.50, 1.48, kz), 0.045, 0.045, "steel", verts=8))
    # Pavio serpentinado + coroa de fagulhas
    p.append(z.capsule_seg((0, 1.88, 0.50), (0.08, 2.08, 0.58), 0.052, 0.042, "ironDark", verts=10))
    p.append(z.capsule_seg((0.08, 2.08, 0.58), (-0.04, 2.24, 0.64), 0.042, 0.028, "furBrown", verts=10))
    p.append(z.ico(0.125, (-0.04, 2.26, 0.65), "emberDeep", subdiv=1))
    for sa in (0.0, 2.1, 4.2):
        p.append(z.crystal(0.055, 0.18, (-0.04 + 0.08 * math.cos(sa), 2.26, 0.65 + 0.08 * math.sin(sa)), "danger", tilt=(-0.4 * math.sin(sa), 0.4 * math.cos(sa)), verts=4))

    # Ombreiras rebitadas
    for sx in (-1, 1):
        p.append(z.ico(0.34, (sx * 0.62, 1.62, 0.0), "ironDark", squash=(0.98, 0.78, 0.94), subdiv=1))
        p.append(z.torus(0.26, 0.042, (sx * 0.62, 1.60, 0.0), "steel", major_seg=14, minor_seg=5, rot=(0.0, sx * 0.4, 0.0)))
        p.append(z.ico(0.045, (sx * 0.78, 1.68, -0.10), "white", subdiv=0))

    # Capuz blindado + respirador duplo + oculos de demolicao luminosos
    p.append(z.ball(0.85, (0, 2.08, -0.04), "tealDark", seg=18, rings=11, squash=(0.96, 1.0, 1.02)))
    p.append(z.ball(0.56, (0, 2.04, -0.26), "ironDark", seg=14, rings=9, squash=(0.94, 0.82, 0.72)))
    p.append(z.cyl(0.16, 0.18, (0, 1.88, -0.46), "steel", verts=12))
    for sx in (-1, 1):
        p.append(z.capsule_seg((sx * 0.12, 1.92, -0.44), (sx * 0.28, 1.84, -0.38), 0.085, 0.095, "iron", verts=10))
        p.append(z.torus(0.15, 0.044, (sx * 0.18, 2.10, -0.49), "steel", major_seg=16, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
        p.append(z.torus(0.115, 0.024, (sx * 0.18, 2.10, -0.53), "crimsonBright", major_seg=12, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
        p.append(z.ico(0.112, (sx * 0.18, 2.10, -0.55), "eyeNeon", squash=(0.95, 0.95, 0.55), subdiv=1))
        p.append(z.crystal(0.082, 0.36, (sx * 0.35, 2.32, -0.02), "iron", tilt=(-0.35, -sx * 0.60), verts=6))

    return p


def pyromancer():
    """Piroforjador (~4,350 tris): manto pregueado, estola runica, fornalha, braseiros, cajado arcano e capuz."""
    y = Rb("pyromancer")
    p = []

    # Manto pregueado + estola frontal mais baixa (-Z garante G2 limpo e altura ~5.32; zero tons 30..55 deg)
    p.append(y.cyl(0.74, 0.78, (0, 0.34, 0.04), "stoneDark", verts=22, r2=0.46))
    p.append(y.taper_plate(0.36, 0.10, 0.26, 0.10, 0.98, (0, 0.02, -0.50), "crimsonCloth", bevel=0.02))
    p.append(y.taper_plate(0.24, 0.08, 0.18, 0.08, 0.84, (0, 0.04, -0.54), "crimsonBright", bevel=0.015))
    p.append(y.torus(0.51, 0.058, (0, 1.04, 0.0), "emberDeep", major_seg=20, minor_seg=6))
    p.append(y.box((0.26, 0.20, 0.14), (0, 1.04, -0.50), "ironDark", bevel=0.02))
    p.append(y.ico(0.085, (0, 1.04, -0.56), "emberDeep", subdiv=1))
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.append(
            y.crystal(
                0.145,
                0.46,
                (0.58 * math.cos(a), 0.74, 0.58 * math.sin(a) + 0.04),
                "crimsonCloth" if k % 3 == 0 else ("tealDark" if k % 2 == 0 else "ironDark"),
                tilt=(-math.pi + 0.28 * math.sin(a), 0.28 * math.cos(a)),
                verts=6,
            )
        )
    # Pergaminhos e turibulo no cinto
    for sx in (-1, 1):
        p.append(y.capsule_seg((sx * 0.50, 0.82, -0.18), (sx * 0.54, 1.06, -0.10), 0.075, 0.075, "iron", verts=10))
        p.append(y.torus(0.08, 0.022, (sx * 0.52, 0.94, -0.14), "crimsonBright", major_seg=10, minor_seg=4))
    p.append(y.ico(0.11, (0.34, 0.68, -0.40), "ironDark", subdiv=1))
    p.append(y.ico(0.07, (0.34, 0.66, -0.44), "emberDeep", subdiv=0))

    # Fornalha peitoral com gaiola de ferro e costelas
    p.append(y.cyl(0.48, 0.20, (0, 0.96, 0), "ironDark", verts=18, r2=0.46))
    p.append(y.ico(0.55, (0, 1.44, 0.02), "stoneDark", squash=(1.05, 1.12, 0.82), subdiv=2))
    p.append(y.ball(0.45, (0, 1.44, -0.30), "emberDeep", seg=16, rings=10, squash=(0.95, 1.10, 0.65)))
    p.append(y.torus(0.29, 0.052, (0, 1.44, -0.36), "ironDark", major_seg=18, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(y.torus(0.20, 0.036, (0, 1.44, -0.41), "steel", major_seg=14, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    for sx in (-1, 1):
        p.append(y.capsule_seg((sx * 0.24, 1.22, -0.34), (sx * 0.18, 1.66, -0.36), 0.048, 0.038, "ironDark", verts=10))
        p.append(y.capsule_seg((sx * 0.12, 1.20, -0.38), (sx * 0.09, 1.68, -0.40), 0.040, 0.034, "steel", verts=8))
        # Braseiros ornamentados nos ombros
        p.append(y.ico(0.28, (sx * 0.58, 1.66, 0.04), "crimsonCloth", squash=(1.05, 0.72, 0.96), subdiv=1))
        p.append(y.cyl(0.23, 0.26, (sx * 0.68, 1.72, 0.06), "ironDark", verts=16, r2=0.30))
        p.append(y.torus(0.28, 0.048, (sx * 0.68, 1.98, 0.06), "steel", major_seg=16, minor_seg=6))
        p.append(y.ico(0.18, (sx * 0.68, 2.00, 0.06), "emberDeep", subdiv=1))
        p.append(y.crystal(0.095, 0.30, (sx * 0.68, 2.10, 0.06), "danger", verts=6))
        for sp in (-1, 1):
            p.append(y.crystal(0.06, 0.20, (sx * 0.68 + sp * 0.12, 2.04, 0.06), "crimsonBright", tilt=(0.0, -sp * 0.35), verts=5))

    # Cajado arcano de piromante (preserva [0.22, 3.10] em Y)
    st_b, st_t = (-0.72, 0.44, -0.24), (-0.86, 2.52, -0.42)
    p.append(y.capsule_seg(st_b, st_t, 0.055, 0.068, "ironDark", verts=12))
    for frac in (0.28, 0.56, 0.84):
        gx = st_b[0] + (st_t[0] - st_b[0]) * frac
        gy = st_b[1] + (st_t[1] - st_b[1]) * frac
        gz = st_b[2] + (st_t[2] - st_b[2]) * frac
        p.append(y.torus(0.082, 0.024, (gx, gy, gz), "steel", major_seg=12, minor_seg=4))
    p.append(y.torus(0.22, 0.042, (-0.88, 2.72, -0.44), "steel", major_seg=18, minor_seg=6, rot=(math.pi / 2, 0.2, 0.0)))
    p.append(y.torus(0.16, 0.032, (-0.88, 2.72, -0.44), "crimsonBright", major_seg=14, minor_seg=5, rot=(0.2, math.pi / 2, 0.0)))
    p.append(y.ico(0.11, (-0.88, 2.72, -0.44), "emberDeep", subdiv=1))
    p.append(y.crystal(0.075, 0.24, (-0.88, 2.86, -0.45), "eyeNeon", verts=6))

    # Colar runico flutuante torus + 8 cristais orbitais
    p.append(y.torus(0.75, 0.048, (0, 1.92, 0.02), "crimsonBright", major_seg=22, minor_seg=6, rot=(0.15, 0.0, 0.0)))
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.25
        p.append(
            y.crystal(
                0.095,
                0.38,
                (0.75 * math.cos(a), 1.92 + 0.05 * (k % 2), 0.66 * math.sin(a)),
                "emberDeep" if k % 2 == 0 else "tealSwarm",
                tilt=(-0.28 * math.sin(a), -0.28 * math.cos(a)),
                verts=6,
            )
        )

    # Gola alta + capuz profundo de mago + viseira e coroa de chifres
    p.append(y.cyl(0.58, 0.28, (0, 1.80, 0.04), "ironDark", verts=18, r2=0.44))
    p.append(y.ball(0.89, (0, 2.24, -0.02), "stoneDark", seg=18, rings=11, squash=(0.96, 1.04, 1.12)))
    p.append(y.torus(0.37, 0.054, (0, 2.20, -0.28), "crimsonCloth", major_seg=18, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(y.crystal(0.38, 0.86, (0, 2.38, 0.14), "crimsonCloth", tilt=(-0.88, 0.0), verts=10))
    p.append(y.ball(0.56, (0, 2.20, -0.28), "ironDark", seg=14, rings=9, squash=(0.92, 0.86, 0.72)))
    for sx in (-1, 1):
        p.append(y.ico(0.115, (sx * 0.15, 2.22, -0.54), "eyeNeon", squash=(1.35, 0.65, 0.68), subdiv=1))
        p.append(y.ico(0.08, (sx * 0.15, 2.22, -0.50), "emberDeep", squash=(1.45, 0.75, 0.60), subdiv=0))
        p.append(y.capsule_seg((sx * 0.22, 2.48, -0.02), (sx * 0.42, 2.80, 0.18), 0.105, 0.058, "danger", verts=12))
        p.append(y.capsule_seg((sx * 0.42, 2.80, 0.18), (sx * 0.54, 3.10, 0.42), 0.058, 0.022, "emberDeep", verts=12))

    return p


def drake():
    """Armored Rift Drake (~4,400 tris): escamas sobrepostas, asas esculpidas c/ membrana, garras e cranio cornudo."""
    d = Rb("drake")
    p = []

    # Torso draconico escamado + peitoral blindado + garras frontais recolhidas
    p.append(d.ball(1.20, (0, 1.14, 0.04), "obsidian", seg=22, rings=14, squash=(0.94, 0.90, 1.34)))
    p.append(d.torus(0.22, 0.045, (0, 1.32, -0.52), "steel", major_seg=16, minor_seg=5, rot=(1.25, 0.0, 0.0)))
    p.append(d.ico(0.12, (0, 1.32, -0.56), "emberDeep", subdiv=1))
    for idx, (py, pz, rad) in enumerate(
        ((0.70, -0.18, 0.28), (0.86, -0.30, 0.33), (1.04, -0.40, 0.37), (1.24, -0.45, 0.40), (1.44, -0.47, 0.36), (1.62, -0.44, 0.31))
    ):
        col = "crimsonCloth" if idx % 2 == 0 else "wyvernScale"
        p.append(d.ico(rad, (0, py, pz), col, squash=(1.12, 0.66, 0.60), subdiv=1))
        for sx in (-1, 1):
            p.append(d.ico(rad * 0.62, (sx * 0.32, py + 0.04, pz + 0.16), "obsidianLight", squash=(0.82, 0.68, 0.58), subdiv=1))

    # Garras dianteiras, escamas dorsais laterais e asas draconicas esculpidas com falanges e membrana solida
    for sx in (-1, 1):
        p.append(d.capsule_seg((sx * 0.38, 0.98, -0.26), (sx * 0.46, 0.72, -0.52), 0.14, 0.09, "obsidianLight", verts=10))
        for tc in (-0.06, 0.0, 0.06):
            p.append(d.crystal(0.038, 0.16, (sx * 0.46 + tc, 0.70, -0.54), "white", tilt=(1.2, 0.0), verts=4))

        for ds_y, ds_z in ((1.02, 0.36), (1.22, 0.22), (1.42, 0.04)):
            p.append(d.ico(0.18, (sx * 0.42, ds_y, ds_z), "wyvernScale", squash=(0.72, 0.65, 0.95), subdiv=1))

        p.append(d.ico(0.35, (sx * 0.48, 1.42, 0.06), "obsidianLight", squash=(0.78, 0.92, 1.10), subdiv=1))
        p.append(d.torus(0.31, 0.05, (sx * 0.50, 1.46, 0.08), "steel", major_seg=16, minor_seg=5, rot=(0.0, sx * 0.45, 0.0)))
        sh = (sx * 0.46, 1.48, 0.10)
        el = (sx * 0.98, 1.84, 0.34)
        wr = (sx * 1.42, 1.98, 0.66)
        p.append(d.capsule_seg(sh, el, 0.165, 0.11, "obsidianLight", verts=14))
        p.append(d.capsule_seg(el, wr, 0.11, 0.055, "steel", verts=12))
        p.append(d.crystal(0.09, 0.36, (el[0], el[1] + 0.05, el[2] - 0.04), "crimsonBright", tilt=(0.35, -sx * 0.5), verts=6))
        p.append(d.crystal(0.075, 0.28, (wr[0], wr[1] + 0.04, wr[2] - 0.04), "white", tilt=(0.45, -sx * 0.55), verts=5))
        fingers = (
            ((sx * 1.56, 1.84, 0.84), (sx * 1.66, 1.66, 1.00)),
            ((sx * 1.48, 1.68, 0.88), (sx * 1.50, 1.38, 1.08)),
            ((sx * 1.34, 1.54, 0.86), (sx * 1.24, 1.16, 1.02)),
            ((sx * 1.16, 1.42, 0.78), (sx * 0.92, 1.04, 0.84)),
        )
        tips = []
        for mid_pt, tip_pt in fingers:
            p.append(d.capsule_seg(wr, mid_pt, 0.068, 0.042, "wyvernScale", verts=10))
            p.append(d.capsule_seg(mid_pt, tip_pt, 0.042, 0.020, "crimsonCloth", verts=8))
            tips.append(tip_pt)
        ring = [sh, el, wr, tips[0], tips[1], tips[2], tips[3], (sx * 0.56, 1.12, 0.46)]
        p.append(d.wing_panel(ring, (sx * 1.04, 1.46, 0.62), 0.045, "wyvernWing"))

    # Colar blindado de aco + pescoco em S com placas e espinhos laterais
    p.append(d.torus(0.37, 0.058, (0, 1.62, -0.30), "steel", major_seg=20, minor_seg=6, rot=(0.62, 0.0, 0.0)))
    p.append(d.capsule_seg((0, 1.46, -0.24), (0, 1.88, -0.48), 0.37, 0.29, "obsidian", verts=16))
    p.append(d.capsule_seg((0, 1.88, -0.48), (0, 2.26, -0.62), 0.29, 0.25, "crimsonCloth", verts=16))
    for py, pz in ((1.64, -0.42), (1.84, -0.52), (2.04, -0.60), (2.20, -0.66)):
        p.append(d.ico(0.20, (0, py, pz), "wyvernScale", squash=(1.12, 0.54, 0.54), subdiv=1))

    # Cranio draconico anatomico (-Z Roblox / -Y Blender) + mandibula + 8 presas + chifres anelados
    p.append(d.ball(0.70, (0, 2.34, -0.78), "obsidian", seg=18, rings=11, squash=(0.90, 0.82, 1.16)))
    p.append(d.capsule_seg((0, 2.34, -0.86), (0, 2.28, -1.40), 0.24, 0.125, "crimsonCloth", verts=14))
    p.append(d.capsule_seg((0, 2.14, -0.84), (0, 2.10, -1.30), 0.185, 0.092, "obsidianLight", verts=12))
    p.append(d.crystal(0.068, 0.24, (0, 2.38, -1.30), "steel", tilt=(0.95, 0.0), verts=5))
    p.append(d.crystal(0.055, 0.20, (0, 2.44, -1.06), "crimsonBright", tilt=(0.55, 0.0), verts=5))
    p.append(d.ico(0.14, (0, 2.22, -1.08), "emberDeep", squash=(0.85, 0.45, 1.25), subdiv=1))
    for sx in (-1, 1):
        p.append(d.ico(0.095, (sx * 0.20, 2.38, -0.98), "eyeNeon", squash=(1.25, 0.70, 0.80), subdiv=1))
        p.append(d.capsule_seg((sx * 0.14, 2.46, -1.06), (sx * 0.26, 2.44, -0.86), 0.052, 0.062, "crimsonCloth", verts=8))
        for fz in (-1.26, -1.08):
            p.append(d.crystal(0.044, 0.15, (sx * 0.10, 2.26, fz), "white", tilt=(math.pi, 0.0), verts=4))
            p.append(d.crystal(0.038, 0.12, (sx * 0.08, 2.14, fz + 0.04), "white", tilt=(0.0, 0.0), verts=4))
        # Chifres principais anelados (mantidos a frente de Z=0 para passar G2 criatura_alada com folga)
        p.append(d.torus(0.11, 0.03, (sx * 0.20, 2.48, -0.70), "steel", major_seg=10, minor_seg=4))
        p.append(d.capsule_seg((sx * 0.20, 2.48, -0.70), (sx * 0.36, 2.76, -0.44), 0.105, 0.062, "obsidianLight", verts=12))
        p.append(d.capsule_seg((sx * 0.36, 2.76, -0.44), (sx * 0.46, 3.02, -0.16), 0.062, 0.022, "white", verts=12))
        p.append(d.crystal(0.08, 0.30, (sx * 0.28, 2.28, -0.68), "steel", tilt=(-0.45, -sx * 0.65), verts=6))

    # Crista dorsal escamada ao longo do pescoco, dorso e inicio de cauda
    for sy, sz, h in (
        (0.92, 0.64, 0.34),
        (1.12, 0.50, 0.38),
        (1.34, 0.32, 0.42),
        (1.56, 0.06, 0.40),
        (1.80, -0.18, 0.36),
        (2.04, -0.38, 0.34),
        (2.28, -0.54, 0.30),
        (2.48, -0.66, 0.26),
    ):
        p.append(d.crystal(0.092, h, (0, sy, sz), "crimsonBright", tilt=(-0.78, 0.0), verts=6))

    return p


CLASS_CONFIG = {
    "swarm": ("prop_estatico", "criatura", 2000, 8, (1500, 1800), swarm),
    "runner": ("prop_estatico", "personagem_humanoide", 3600, 6, (2800, 3400), runner),
    "wisp": ("prop_estatico", "criatura", 3600, 6, (2800, 3400), wisp),
    "brute": ("prop_estatico", "personagem_humanoide", 5000, 4, (3800, 4800), brute),
    "shieldbearer": ("prop_estatico", "personagem_humanoide", 5000, 4, (3800, 4800), shieldbearer),
    "pyromancer": ("prop_estatico", "personagem_humanoide", 5000, 4, (3800, 4800), pyromancer),
    "sapper": ("prop_estatico", "personagem_humanoide", 5000, 4, (3800, 4800), sapper),
    "drake": ("prop_estatico", "criatura_alada", 5000, 4, (3800, 4800), drake),
}


def specs():
    out = []
    for kind in ("runner", "brute", "swarm", "shieldbearer", "pyromancer", "sapper", "wisp", "drake"):
        tipo, _, limite, qtd, _, fn = CLASS_CONFIG[kind]
        out.append(
            {
                "id": f"horde.{kind}.01",
                "name": f"CMD_{kind}",
                "glb": f"horde_{kind}.glb",
                "tipo": tipo,
                "limite": limite,
                "qualidade": "standard",
                "hero_pbr": False,
                "quantidade_cena": qtd,
                "suavizacao_normais": SUAVIZACAO_HORDE,
                "tags": ["muralha", "horde", kind],
                "build": fn,
            }
        )
    return out


def _verify_horde_objs(objs) -> None:
    """Valida faixas exatas de triangulos e orientacao frontal (-Y Blender -> +Z glTF -> -X mundo Roblox)."""
    errs = []
    for o in objs:
        kind = o.name.removeprefix("CMD_")
        _, arq, _, _, (t_min, t_max), _ = CLASS_CONFIG[kind]
        n = L.tris(o)
        if not (t_min <= n <= t_max):
            errs.append(f"{o.name}: tris={n} fora de [{t_min}, {t_max}]")
        vs = o.data.vertices
        ys = [v.co.y for v in vs]
        zs = [v.co.z for v in vs]
        z0, z1 = min(zs), max(zs)
        y0, y1 = min(ys), max(ys)
        dz, dy = z1 - z0, y1 - y0
        if arq in ("criatura", "criatura_alada"):
            topo_ys = [v.co.y for v in vs if v.co.z >= z0 + 0.72 * dz]
            if topo_ys and (sum(topo_ys) / len(topo_ys)) > 0.5 * (y0 + y1) + 0.08 * dy:
                errs.append(f"{o.name}: criatura_de_costas (mean_topo_y alto demais)")
        elif arq == "personagem_humanoide":
            pes = [v.co.y for v in vs if v.co.z <= z0 + 0.06 * dz]
            can = [v.co.y for v in vs if z0 + 0.12 * dz <= v.co.z <= z0 + 0.30 * dz]
            if pes and can:
                p_mean, c_mean = sum(pes) / len(pes), sum(can) / len(can)
                p_mid, c_mid = 0.5 * (min(pes) + max(pes)), 0.5 * (min(can) + max(can))
                score = 0.5 * ((p_mean - c_mean) + (p_mid - c_mid)) / dz
                if score >= -0.035:
                    errs.append(f"{o.name}: orientacao humanoide score={score:.4f} (esperado < -0.035)")
    if errs:
        raise SystemExit("[horde] falha de verificacao AA:\n  - " + "\n  - ".join(errs))


_objs = L.run_group("horde", specs(), "torso/capuz esculpido AA da horda hibrida (art/scripts/make_horde.py)", hero_pbr=False)
_verify_horde_objs(_objs)
