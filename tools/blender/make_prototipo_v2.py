"""Protótipo S-Senna v2 (``car:base/prototipo``), feito de ponta a ponta pelo add-on S-Senna CarKit.

The shape is modeled here with bmesh (curves along the car + cross sections smoothed
with Catmull-Rom, round wheel arches, separate glass, lights, grille and mirrors).
Everything else goes through the add-on's own buttons, exactly as a modeler would use
them: "Novo carro", "Criar variante", "Material do jogo", "Criar soquete", "Espelhar L→R",
"Detectar rodas" (normalizes the rim), "Validar" and "Exportar". Then ``car.json`` is
updated from the manifest with ``update_car_json.py`` (names, prices, stats and
``tuning_overrides`` are kept).

Run from the repository root:  tools/blender/make_prototipo_v2.sh
(= blender -b --factory-startup -P tools/blender/make_prototipo_v2.py [-- --blend <out.blend>])

Coordinates: helper functions take (x, y, s) with x = left, y = up and s = toward the
front (the Godot axes) and convert to Blender (front = -Y): (x, -s, y).
"""

from __future__ import annotations

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import senna_carkit  # noqa: E402
import update_car_json  # noqa: E402
from senna_carkit import exporter, materials, operators, validator  # noqa: E402
from senna_carkit.conventions import Conventions  # noqa: E402

CONV = Conventions.load()
SLUG = "prototipo"
OUT_DIR = os.path.join(REPO, "godot", "content", "packs", "base", "cars", SLUG)
DIMS_MM = {"length": 4340, "width": 1760, "height": 1265, "wheelbase": 2550}
INCH = 0.0254

FRONT = 2.12  # nose of the body (the bumper goes further)
REAR = -2.1
AXLES = (1.275, -1.275)
WHEEL_X = 0.77
TIRE_D = 0.62
TIRE_W = 0.215
ARCH_R = 0.37
ARCH_Y = TIRE_D / 2.0
WINDSHIELD = (0.27, 0.95)
REAR_WINDOW = (-1.62, -0.88)
SIDE_WINDOW = (-1.18, 0.95)
B_PILLAR = (-0.3, -0.2)
STEP = 0.05
SHARP_ANGLE = math.radians(38.0)


def to_blender(x: float, y: float, s: float) -> Vector:
    return Vector((x, -s, y))


# --- Profile curves (monotone cubic: smooth and without overshoot) ---------------------------------


class Curve:
    """Fritsch-Carlson monotone cubic interpolation of ``[(s, value), ...]``."""

    def __init__(self, points: list[tuple[float, float]]) -> None:
        self.s = [p[0] for p in sorted(points)]
        self.v = [p[1] for p in sorted(points)]
        count = len(self.s)
        delta = [(self.v[i + 1] - self.v[i]) / (self.s[i + 1] - self.s[i]) for i in range(count - 1)]
        tangents = [delta[0]] + [(delta[i - 1] + delta[i]) / 2.0 for i in range(1, count - 1)] + [delta[-1]]
        for i in range(count - 1):
            if delta[i] == 0.0:
                tangents[i] = tangents[i + 1] = 0.0
                continue
            a, b = tangents[i] / delta[i], tangents[i + 1] / delta[i]
            if a < 0.0:
                tangents[i] = 0.0
            if b < 0.0:
                tangents[i + 1] = 0.0
            norm = math.hypot(a, b)
            if norm > 3.0:
                tangents[i] = 3.0 * a / norm * delta[i]
                tangents[i + 1] = 3.0 * b / norm * delta[i]
        self.m = tangents

    def __call__(self, s: float) -> float:
        if s <= self.s[0]:
            return self.v[0]
        if s >= self.s[-1]:
            return self.v[-1]
        i = max(index for index in range(len(self.s) - 1) if self.s[index] <= s)
        h = self.s[i + 1] - self.s[i]
        t = (s - self.s[i]) / h
        h00, h10 = 2 * t**3 - 3 * t**2 + 1, t**3 - 2 * t**2 + t
        h01, h11 = -2 * t**3 + 3 * t**2, t**3 - t**2
        return h00 * self.v[i] + h10 * h * self.m[i] + h01 * self.v[i + 1] + h11 * h * self.m[i + 1]


