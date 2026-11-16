"""Gera 9 malhas AA de fauna esculpidas para o Bastiao (FAUNA_) sob Forge3D 0.9.0 (spec@6).

Convencoes:
  - Z-up, frente = -Y (focinho/bico), cauda = +Y.
  - Tier Standard (`hero_pbr=False`, `qualidade="standard"`) em todas as 9 malhas para preservar
    GPU Instancing via MASTER_ATLAS.
  - As 4 asas (`wyvern_wing_l/r`, `bird_wing_l/r`) mantem `center_xy=False` e `pivot: origem`
    com junta de ombro em `(0, 0, r_sh)` -> base `Z=0`, origem `(0, 0, 0)` no ombro e extensao
    estrita em `-X` (`wing_l`) / `+X` (`wing_r`) conforme contrato de `AmbientLife.luau`.
  - Criaturas (`criatura_alada` / `criatura_quadrupede`) respeitam o gate G2 de orientacao do
    Forge3D: vertices no topo 28% Z (`z >= z_min + 0.72*dz`) satisfazem `mean(y) <= y_mid + 0.08*dy`.

Itens (id Forge3D -> objeto -> alvo tris):
  1. fauna.wyvern_body.01   -> FAUNA_wyvern_body   (wyvern_body.glb,   4200..4800 tris, lim 5000)
  2. fauna.wyvern_wing_l.01 -> FAUNA_wyvern_wing_l (wyvern_wing_l.glb, 2000..2400 tris, lim 2600)
  3. fauna.wyvern_wing_r.01 -> FAUNA_wyvern_wing_r (wyvern_wing_r.glb, 2000..2400 tris, lim 2600)
  4. fauna.bird_body.01     -> FAUNA_bird_body     (bird_body.glb,      800..1000 tris, lim 1200)
  5. fauna.bird_wing_l.01   -> FAUNA_bird_wing_l   (bird_wing_l.glb,    400..500  tris, lim  650)
  6. fauna.bird_wing_r.01   -> FAUNA_bird_wing_r   (bird_wing_r.glb,    400..500  tris, lim  650)
  7. fauna.stag.01          -> FAUNA_stag          (stag.glb,          4000..4800 tris, lim 5000)
  8. fauna.pack_ox.01       -> FAUNA_pack_ox       (pack_ox.glb,       4000..4800 tris, lim 5000)
  9. fauna.ram.01           -> FAUNA_ram           (ram.glb,           4000..4800 tris, lim 5000)

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_fauna.py
"""

from __future__ import annotations

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

NORMALS_FAUNA = {
    "modo": "hard_surface",
    "angulo_graus": 52,
    "weighted_normals": True,
    "corrective_smooth": False,
}

TRI_TARGETS = {
    "fauna.wyvern_body.01": (4200, 4800),
    "fauna.wyvern_wing_l.01": (2000, 2400),
    "fauna.wyvern_wing_r.01": (2000, 2400),
    "fauna.bird_body.01": (800, 1000),
    "fauna.bird_wing_l.01": (400, 500),
    "fauna.bird_wing_r.01": (400, 500),
    "fauna.stag.01": (4000, 4800),
    "fauna.pack_ox.01": (4000, 4800),
    "fauna.ram.01": (4000, 4800),
}


# ---------------------------------------------------------------- helpers BMesh manifold
def _smooth(obj, enabled: bool = True):
    for poly in obj.data.polygons:
        poly.use_smooth = enabled
    obj.data.update()
    return obj


def _sball(r, center, color, seg=14, rings=9, squash=(1.0, 1.0, 1.0), rot=(0.0, 0.0, 0.0)):
    o = L.ball(r, center, color, seg=seg, rings=rings, squash=squash)
    if any(abs(a) > 1e-6 for a in rot):
        o.rotation_euler = rot
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return _smooth(o, True)


def _sico(r, center, color, squash=(1.0, 1.0, 1.0), subdiv=2, rot=(0.0, 0.0, 0.0)):
    o = L.ico(r, center, color, squash=squash, subdiv=subdiv)
    if any(abs(a) > 1e-6 for a in rot):
        o.rotation_euler = rot
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return _smooth(o, True)


def _storus(r_maj, r_min, center, color, major_seg=14, minor_seg=6, rot=(0.0, 0.0, 0.0), squash=(1.0, 1.0, 1.0)):
    return _smooth(
        L.torus(r_maj, r_min, center, color, major_seg=major_seg, minor_seg=minor_seg, rot=rot, squash=squash),
        True,
    )


def _from_bm(bm, name: str, color: str, smooth: bool = True):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return L.paint(obj, color)


def _loft_tube(
    stations,
    color: str,
    verts: int = 12,
    cap0: float = 0.42,
    cap1: float = 0.55,
    smooth: bool = True,
    ref_up=(0.0, 0.0, 1.0),
    name: str = "loft_tube",
):
    """Tubo organico 2-manifold ao longo de `stations` = [(pos, rx[, ru]), ...] com Bishop frame.

    Triangulos exatos = `2 * len(stations) * verts`.
    """
    pts: list[Vector] = []
    rxs: list[float] = []
    rus: list[float] = []
    for st in stations:
        pts.append(Vector(st[0]))
        rx = max(float(st[1]), 0.008)
        ru = max(float(st[2]) if len(st) > 2 else rx, 0.008)
        rxs.append(rx)
        rus.append(ru)

    k_len = len(pts)
    assert k_len >= 2, "_loft_tube exige >= 2 estacoes"

    tangents: list[Vector] = []
    for i in range(k_len):
        if i == 0:
            d = pts[1] - pts[0]
        elif i == k_len - 1:
            d = pts[k_len - 1] - pts[k_len - 2]
        else:
            d1 = (pts[i] - pts[i - 1]).normalized()
            d2 = (pts[i + 1] - pts[i]).normalized()
            d = d1 + d2
            if d.length < 1e-5:
                d = d2
        tangents.append(d.normalized() if d.length > 1e-6 else Vector((0.0, -1.0, 0.0)))

    up_hint = Vector(ref_up).normalized()
    if abs(tangents[0].dot(up_hint)) > 0.94:
        up_hint = Vector((0.0, 1.0, 0.0)) if abs(tangents[0].y) < 0.9 else Vector((1.0, 0.0, 0.0))
    side = up_hint.cross(tangents[0]).normalized()
    up = tangents[0].cross(side).normalized()

    bm = bmesh.new()
    rings = []
    for i in range(k_len):
        if i > 0:
            q = tangents[i - 1].rotation_difference(tangents[i])
            side = q @ side
            side = side - tangents[i] * side.dot(tangents[i])
            if side.length < 1e-6:
                alt = Vector((1.0, 0.0, 0.0)) if abs(tangents[i].x) < 0.9 else Vector((0.0, 1.0, 0.0))
                side = alt.cross(tangents[i])
            side.normalize()
            up = tangents[i].cross(side).normalized()
        ring = []
        for k in range(verts):
            ang = 2.0 * math.pi * k / verts
            co = pts[i] + side * (rxs[i] * math.cos(ang)) + up * (rus[i] * math.sin(ang))
            ring.append(bm.verts.new(tuple(co)))
        rings.append(ring)

    ext0 = max(0.012, cap0 * min(rxs[0], rus[0]))
    ext1 = max(0.012, cap1 * min(rxs[-1], rus[-1]))
    v_start = bm.verts.new(tuple(pts[0] - tangents[0] * ext0))
    v_end = bm.verts.new(tuple(pts[-1] + tangents[-1] * ext1))

    for k in range(verts):
        nk = (k + 1) % verts
        bm.faces.new((v_start, rings[0][nk], rings[0][k]))
    for i in range(k_len - 1):
        r0, r1 = rings[i], rings[i + 1]
        for k in range(verts):
            nk = (k + 1) % verts
            bm.faces.new((r0[k], r0[nk], r1[nk], r1[k]))
    for k in range(verts):
        nk = (k + 1) % verts
        bm.faces.new((v_end, rings[-1][k], rings[-1][nk]))

    return _from_bm(bm, name, color, smooth=smooth)


def _wing_membrane_cambered(
    ring_pts,
    hub_pt,
    thickness: float,
    color: str,
    radial_rings: int = 2,
    camber: float = 0.04,
    smooth: bool = True,
):
    """Membrana alar 2-manifold arqueada com `radial_rings` faixas concentricas (`4 * R * N` tris)."""
    bm = bmesh.new()
    hx, hy, hz = hub_pt
    ht = bm.verts.new((hx, hy, hz + thickness * 0.55))
    hb = bm.verts.new((hx, hy, hz - thickness * 0.55))

    n = len(ring_pts)
    top_rings = []
    bot_rings = []
    for r_idx in range(1, radial_rings + 1):
        f = r_idx / float(radial_rings)
        arch = camber * math.sin(f * math.pi)
        dz = max(0.014, thickness * 0.5 * (1.0 - 0.32 * f))
        tr = []
        br = []
        for px, py, pz in ring_pts:
            cx = hx + f * (px - hx)
            cy = hy + f * (py - hy)
            cz = hz + f * (pz - hz) + arch
            tr.append(bm.verts.new((cx, cy, cz + dz)))
            br.append(bm.verts.new((cx, cy, cz - dz)))
        top_rings.append(tr)
        bot_rings.append(br)

    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ht, top_rings[0][i], top_rings[0][j]))
        bm.faces.new((hb, bot_rings[0][j], bot_rings[0][i]))

    for r_idx in range(radial_rings - 1):
        t0, t1 = top_rings[r_idx], top_rings[r_idx + 1]
        b0, b1 = bot_rings[r_idx], bot_rings[r_idx + 1]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((t0[i], t1[i], t1[j], t0[j]))
            bm.faces.new((b0[j], b1[j], b1[i], b0[i]))

    tout, bout = top_rings[-1], bot_rings[-1]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bout[i], bout[j], tout[j], tout[i]))

    return _from_bm(bm, "wing_membrane", color, smooth=smooth)


