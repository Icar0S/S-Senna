"""``carkit_manifest.json``: what the add-on exported, in GODOT axes (doc 03 §5).

The S-Senna Studio (Etapa 06) and ``tools/blender/update_car_json.py`` use it to
fill ``car.json`` (parts, sockets, wheel anchors, tire size) without anyone typing them.

Pure Python (no ``bpy``).
"""

from __future__ import annotations

from . import naming
from .conventions import Conventions
from .geometry import merge_bboxes, round_vec, to_godot
from .validator import RADIUS_PROP, SceneInfo, counts_for_size

SCHEMA = "carkit_manifest"
SCHEMA_VERSION = 1
# Custom properties that are not socket parameters.
_INTERNAL_PROPS = {RADIUS_PROP, "ss_role", "ss_slot", "ss_variant", "ss_ignore"}


def build(scene: SceneInfo, conv: Conventions, addon_version: str, model_file: str = "model.glb") -> dict:
    parts, sockets, wheels, fixed = [], {}, {}, []
    materials: set[str] = set()
    triangles: dict[str, int] = {}
    rim = ""
    boxes = []
    for obj in sorted(scene.objects, key=lambda item: item.name):
        info = naming.classify(obj.name, conv)
        if obj.kind == "MESH":
            materials.update(name for name in obj.materials if name)
            triangles[obj.name] = obj.triangles
            if counts_for_size(info):
                boxes.append((obj.bbox_min, obj.bbox_max))
        if info.role == naming.ROLE_PART:
            parts.append({"slot": info.slot, "variant": info.variant, "triangles": obj.triangles})
        elif info.role == naming.ROLE_SOCKET:
            entry = {"position": round_vec(to_godot(obj.location))}
            for key, value in sorted(obj.props.items()):
                if key not in _INTERNAL_PROPS and isinstance(value, (int, float)):
                    entry[key] = round(float(value), 4)
            sockets[info.slot] = entry
        elif info.role == naming.ROLE_WHEEL:
            wheels[info.slot] = {
                "position": round_vec(to_godot(obj.location)),
                "radius_m": round(float(obj.props.get(RADIUS_PROP, 0.0)), 4),
            }
        elif info.role == naming.ROLE_RIM:
            rim = obj.name
        elif info.role == naming.ROLE_FIXED:
            fixed.append(obj.name)
    manifest = {
        "schema": SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "kind": scene.kind,
        "slug": scene.slug,
        "addon_version": addon_version,
        "model": model_file,
        "parts": parts,
        "sockets": sockets,
        "wheels": dict(sorted(wheels.items())),
        "rim": rim,
        "fixed": fixed,
        "materials": sorted(materials),
        "triangles": {"total": sum(triangles.values()), "by_object": triangles},
    }
    box = merge_bboxes(boxes)
    if box is not None:
        manifest["measured_mm"] = {
            "length": round((box[1][1] - box[0][1]) * 1000.0),
            "width": round((box[1][0] - box[0][0]) * 1000.0),
            "height": round(box[1][2] * 1000.0),
        }
    if scene.dims_mm:
        manifest["dimensions_mm"] = {key: int(round(float(value))) for key, value in scene.dims_mm.items()}
    return manifest