TOP = Curve(
    [
        (-2.10, 0.89),
        (-1.95, 0.925),
        (-1.65, 0.94),
        (-1.30, 1.06),
        (-0.85, 1.225),
        (-0.20, 1.255),
        (0.25, 1.20),
        (0.60, 1.00),
        (0.97, 0.80),
        (1.40, 0.755),
        (1.90, 0.68),
        (2.06, 0.62),
        (2.12, 0.56),
    ]
)
BELT = Curve(
    [
        (-2.10, 0.86),
        (-1.95, 0.895),
        (-1.65, 0.895),
        (-1.00, 0.86),
        (0.97, 0.775),
        (1.40, 0.725),
        (1.90, 0.655),
        (2.06, 0.585),
        (2.12, 0.54),
    ]
)
HALF_WIDTH = Curve(
    [(-2.10, 0.80), (-1.97, 0.855), (-1.75, 0.88), (1.60, 0.88), (1.95, 0.83), (2.06, 0.74), (2.12, 0.66)]
)
SILL = Curve(
    [
        (-2.10, 0.33),
        (-1.95, 0.26),
        (-1.70, 0.2),
        (-0.9, 0.185),
        (0.9, 0.185),
        (1.70, 0.2),
        (1.95, 0.23),
        (2.06, 0.27),
        (2.12, 0.33),
    ]
)


def in_range(s: float, bounds: tuple[float, float]) -> bool:
    return bounds[0] < s < bounds[1]


# --- Mesh building ---------------------------------------------------------------------------------


class MeshBuilder:
    """Faces with a game material each; shared vertices (smooth shading + sharp by angle)."""

    def __init__(self) -> None:
        self.vertices: list[Vector] = []
        self.index: dict[tuple, int] = {}
        self.faces: list[list[int]] = []
        self.face_materials: list[str] = []

    def _vertex(self, point: Vector) -> int:
        key = tuple(round(value, 5) for value in point)
        if key not in self.index:
            self.index[key] = len(self.vertices)
            self.vertices.append(Vector(point))
        return self.index[key]

    def face(
        self, points: list[Vector], material: str, inside: Vector | None = None, normal: Vector | None = None
    ) -> None:
        """Adds a polygon facing away from ``inside`` (or along ``normal``)."""
        indices: list[int] = []
        for point in points:
            vertex = self._vertex(point)
            if not indices or indices[-1] != vertex:
                indices.append(vertex)
        if len(indices) > 1 and indices[0] == indices[-1]:
            indices.pop()
        if len(set(indices)) < 3:
            return
        corners = [self.vertices[i] for i in indices]
        face_normal = Vector((0.0, 0.0, 0.0))
        for a, b in zip(corners, corners[1:] + corners[:1], strict=True):
            face_normal += a.cross(b)
        center = sum(corners, Vector((0.0, 0.0, 0.0))) / len(corners)
        wanted = normal if normal is not None else (center - inside if inside is not None else None)
        if wanted is not None and face_normal.dot(wanted) < 0.0:
            indices.reverse()
        self.faces.append(indices)
        self.face_materials.append(material)

    def box(self, center: Vector, half: Vector, material: str) -> None:
        corners = [
            center + Vector((sx * half.x, sy * half.y, sz * half.z))
            for sx in (-1, 1)
            for sy in (-1, 1)
            for sz in (-1, 1)
        ]
        for quad in ((0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)):
            self.face([corners[i] for i in quad], material, inside=center)

    def loft(
        self, rings: list[list[Vector]], materials_of: list[str], centers: list[Vector], closed: bool = True
    ) -> None:
        """Quads between consecutive rings; ``materials_of[k]`` is the material of segment k."""
        count = len(rings[0])
        segments = count if closed else count - 1
        for r in range(len(rings) - 1):
            inside = (centers[r] + centers[r + 1]) / 2.0
            for k in range(segments):
                k2 = (k + 1) % count
                quad = [rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k]]
                self.face(quad, materials_of[k], inside=inside)

    def cap(self, ring: list[Vector], material: str, normal: Vector) -> None:
        center = sum(ring, Vector((0.0, 0.0, 0.0))) / len(ring)
        for a, b in zip(ring, ring[1:] + ring[:1], strict=True):
            self.face([center, a, b], material, normal=normal)

    def build(self, name: str, collection: bpy.types.Collection, location: Vector | None = None) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(name)
        offset = location if location is not None else Vector((0.0, 0.0, 0.0))
        mesh.from_pydata([v - offset for v in self.vertices], [], self.faces)
        names = sorted(set(self.face_materials))
        for material_name in names:
            mesh.materials.append(materials.ensure_material(material_name, CONV))
        mesh.polygons.foreach_set("material_index", [names.index(m) for m in self.face_materials])
        mesh.validate()
        mesh.update()
        mesh.shade_smooth()
        mesh.set_sharp_from_angle(angle=SHARP_ANGLE)
        obj = bpy.data.objects.new(name, mesh)
        obj.location = offset
        collection.objects.link(obj)
        return obj