def _feather_blade(p0, p1, w_mid: float, thick: float, color: str, camber: float = 0.015, ref_up=(0.0, 0.0, 1.0)):
    """Pena aerodinamica losangular com raque central elevada (24 tris)."""
    v0, v1 = Vector(p0), Vector(p1)
    vm = v0.lerp(v1, 0.46) + Vector(ref_up).normalized() * camber
    return _loft_tube(
        [
            (tuple(v0), w_mid * 0.30, thick * 0.55),
            (tuple(vm), w_mid * 0.50, thick * 0.48),
            (tuple(v1), w_mid * 0.12, thick * 0.24),
        ],
        color,
        verts=4,
        cap0=0.28,
        cap1=0.95,
        smooth=False,
        ref_up=ref_up,
        name="feather_blade",
    )


def _scale_plate(pos, width: float, length: float, thick: float, color: str, rot=(0.0, 0.0, 0.0)):
    """Placa/escama chanfrada (20 tris)."""
    mat = Euler(rot, "XYZ").to_matrix()
    fwd = mat @ Vector((0.0, -1.0, 0.0))
    up = mat @ Vector((0.0, 0.0, 1.0))
    c = Vector(pos)
    p0 = c - fwd * (length * 0.42)
    p1 = c + fwd * (length * 0.42)
    return _loft_tube(
        [
            (tuple(p0), width * 0.52, thick * 0.55),
            (tuple(p1), width * 0.34, thick * 0.38),
        ],
        color,
        verts=5,
        cap0=0.30,
        cap1=0.55,
        smooth=False,
        ref_up=tuple(up),
        name="scale_plate",
    )


def _curved_claw(base_pos, tip_pos, mid_offset, r_base: float, color: str, verts: int = 6):
    """Garra/presa curva de 3 estacoes (2 * 3 * verts tris)."""
    v0, v2 = Vector(base_pos), Vector(tip_pos)
    v1 = v0.lerp(v2, 0.52) + Vector(mid_offset)
    return _loft_tube(
        [
            (tuple(v0), r_base, r_base * 1.08),
            (tuple(v1), r_base * 0.62, r_base * 0.72),
            (tuple(v2), max(0.010, r_base * 0.18), max(0.010, r_base * 0.22)),
        ],
        color,
        verts=verts,
        cap0=0.30,
        cap1=1.20,
        smooth=True,
        name="claw",
    )


def _cloven_hoof(cx: float, cy: float, width: float, height: float, color: str = "ironDark"):
    """Casco fendido esculpido em duas unhas chanfradas apoiadas em Z=0 + coroa superior."""
    parts = []
    half_gap = width * 0.28
    toe_w = width * 0.46
    for sx in (-1, 1):
        hx = cx + sx * half_gap
        parts.append(
            _loft_tube(
                [
                    ((hx, cy + 0.02, 0.018), toe_w, width * 0.62),
                    ((hx - sx * 0.008, cy - 0.025, height), toe_w * 0.80, width * 0.48),
                ],
                color,
                verts=6,
                cap0=0.12,
                cap1=0.35,
                smooth=False,
                ref_up=(0.0, -1.0, 0.15),
                name="hoof_toe",
            )
        )
    return parts


def _barrel_pack(center, r_end: float, r_mid: float, length: float, color: str, band_color: str, verts: int = 10):
    """Barril horizontal alinhado ao eixo X para carga de suprimentos."""
    cx, cy, cz = center
    hx = length * 0.5
    parts = [
        _loft_tube(
            [
                ((cx - hx, cy, cz), r_end),
                ((cx - hx * 0.45, cy, cz), r_mid),
                ((cx + hx * 0.45, cy, cz), r_mid),
                ((cx + hx, cy, cz), r_end),
            ],
            color,
            verts=verts,
            cap0=0.15,
            cap1=0.15,
            smooth=True,
            ref_up=(0.0, 0.0, 1.0),
            name="supply_cask",
        )
    ]
    for sx in (-1, 1):
        parts.append(
            _storus(
                r_mid * 0.97,
                0.024,
                (cx + sx * hx * 0.52, cy, cz),
                band_color,
                major_seg=9,
                minor_seg=4,
                rot=(0.0, math.pi / 2, 0.0),
            )
        )
    return parts


