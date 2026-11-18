"""Validation rules for a car (or universal part / rim) before export.

Works on a plain description of the scene (:class:`SceneInfo`), so every rule is
tested without Blender. ``scene_info.collect`` builds it from a real collection.
Errors block the export; warnings don't. Messages are in pt-BR (shown in the panel).

Pure Python (no ``bpy``).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from . import naming
from .conventions import Conventions
from .geometry import merge_bboxes

ERROR = "error"
WARNING = "warning"
KIND_CAR = "car"
KIND_PART = "part"
KIND_RIM = "rim"
RADIUS_PROP = "radius_m"
INCH = 0.0254
# Slots left out of the measured size, like the real car's spec sheet
# (width without mirrors, length/height without the wing).
UNMEASURED_SLOTS = ("spoiler", "mirrors")


def counts_for_size(info: naming.Classification) -> bool:
    """Whether a mesh enters the car's measured size (stock parts and fixed pieces)."""
    stock_part = info.role == naming.ROLE_PART and info.variant == naming.STOCK and info.slot not in UNMEASURED_SLOTS
    return stock_part or info.role == naming.ROLE_FIXED


@dataclass
class ObjInfo:
    """What the validator needs to know about one object (world space, Blender axes)."""

    name: str
    kind: str = "MESH"  # MESH | EMPTY | OTHER
    location: tuple = (0.0, 0.0, 0.0)
    rotation: tuple = (0.0, 0.0, 0.0)
    scale: tuple = (1.0, 1.0, 1.0)
    bbox_min: tuple = (0.0, 0.0, 0.0)
    bbox_max: tuple = (0.0, 0.0, 0.0)
    materials: list = field(default_factory=list)
    faces_without_material: int = 0
    triangles: int = 0
    props: dict = field(default_factory=dict)


@dataclass
class SceneInfo:
    kind: str = KIND_CAR
    slug: str = ""
    # length, width, height, wheelbase (mm) as typed by the user; None = don't check.
    dims_mm: dict | None = None
    objects: list = field(default_factory=list)


@dataclass
class Issue:
    severity: str
    code: str
    message: str
    object_name: str = ""


def validate(scene: SceneInfo, conv: Conventions) -> list[Issue]:
    issues: list[Issue] = []
    classified = {obj.name: naming.classify(obj.name, conv) for obj in scene.objects}
    _check_names_and_transforms(scene, conv, classified, issues)
    _check_materials(scene, conv, issues)
    if scene.kind == KIND_CAR:
        _check_car_parts(scene, classified, issues)
        _check_wheels(scene, conv, classified, issues)
        _check_dimensions(scene, conv, classified, issues)
        _check_car_budgets(scene, conv, classified, issues)
        _check_sockets(scene, conv, classified, issues)
    elif scene.kind == KIND_RIM:
        _check_rim(scene, conv, classified, issues)
    elif scene.kind == KIND_PART:
        _check_part(scene, conv, classified, issues)
    return issues


def has_errors(issues: list[Issue]) -> bool:
    return any(issue.severity == ERROR for issue in issues)


def _check_names_and_transforms(scene, conv, classified, issues) -> None:
    for obj in scene.objects:
        if naming.has_duplicate_suffix(obj.name):
            issues.append(
                Issue(
                    ERROR, "duplicate_suffix", f"nome com sufixo de cópia do Blender: '{obj.name}' (renomeie)", obj.name
                )
            )
            continue
        if naming.has_forbidden_suffix(obj.name, conv):
            issues.append(
                Issue(ERROR, "forbidden_suffix", f"'{obj.name}' termina com um sufixo de importação do Godot", obj.name)
            )
        info = classified[obj.name]
        if info.role is None:
            issues.append(Issue(ERROR, "unknown_name", info.problem, obj.name))
        if any(value < 0.0 for value in obj.scale):
            issues.append(
                Issue(
                    ERROR,
                    "negative_scale",
                    f"escala negativa em '{obj.name}' (inverte as normais; use Ctrl+A)",
                    obj.name,
                )
            )
        elif obj.kind == "MESH" and (
            any(abs(value - 1.0) > 1e-4 for value in obj.scale) or any(abs(value) > 1e-4 for value in obj.rotation)
        ):
            issues.append(
                Issue(
                    WARNING,
                    "unapplied_transform",
                    f"rotação/escala não aplicadas em '{obj.name}' (o exportador aplica numa cópia)",
                    obj.name,
                )
            )