# --- Body ------------------------------------------------------------------------------------------


def centripetal(p0: Vector, p1: Vector, p2: Vector, p3: Vector, t: float) -> Vector:
    """Point ``t`` (0..1) between p1 and p2 of a centripetal Catmull-Rom spline."""

    def knot(previous: float, a: Vector, b: Vector) -> float:
        return previous + max((b - a).length, 1e-6) ** 0.5

    t0 = 0.0
    t1 = knot(t0, p0, p1)
    t2 = knot(t1, p1, p2)
    t3 = knot(t2, p2, p3)
    tt = t1 + (t2 - t1) * t
    a1 = (t1 - tt) / (t1 - t0) * p0 + (tt - t0) / (t1 - t0) * p1
    a2 = (t2 - tt) / (t2 - t1) * p1 + (tt - t1) / (t2 - t1) * p2
    a3 = (t3 - tt) / (t3 - t2) * p2 + (tt - t2) / (t3 - t2) * p3
    b1 = (t2 - tt) / (t2 - t0) * a1 + (tt - t0) / (t2 - t0) * a2
    b2 = (t3 - tt) / (t3 - t1) * a2 + (tt - t1) / (t3 - t1) * a3
    return (t2 - tt) / (t2 - t1) * b1 + (tt - t1) / (t2 - t1) * b2


# Segment tags of the cross section (left side, bottom -> roof center) and subdivisions.
RING_TAGS = ("rocker", "side", "side", "seal", "window", "rail", "roof")
RING_SUBDIVISIONS = (1, 2, 2, 1, 2, 1, 4)


def section(s: float, sill: float) -> tuple[list[Vector], list[str]]:
    """Cross section at ``s``: 2D points (x, y) around the body and the tag of each segment."""
    top = TOP(s)
    belt = min(BELT(s), top - 0.005)
    half = HALF_WIDTH(s)
    cabin = min(max((top - belt - 0.02) / 0.3, 0.0), 1.0)
    roof = half * (0.95 + (0.70 - 0.95) * cabin)
    height = belt - sill
    shoulder = half * 0.975
    controls = [
        Vector((half * 0.93, sill)),
        Vector((half * 0.985, sill + 0.30 * height)),
        Vector((half, sill + 0.70 * height)),
        Vector((shoulder, belt)),
        Vector((shoulder + (roof - shoulder) * 0.06, belt + 0.05 * (top - belt))),
        Vector((shoulder + (roof - shoulder) * 0.88, belt + 0.86 * (top - belt))),
        Vector((roof, belt + 0.975 * (top - belt))),
        Vector((0.0, top)),
    ]
    mirrored = [Vector((-p.x, p.y)) for p in reversed(controls[:-1])]
    path = controls + mirrored
    tags = list(RING_TAGS) + list(reversed(RING_TAGS))
    subdivisions = list(RING_SUBDIVISIONS) + list(reversed(RING_SUBDIVISIONS))
    points: list[Vector] = []
    point_tags: list[str] = []
    last = len(path) - 1
    for k in range(last):
        p0 = path[k - 1] if k > 0 else path[0] + (path[0] - path[1])
        p3 = path[k + 2] if k + 2 <= last else path[last] + (path[last] - path[last - 1])
        for step in range(subdivisions[k]):
            t = step / subdivisions[k]
            if subdivisions[k] == 1:
                points.append(path[k].copy())
            else:
                points.append(centripetal(p0, path[k], path[k + 1], p3, t))
            point_tags.append(tags[k])
    points.append(path[last].copy())
    point_tags.append("floor")  # closing segment: right sill -> left sill
    return points, point_tags


def body_material(tag: str, s: float, cabin: bool) -> str:
    side_glass = cabin and in_range(s, SIDE_WINDOW) and not in_range(s, B_PILLAR)
    if tag == "floor":
        return "trim_black"
    if tag == "rocker":
        return "trim_black" if abs(s) < AXLES[0] - ARCH_R - 0.02 else "paint_body"
    if tag == "seal":
        return "trim_black" if side_glass else "paint_body"
    if tag == "window":
        if side_glass:
            return "glass"
        return "trim_black" if cabin and in_range(s, B_PILLAR) else "paint_body"
    if tag == "roof" and (in_range(s, WINDSHIELD) or in_range(s, REAR_WINDOW)):
        return "glass"
    return "paint_body"