# ---------------------------------------------------------------- 1. Wyvern Body (4200..4800 tris)
def wyvern_body():
    """Corpo esculpido do wyvern: cabeca draconica chifruda + mandibula/presas (-Y), escamas peitorais e dorsais,
    encaixes de ombro em x=+-0.55, patas traseiras musculosas com garras triplas e cauda farpada em +Y."""
    p = []

    # 1. Tronco anatomico em arco + peitoral musculoso
    p.append(
        _loft_tube(
            [
                ((0.0, -0.72, 1.74), 0.46, 0.48),
                ((0.0, -0.42, 1.66), 0.62, 0.64),
                ((0.0, -0.06, 1.56), 0.66, 0.66),
                ((0.0, 0.34, 1.50), 0.56, 0.56),
                ((0.0, 0.72, 1.52), 0.42, 0.44),
            ],
            "wyvernScale",
            verts=15,
            cap0=0.38,
            cap1=0.38,
        )
    )
    for sx in (-1, 1):
        p.append(_sball(0.38, (sx * 0.28, -0.40, 1.56), "roof", seg=10, rings=7, squash=(0.95, 1.18, 0.86)))
        p.append(_sball(0.30, (sx * 0.30, 0.06, 1.64), "wyvernScale", seg=9, rings=6, squash=(0.88, 1.25, 0.78)))

    # Placas ventrais/esternais sobrepostas do papo ao ventre
    belly_scutes = (
        (-0.92, 1.88, 0.42, 0.30, 0.52),
        (-0.74, 1.58, 0.52, 0.34, 0.36),
        (-0.52, 1.32, 0.64, 0.38, 0.18),
        (-0.26, 1.14, 0.70, 0.40, 0.02),
        (0.02, 1.08, 0.66, 0.38, -0.08),
        (0.30, 1.12, 0.56, 0.36, -0.16),
        (0.56, 1.22, 0.46, 0.32, -0.22),
    )
    for idx, (by, bz, bw, bl, rx_tilt) in enumerate(belly_scutes):
        sc_col = "gold" if idx in (1, 2, 3) else "amber"
        p.append(_scale_plate((0.0, by, bz), bw, bl, 0.14, sc_col, rot=(rx_tilt, 0.0, 0.0)))

    # Escamas dorsais blindadas em camadas sobre cernelha e dorso
    dorsal_plates = (
        (-0.58, 2.06, 0.56, 0.44, -0.26),
        (-0.24, 2.12, 0.64, 0.48, -0.10),
        (0.12, 2.06, 0.60, 0.46, 0.02),
        (0.48, 1.94, 0.48, 0.40, 0.10),
    )
    for dy, dz, dw, dl, rx_tilt in dorsal_plates:
        p.append(_scale_plate((0.0, dy, dz), dw, dl, 0.15, "roof", rot=(rx_tilt, 0.0, 0.0)))
        for sx in (-1, 1):
            p.append(
                _scale_plate(
                    (sx * (dw * 0.46), dy + 0.04, dz - 0.14),
                    dw * 0.52,
                    dl * 0.78,
                    0.11,
                    "crimsonCloth",
                    rot=(rx_tilt, sx * 0.45, 0.0),
                )
            )

    # 2. Encaixes de ombro em x = +-0.55 + ombreiras escapulares
    for sx in (-1, 1):
        p.append(_sball(0.33, (sx * 0.55, -0.26, 1.78), "wyvernScale", seg=12, rings=8, squash=(1.05, 1.02, 0.96)))
        p.append(
            _storus(
                0.24,
                0.055,
                (sx * 0.58, -0.26, 1.78),
                "roof",
                major_seg=10,
                minor_seg=5,
                rot=(0.0, math.pi / 2, 0.18 * sx),
            )
        )
        p.append(_curved_claw((sx * 0.54, -0.22, 1.96), (sx * 0.76, -0.02, 2.30), (sx * 0.06, -0.05, 0.08), 0.11, "hornIvory", verts=6))
        p.append(_scale_plate((sx * 0.50, -0.34, 1.96), 0.32, 0.40, 0.12, "roof", rot=(-0.22, sx * 0.52, 0.0)))

    # 3. Pescoco em S musculoso + placas cervicais
    p.append(
        _loft_tube(
            [
                ((0.0, -0.64, 1.76), 0.38, 0.40),
                ((0.0, -0.92, 1.98), 0.33, 0.35),
                ((0.0, -1.16, 2.26), 0.29, 0.31),
                ((0.0, -1.36, 2.52), 0.26, 0.28),
                ((0.0, -1.54, 2.66), 0.25, 0.26),
            ],
            "wyvernScale",
            verts=12,
            cap0=0.30,
            cap1=0.30,
        )
    )
    for ny, nz, tilt_x in ((-0.88, 1.74, 0.68), (-1.08, 1.98, 0.78), (-1.28, 2.24, 0.72), (-1.44, 2.44, 0.55)):
        p.append(_scale_plate((0.0, ny, nz), 0.34, 0.26, 0.10, "amber", rot=(tilt_x, 0.0, 0.0)))

    # 4. Cabeca draconica anatomica (-Y) + mandibula articulada + presas + chifres
    p.append(_sball(0.34, (0.0, -1.62, 2.68), "wyvernScale", seg=11, rings=7, squash=(0.88, 1.12, 0.78)))
    # Focinho superior esculpido + crista nasal + chifre rostral
    p.append(
        _loft_tube(
            [
                ((0.0, -1.68, 2.69), 0.26, 0.20),
                ((0.0, -1.94, 2.66), 0.21, 0.17),
                ((0.0, -2.18, 2.62), 0.16, 0.14),
                ((0.0, -2.36, 2.59), 0.11, 0.11),
            ],
            "roof",
            verts=10,
            cap0=0.25,
            cap1=0.45,
        )
    )
    p.append(_curved_claw((0.0, -2.24, 2.64), (0.0, -2.38, 2.86), (0.0, -0.06, 0.04), 0.062, "hornIvory", verts=6))
    p.append(_curved_claw((0.0, -1.96, 2.74), (0.0, -2.02, 2.90), (0.0, -0.03, 0.02), 0.046, "hornIvory", verts=5))

    # Mandibula inferior articulada + interior bucal + lingua + espigao mentoniano
    p.append(
        _loft_tube(
            [
                ((0.0, -1.64, 2.51), 0.22, 0.13),
                ((0.0, -1.88, 2.44), 0.18, 0.11),
                ((0.0, -2.12, 2.39), 0.13, 0.09),
                ((0.0, -2.28, 2.37), 0.085, 0.07),
            ],
            "amber",
            verts=9,
            cap0=0.30,
            cap1=0.45,
        )
    )
    p.append(
        _loft_tube(
            [((0.0, -1.72, 2.53), 0.14, 0.05), ((0.0, -2.14, 2.45), 0.07, 0.035)],
            "ember",
            verts=6,
            cap0=0.25,
            cap1=0.55,
        )
    )
    p.append(_curved_claw((0.0, -2.22, 2.35), (0.0, -2.34, 2.22), (0.0, -0.04, -0.02), 0.048, "hornIvory", verts=5))

    # Fileiras de presas superiores e inferiores (bone / hornIvory)
    upper_fangs = ((-2.28, 2.55, 0.075, 0.13), (-2.08, 2.57, 0.12, 0.11), (-1.88, 2.59, 0.155, 0.095))
    for fy, fz, fx, fh in upper_fangs:
        for sx in (-1, 1):
            p.append(L.crystal(0.026, fh, (sx * fx, fy, fz), "bone", tilt=(math.pi - 0.12, sx * 0.08), verts=4))
    lower_fangs = ((-2.18, 2.41, 0.07, 0.11), (-1.94, 2.44, 0.115, 0.09))
    for fy, fz, fx, fh in lower_fangs:
        for sx in (-1, 1):
            p.append(L.crystal(0.022, fh, (sx * fx, fy, fz), "hornIvory", tilt=(0.15, -sx * 0.06), verts=4))

    # Arcos supraorbitais, olhos incandescentes, jugais e chifres draconicos curvos
    for sx in (-1, 1):
        p.append(_sball(0.11, (sx * 0.21, -1.62, 2.52), "wyvernScale", seg=8, rings=5))
        p.append(_sball(0.078, (sx * 0.21, -1.82, 2.72), "amberBright", seg=8, rings=5, squash=(0.75, 1.15, 0.85)))
        p.append(_sball(0.042, (sx * 0.24, -1.84, 2.72), "obsidian", seg=6, rings=4, squash=(0.55, 0.75, 1.10)))
        p.append(
            _loft_tube(
                [
                    ((sx * 0.13, -2.02, 2.74), 0.042, 0.036),
                    ((sx * 0.23, -1.82, 2.81), 0.056, 0.048),
                    ((sx * 0.26, -1.58, 2.82), 0.064, 0.052),
                ],
                "roof",
                verts=7,
            )
        )
        # Espigoes zigomaticos / mandibulares
        p.append(_curved_claw((sx * 0.24, -1.58, 2.58), (sx * 0.42, -1.36, 2.54), (sx * 0.04, 0.02, -0.01), 0.055, "hornIvory", verts=5))
        p.append(_curved_claw((sx * 0.19, -1.68, 2.46), (sx * 0.31, -1.52, 2.38), (sx * 0.03, 0.01, -0.01), 0.040, "bone", verts=5))
        # Chifre principal curvo em S com anel basal
        p.append(
            _storus(
                0.095,
                0.026,
                (sx * 0.18, -1.48, 2.79),
                "bronze",
                major_seg=8,
                minor_seg=4,
                rot=(-0.65, sx * 0.28, 0.0),
            )
        )
        p.append(
            _loft_tube(
                [
                    ((sx * 0.18, -1.48, 2.79), 0.105),
                    ((sx * 0.30, -1.18, 3.04), 0.082),
                    ((sx * 0.41, -0.88, 3.26), 0.058),
                    ((sx * 0.48, -0.60, 3.44), 0.034),
                    ((sx * 0.52, -0.36, 3.58), 0.015),
                ],
                "hornIvory",
                verts=9,
                cap0=0.25,
                cap1=1.35,
            )
        )
        # Chifre temporal secundario
        p.append(
            _loft_tube(
                [
                    ((sx * 0.24, -1.44, 2.68), 0.064),
                    ((sx * 0.38, -1.20, 2.76), 0.044),
                    ((sx * 0.48, -0.96, 2.84), 0.020),
                ],
                "amber",
                verts=7,
                cap0=0.25,
                cap1=1.20,
            )
        )

    # 5. Placas espinhosas ao longo da coluna (nuca ate base da cauda)
    spine_pts = (
        (-1.38, 2.76, 0.22, -0.55),
        (-1.14, 2.52, 0.26, -0.62),
        (-0.88, 2.26, 0.30, -0.58),
        (-0.56, 2.20, 0.36, -0.45),
        (-0.24, 2.24, 0.40, -0.38),
        (0.08, 2.20, 0.38, -0.40),
        (0.40, 2.10, 0.32, -0.44),
        (0.70, 1.96, 0.28, -0.48),
    )
    for sy, sz, sh, stilt in spine_pts:
        p.append(L.crystal(0.078, sh, (0.0, sy, sz), "hornIvory", tilt=(stilt, 0.0), verts=5))

    # 6. Pernas traseiras musculosas recolhidas com garras triplas + halux
    for sx in (-1, 1):
        hip = (sx * 0.40, 0.42, 1.42)
        knee = (sx * 0.54, 0.14, 0.86)
        hock = (sx * 0.48, 0.56, 0.38)
        foot = (sx * 0.48, 0.26, 0.10)
        p.append(_sball(0.27, hip, "wyvernScale", seg=9, rings=6, squash=(0.92, 1.18, 1.05)))
        p.append(_loft_tube([(hip, 0.24, 0.26), (knee, 0.16, 0.18)], "wyvernScale", verts=9))
        p.append(_scale_plate((sx * 0.56, 0.08, 0.88), 0.20, 0.26, 0.08, "roof", rot=(0.35, sx * 0.35, 0.0)))
        p.append(_loft_tube([(knee, 0.15, 0.16), (hock, 0.11, 0.12)], "roof", verts=8))
        p.append(_sball(0.11, hock, "wyvernScale", seg=7, rings=5))
        p.append(_loft_tube([(hock, 0.11, 0.10), (foot, 0.09, 0.08)], "ironDark", verts=8))
        for td, spread in ((-0.10, -0.18), (0.0, 0.0), (0.10, 0.18)):
            t_base = (sx * 0.48 + td, 0.24, 0.09)
            t_mid = (sx * 0.48 + td * 1.35 + spread * 0.04, 0.06, 0.06)
            t_tip = (sx * 0.48 + td * 1.55 + spread * 0.06, -0.08, 0.015)
            p.append(_loft_tube([(t_base, 0.048), (t_mid, 0.036)], "ironDark", verts=6))
            p.append(_curved_claw(t_mid, t_tip, (0.0, -0.02, 0.025), 0.038, "hornIvory", verts=5))
        # Garra traseira (halux)
        p.append(_curved_claw((sx * 0.48, 0.36, 0.12), (sx * 0.48, 0.54, 0.03), (0.0, 0.03, 0.02), 0.034, "hornIvory", verts=5))

    # 7. Cauda segmentada sinuosa com espinhos e dardo farpado em +Y (mantida abaixo de top 28% Z)
    tail_stations = [
        ((0.0, 0.72, 1.50), 0.35, 0.36),
        ((0.0, 1.32, 1.44), 0.28, 0.29),
        ((0.0, 1.96, 1.52), 0.21, 0.22),
        ((0.0, 2.60, 1.64), 0.15, 0.16),
        ((0.0, 3.22, 1.62), 0.095, 0.10),
        ((0.0, 3.78, 1.52), 0.055, 0.06),
    ]
    p.append(_loft_tube(tail_stations, "wyvernScale", verts=10, cap0=0.25, cap1=0.50))
    for i in range(len(tail_stations) - 1):
        c0 = tail_stations[i][0]
        c1 = tail_stations[i + 1][0]
        my = 0.5 * (c0[1] + c1[1])
        mz = 0.5 * (c0[2] + c1[2])
        r_seg = 0.5 * (tail_stations[i][1] + tail_stations[i + 1][1])
        p.append(L.crystal(max(0.04, r_seg * 0.38), 0.28 - i * 0.03, (0.0, my, mz + r_seg * 0.75), "hornIvory", tilt=(-0.58, 0.0), verts=5))
        p.append(_scale_plate((0.0, my, mz - r_seg * 0.72), r_seg * 1.55, 0.30, 0.07, "amber", rot=(0.08, 0.0, 0.0)))

    # Lamina caudal farpada tripla
    p.append(
        _loft_tube(
            [
                ((0.0, 3.68, 1.54), 0.16, 0.055),
                ((0.0, 3.96, 1.50), 0.24, 0.050),
                ((0.0, 4.28, 1.46), 0.035, 0.022),
            ],
            "amber",
            verts=7,
            cap0=0.30,
            cap1=1.20,
            smooth=False,
        )
    )
    for sx in (-1, 1):
        p.append(_curved_claw((sx * 0.08, 3.72, 1.54), (sx * 0.34, 4.04, 1.50), (sx * 0.06, 0.02, 0.01), 0.055, "roof", verts=5))

    return p


