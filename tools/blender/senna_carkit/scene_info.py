"""Reads a kit collection of the open .blend into a :class:`validator.SceneInfo`."""

from __future__ import annotations

import bpy
from mathutils import Vector

from . import validator

KIND_PROP = "senna_kind"
SLUG_PROP = "senna_slug"
IGNORE_PROP = "ss_ignore"
# Sub-collections that are never validated nor exported (guides, reference images).
REFERENCE_COLLECTION = "referências"
DIM_KEYS = ("length", "width", "height", "wheelbase")


def kit_objects(collection: bpy.types.Collection) -> list[bpy.types.Object]:
    """Objects of the kit (recursively), without references, guides and ignored objects."""
    found: list[bpy.types.Object] = []

    def walk(current: bpy.types.Collection) -> None:
        for obj in current.objects:
            if obj.get(IGNORE_PROP) or obj.type not in {"MESH", "EMPTY"}:
                continue
            if obj not in found:
                found.append(obj)
        for child in current.children:
            if not child.name.startswith(REFERENCE_COLLECTION):
                walk(child)

    walk(collection)
    return found


def object_info(obj: bpy.types.Object) -> validator.ObjInfo:
    world = obj.matrix_world
    corners = [world @ Vector(corner) for corner in obj.bound_box]
    info = validator.ObjInfo(
        name=obj.name,
        kind=obj.type if obj.type in {"MESH", "EMPTY"} else "OTHER",
        location=tuple(world.translation),
        rotation=tuple(obj.rotation_euler),
        scale=tuple(obj.scale),
        bbox_min=tuple(min(c[i] for c in corners) for i in range(3)),
        bbox_max=tuple(max(c[i] for c in corners) for i in range(3)),
        props={key: obj[key] for key in obj.keys() if isinstance(obj[key], (int, float, str))},
    )
    if obj.type == "MESH":
        mesh = obj.data
        mesh.calc_loop_triangles()
        info.triangles = len(mesh.loop_triangles)
        names = []
        missing = 0
        slots = obj.material_slots
        for polygon in mesh.polygons:
            index = polygon.material_index
            material = slots[index].material if index < len(slots) else None
            if material is None:
                missing += 1
            else:
                names.append(material.name)
        info.materials = sorted(set(names))
        info.faces_without_material = missing
    return info


def stored_dims_mm(collection: bpy.types.Collection) -> dict | None:
    """Dimensions saved on the kit by "Novo carro" (``dim_<key>_mm``), if any."""
    dims = {key: collection[f"dim_{key}_mm"] for key in DIM_KEYS if f"dim_{key}_mm" in collection}
    return dims or None


def collect(collection: bpy.types.Collection, dims_mm: dict | None = None) -> validator.SceneInfo:
    """``dims_mm`` defaults to the dimensions stored on the kit."""
    kind = collection.get(KIND_PROP, validator.KIND_CAR)
    if dims_mm is None:
        dims_mm = stored_dims_mm(collection)
    return validator.SceneInfo(
        kind=kind,
        slug=collection.get(SLUG_PROP, collection.name),
        dims_mm=dims_mm if kind == validator.KIND_CAR else None,
        objects=[object_info(obj) for obj in kit_objects(collection)],
    )
