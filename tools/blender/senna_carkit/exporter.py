"""Exports a kit collection to ``model.glb`` + ``carkit_manifest.json``.

ALWAYS works on temporary copies: the user's objects are never modified (apart from
a temporary rename that is undone even if the export fails).
Copies get rotation/scale applied into the mesh (the object position is kept, so
``rim-stock`` keeps its origin at the center), the ``ss_role``/``ss_slot``/``ss_variant``
properties (glTF ``extras``), and are exported as binary glTF with +Y up.
"""

from __future__ import annotations

import json
import os

import bpy
from mathutils import Matrix

from . import manifest, naming, scene_info, validator
from .conventions import Conventions

MODEL_FILE = "model.glb"
RIM_FILE = "rim.glb"
MANIFEST_FILE = "carkit_manifest.json"
TEMP_SUFFIX = "__senna_original"
TEMP_COLLECTION = "senna_export_tmp"


class ExportError(Exception):
    pass


def model_file_for(kind: str) -> str:
    return RIM_FILE if kind == validator.KIND_RIM else MODEL_FILE


def export_kit(
    collection: bpy.types.Collection,
    out_dir: str,
    conv: Conventions,
    addon_version: str,
    dims_mm: dict | None = None,
) -> tuple[str, dict]:
    """Validates and exports. Returns (glb path, manifest). Raises ExportError on errors."""
    info = scene_info.collect(collection, dims_mm)
    issues = validator.validate(info, conv)
    if validator.has_errors(issues):
        first = next(issue for issue in issues if issue.severity == validator.ERROR)
        raise ExportError(f"corrija os erros da validação antes de exportar ({first.message})")
    os.makedirs(out_dir, exist_ok=True)
    model_file = model_file_for(info.kind)
    glb_path = os.path.join(out_dir, model_file)
    _export_copies(scene_info.kit_objects(collection), glb_path, conv)
    data = manifest.build(info, conv, addon_version, model_file)
    with open(os.path.join(out_dir, MANIFEST_FILE), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return glb_path, data


def _export_copies(objects: list[bpy.types.Object], glb_path: str, conv: Conventions) -> None:
    scene = bpy.context.scene
    temp = bpy.data.collections.new(TEMP_COLLECTION)
    scene.collection.children.link(temp)
    originals: dict[bpy.types.Object, str] = {}
    copies: list[bpy.types.Object] = []
    previous_selection = list(bpy.context.selected_objects)
    previous_active = bpy.context.view_layer.objects.active
    try:
        for obj in objects:
            originals[obj] = obj.name
            obj.name = obj.name + TEMP_SUFFIX
        for obj, name in originals.items():
            copy = _make_copy(obj, name, conv)
            temp.objects.link(copy)
            copies.append(copy)
        bpy.ops.object.select_all(action="DESELECT")
        for copy in copies:
            copy.select_set(True)
        bpy.context.view_layer.objects.active = copies[0] if copies else None
        bpy.ops.export_scene.gltf(
            filepath=glb_path,
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_apply=True,
            export_extras=True,
            export_cameras=False,
            export_lights=False,
            export_animations=False,
            export_skins=False,
            export_morph=False,
            export_tangents=False,
        )
    finally:
        for copy in copies:
            data = copy.data
            bpy.data.objects.remove(copy, do_unlink=True)
            if data is not None and data.users == 0:
                bpy.data.meshes.remove(data)
        bpy.data.collections.remove(temp)
        for obj, name in originals.items():
            obj.name = name
        for obj in previous_selection:
            if obj.name in bpy.data.objects:
                obj.select_set(True)
        bpy.context.view_layer.objects.active = previous_active


def _make_copy(obj: bpy.types.Object, name: str, conv: Conventions) -> bpy.types.Object:
    copy = obj.copy()
    copy.name = name
    world = obj.matrix_world.copy()
    copy.parent = None
    location, rotation, scale = world.decompose()
    if obj.type == "MESH":
        copy.data = obj.data.copy()
        # Apply rotation and scale into the vertices; keep the position on the object.
        copy.data.transform(Matrix.LocRotScale(None, rotation, scale))
        copy.matrix_world = Matrix.Translation(location)
    else:
        copy.matrix_world = world
    info = naming.classify(name, conv)
    for key in list(copy.keys()):
        if key.startswith("ss_") and key != validator.RADIUS_PROP:
            del copy[key]
    if info.role is not None:
        copy[conv.metadata_key("role")] = info.role
        if info.slot:
            copy[conv.metadata_key("slot")] = info.slot
        if info.variant:
            copy[conv.metadata_key("variant")] = info.variant
    return copy