# ---------------------------------------------------------------- 2. Wyvern Wing (2000..2400 tris)
def wyvern_wing(side: int):
    """Asa draconica esculpida a partir do ombro (0, 0, 0) estendendo estritamente para side*X (~4.85 studs)."""
    s = float(side)
    p = []

    # Junta de ombro em (0, 0, 0.18) -> base Z=0, pivo em (0, 0, 0)
    sh = (0.0, 0.0, 0.18)
    elbow = (s * 1.46, -0.36, 0.68)
    wrist = (s * 2.58, -0.54, 1.14)

    # 4 dedos multi-falange irradiando da palma/cotovelo
    f1_a = (s * 3.42, -0.44, 1.30)
    f1_b = (s * 4.18, -0.32, 1.41)
    f1_tip = (s * 4.84, -0.16, 1.48)

    f2_a = (s * 3.22, 0.02, 1.14)
    f2_b = (s * 3.76, 0.46, 1.12)
    f2_tip = (s * 4.22, 0.90, 1.08)

    f3_a = (s * 2.66, 0.24, 0.98)
    f3_b = (s * 2.74, 0.92, 0.82)
    f3_tip = (s * 2.80, 1.54, 0.66)

    f4_a = (s * 1.56, 0.56, 0.56)
    f4_tip = (s * 1.62, 1.30, 0.42)
    flank = (s * 0.26, 1.04, 0.16)

    # Articulacoes principais
    p.append(_sball(0.18, sh, "wyvernScale", seg=15, rings=9))
    p.append(_sball(0.15, elbow, "wyvernScale", seg=12, rings=8))
    p.append(_sball(0.145, wrist, "roof", seg=12, rings=8))

    # Braco (umero) e antebraco (radio/ulna) musculosos
    p.append(
        _loft_tube(
            [
                (sh, 0.145, 0.155),
                ((s * 0.52, -0.14, 0.36), 0.155, 0.165),
                ((s * 1.02, -0.26, 0.54), 0.132, 0.142),
                (elbow, 0.122, 0.128),
            ],
            "wyvernScale",
            verts=13,
        )
    )
    p.append(
        _loft_tube(
            [
                (elbow, 0.128, 0.132),
                ((s * 1.88, -0.44, 0.86), 0.120, 0.126),
                ((s * 2.26, -0.50, 1.02), 0.108, 0.114),
                (wrist, 0.102, 0.108),
            ],
            "roof",
            verts=13,
        )
    )

    # Escamas de armadura ao longo do bordo de ataque (estritamente em side*X)
    for frac in (0.24, 0.48, 0.74):
        px = s * (0.18 + frac * 1.18)
        py = -0.36 * frac - 0.05
        pz = 0.20 + 0.48 * frac + 0.06
        p.append(_scale_plate((px, py, pz), 0.22, 0.28, 0.085, "roof", rot=(0.25, -s * 0.32, s * 0.65)))
    for frac in (0.28, 0.62, 0.88):
        px = elbow[0] + (wrist[0] - elbow[0]) * frac
        py = elbow[1] + (wrist[1] - elbow[1]) * frac - 0.05
        pz = elbow[2] + (wrist[2] - elbow[2]) * frac + 0.06
        p.append(_scale_plate((px, py, pz), 0.19, 0.24, 0.075, "amber", rot=(0.22, -s * 0.36, s * 0.55)))

    # Garra de pulso (alula articulada) + esporao de cotovelo
    alula_mid = (s * 2.66, -0.78, 1.26)
    alula_tip = (s * 2.54, -1.04, 1.38)
    p.append(_loft_tube([(wrist, 0.076), (alula_mid, 0.052)], "wyvernScale", verts=8))
    p.append(_curved_claw(alula_mid, alula_tip, (-s * 0.03, -0.04, 0.04), 0.055, "hornIvory", verts=7))
    p.append(_curved_claw(elbow, (s * 1.42, -0.64, 0.82), (0.0, -0.04, 0.04), 0.052, "hornIvory", verts=6))

    # Dedos articulados multi-falange + juntas + garras nas pontas
    digits = (
        (wrist, f1_a, f1_b, f1_tip, 0.088, (s * 4.98, -0.10, 1.50)),
        (wrist, f2_a, f2_b, f2_tip, 0.078, (s * 4.34, 1.00, 1.06)),
        (wrist, f3_a, f3_b, f3_tip, 0.068, (s * 2.82, 1.68, 0.63)),
    )
    for d0, da, db, dtip, r0, ctip in digits:
        p.append(
            _loft_tube(
                [(d0, r0), (da, r0 * 0.74), (db, r0 * 0.52), (dtip, r0 * 0.28)],
                "wyvernScale",
                verts=9,
            )
        )
        p.append(_sball(r0 * 0.82, da, "roof", seg=7, rings=5))
        p.append(_sball(r0 * 0.60, db, "amber", seg=7, rings=5))
        p.append(_curved_claw(dtip, ctip, (s * 0.02, 0.02, -0.01), r0 * 0.34, "hornIvory", verts=5))

    # 4o dedo interno saindo do cotovelo
    p.append(_loft_tube([(elbow, 0.066), (f4_a, 0.048), (f4_tip, 0.022)], "wyvernScale", verts=8))
    p.append(_sball(0.054, f4_a, "roof", seg=7, rings=5))
    p.append(_curved_claw(f4_tip, (s * 1.64, 1.44, 0.38), (0.0, 0.02, -0.01), 0.028, "hornIvory", verts=5))

    # Nervuras estruturais internas da membrana
    for st_a, st_b in (
        (wrist, (s * 3.94, 0.36, 1.08)),
        (wrist, (s * 3.16, 0.94, 0.78)),
        (elbow, (s * 2.18, 1.18, 0.54)),
        ((s * 0.78, -0.18, 0.42), (s * 0.96, 1.04, 0.30)),
    ):
        p.append(_loft_tube([(st_a, 0.026), (st_b, 0.014)], "crimsonCloth", verts=6, smooth=True))

    # Propatagio frontal (ombro-cotovelo-pulso) + membrana principal recortada em catenarias
    p.append(
        _wing_membrane_cambered(
            [sh, (s * 0.72, -0.30, 0.46), elbow, (s * 2.02, -0.52, 0.94), wrist, (s * 1.28, -0.22, 0.64)],
            (s * 1.32, -0.34, 0.68),
            0.042,
            "crimsonCloth",
            radial_rings=1,
            camber=0.02,
        )
    )

    ring = [
        sh,
        elbow,
        wrist,
        f1_a,
        f1_b,
        f1_tip,
        (s * 4.54, 0.14, 1.26),
        (s * 4.18, 0.32, 1.12),
        (s * 3.98, 0.42, 1.06),
        (s * 4.08, 0.66, 1.07),
        f2_tip,
        (s * 3.84, 0.94, 0.94),
        (s * 3.44, 0.92, 0.82),
        (s * 3.08, 1.14, 0.74),
        f3_tip,
        (s * 2.52, 1.34, 0.58),
        (s * 2.18, 1.18, 0.52),
        (s * 1.88, 1.22, 0.46),
        f4_tip,
        (s * 1.24, 1.12, 0.34),
        (s * 0.76, 1.02, 0.24),
        flank,
    ]
    hub = (s * 2.18, 0.34, 0.78)
    p.append(_wing_membrane_cambered(ring, hub, 0.052, "wyvernWing", radial_rings=3, camber=0.055))

    return p


# ---------------------------------------------------------------- 3. Bird Body (800..1000 tris)
def bird_body():
    """Corpo aerodinamico enxuto de falcao/corvo (800..1000 tris): bico em -Y, peito plumado, garras recolhidas e cauda em leque (+Y)."""
    p = []

    # Tronco aerodinamico enxuto + quilha peitoral + raizes de ombro (x = +-0.32)
    p.append(
        _loft_tube(
            [
                ((0.0, -0.50, 1.12), 0.24, 0.25),
                ((0.0, -0.22, 0.98), 0.37, 0.38),
                ((0.0, 0.10, 0.94), 0.33, 0.34),
                ((0.0, 0.44, 0.92), 0.18, 0.16),
            ],
            "ironDark",
            verts=10,
            cap0=0.35,
            cap1=0.40,
        )
    )
    p.append(_sball(0.29, (0.0, -0.22, 0.86), "stoneDark", seg=8, rings=5, squash=(0.82, 1.14, 0.76)))
    p.append(_scale_plate((0.0, -0.38, 0.94), 0.34, 0.28, 0.09, "stone", rot=(0.42, 0.0, 0.0)))
    for sx in (-1, 1):
        p.append(_sball(0.15, (sx * 0.32, -0.08, 1.08), "iron", seg=7, rings=5))

    # Cabeca de rapina, penacho nucal e bico curvo em -Y (topo Z na frente para G2!)
    p.append(_sball(0.26, (0.0, -0.58, 1.25), "ironDark", seg=8, rings=5, squash=(0.88, 1.10, 0.94)))
    p.append(_storus(0.20, 0.036, (0.0, -0.45, 1.13), "stoneDark", major_seg=8, minor_seg=4, rot=(0.48, 0.0, 0.0)))
    p.append(
        _loft_tube(
            [
                ((0.0, -0.76, 1.25), 0.095, 0.090),
                ((0.0, -1.00, 1.20), 0.056, 0.062),
                ((0.0, -1.17, 1.07), 0.016, 0.020),
            ],
            "amber",
            verts=7,
            cap0=0.25,
            cap1=1.20,
        )
    )
    for sx in (-1, 1):
        p.append(_sball(0.052, (sx * 0.16, -0.70, 1.30), "amberBright", seg=6, rings=4))
    for k, dz in enumerate((1.44, 1.36)):
        p.append(_feather_blade((0.0, -0.50, dz), (0.0, -0.16, dz + 0.06 - k * 0.02), 0.11, 0.04, "ironDark"))

    # Garras recolhidas aerodinamicamente sob o ventre
    for sx in (-1, 1):
        p.append(_loft_tube([((sx * 0.15, 0.02, 0.72), 0.066), ((sx * 0.17, 0.14, 0.48), 0.040)], "amber", verts=6))
        p.append(_curved_claw((sx * 0.17, 0.14, 0.48), (sx * 0.16, -0.04, 0.38), (0.0, -0.02, -0.02), 0.035, "ironDark", verts=5))
        p.append(_curved_claw((sx * 0.17, 0.14, 0.48), (sx * 0.24, -0.02, 0.39), (sx * 0.01, -0.02, -0.02), 0.030, "amberBright", verts=5))

    # Cauda em leque (+Y) com 5 penas losangulares largas + coberteira central
    for k in (-2, -1, 0, 1, 2):
        ang = k * 0.22
        tip = (0.52 * math.sin(ang), 1.48 * math.cos(ang), 0.92 + abs(k) * 0.022)
        col = "stoneDark" if k % 2 == 0 else "ironDark"
        p.append(_feather_blade((0.0, 0.44, 0.92), tip, 0.26, 0.042, col))
    p.append(_feather_blade((0.0, 0.36, 0.99), (0.0, 0.98, 0.97), 0.22, 0.04, "iron"))

    return p