def sill_at(s: float) -> float:
    """Bottom edge of the body side: the sill curve, or the round arch over a wheel."""
    for axle in AXLES:
        distance = abs(s - axle)
        if distance <= ARCH_R:
            return ARCH_Y + math.sqrt(max(ARCH_R**2 - distance**2, 0.0))
    return SILL(s)


def stations() -> list[tuple[float, float]]:
    """(s, sill height) from the rear to the front: a regular grid, the glass/pillar edges
    and the arch samples, plus a station just outside each arch (the arch's vertical edge)."""
    special = [value for pair in (WINDSHIELD, REAR_WINDOW, SIDE_WINDOW, B_PILLAR) for value in pair]
    edges = []
    for axle in AXLES:
        special += [axle + ARCH_R * math.cos(math.pi * step / 12.0) for step in range(13)]
        edges += [axle - ARCH_R - 0.015, axle + ARCH_R + 0.015]
    count = round((FRONT - REAR) / STEP)
    grid = [REAR + (FRONT - REAR) * i / count for i in range(count + 1)]
    taken = special + edges
    values = special + [s for s in grid if all(abs(s - other) > 0.012 for other in taken)]
    return sorted([(s, sill_at(s)) for s in values] + [(s, SILL(s)) for s in edges])


def make_body(parts: bpy.types.Collection, kit: bpy.types.Collection) -> None:
    paint = MeshBuilder()
    glass = MeshBuilder()
    sections = []
    for s, sill in stations():
        points, tags = section(s, sill)
        ring = [to_blender(p.x, p.y, s) for p in points]
        center = to_blender(0.0, (sill + TOP(s)) / 2.0, s)
        sections.append((s, ring, tags, center))
    for (s_a, ring_a, tags, center_a), (s_b, ring_b, _, center_b) in zip(sections, sections[1:], strict=False):
        s_mid = (s_a + s_b) / 2.0
        cabin = TOP(s_mid) - BELT(s_mid) > 0.12
        inside = (center_a + center_b) / 2.0
        count = len(ring_a)
        for k in range(count):
            k2 = (k + 1) % count
            material = body_material(tags[k], s_mid, cabin)
            target = glass if material == "glass" else paint
            target.face([ring_a[k], ring_a[k2], ring_b[k2], ring_b[k]], material, inside=inside)
    paint.cap(sections[0][1], "paint_body", normal=Vector((0.0, 1.0, 0.0)))
    paint.cap(sections[-1][1], "paint_body", normal=Vector((0.0, -1.0, 0.0)))
    _lights(paint)
    paint.build("body-stock", parts)
    glass.build("glass-stock", kit)


def _lights(paint: MeshBuilder) -> None:
    for side in (1.0, -1.0):
        paint.box(to_blender(0.5 * side, 0.515, 2.075), Vector((0.17, 0.05, 0.028)), "light_head")
        paint.box(to_blender(0.6 * side, 0.79, REAR + 0.004), Vector((0.17, 0.012, 0.035)), "light_tail")
    paint.box(to_blender(0.0, 0.79, REAR + 0.002), Vector((0.43, 0.008, 0.022)), "trim_black")
    paint.box(to_blender(0.0, 0.3, REAR + 0.045), Vector((0.6, 0.06, 0.06)), "trim_black")


# --- Bumpers, hood, spoiler, mirrors ---------------------------------------------------------------


def rounded_rect(s: float, half: float, bottom: float, top: float) -> list[Vector]:
    r = min(0.06, (top - bottom) / 3.0)
    left = [
        (half - r, bottom),
        (half - r * 0.3, bottom + r * 0.3),
        (half, bottom + r),
        (half, top - r),
        (half - r * 0.3, top - r * 0.3),
        (half - r, top),
    ]
    right = [(-x, y) for x, y in reversed(left)]
    return [to_blender(x, y, s) for x, y in left + right]