def _check_materials(scene, conv, issues) -> None:
    for obj in scene.objects:
        if obj.kind != "MESH":
            continue
        for material in sorted(set(obj.materials)):
            if material and not conv.is_material_name(material):
                issues.append(
                    Issue(
                        ERROR,
                        "unknown_material",
                        f"material fora da lista do jogo '{material}' em '{obj.name}'",
                        obj.name,
                    )
                )
        if obj.faces_without_material > 0:
            issues.append(
                Issue(
                    ERROR,
                    "face_without_material",
                    f"{obj.faces_without_material} face(s) sem material em '{obj.name}'",
                    obj.name,
                )
            )


def _parts(scene, classified) -> dict[str, dict[str, ObjInfo]]:
    parts: dict[str, dict[str, ObjInfo]] = {}
    for obj in scene.objects:
        info = classified[obj.name]
        if info.role == naming.ROLE_PART:
            parts.setdefault(info.slot, {})[info.variant] = obj
    return parts


def _by_role(scene, classified, role) -> dict[str, ObjInfo]:
    found = {}
    for obj in scene.objects:
        info = classified[obj.name]
        if info.role == role:
            found[info.slot or info.variant or obj.name] = obj
    return found


def _check_car_parts(scene, classified, issues) -> None:
    parts = _parts(scene, classified)
    if naming.STOCK not in parts.get("body", {}):
        issues.append(Issue(ERROR, "missing_body", "o carro precisa da carroceria original 'body-stock'"))
    for slot, variants in sorted(parts.items()):
        if naming.STOCK not in variants:
            any_variant = next(iter(variants.values()))
            issues.append(
                Issue(
                    ERROR,
                    "missing_stock",
                    f"o slot '{slot}' não tem a variante original ({slot}-stock)",
                    any_variant.name,
                )
            )


def _check_wheels(scene, conv, classified, issues) -> None:
    wheels = _by_role(scene, classified, naming.ROLE_WHEEL)
    missing = [position for position in conv.wheels() if position not in wheels]
    if missing:
        issues.append(
            Issue(ERROR, "missing_wheel", f"âncoras de roda ausentes: {', '.join(missing)} (use 'Detectar rodas')")
        )
        return
    ground = conv.tolerance("wheel_ground_m")
    for obj in wheels.values():
        radius = obj.props.get(RADIUS_PROP)
        if radius is None:
            issues.append(
                Issue(
                    ERROR, "wheel_radius_missing", f"'{obj.name}' sem o raio da roda (use 'Detectar rodas')", obj.name
                )
            )
        elif abs(obj.location[2] - float(radius)) > ground:
            issues.append(
                Issue(
                    ERROR,
                    "wheel_ground",
                    f"'{obj.name}': a roda não toca o chão (Z do centro {obj.location[2]:.3f} m, raio {float(radius):.3f} m)",
                    obj.name,
                )
            )
    # Front = -Y in Blender.
    if wheels["FL"].location[1] > wheels["RL"].location[1] or wheels["FR"].location[1] > wheels["RR"].location[1]:
        issues.append(
            Issue(
                ERROR,
                "front_axis",
                "as rodas dianteiras estão atrás das traseiras: a frente do carro deve apontar para -Y",
                wheels["FL"].name,
            )
        )
    if wheels["FL"].location[0] < 0.0 or wheels["RL"].location[0] < 0.0:
        issues.append(Issue(ERROR, "left_side", "as rodas da esquerda (L) devem ficar em +X", wheels["FL"].name))
    tolerance = conv.tolerance("wheel_symmetry_m")
    for left, right in (("FL", "FR"), ("RL", "RR")):
        a, b = wheels[left].location, wheels[right].location
        if abs(a[0] + b[0]) > tolerance or abs(a[1] - b[1]) > tolerance or abs(a[2] - b[2]) > tolerance:
            issues.append(
                Issue(
                    ERROR,
                    "wheel_asymmetric",
                    f"rodas {left}/{right} não estão simétricas (> {tolerance * 100:.0f} cm)",
                    wheels[left].name,
                )
            )


def _assembled_bbox(scene, classified):
    """Bounding box of the car as it comes from the factory (see :func:`counts_for_size`)."""
    boxes = []
    for obj in scene.objects:
        if obj.kind == "MESH" and counts_for_size(classified[obj.name]):
            boxes.append((obj.bbox_min, obj.bbox_max))
    return merge_bboxes(boxes)