# ---------------------------------------------------------------- 4. Bird Wing (400..500 tris)
def bird_wing(side: int):
    """Asa aerodinamica enxuta (400..500 tris) a partir do ombro (0, 0, 0) para side*X (~3.22 studs)."""
    s = float(side)
    p = []

    sh = (0.0, 0.0, 0.14)
    wrist = (s * 1.45, -0.22, 0.62)
    tip = (s * 3.16, 0.24, 0.98)

    p.append(_sball(0.14, sh, "ironDark", seg=8, rings=5))
    p.append(_sball(0.105, wrist, "iron", seg=6, rings=4))
    p.append(_loft_tube([(sh, 0.115), (wrist, 0.088), (tip, 0.026)], "ironDark", verts=7))
    # Pena alular no pulso
    p.append(_feather_blade(wrist, (s * 2.02, -0.26, 0.78), 0.13, 0.035, "stoneDark"))

    # Lamina alar manifold arqueada
    p.append(
        _wing_membrane_cambered(
            [sh, wrist, tip, (s * 2.46, 0.56, 0.72), (s * 1.56, 0.66, 0.48), (s * 0.36, 0.58, 0.18)],
            (s * 1.36, 0.16, 0.48),
            0.045,
            "iron",
            radial_rings=2,
            camber=0.03,
        )
    )

    # 7 penas primarias/secundarias losangulares
    feathers = (
        ((s * 2.24, -0.04, 0.76), (s * 3.22, 0.38, 0.96), 0.19, "ironDark"),
        ((s * 1.92, 0.03, 0.67), (s * 2.94, 0.60, 0.85), 0.21, "stoneDark"),
        ((s * 1.60, 0.09, 0.58), (s * 2.60, 0.80, 0.74), 0.22, "ironDark"),
        ((s * 1.28, 0.15, 0.49), (s * 2.20, 0.96, 0.61), 0.23, "stone"),
        ((s * 0.96, 0.20, 0.40), (s * 1.76, 1.06, 0.48), 0.24, "stoneDark"),
        ((s * 0.66, 0.24, 0.31), (s * 1.30, 1.06, 0.36), 0.24, "ironDark"),
        ((s * 0.36, 0.28, 0.22), (s * 0.80, 0.98, 0.24), 0.24, "stone"),
    )
    for p0, p1, w, col in feathers:
        p.append(_feather_blade(p0, p1, w, 0.038, col))

    # 3 coberteiras dorsais
    coverts = (
        ((s * 1.82, -0.08, 0.70), (s * 2.34, 0.34, 0.78), 0.17, "stone"),
        ((s * 1.28, -0.03, 0.53), (s * 1.74, 0.46, 0.59), 0.19, "iron"),
        ((s * 0.72, 0.04, 0.36), (s * 1.08, 0.54, 0.38), 0.20, "stone"),
    )
    for p0, p1, w, col in coverts:
        p.append(_feather_blade(p0, p1, w, 0.042, col))

    return p


# ---------------------------------------------------------------- 5. Stag (4000..4800 tris)
def stag():
    """Cervo real esculpido (4000..4800 tris): garupa e espaduas musculosas, juba peitoral em camadas,
    pernas com jarretes/boletos/cascos fendidos, focinho/orelhas (-Y) e galhada imperial ramificada."""
    p = []

    # 1. Tronco cervino anatomico + espaduas e garupa musculosas
    p.append(
        _loft_tube(
            [
                ((0.0, -0.68, 1.56), 0.40, 0.48),
                ((0.0, -0.34, 1.54), 0.48, 0.54),
                ((0.0, 0.10, 1.52), 0.43, 0.48),
                ((0.0, 0.52, 1.55), 0.45, 0.50),
                ((0.0, 0.82, 1.52), 0.32, 0.38),
            ],
            "furBrown",
            verts=17,
            cap0=0.38,
            cap1=0.38,
        )
    )
    # Faixa dorsal escura e ventre claro
    p.append(_loft_tube([((0.0, -0.58, 1.98), 0.14, 0.07), ((0.0, 0.72, 1.94), 0.12, 0.06)], "barkDark", verts=10))
    p.append(_sball(0.36, (0.0, -0.04, 1.22), "furTan", seg=11, rings=7, squash=(0.92, 1.85, 0.55)))
    for sx in (-1, 1):
        # Espaduas e coxas superiores musculosas
        p.append(_sball(0.29, (sx * 0.26, -0.52, 1.48), "furBrown", seg=11, rings=8, squash=(0.76, 1.05, 1.22)))
        p.append(_sball(0.32, (sx * 0.26, 0.58, 1.50), "furBrown", seg=11, rings=8, squash=(0.78, 1.12, 1.24)))

    # Cauda branca erguida em +Y
    p.append(
        _loft_tube(
            [((0.0, 0.86, 1.60), 0.12, 0.11), ((0.0, 1.06, 1.74), 0.09, 0.08), ((0.0, 1.18, 1.86), 0.03, 0.03)],
            "white",
            verts=9,
            cap1=1.1,
        )
    )
    p.append(_sball(0.14, (0.0, 0.88, 1.44), "hornIvory", seg=8, rings=5, squash=(1.15, 0.65, 1.05)))

    # 2. Juba peitoral em camadas (inverno real)
    ruff_layers = (
        (0.0, -0.78, 1.82, 0.28, "furTan"),
        (0.0, -0.86, 1.58, 0.32, "hornIvory"),
        (0.0, -0.82, 1.34, 0.28, "bone"),
        (-0.18, -0.72, 1.66, 0.22, "furTan"),
        (0.18, -0.72, 1.66, 0.22, "furTan"),
        (-0.16, -0.76, 1.44, 0.20, "hornIvory"),
        (0.16, -0.76, 1.44, 0.20, "hornIvory"),
    )
    for rx, ry, rz, rad, col in ruff_layers:
        p.append(_sball(rad, (rx, ry, rz), col, seg=8, rings=6, squash=(0.86, 0.95, 1.18)))

    # 3. 4 pernas anatomicas com joelhos/jarretes, boletos, ergots e cascos fendidos
    front_legs = ((-0.25, -0.54), (0.25, -0.54))
    for lx, ly in front_legs:
        knee = (lx, ly - 0.05, 0.72)
        fetlock = (lx, ly - 0.02, 0.20)
        p.append(_loft_tube([((lx, ly, 1.36), 0.155, 0.175), (knee, 0.088, 0.094)], "furBrown", verts=9))
        p.append(_sball(0.092, knee, "furBrown", seg=7, rings=5))
        p.append(_loft_tube([(knee, 0.080, 0.084), (fetlock, 0.064, 0.068)], "furTan", verts=9))
        p.append(_sball(0.072, fetlock, "furTan", seg=7, rings=5))
        p.append(L.crystal(0.026, 0.08, (lx, ly + 0.05, 0.18), "ironDark", tilt=(-2.2, 0.0), verts=5))
        p.extend(_cloven_hoof(lx, ly - 0.04, 0.088, 0.15, "ironDark"))

    hind_legs = ((-0.26, 0.60), (0.26, 0.60))
    for lx, ly in hind_legs:
        hock = (lx, ly + 0.12, 0.76)
        fetlock = (lx, ly + 0.04, 0.20)
        p.append(_loft_tube([((lx, ly, 1.38), 0.175, 0.205), (hock, 0.092, 0.105)], "furBrown", verts=9))
        p.append(_sball(0.098, hock, "furBrown", seg=7, rings=5))
        p.append(_loft_tube([(hock, 0.082, 0.088), (fetlock, 0.064, 0.068)], "furTan", verts=9))
        p.append(_sball(0.072, fetlock, "furTan", seg=7, rings=5))
        p.append(L.crystal(0.026, 0.08, (lx, ly + 0.11, 0.18), "ironDark", tilt=(-2.2, 0.0), verts=5))
        p.extend(_cloven_hoof(lx, ly + 0.02, 0.088, 0.15, "ironDark"))

    # 4. Pescoco erguido + cabeca nobre, orelhas e focinho (-Y)
    p.append(
        _loft_tube(
            [
                ((0.0, -0.66, 1.66), 0.30, 0.34),
                ((0.0, -0.88, 2.08), 0.24, 0.27),
                ((0.0, -1.06, 2.48), 0.19, 0.21),
            ],
            "furBrown",
            verts=13,
        )
    )
    p.append(_sball(0.24, (0.0, -1.16, 2.60), "furBrown", seg=11, rings=7, squash=(0.84, 1.16, 0.82)))
    p.append(
        _loft_tube(
            [
                ((0.0, -1.24, 2.58), 0.16, 0.15),
                ((0.0, -1.50, 2.52), 0.115, 0.115),
                ((0.0, -1.70, 2.48), 0.082, 0.082),
            ],
            "furTan",
            verts=11,
        )
    )
    p.append(
        _loft_tube(
            [((0.0, -1.24, 2.46), 0.11, 0.07), ((0.0, -1.62, 2.40), 0.062, 0.048)],
            "furBrown",
            verts=8,
        )
    )
    p.append(_sball(0.072, (0.0, -1.73, 2.50), "ink", seg=8, rings=5, squash=(1.08, 0.85, 0.82)))

    for sx in (-1, 1):
        p.append(_sball(0.056, (sx * 0.17, -1.28, 2.64), "ink", seg=7, rings=5))
        p.append(_sball(0.032, (sx * 0.19, -1.30, 2.65), "amber", seg=6, rings=4))
        # Orelha em concha (externa furBrown + interna hornIvory)
        p.append(
            _loft_tube(
                [
                    ((sx * 0.18, -1.04, 2.68), 0.055, 0.038),
                    ((sx * 0.36, -0.94, 2.82), 0.078, 0.042),
                    ((sx * 0.48, -0.88, 2.94), 0.024, 0.018),
                ],
                "furBrown",
                verts=7,
            )
        )
        p.append(
            _loft_tube(
                [((sx * 0.22, -1.04, 2.69), 0.038, 0.022), ((sx * 0.42, -0.94, 2.86), 0.026, 0.016)],
                "hornIvory",
                verts=6,
            )
        )

        # 5. Galhada imperial multi-pontas (coroa mantida em -Y para silhueta imponente e G2)
        b0 = (sx * 0.14, -1.08, 2.76)
        b1 = (sx * 0.34, -0.98, 3.08)
        b2 = (sx * 0.54, -0.84, 3.44)
        b3 = (sx * 0.68, -0.68, 3.80)
        b4 = (sx * 0.72, -0.54, 4.12)
        p.append(_storus(0.074, 0.026, b0, "gold", major_seg=9, minor_seg=4, rot=(-0.25, sx * 0.35, 0.0)))
        p.append(
            _loft_tube(
                [(b0, 0.068), (b1, 0.058), (b2, 0.048), (b3, 0.038), (b4, 0.016)],
                "hornIvory",
                verts=10,
                cap0=0.20,
                cap1=1.35,
            )
        )
        # Ponta ocular (brow tine, -Y), bez tine, trez tine e coroa real tripla
        tines = (
            (b0, (sx * 0.26, -1.36, 2.94), (sx * 0.24, -1.56, 3.18), 0.046, "amber"),
            (b1, (sx * 0.46, -1.24, 3.28), (sx * 0.42, -1.42, 3.54), 0.042, "hornIvory"),
            (b2, (sx * 0.68, -1.06, 3.64), (sx * 0.64, -1.20, 3.92), 0.038, "amber"),
            (b2, (sx * 0.42, -0.78, 3.68), (sx * 0.34, -0.82, 3.96), 0.034, "bone"),
            (b3, (sx * 0.56, -0.76, 3.98), (sx * 0.50, -0.86, 4.18), 0.032, "amber"),
            (b3, (sx * 0.82, -0.74, 3.96), (sx * 0.88, -0.80, 4.14), 0.030, "hornIvory"),
            (b3, (sx * 0.74, -0.46, 3.96), (sx * 0.76, -0.34, 4.12), 0.028, "bone"),
        )
        for t0, tm, tt, tr, tcol in tines:
            p.append(_loft_tube([(t0, tr), (tm, tr * 0.64), (tt, 0.013)], tcol, verts=8, cap0=0.20, cap1=1.35))

    return p