def make_bumper(variant: str, rings: list[tuple[float, float, float, float]], extras, collection) -> bpy.types.Object:
    builder = MeshBuilder()
    lofted = [rounded_rect(*ring) for ring in rings]
    centers = [to_blender(0.0, (ring[2] + ring[3]) / 2.0, ring[0]) for ring in rings]
    segment_materials = ["paint_body"] * 11 + ["trim_black"]
    builder.loft(lofted, segment_materials, centers)
    builder.cap(lofted[0], "paint_body", normal=Vector((0.0, 1.0, 0.0)))
    s, half, bottom, top = rings[-1]
    middle = (bottom + top) / 2.0
    grille = rounded_rect(s + 0.004, half * 0.78, middle - (top - bottom) * 0.3, middle + (top - bottom) * 0.22)
    inset = [Vector((p.x, p.y + 0.012, p.z)) for p in grille]
    front = lofted[-1]
    for k in range(len(front)):
        k2 = (k + 1) % len(front)
        builder.face([front[k], front[k2], grille[k2], grille[k]], "paint_body", normal=Vector((0.0, -1.0, 0.0)))
        builder.face(
            [grille[k], grille[k2], inset[k2], inset[k]], "trim_black", inside=to_blender(0.0, middle, s - 0.2)
        )
    builder.cap(inset, "trim_black", normal=Vector((0.0, -1.0, 0.0)))
    for center, half_size in extras:
        builder.box(to_blender(*center), Vector(half_size), "trim_black")
    return builder.build(f"bumper_front-{variant}", collection)


def make_bumpers(parts: bpy.types.Collection) -> None:
    make_bumper("stock", [(2.0, 0.83, 0.24, 0.47), (2.15, 0.81, 0.25, 0.46), (2.22, 0.72, 0.29, 0.43)], [], parts)
    # "Criar variante" duplicates the stock bumper as kit01/kit02; then each gets its own shape.
    kits = {
        "kit01": (
            [(2.0, 0.85, 0.16, 0.47), (2.2, 0.84, 0.16, 0.45), (2.28, 0.78, 0.17, 0.40)],
            [((0.0, 0.165, 2.25), (0.78, 0.06, 0.008))],
        ),
        "kit02": (
            [(2.0, 0.87, 0.12, 0.47), (2.24, 0.88, 0.12, 0.44), (2.32, 0.86, 0.13, 0.24)],
            [
                ((0.0, 0.125, 2.33), (0.86, 0.08, 0.01)),
                ((0.8, 0.3, 2.26), (0.06, 0.05, 0.006)),
                ((-0.8, 0.3, 2.26), (0.06, 0.05, 0.006)),
            ],
        ),
    }
    for variant, (rings, extras) in kits.items():
        _variant_of("bumper_front-stock", f"bumper_front-{variant}")
        shaped = make_bumper(variant + "_tmp", rings, extras, parts)
        _replace_mesh(f"bumper_front-{variant}", shaped)


def _variant_of(source: str, expected: str) -> None:
    obj = bpy.data.objects[source]
    obj.hide_set(False)
    select_only([obj])
    assert bpy.ops.senna.create_variant() == {"FINISHED"}
    created = bpy.context.view_layer.objects.active
    assert created.name == expected, f"variante inesperada: {created.name} (esperada {expected})"


def _replace_mesh(target_name: str, shaped: bpy.types.Object) -> None:
    target = bpy.data.objects[target_name]
    old = target.data
    target.data = shaped.data
    target.data.name = target_name
    bpy.data.objects.remove(shaped, do_unlink=True)
    bpy.data.meshes.remove(old)


def make_hood(variant: str, bulge: float, collection) -> bpy.types.Object:
    builder = MeshBuilder()
    s_front, s_back = 2.06, WINDSHIELD[1] + 0.03
    fractions = (1.0, 0.7, 0.45, 0.25, 0.1, 0.0, -0.1, -0.25, -0.45, -0.7, -1.0)
    rings, centers = [], []
    for i in range(13):
        u = i / 12.0
        s = s_front + (s_back - s_front) * u
        width = HALF_WIDTH(s) * 0.82
        y = TOP(s) + 0.006
        rise = bulge * math.sin(math.pi * min(u * 1.3, 1.0)) if u > 0 else 0.0
        points = []
        for f in fractions:
            lift = rise * max(0.0, 1.0 - (abs(f) / 0.45) ** 2)
            points.append(to_blender(width * f, y + lift - 0.004 * f * f, s))
        points += [to_blender(-width, y - 0.016, s), to_blender(width, y - 0.016, s)]
        rings.append(points)
        centers.append(to_blender(0.0, y - 0.008, s))
    builder.loft(rings, ["paint_body"] * len(rings[0]), centers)
    builder.cap(rings[0], "paint_body", normal=Vector((0.0, -1.0, 0.0)))
    builder.cap(rings[-1], "paint_body", normal=Vector((0.0, 1.0, 0.0)))
    return builder.build(f"hood-{variant}", collection)