def _check_dimensions(scene, conv, classified, issues) -> None:
    box = _assembled_bbox(scene, classified)
    if box is None:
        return
    size = [box[1][i] - box[0][i] for i in range(3)]
    if size[0] > size[1]:
        issues.append(
            Issue(ERROR, "front_axis", "o carro está mais largo (X) que comprido (Y): a frente deve apontar para -Y")
        )
    if not scene.dims_mm:
        return
    tolerance = conv.tolerance("dimension_tolerance_pct") / 100.0
    measured = {"length": size[1], "width": size[0], "height": box[1][2]}
    for key, value in measured.items():
        expected = float(scene.dims_mm.get(key, 0.0)) / 1000.0
        if expected > 0.0 and abs(value - expected) > expected * tolerance:
            issues.append(
                Issue(
                    ERROR,
                    "dimensions",
                    f"{_DIMENSION_LABELS[key]}: modelo {value * 1000:.0f} mm, informado {expected * 1000:.0f} mm (tolerância {tolerance * 100:.0f}%)",
                )
            )


_DIMENSION_LABELS = {"length": "comprimento", "width": "largura", "height": "altura"}


def _check_car_budgets(scene, conv, classified, issues) -> None:
    total = 0
    biggest_variant: dict[str, int] = {}
    rim_triangles = 0
    for obj in scene.objects:
        info = classified[obj.name]
        if obj.kind != "MESH" or info.role is None:
            continue
        if info.role == naming.ROLE_PART:
            limit = conv.budget("body_tris") if info.slot == "body" else conv.budget("part_tris")
            if obj.triangles > limit:
                issues.append(
                    Issue(
                        ERROR,
                        "budget_object",
                        f"'{obj.name}' tem {obj.triangles} triângulos (máximo {limit})",
                        obj.name,
                    )
                )
            biggest_variant[info.slot] = max(biggest_variant.get(info.slot, 0), obj.triangles)
        elif info.role == naming.ROLE_RIM:
            rim_triangles = obj.triangles
            if obj.triangles > conv.budget("rim_tris"):
                issues.append(
                    Issue(
                        ERROR,
                        "budget_object",
                        f"'{obj.name}' tem {obj.triangles} triângulos (máximo {conv.budget('rim_tris')})",
                        obj.name,
                    )
                )
        elif info.role == naming.ROLE_FIXED:
            total += obj.triangles
    total += sum(biggest_variant.values()) + rim_triangles * 4
    if total > conv.budget("car_total_tris"):
        issues.append(
            Issue(
                ERROR,
                "budget_total",
                f"o carro montado tem {total} triângulos (máximo {conv.budget('car_total_tris')})",
            )
        )


def _check_sockets(scene, conv, classified, issues) -> None:
    sockets = _by_role(scene, classified, naming.ROLE_SOCKET)
    missing = [name for name in conv.recommended_sockets() if name not in sockets]
    if missing:
        issues.append(Issue(WARNING, "socket_missing", f"soquetes recomendados ausentes: {', '.join(missing)}"))


def _check_rim(scene, conv, classified, issues) -> None:
    rims = [obj for obj in scene.objects if classified[obj.name].role == naming.ROLE_RIM and obj.kind == "MESH"]
    if len(rims) != 1:
        issues.append(
            Issue(ERROR, "rim_count", f"um aro deve ter exatamente um objeto 'rim-<nome>' (encontrados: {len(rims)})")
        )
        return
    rim = rims[0]
    diameter_in, width_in = conv.rim_model()
    size = [rim.bbox_max[i] - rim.bbox_min[i] for i in range(3)]
    tolerance = conv.tolerance("dimension_tolerance_pct") / 100.0
    diameter = max(size[1], size[2])
    if (
        abs(diameter - diameter_in * INCH) > diameter_in * INCH * tolerance
        or abs(size[0] - width_in * INCH) > width_in * INCH * tolerance
    ):
        issues.append(
            Issue(
                ERROR,
                "rim_size",
                f'o aro deve ter {diameter_in:.0f}" x {width_in:.0f}" com o eixo em X (medido: {diameter / INCH:.1f}" x {size[0] / INCH:.1f}")',
                rim.name,
            )
        )
    if rim.triangles > conv.budget("rim_tris"):
        issues.append(
            Issue(
                ERROR,
                "budget_object",
                f"'{rim.name}' tem {rim.triangles} triângulos (máximo {conv.budget('rim_tris')})",
                rim.name,
            )
        )


def _check_part(scene, conv, classified, issues) -> None:
    parts = [obj for obj in scene.objects if classified[obj.name].role == naming.ROLE_PART and obj.kind == "MESH"]
    if len(parts) != 1:
        issues.append(
            Issue(
                ERROR,
                "part_count",
                f"uma peça universal deve ter exatamente um objeto '<slot>-<nome>' (encontrados: {len(parts)})",
            )
        )
        return
    if parts[0].triangles > conv.budget("part_tris"):
        issues.append(
            Issue(
                ERROR,
                "budget_object",
                f"'{parts[0].name}' tem {parts[0].triangles} triângulos (máximo {conv.budget('part_tris')})",
                parts[0].name,
            )
        )