# ---------------------------------------------------------------- 6. Pack Ox (4000..4800 tris)
def pack_ox():
    """Boi de carga robusto do Bastiao (4000..4800 tris): cupim musculoso, chifres erguidos + estandarte/lanterna
    na canga frontal (-Y, garantindo G2 de orientacao!), sino de latao, manta e alforges rebitados com cristais ambar."""
    p = []

    # 1. Tronco pesado + cupim elevado na cernelha (-Y) + barbela pregueada
    p.append(
        _loft_tube(
            [
                ((0.0, -0.82, 1.44), 0.58, 0.62),
                ((0.0, -0.38, 1.42), 0.76, 0.74),
                ((0.0, 0.16, 1.38), 0.78, 0.74),
                ((0.0, 0.68, 1.40), 0.68, 0.68),
                ((0.0, 1.04, 1.38), 0.46, 0.50),
            ],
            "furBrown",
            verts=16,
            cap0=0.38,
            cap1=0.38,
        )
    )
    # Cupim e musculatura das espaduas
    p.append(_sball(0.58, (0.0, -0.62, 1.72), "woodDark", seg=13, rings=8, squash=(0.92, 1.05, 0.94)))
    for sx in (-1, 1):
        p.append(_sball(0.40, (sx * 0.44, -0.58, 1.36), "woodDark", seg=11, rings=7, squash=(0.78, 1.08, 1.18)))
        p.append(_sball(0.42, (sx * 0.42, 0.66, 1.36), "furBrown", seg=11, rings=7, squash=(0.78, 1.12, 1.18)))
    # Barbela sob o pescoco
    p.append(
        _loft_tube(
            [
                ((0.0, -1.24, 1.22), 0.12, 0.22),
                ((0.0, -0.96, 1.02), 0.14, 0.26),
                ((0.0, -0.66, 0.98), 0.15, 0.22),
            ],
            "furTan",
            verts=8,
        )
    )

    # Cauda com tufo em +Y
    p.append(
        _loft_tube(
            [((0.0, 1.14, 1.44), 0.08, 0.08), ((0.0, 1.36, 1.08), 0.055, 0.055), ((0.0, 1.44, 0.74), 0.04, 0.04)],
            "woodDark",
            verts=7,
        )
    )
    p.append(_sball(0.11, (0.0, 1.45, 0.66), "furBrown", seg=7, rings=5, squash=(0.85, 0.85, 1.45)))

    # 2. 4 pernas possantes com joelhos e cascos fendidos
    for sx in (-1, 1):
        for sy, ky, fy in ((-0.62, -0.66, -0.66), (0.68, 0.76, 0.72)):
            p.append(_loft_tube([((sx * 0.44, sy, 1.18), 0.22, 0.24), ((sx * 0.44, ky, 0.62), 0.15, 0.16)], "woodDark", verts=9))
            p.append(_sball(0.155, (sx * 0.44, ky, 0.62), "woodDark", seg=7, rings=5))
            p.append(_loft_tube([((sx * 0.44, ky, 0.62), 0.14, 0.14), ((sx * 0.44, fy, 0.20), 0.12, 0.12)], "furBrown", verts=8))
            p.extend(_cloven_hoof(sx * 0.44, fy - 0.02, 0.135, 0.18, "ironDark"))

    # 3. Cabeca bovina esculpida (-Y), argola nasal, sino de latao e chifres altivos erguidos
    p.append(_sball(0.38, (0.0, -1.20, 1.54), "furBrown", seg=10, rings=7, squash=(0.96, 0.98, 0.88)))
    p.append(_sball(0.24, (0.0, -1.16, 1.82), "woodDark", seg=8, rings=5, squash=(1.15, 0.92, 0.68)))
    p.append(
        _loft_tube(
            [
                ((0.0, -1.30, 1.48), 0.29, 0.23),
                ((0.0, -1.56, 1.38), 0.24, 0.19),
                ((0.0, -1.74, 1.32), 0.21, 0.16),
            ],
            "furTan",
            verts=10,
        )
    )
    p.append(_loft_tube([((0.0, -1.32, 1.32), 0.19, 0.10), ((0.0, -1.66, 1.22), 0.14, 0.08)], "furBrown", verts=8))
    # Argola de ouro no focinho
    p.append(_storus(0.115, 0.030, (0.0, -1.80, 1.18), "gold", major_seg=9, minor_seg=4, rot=(0.38, 0.0, 0.0)))

    # Coleira de couro + sino de latao com badalo brilhante
    p.append(_storus(0.46, 0.048, (0.0, -0.96, 1.46), "woodDark", major_seg=10, minor_seg=4, rot=(1.12, 0.0, 0.0)))
    p.append(L.cyl(0.135, 0.24, (0.0, -1.08, 0.78), "brass", verts=10, r2=0.075))
    p.append(_storus(0.135, 0.022, (0.0, -1.08, 0.79), "gold", major_seg=9, minor_seg=4))
    p.append(_sball(0.058, (0.0, -1.08, 0.75), "goldBright", seg=7, rings=5))

    for sx in (-1, 1):
        p.append(_sball(0.062, (sx * 0.28, -1.34, 1.58), "ink", seg=7, rings=5))
        p.append(_sball(0.09, (sx * 0.11, -1.75, 1.35), "ink", seg=6, rings=4, squash=(0.65, 0.55, 0.55)))
        # Orelhas laterais caidas
        p.append(
            _loft_tube(
                [((sx * 0.28, -1.14, 1.56), 0.065, 0.045), ((sx * 0.52, -1.12, 1.46), 0.085, 0.042), ((sx * 0.64, -1.10, 1.40), 0.032, 0.022)],
                "furBrown",
                verts=7,
            )
        )
        # Chifres longhorn varridos para frente (-Y) e para o alto (+Z ate 2.76!) com aneis
        h_pts = [
            ((sx * 0.24, -1.16, 1.74), 0.125),
            ((sx * 0.54, -1.18, 1.84), 0.106),
            ((sx * 0.78, -1.26, 2.04), 0.088),
            ((sx * 0.88, -1.38, 2.30), 0.068),
            ((sx * 0.82, -1.48, 2.56), 0.046),
            ((sx * 0.70, -1.54, 2.76), 0.020),
        ]
        p.append(_loft_tube(h_pts, "hornIvory", verts=12, cap0=0.25, cap1=1.35))
        p.append(_storus(0.128, 0.026, (sx * 0.28, -1.16, 1.75), "amber", major_seg=9, minor_seg=4, rot=(0.0, math.pi / 2, 0.0)))
        p.append(_storus(0.106, 0.022, (sx * 0.54, -1.18, 1.84), "amber", major_seg=9, minor_seg=4, rot=(0.2, sx * 1.2, 0.0)))

    # 4. Canga de madeira esculpida e ferrada + arco/lanterna de vigia frontal (-Y, alto Z!)
    p.append(L.box((1.66, 0.34, 0.26), (0.0, -0.74, 2.10), "wood", bevel=0.03))
    p.append(L.box((0.36, 0.38, 0.30), (0.0, -0.74, 2.12), "ironDark", bevel=0.02))
    for sx in (-1, 1):
        p.append(L.box((0.15, 0.26, 0.62), (sx * 0.62, -0.74, 1.80), "woodLight", bevel=0.02))
        p.append(L.box((0.18, 0.36, 0.28), (sx * 0.62, -0.74, 2.10), "ironDark"))
        p.append(_storus(0.105, 0.028, (sx * 0.76, -0.74, 2.10), "steel", major_seg=9, minor_seg=4, rot=(0.0, math.pi / 2, 0.0)))
        # Arco de ferro forjado sobre a canga apontando para frente (-Y)
        p.append(
            _loft_tube(
                [
                    ((sx * 0.38, -0.74, 2.22), 0.042),
                    ((sx * 0.28, -0.82, 2.52), 0.036),
                    ((0.0, -0.88, 2.70), 0.034),
                ],
                "ironDark",
                verts=8,
            )
        )
    # Finial e lanterna de cristal ambar no topo do arco da canga (-Y, z=2.36..2.78)
    p.append(L.cyl(0.11, 0.08, (0.0, -0.88, 2.66), "brass", verts=9, r2=0.04))
    p.append(L.crystal(0.055, 0.14, (0.0, -0.88, 2.72), "goldBright", verts=6))
    p.append(L.cyl(0.12, 0.22, (0.0, -0.92, 2.38), "amberBright", verts=9, r2=0.09))
    p.append(L.cyl(0.145, 0.06, (0.0, -0.92, 2.58), "brass", verts=9, r2=0.06))
    p.append(L.cyl(0.13, 0.05, (0.0, -0.92, 2.34), "ironDark", verts=9))

    # 5. Manta tecida + cilha/peitoral + alforges laterais rebitados + barril frontal + cristais ambar
    p.append(L.box((1.64, 1.32, 0.14), (0.0, 0.10, 1.84), "crimsonCloth", bevel=0.025))
    p.append(L.box((1.68, 0.16, 0.15), (0.0, -0.50, 1.85), "gold"))
    p.append(L.box((1.68, 0.16, 0.15), (0.0, 0.70, 1.85), "gold"))
    # Cilha abdominal e correia peitoral com fivela de latao
    p.append(_storus(0.76, 0.042, (0.0, 0.12, 1.36), "woodDark", major_seg=14, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(_storus(0.56, 0.036, (0.0, -0.68, 1.32), "woodDark", major_seg=12, minor_seg=4, rot=(0.45, 0.0, 0.0)))
    p.append(_storus(0.085, 0.024, (0.0, -0.98, 1.18), "brass", major_seg=8, minor_seg=4, rot=(0.95, 0.0, 0.0)))
    # Barril de suprimentos amarrado na frente da sela (y=-0.24, z=2.00)
    p.extend(_barrel_pack((0.0, -0.24, 2.00), 0.17, 0.21, 0.96, "wood", "ironDark", verts=11))

    # Alforges laterais rebitados com cristais ambar brilhantes
    for sx in (-1, 1):
        bx = sx * 0.96
        p.append(L.box((0.56, 1.14, 0.72), (bx, 0.14, 1.44), "woodDark", bevel=0.028))
        p.append(L.box((0.60, 1.18, 0.14), (bx, 0.14, 1.79), "wood", bevel=0.02))
        for sy_b in (-0.36, 0.0, 0.36):
            p.append(L.box((0.62, 0.10, 0.70), (bx, 0.14 + sy_b, 1.44), "ironDark"))
            p.append(L.crystal(0.036, 0.045, (bx + sx * 0.30, 0.14 + sy_b, 1.64), "steel", tilt=(0.0, sx * math.pi / 2), verts=5))
            p.append(L.crystal(0.036, 0.045, (bx + sx * 0.30, 0.14 + sy_b, 1.24), "steel", tilt=(0.0, sx * math.pi / 2), verts=5))

        # Cristais ambar emergindo dos alforges (mais altos na frente, mais baixos atras -> G2 seguro!)
        crystals = (
            (-0.32, "amberBright", 0.48, (0.24, -sx * 0.22)),
            (-0.10, "amber", 0.42, (0.10, -sx * 0.18)),
            (0.14, "goldBright", 0.32, (-0.12, -sx * 0.26)),
            (0.34, "amber", 0.26, (-0.22, sx * 0.16)),
        )
        for dy, col, ch, ctilt in crystals:
            p.append(L.crystal(0.125, ch, (bx + sx * 0.03, 0.14 + dy, 1.80), col, tilt=ctilt, verts=6))

    return p


# ---------------------------------------------------------------- 7. Ram (4000..4800 tris)
def ram():
    """Carneiro da montanha esculpido (4000..4800 tris): velo lanoso em camadas, pernas musculosas
    com cascos fendidos, cabeca ovina (-Y) e chifres espiralados canelados com aneis."""
    p = []

    # 1. Tronco base + manto denso de tufos de la esculpidos (costas <= 1.50, ombros/juba em -Y ate 1.66)
    p.append(
        _loft_tube(
            [
                ((0.0, -0.62, 1.18), 0.44, 0.48),
                ((0.0, -0.14, 1.14), 0.54, 0.52),
                ((0.0, 0.38, 1.12), 0.50, 0.48),
                ((0.0, 0.74, 1.12), 0.36, 0.38),
            ],
            "stoneLight",
            verts=12,
        )
    )

    # Tufos de la sobre o pescoco/peito (-Y) e flancos/dorso
    fleece_center = (
        (0.0, -0.68, 1.32, 0.38, "whiteStone", (0.94, 0.92, 1.04)),
        (0.0, -0.78, 1.06, 0.34, "parchment", (0.92, 0.86, 1.08)),
        (0.0, -0.44, 1.34, 0.42, "furTan", (0.96, 1.02, 0.84)),
        (0.0, -0.06, 1.24, 0.44, "whiteStone", (1.02, 1.12, 0.74)),
        (0.0, 0.36, 1.22, 0.42, "stoneLight", (0.98, 1.08, 0.74)),
        (0.0, 0.72, 1.18, 0.32, "whiteStone", (0.94, 0.96, 0.82)),
        (0.0, 0.96, 1.16, 0.20, "parchment", (0.85, 0.95, 0.92)),
    )
    for fx, fy, fz, fr, fcol, fsq in fleece_center:
        p.append(_sball(fr, (fx, fy, fz), fcol, seg=9, rings=6, squash=fsq))

    fleece_sides = (
        (0.32, -0.56, 1.24, 0.26, "parchment"),
        (0.38, -0.24, 1.18, 0.31, "whiteStone"),
        (0.40, 0.12, 1.16, 0.31, "stoneLight"),
        (0.37, 0.46, 1.15, 0.28, "whiteStone"),
        (0.28, 0.72, 1.14, 0.24, "parchment"),
        (0.30, -0.58, 0.96, 0.25, "whiteStone"),
        (0.33, 0.08, 0.95, 0.27, "furTan"),
    )
    for fx, fy, fz, fr, fcol in fleece_sides:
        for sx in (-1, 1):
            p.append(_sball(fr, (sx * fx, fy, fz), fcol, seg=8, rings=5, squash=(0.86, 1.08, 0.88)))

    # 2. 4 pernas alpinas musculosas + jarretes + cascos fendidos
    for sx in (-1, 1):
        for sy, ky, fy in ((-0.48, -0.52, -0.50), (0.54, 0.62, 0.58)):
            p.append(_sball(0.20, (sx * 0.32, sy, 0.94), "stoneLight", seg=8, rings=5, squash=(0.88, 1.04, 1.12)))
            p.append(_loft_tube([((sx * 0.32, sy, 0.88), 0.145, 0.155), ((sx * 0.32, ky, 0.48), 0.102, 0.108)], "furBrown", verts=9))
            p.append(_sball(0.105, (sx * 0.32, ky, 0.48), "furBrown", seg=7, rings=5))
            p.append(_loft_tube([((sx * 0.32, ky, 0.48), 0.095, 0.095), ((sx * 0.32, fy, 0.16), 0.082, 0.082)], "furTan", verts=8))
            p.append(L.crystal(0.024, 0.07, (sx * 0.32, fy + 0.06, 0.15), "ironDark", tilt=(-2.2, 0.0), verts=5))
            p.extend(_cloven_hoof(sx * 0.32, fy - 0.02, 0.098, 0.15, "ironDark"))

    # 3. Cabeca ovina forte esculpida (-Y)
    p.append(_sball(0.28, (0.0, -0.94, 1.50), "furBrown", seg=10, rings=7, squash=(0.88, 1.12, 0.86)))
    p.append(_sball(0.20, (0.0, -0.88, 1.66), "whiteStone", seg=9, rings=6, squash=(1.08, 0.92, 0.72)))
    p.append(
        _loft_tube(
            [
                ((0.0, -1.04, 1.46), 0.19, 0.17),
                ((0.0, -1.26, 1.38), 0.145, 0.135),
                ((0.0, -1.42, 1.30), 0.105, 0.105),
            ],
            "furTan",
            verts=9,
        )
    )
    p.append(_loft_tube([((0.0, -1.06, 1.32), 0.12, 0.075), ((0.0, -1.36, 1.22), 0.075, 0.055)], "furBrown", verts=7))
    p.append(_sball(0.058, (0.0, -1.44, 1.31), "ink", seg=7, rings=5, squash=(1.1, 0.8, 0.8)))

    # 4. Chifres espiralados canelados + aneis esculpidos (arco superior em -Y ate z=2.04 -> G2!)
    base_spiral = (
        (0.15, -0.86, 1.66, 0.155),
        (0.29, -0.74, 1.92, 0.144),
        (0.44, -0.62, 1.98, 0.132),
        (0.55, -0.58, 1.74, 0.118),
        (0.58, -0.74, 1.42, 0.102),
        (0.53, -0.98, 1.24, 0.084),
        (0.51, -1.18, 1.30, 0.064),
        (0.60, -1.26, 1.50, 0.042),
        (0.68, -1.18, 1.68, 0.020),
    )
    for sx in (-1, 1):
        p.append(_sball(0.056, (sx * 0.22, -1.08, 1.54), "amberBright", seg=7, rings=5))
        p.append(_sball(0.032, (sx * 0.25, -1.09, 1.54), "ink", seg=6, rings=4, squash=(0.55, 1.1, 0.6)))
        # Orelha atras da base do chifre
        p.append(
            _loft_tube(
                [((sx * 0.22, -0.82, 1.50), 0.050, 0.034), ((sx * 0.40, -0.76, 1.44), 0.028, 0.020)],
                "furBrown",
                verts=7,
            )
        )

        # Interpola estacoes intermediarias alternando crista/sulco para caneluras organicas!
        horn_stations = []
        for idx in range(len(base_spiral) - 1):
            x0, y0, z0, r0 = base_spiral[idx]
            x1, y1, z1, r1 = base_spiral[idx + 1]
            horn_stations.append(((sx * x0, y0, z0), r0 * 1.06, r0 * 1.12))
            mx, my, mz = 0.5 * (x0 + x1), 0.5 * (y0 + y1), 0.5 * (z0 + z1)
            mr = 0.5 * (r0 + r1)
            horn_stations.append(((sx * mx, my, mz), mr * 0.92, mr * 0.96))
        xl, yl, zl, rl = base_spiral[-1]
        horn_stations.append(((sx * xl, yl, zl), rl, rl))

        p.append(_loft_tube(horn_stations, "hornIvory", verts=11, cap0=0.25, cap1=1.35))

        # Aneis pronunciados ao longo da curva superior do chifre
        for r_idx in (0, 1, 2, 3):
            rx0, ry0, rz0, rr0 = base_spiral[r_idx]
            rx1, ry1, rz1, _ = base_spiral[r_idx + 1]
            dvec = Vector((sx * (rx1 - rx0), ry1 - ry0, rz1 - rz0)).normalized()
            rot_ring = Vector((0.0, 0.0, 1.0)).rotation_difference(dvec).to_euler("XYZ")
            p.append(
                _storus(
                    rr0 * 1.04,
                    0.022,
                    (sx * rx0, ry0, rz0),
                    "bone" if r_idx % 2 == 0 else "amber",
                    major_seg=8,
                    minor_seg=4,
                    rot=tuple(rot_ring),
                )
            )

    return p


# ---------------------------------------------------------------- SPECS (spec@6)
SPECS = [
    {
        "id": "fauna.wyvern_body.01",
        "name": "FAUNA_wyvern_body",
        "glb": "wyvern_body.glb",
        "tipo": "prop_estatico",
        "pivot": "base",
        "limite": 5000,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 1,
        "center_xy": True,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "wyvern", "body"],
        "seed": L.SEED_BASE + 8101,
        "build": wyvern_body,
    },
    {
        "id": "fauna.wyvern_wing_l.01",
        "name": "FAUNA_wyvern_wing_l",
        "glb": "wyvern_wing_l.glb",
        "tipo": "prop_estatico",
        "pivot": "origem",
        "center_xy": False,
        "limite": 2600,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 1,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "wyvern", "wing_l"],
        "seed": L.SEED_BASE + 8102,
        "build": (lambda: wyvern_wing(-1)),
    },
    {
        "id": "fauna.wyvern_wing_r.01",
        "name": "FAUNA_wyvern_wing_r",
        "glb": "wyvern_wing_r.glb",
        "tipo": "prop_estatico",
        "pivot": "origem",
        "center_xy": False,
        "limite": 2600,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 1,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "wyvern", "wing_r"],
        "seed": L.SEED_BASE + 8103,
        "build": (lambda: wyvern_wing(1)),
    },
    {
        "id": "fauna.bird_body.01",
        "name": "FAUNA_bird_body",
        "glb": "bird_body.glb",
        "tipo": "prop_estatico",
        "pivot": "base",
        "limite": 1200,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 2,
        "center_xy": True,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "bird", "body"],
        "seed": L.SEED_BASE + 8201,
        "build": bird_body,
    },
    {
        "id": "fauna.bird_wing_l.01",
        "name": "FAUNA_bird_wing_l",
        "glb": "bird_wing_l.glb",
        "tipo": "prop_estatico",
        "pivot": "origem",
        "center_xy": False,
        "limite": 650,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 2,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "bird", "wing_l"],
        "seed": L.SEED_BASE + 8202,
        "build": (lambda: bird_wing(-1)),
    },
    {
        "id": "fauna.bird_wing_r.01",
        "name": "FAUNA_bird_wing_r",
        "glb": "bird_wing_r.glb",
        "tipo": "prop_estatico",
        "pivot": "origem",
        "center_xy": False,
        "limite": 650,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 2,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "bird", "wing_r"],
        "seed": L.SEED_BASE + 8203,
        "build": (lambda: bird_wing(1)),
    },
    {
        "id": "fauna.stag.01",
        "name": "FAUNA_stag",
        "glb": "stag.glb",
        "tipo": "prop_estatico",
        "pivot": "base",
        "limite": 5000,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 2,
        "center_xy": True,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "stag"],
        "seed": L.SEED_BASE + 8301,
        "build": stag,
    },
    {
        "id": "fauna.pack_ox.01",
        "name": "FAUNA_pack_ox",
        "glb": "pack_ox.glb",
        "tipo": "prop_estatico",
        "pivot": "base",
        "limite": 5000,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 2,
        "center_xy": True,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "pack_ox"],
        "seed": L.SEED_BASE + 8401,
        "build": pack_ox,
    },
    {
        "id": "fauna.ram.01",
        "name": "FAUNA_ram",
        "glb": "ram.glb",
        "tipo": "prop_estatico",
        "pivot": "base",
        "limite": 5000,
        "hero_pbr": False,
        "qualidade": "standard",
        "quantidade_cena": 2,
        "center_xy": True,
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "ram"],
        "seed": L.SEED_BASE + 8501,
        "build": ram,
    },
]