def make_hoods(parts: bpy.types.Collection) -> None:
    hood = make_hood("stock", 0.0, parts)
    select_only([hood])
    bpy.context.scene.senna.material = "paint_body"
    assert bpy.ops.senna.assign_material() == {"FINISHED"}
    _variant_of("hood-stock", "hood-kit01")
    _replace_mesh("hood-kit01", make_hood("kit01_tmp", 0.05, parts))


def spoiler_mount() -> tuple[float, float, float]:
    s = REAR + 0.22
    return (0.0, round(TOP(s), 3), round(s, 3))


def make_spoiler(parts: bpy.types.Collection) -> None:
    builder = MeshBuilder()
    x0, y0, s0 = spoiler_mount()
    height, chord, half = 0.12, 0.24, 0.6
    for side in (1.0, -1.0):
        builder.box(to_blender(0.38 * side, y0 + height / 2.0, s0), Vector((0.022, 0.05, height / 2.0)), "trim_black")
        builder.box(to_blender(0.61 * side, y0 + height + 0.01, s0 - 0.01), Vector((0.006, 0.12, 0.045)), "trim_black")
    profile = [(0.55, 0.0), (0.3, 0.028), (0.0, 0.035), (-0.45, 0.02), (-0.5, 0.0), (-0.1, -0.008)]
    rings = []
    for x in (half, -half):
        rings.append([to_blender(x, y0 + height + dy, s0 + chord * ds) for ds, dy in profile])
    centers = [to_blender(x, y0 + height + 0.012, s0) for x in (half, -half)]
    builder.loft(rings, ["paint_body"] * len(profile), centers)
    builder.cap(rings[0], "paint_body", normal=Vector((1.0, 0.0, 0.0)))
    builder.cap(rings[1], "paint_body", normal=Vector((-1.0, 0.0, 0.0)))
    builder.build("spoiler-stock", parts, location=to_blender(x0, y0, s0))


def make_mirrors(parts: bpy.types.Collection) -> None:
    builder = MeshBuilder()
    for side in (1.0, -1.0):
        builder.box(to_blender(0.885 * side, 0.79, 0.8), Vector((0.035, 0.02, 0.01)), "trim_black")
        builder.box(to_blender(0.935 * side, 0.81, 0.8), Vector((0.045, 0.05, 0.032)), "paint_body")
        builder.box(to_blender(0.935 * side, 0.81, 0.748), Vector((0.038, 0.002, 0.026)), "chrome")
    builder.build("mirrors-stock", parts)


def make_interior(kit: bpy.types.Collection) -> None:
    """Dark cabin (fixed piece): blocks the view through the glass to the wheels."""
    builder = MeshBuilder()
    blocks = [
        ((0.0, 0.45, 0.0), (0.8, 0.85, 0.25)),  # tub between the arches
        ((0.0, 0.82, 0.62), (0.78, 0.18, 0.08)),  # dashboard
        ((0.0, 0.76, -1.07), (0.75, 0.2, 0.03)),  # parcel shelf
    ]
    for side in (1.0, -1.0):
        blocks.append(((0.36 * side, 0.73, -0.35), (0.2, 0.24, 0.04)))  # seat
        blocks.append(((0.36 * side, 0.94, -0.6), (0.2, 0.05, 0.2)))  # seat back
    for (x, y, s), half in blocks:
        builder.box(to_blender(x, y, s), Vector(half), "interior")
    builder.build("interior-stock", kit)


# --- Rim (5 spokes) and tires for "Detectar rodas" ---------------------------------------------------


