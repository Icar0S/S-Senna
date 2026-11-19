"""Game materials in Blender: only the NAME matters (the game replaces them, ADR 006);
the color is just a preview so the modeler sees what is what."""

from __future__ import annotations

import bmesh
import bpy

from .conventions import Conventions


def ensure_material(name: str, conv: Conventions) -> bpy.types.Material:
    """The material ``name`` (created with its preview color if it doesn't exist)."""
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
        color = conv.preview_color(name)
        material.diffuse_color = color
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled is not None:
            principled.inputs["Base Color"].default_value = color
            metallic = 1.0 if name in {"chrome", "metal_dark", "rim", "rim_accent"} else 0.0
            principled.inputs["Metallic"].default_value = metallic
            principled.inputs["Roughness"].default_value = 0.3 if name.startswith("paint") else 0.6
    return material


def slot_index(obj: bpy.types.Object, material: bpy.types.Material) -> int:
    """Index of ``material`` in the object's slots (added if missing)."""
    for index, slot in enumerate(obj.material_slots):
        if slot.material == material:
            return index
    obj.data.materials.append(material)
    return len(obj.material_slots) - 1


def assign(obj: bpy.types.Object, material: bpy.types.Material, only_selected: bool) -> int:
    """Assigns ``material`` to the selected faces (edit mode) or the whole mesh.
    Returns how many faces changed."""
    index = slot_index(obj, material)
    mesh = obj.data
    if obj.mode == "EDIT":
        edit = bmesh.from_edit_mesh(mesh)
        changed = 0
        for face in edit.faces:
            if face.select or not only_selected:
                face.material_index = index
                changed += 1
        bmesh.update_edit_mesh(mesh)
        return changed
    for polygon in mesh.polygons:
        if polygon.select or not only_selected:
            polygon.material_index = index
    return len(mesh.polygons)