def _audit_fauna(objs) -> None:
    """Valida faixas exatas de tris, cores PAL <= 16, contrato de pivo das asas e frente -Y Blender."""
    audit_rows = []
    errors = []
    for spec, obj in zip(SPECS, objs):
        iid = spec["id"]
        n_tris = L.tris(obj)
        lo, hi = TRI_TARGETS[iid]
        if not (lo <= n_tris <= hi):
            errors.append(f"{iid}: tris={n_tris} fora do alvo [{lo}, {hi}]")

        pal_n = len(L.extract_pal_colors(obj, max_colors=64))
        if pal_n > 16:
            errors.append(f"{iid}: pal_colors={pal_n} > 16")

        mn, mx = L.bbox(obj)
        row = {"id": iid, "tris": n_tris, "target": [lo, hi], "pal_colors": pal_n}

        if "wing_" not in iid:
            z_min, z_max = mn[2], mx[2]
            y_min, y_max = mn[1], mx[1]
            dz = z_max - z_min
            dy = y_max - y_min
            y_mid = 0.5 * (y_min + y_max)
            lim_y = y_mid + 0.08 * dy
            z_cut = z_min + 0.72 * dz
            top_v = [v.co.y for v in obj.data.vertices if v.co.z >= z_cut]
            top_loop = [
                obj.data.vertices[vi].co.y
                for poly in obj.data.polygons
                for vi in poly.vertices
                if obj.data.vertices[vi].co.z >= z_cut
            ]
            mean_v = sum(top_v) / len(top_v)
            mean_loop = sum(top_loop) / len(top_loop)
            row["g2_mean_y"] = round(mean_v, 4)
            row["g2_loop_y"] = round(mean_loop, 4)
            row["g2_limit_y"] = round(lim_y, 4)
            if mean_v > lim_y or mean_loop > lim_y:
                errors.append(
                    f"{iid}: G2 criatura_de_costas mean_v={mean_v:.4f} mean_loop={mean_loop:.4f} > {lim_y:.4f}"
                )

        if "wing_l" in iid:
            row["x_span"] = [round(mn[0], 4), round(mx[0], 4)]
            if abs(mn[2]) > 1e-4 or not (mn[0] < -2.5 and abs(mn[0]) > 8.0 * abs(mx[0])):
                errors.append(f"{iid}: wing_l pivot/span invalido min={mn} max={mx}")
        elif "wing_r" in iid:
            row["x_span"] = [round(mn[0], 4), round(mx[0], 4)]
            if abs(mn[2]) > 1e-4 or not (mx[0] > 2.5 and abs(mx[0]) > 8.0 * abs(mn[0])):
                errors.append(f"{iid}: wing_r pivot/span invalido min={mn} max={mx}")

        audit_rows.append(row)

    print("FAUNA_AUDIT " + json.dumps({"ok": not errors, "items": audit_rows, "errors": errors}))
    if errors:
        raise SystemExit("[fauna-audit] reprovado: " + "; ".join(errors))


_built_objs = L.run_group(
    "fauna",
    SPECS,
    "fauna articulada e silvestre do Bastiao (art/scripts/make_fauna.py)",
    hero_pbr=False,
)
_audit_fauna(_built_objs)