def make_rim_source(collection: bpy.types.Collection) -> bpy.types.Object:
    """5-spoke rim around the X axis, face toward +X (normalized to 18" x 8" by the add-on)."""
    builder = MeshBuilder()
    segments = 40
    radius = 9.0 * INCH
    half = 4.0 * INCH
    inner = radius - 0.022
    face_x = half - 0.03

    def ring(x: float, r: float) -> list[Vector]:
        return [
            Vector((x, r * math.cos(2 * math.pi * i / segments), r * math.sin(2 * math.pi * i / segments)))
            for i in range(segments)
        ]

    origin = Vector((0.0, 0.0, 0.0))
    outer = [
        ring(-half, radius - 0.01),
        ring(-half + 0.012, radius),
        ring(half - 0.012, radius),
        ring(half, radius - 0.004),
    ]
    builder.loft(outer, ["rim"] * segments, [origin] * 4)
    lip = [ring(half, radius - 0.004), ring(half, inner), ring(face_x, inner - 0.004)]
    for a, b in zip(lip, lip[1:], strict=False):
        for k in range(segments):
            k2 = (k + 1) % segments
            builder.face([a[k], a[k2], b[k2], b[k]], "rim", normal=Vector((1.0, 0.0, 0.0)))
    barrel = [ring(face_x, inner - 0.004), ring(-half, inner - 0.004)]
    for k in range(segments):
        k2 = (k + 1) % segments
        quad = [barrel[0][k], barrel[0][k2], barrel[1][k2], barrel[1][k]]
        builder.face(quad, "metal_dark", normal=-(quad[0] - Vector((quad[0].x, 0.0, 0.0))))
    back = [ring(-half, radius - 0.01), ring(-half, inner - 0.004)]
    for k in range(segments):
        k2 = (k + 1) % segments
        builder.face([back[0][k], back[0][k2], back[1][k2], back[1][k]], "rim", normal=Vector((-1.0, 0.0, 0.0)))
    hub = 0.065
    for spoke in range(5):
        angle = 2 * math.pi * spoke / 5
        direction = Vector((0.0, math.cos(angle), math.sin(angle)))
        across = Vector((0.0, -math.sin(angle), math.cos(angle)))
        root = Vector((face_x + 0.022, 0.0, 0.0)) + direction * (hub - 0.005)
        tip = Vector((face_x - 0.004, 0.0, 0.0)) + direction * (inner - 0.006)
        center = (root + tip) / 2.0 - Vector((0.012, 0.0, 0.0))
        corners = []
        for point, width in ((root, 0.034), (tip, 0.022)):
            for side in (-1.0, 1.0):
                corners.append(point + across * width * side)
        back_corners = [c - Vector((0.024, 0.0, 0.0)) for c in corners]
        front_face = [corners[0], corners[1], corners[3], corners[2]]
        builder.face(front_face, "rim", normal=Vector((1.0, 0.0, 0.0)))
        builder.face([back_corners[i] for i in (0, 1, 3, 2)], "rim", normal=Vector((-1.0, 0.0, 0.0)))
        for i, j in ((0, 2), (1, 3), (0, 1), (2, 3)):
            builder.face([corners[i], corners[j], back_corners[j], back_corners[i]], "rim", inside=center)
    hub_front = ring(face_x + 0.03, hub)
    hub_back = ring(face_x - 0.02, hub)
    for k in range(segments):
        k2 = (k + 1) % segments
        quad = [hub_front[k], hub_front[k2], hub_back[k2], hub_back[k]]
        builder.face(quad, "rim", inside=Vector((quad[0].x, 0.0, 0.0)))
    cap_ring = ring(face_x + 0.036, 0.03)
    for k in range(segments):
        k2 = (k + 1) % segments
        builder.face([hub_front[k], hub_front[k2], cap_ring[k2], cap_ring[k]], "rim", normal=Vector((1.0, 0.0, 0.0)))
    builder.cap(cap_ring, "rim_accent", normal=Vector((1.0, 0.0, 0.0)))
    for nut in range(5):
        angle = 2 * math.pi * (nut + 0.5) / 5
        position = Vector((face_x + 0.034, 0.045 * math.cos(angle), 0.045 * math.sin(angle)))
        builder.box(position, Vector((0.006, 0.007, 0.007)), "chrome")
    rim = builder.build("aro_fonte", collection)
    rim.location = (3.0, 0.0, radius)  # anywhere: "Detectar rodas" moves it to wheel-FL
    return rim


def make_tires(collection: bpy.types.Collection) -> list[bpy.types.Object]:
    tires = []
    for x in (WHEEL_X, -WHEEL_X):
        for s in AXLES:
            mesh = bpy.data.meshes.new("pneu")
            data = bmesh.new()
            bmesh.ops.create_cone(
                data, cap_ends=True, segments=32, radius1=TIRE_D / 2, radius2=TIRE_D / 2, depth=TIRE_W
            )
            bmesh.ops.rotate(data, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90.0), 3, "Y"), verts=data.verts)
            data.to_mesh(mesh)
            data.free()
            tire = bpy.data.objects.new(f"pneu_{len(tires)}", mesh)
            tire.location = to_blender(x, TIRE_D / 2.0, s)
            collection.objects.link(tire)
            tires.append(tire)
    return tires


# --- Sockets ------------------------------------------------------------------------------------------


