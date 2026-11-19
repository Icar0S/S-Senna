"""Geometry helpers: Blender <-> Godot axes and wheel detection.

Blender: front = -Y, left = +X, up = +Z. Godot (after the glTF export with +Y up):
front = +Z, left = +X, up = +Y. So a Blender point (x, y, z) is (x, z, -y) in Godot.

Pure Python (no ``bpy``).
"""

from __future__ import annotations

Vec3 = tuple[float, float, float]


def to_godot(point: Vec3) -> Vec3:
    x, y, z = point
    return (x, z, -y)


def round_vec(point: Vec3, digits: int = 4) -> list[float]:
    return [round(value, digits) + 0.0 for value in point]


def bbox_center(minimum: Vec3, maximum: Vec3) -> Vec3:
    return tuple((a + b) / 2.0 for a, b in zip(minimum, maximum, strict=True))


def merge_bboxes(boxes: list[tuple[Vec3, Vec3]]) -> tuple[Vec3, Vec3] | None:
    if not boxes:
        return None
    minimum = tuple(min(box[0][i] for box in boxes) for i in range(3))
    maximum = tuple(max(box[1][i] for box in boxes) for i in range(3))
    return minimum, maximum


def detect_wheels(boxes: list[tuple[str, Vec3, Vec3]]) -> dict[str, dict]:
    """Wheel position (``FL``...) -> ``{"center": (x, y, z), "radius": r, "source": name}``
    from the world bounding boxes of exactly 4 wheel meshes (axle along X)."""
    if len(boxes) != 4:
        raise ValueError(f"selecione exatamente 4 rodas (selecionadas: {len(boxes)})")
    wheels = []
    for name, minimum, maximum in boxes:
        center = bbox_center(minimum, maximum)
        radius = max(maximum[1] - minimum[1], maximum[2] - minimum[2]) / 2.0
        wheels.append((name, center, radius))
    mean_y = sum(center[1] for _, center, _ in wheels) / 4.0
    result: dict[str, dict] = {}
    for name, center, radius in wheels:
        front = "F" if center[1] < mean_y else "R"
        side = "L" if center[0] > 0.0 else "R"
        position = front + side
        if position in result:
            raise ValueError(f"duas rodas na mesma posição ({position}): confira a frente (-Y)")
        result[position] = {"center": center, "radius": radius, "source": name}
    return result


def symmetrize(wheels: dict[str, dict]) -> dict[str, dict]:
    """Left/right pairs mirrored exactly (average of both sides), same radius per axle."""
    result = {key: dict(value) for key, value in wheels.items()}
    for axle in ("F", "R"):
        left, right = wheels[axle + "L"], wheels[axle + "R"]
        x = (abs(left["center"][0]) + abs(right["center"][0])) / 2.0
        y = (left["center"][1] + right["center"][1]) / 2.0
        radius = (left["radius"] + right["radius"]) / 2.0
        z = radius
        result[axle + "L"]["center"] = (x, y, z)
        result[axle + "R"]["center"] = (-x, y, z)
        result[axle + "L"]["radius"] = radius
        result[axle + "R"]["radius"] = radius
    return result