def socket_specs() -> dict[str, tuple[tuple[float, float, float], dict]]:
    """Left/center sockets (the _R ones come from "Espelhar L→R"): (x, y, s) and parameters."""
    return {
        "spoiler": (spoiler_mount(), {"width_m": 1.3}),
        "exhaust_L": ((0.45, 0.26, REAR - 0.02), {}),
        "lip_front": ((0.0, 0.25, 2.18), {"width_m": 1.6}),
        "lip_rear": ((0.0, 0.3, REAR), {"width_m": 1.6}),
        "canard_L": ((0.8, 0.36, 2.13), {}),
        "hood_scoop": ((0.0, round(TOP(1.45) + 0.012, 3), 1.45), {}),
        "roof_scoop": ((0.0, round(TOP(-0.3), 3), -0.3), {}),
        "plate_front": ((0.0, 0.36, 2.225), {}),
        "plate_rear": ((0.0, round(BELT(REAR) - 0.3, 3), REAR - 0.01), {}),
        "neon": ((0.0, 0.18, 0.0), {"length_m": 3.6, "width_m": 1.5}),
        "cam_hood": ((0.0, round(TOP(1.2) + 0.15, 3), 1.2), {}),
        "cam_bumper": ((0.0, 0.45, 2.24), {}),
        "light_head_L": ((0.5, 0.515, 2.1), {}),
        "light_tail_L": ((0.6, 0.79, REAR - 0.01), {}),
    }


def make_sockets() -> None:
    props = bpy.context.scene.senna
    for name, (position, params) in socket_specs().items():
        props.socket = name
        props.socket_width_m = params.get("width_m", 0.0)
        props.socket_length_m = params.get("length_m", 0.0)
        bpy.context.scene.cursor.location = to_blender(*position)
        assert bpy.ops.senna.create_socket() == {"FINISHED"}
    assert bpy.ops.senna.mirror_left_right() == {"FINISHED"}


# --- Flow ---------------------------------------------------------------------------------------------


def select_only(objects: list[bpy.types.Object]) -> None:
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0] if objects else None


def build_car() -> bpy.types.Collection:
    props = bpy.context.scene.senna
    props.slug = SLUG
    props.length_mm, props.width_mm = DIMS_MM["length"], DIMS_MM["width"]
    props.height_mm, props.wheelbase_mm = DIMS_MM["height"], DIMS_MM["wheelbase"]
    assert bpy.ops.senna.new_car() == {"FINISHED"}
    kit = props.kit
    parts = operators.sub_collection(kit, "peças")
    make_body(parts, kit)
    make_bumpers(parts)
    make_hoods(parts)
    make_spoiler(parts)
    make_mirrors(parts)
    make_interior(kit)
    make_sockets()
    props.rim_source = make_rim_source(bpy.context.scene.collection)
    props.symmetric_wheels = True
    select_only(make_tires(bpy.context.scene.collection))
    assert bpy.ops.senna.detect_wheels() == {"FINISHED"}
    return kit


def export(kit: bpy.types.Collection) -> dict:
    props = bpy.context.scene.senna
    bpy.ops.senna.validate()
    for issue in props.issues:
        print(f"  [{issue.severity}] {issue.message}")
    if any(item.severity == validator.ERROR for item in props.issues):
        raise SystemExit("make_prototipo_v2: a validação encontrou erros")
    props.export_dir = OUT_DIR
    assert bpy.ops.senna.export() == {"FINISHED"}
    with open(os.path.join(OUT_DIR, exporter.MANIFEST_FILE), encoding="utf-8") as handle:
        return json.load(handle)


def update_car(manifest: dict) -> None:
    path = os.path.join(OUT_DIR, "car.json")
    with open(path, encoding="utf-8") as handle:
        car = json.load(handle)
    update_car_json.update(car, manifest)
    car["credits"] = {
        "model_author": "S-Senna (gerado pelo add-on S-Senna CarKit)",
        "license": "CC-BY-NC-SA-4.0",
        "source": "tools/blender/make_prototipo_v2.py",
    }
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(car, ensure_ascii=False, indent=2) + "\n")


def main(argv: list[str]) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    senna_carkit.register()
    kit = build_car()
    manifest = export(kit)
    update_car(manifest)
    if "--blend" in argv:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(argv[argv.index("--blend") + 1]))
    total = manifest["triangles"]["total"]
    print(
        f"make_prototipo_v2: OK ({total} triângulos, {len(manifest['parts'])} peças, {len(manifest['sockets'])} soquetes)"
    )


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])
