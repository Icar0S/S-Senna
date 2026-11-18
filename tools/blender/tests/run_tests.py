"""Headless tests of the add-on inside Blender (operators, scene reading, exporter).

Run:  blender -b --factory-startup -P tools/blender/tests/run_tests.py
      (tools/blender/run_tests.sh finds Blender and does that)

Also runs the pure tests (test_pure.py). Exit code 1 if anything fails.
"""

from __future__ import annotations

import json
import math
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
sys.path.insert(0, HERE)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

import senna_carkit  # noqa: E402
from senna_carkit import exporter, materials, scene_info, validator  # noqa: E402
from senna_carkit.conventions import Conventions  # noqa: E402

CONV = Conventions.load()
R = 0.31
INCH = 0.0254


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not hasattr(bpy.types.Scene, "senna"):
        senna_carkit.register()


def box(name: str, center, size, material: str = "paint_body", collection=None) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    data = bmesh.new()
    bmesh.ops.create_cube(data, size=1.0)
    bmesh.ops.scale(data, vec=size, verts=data.verts)
    bmesh.ops.translate(data, vec=center, verts=data.verts)
    data.to_mesh(mesh)
    data.free()
    obj = bpy.data.objects.new(name, mesh)
    if material:
        mesh.materials.append(materials.ensure_material(material, CONV))
    (collection or bpy.context.scene.collection).objects.link(obj)
    return obj


def cylinder_x(name: str, center, diameter: float, width: float, material: str = "rubber") -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    data = bmesh.new()
    bmesh.ops.create_cone(data, cap_ends=True, segments=24, radius1=diameter / 2, radius2=diameter / 2, depth=width)
    bmesh.ops.rotate(data, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"), verts=data.verts)
    data.to_mesh(mesh)
    data.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(materials.ensure_material(material, CONV))
    obj.location = center
    bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(objects) -> None:
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0] if objects else None


def make_car(slug: str = "teste") -> bpy.types.Collection:
    """Synthetic car built with the panel's buttons: 4300 x 1760 x 1250 mm."""
    props = bpy.context.scene.senna
    props.slug = slug
    props.length_mm, props.width_mm, props.height_mm, props.wheelbase_mm = 4300, 1760, 1250, 2550
    assert bpy.ops.senna.new_car() == {"FINISHED"}
    kit = props.kit
    parts = operators_sub(kit, "peças")
    box("body-stock", (0, 0, 0.7), (1.76, 4.2, 1.1), collection=parts)
    box("bumper_front-stock", (0, -2.1, 0.35), (1.7, 0.1, 0.3), collection=parts)
    box("glass-stock", (0, 0.2, 1.1), (1.4, 1.4, 0.3), "glass", collection=kit)
    tires = [cylinder_x(f"pneu_{i}", (x, y, R), 2 * R, 0.22) for i, (x, y) in enumerate(_wheel_spots())]
    rim_source = cylinder_x("aro_baixado", (3.0, 0.0, 0.5), 0.4, 0.15, "rim")
    props.rim_source = rim_source
    select_only(tires)
    assert bpy.ops.senna.detect_wheels() == {"FINISHED"}
    for socket in CONV.recommended_sockets():
        props.socket = socket
        bpy.context.scene.cursor.location = (0.0, 1.9, 1.0)
        props.socket_width_m = 1.3 if socket == "spoiler" else 0.0
        assert bpy.ops.senna.create_socket() == {"FINISHED"}
    return kit


def operators_sub(kit, base):
    from senna_carkit import operators

    return operators.sub_collection(kit, base)


def _wheel_spots():
    return [(0.77, -1.275), (-0.76, -1.27), (0.78, 1.28), (-0.77, 1.275)]


def snapshot() -> dict:
    state = {}
    for obj in bpy.data.objects:
        vertices = len(obj.data.vertices) if obj.type == "MESH" else 0
        state[obj.name] = (tuple(round(v, 6) for v in obj.matrix_world.translation), vertices)
    return state


class CarKitOperators(unittest.TestCase):
    def setUp(self):
        reset_scene()
        self.out = tempfile.mkdtemp(prefix="senna_carkit_")

    def test_register(self):
        for name in ("new_car", "detect_wheels", "validate", "export", "new_rim", "new_universal_part"):
            self.assertTrue(hasattr(bpy.ops.senna, name), name)

    def test_new_car_collections_and_guide(self):
        make_car()
        kit = bpy.data.collections["carro-teste"]
        children = {child.name for child in kit.children}
        self.assertTrue({"peças-teste", "soquetes-teste", "rodas-teste", "referências-teste"} <= children)
        self.assertEqual(4300, kit["dim_length_mm"])
        names = {obj.name for obj in scene_info.kit_objects(kit)}
        self.assertNotIn("guia-teste", names)
        self.assertNotIn("pneu_0", names)  # moved to the references after "Detectar rodas"

    def test_detect_wheels_and_rim(self):
        make_car()
        fl = bpy.data.objects["wheel-FL"]
        self.assertAlmostEqual(R, fl["radius_m"], places=3)
        self.assertAlmostEqual(R, fl.location.z, places=3)
        self.assertAlmostEqual(-fl.location.x, bpy.data.objects["wheel-FR"].location.x, places=4)
        rim = bpy.data.objects["rim-stock"]
        dims = rim.dimensions
        self.assertAlmostEqual(CONV.rim_model()[0] * INCH, dims.z, places=3)
        self.assertAlmostEqual(CONV.rim_model()[1] * INCH, dims.x, places=3)
        self.assertLess((rim.location - fl.location).length, 1e-4)

    def test_good_car_validates_and_exports_a_copy(self):
        make_car()
        bpy.context.view_layer.objects.active = bpy.data.objects["bumper_front-stock"]
        assert bpy.ops.senna.create_variant() == {"FINISHED"}
        self.assertFalse(bpy.data.objects["bumper_front-stock"].visible_get())
        # Unapplied scale on purpose: the export applies it on the copy only.
        bpy.data.objects["glass-stock"].scale = (1.0, 1.0, 1.02)
        assert bpy.ops.senna.validate() == {"FINISHED"}
        props = bpy.context.scene.senna
        errors = [item.message for item in props.issues if item.severity == validator.ERROR]
        self.assertEqual([], errors)
        before = snapshot()
        props.export_dir = self.out
        self.assertEqual({"FINISHED"}, bpy.ops.senna.export())
        self.assertEqual(before, snapshot(), "o exportador mexeu nos objetos do usuário")
        self.assertEqual((1.0, 1.0, 1.02), tuple(round(v, 4) for v in bpy.data.objects["glass-stock"].scale))
        self.assertNotIn(exporter.TEMP_COLLECTION, bpy.data.collections)
        with open(os.path.join(self.out, exporter.MANIFEST_FILE), encoding="utf-8") as handle:
            data = json.load(handle)
        self.assertEqual("teste", data["slug"])
        self.assertEqual(senna_carkit.ADDON_VERSION, data["addon_version"])
        variants = {(p["slot"], p["variant"]) for p in data["parts"]}
        self.assertEqual({("body", "stock"), ("bumper_front", "stock"), ("bumper_front", "kit01")}, variants)
        self.assertEqual(sorted(CONV.recommended_sockets()), sorted(data["sockets"]))
        self.assertEqual([0.0, 1.0, -1.9], data["sockets"]["spoiler"]["position"])
        self.assertEqual(1.3, data["sockets"]["spoiler"]["width_m"])
        self.assertGreater(data["wheels"]["FL"]["position"][2], 1.0)  # front = +Z in Godot
        self.assertNotIn("rubber", data["materials"])  # the tires stayed in the references
        self._check_glb(os.path.join(self.out, exporter.MODEL_FILE))

    def _check_glb(self, path: str) -> None:
        """Re-imports the .glb in an empty scene: names, extras and +Y up."""
        self.assertTrue(os.path.isfile(path))
        reset_scene()
        bpy.ops.import_scene.gltf(filepath=path)
        names = {obj.name for obj in bpy.data.objects}
        self.assertIn("body-stock", names)
        self.assertIn("bumper_front-kit01", names)
        self.assertIn("socket-neon", names)
        self.assertNotIn("guia-teste", names)
        self.assertFalse(any(name.startswith("pneu_") for name in names))
        body = bpy.data.objects["body-stock"]
        self.assertEqual("part", body.get("ss_role"))
        self.assertEqual("body", body.get("ss_slot"))
        self.assertEqual("stock", body.get("ss_variant"))
        self.assertEqual("socket", bpy.data.objects["socket-spoiler"].get("ss_role"))
        # The importer converts back to Blender axes: front still at -Y.
        self.assertLess(bpy.data.objects["wheel-FL"].location.y, 0.0)
        self.assertIn("paint_body", {slot.material.name for slot in body.material_slots})

    def test_bad_car_does_not_export(self):
        make_car()
        box("Cube", (0, 0, 2), (0.2, 0.2, 0.2), collection=bpy.context.scene.senna.kit)
        bpy.data.objects["body-stock"].data.materials.append(bpy.data.materials.new("Material"))
        assert bpy.ops.senna.validate() == {"FINISHED"}
        codes = {issue.code for issue in validator.validate(scene_info.collect(bpy.context.scene.senna.kit), CONV)}
        self.assertIn("unknown_name", codes)
        bpy.context.scene.senna.export_dir = self.out
        with self.assertRaises(RuntimeError):  # Blender raises the operator's ERROR report
            bpy.ops.senna.export()
        self.assertFalse(os.path.exists(os.path.join(self.out, exporter.MODEL_FILE)))

    def test_material_has_preview_color(self):
        obj = box("hood-stock", (0, 0, 0), (1, 1, 0.1), material="")
        select_only([obj])
        bpy.context.scene.senna.material = "carbon"
        self.assertEqual({"FINISHED"}, bpy.ops.senna.assign_material())
        material = obj.material_slots[0].material
        self.assertEqual("carbon", material.name)
        expected = CONV.preview_color("carbon")
        self.assertAlmostEqual(expected[0], material.diffuse_color[0], places=3)

    def test_mirror_left_right(self):
        make_car()
        props = bpy.context.scene.senna
        props.socket = "canard_L"
        bpy.context.scene.cursor.location = (0.8, -1.9, 0.4)
        bpy.ops.senna.create_socket()
        self.assertEqual({"FINISHED"}, bpy.ops.senna.mirror_left_right())
        right = bpy.data.objects["socket-canard_R"]
        self.assertAlmostEqual(-0.8, right.location.x, places=5)
        self.assertAlmostEqual(-1.9, right.location.y, places=5)

    def test_fit_length(self):
        obj = box("body-stock", (0, 0, 0), (1.0, 2.0, 1.0))
        select_only([obj])
        bpy.context.scene.senna.length_mm = 4000
        bpy.ops.senna.fit_length()
        self.assertAlmostEqual(4.0, obj.dimensions.y, places=4)

    def test_separate_part(self):
        obj = box("body-stock", (0, 0, 0.5), (1.7, 4.0, 1.0))
        props = bpy.context.scene.senna
        select_only([obj])
        bpy.ops.object.mode_set(mode="EDIT")
        edit = bmesh.from_edit_mesh(obj.data)
        for face in edit.faces:
            face.select = face.calc_center_median().y < -1.9
        bmesh.update_edit_mesh(obj.data)
        props.slot = "bumper_front"
        self.assertEqual({"FINISHED"}, bpy.ops.senna.separate_part())
        self.assertIn("bumper_front-stock", bpy.data.objects)

    def test_rim_and_universal_part_kits(self):
        props = bpy.context.scene.senna
        props.rim_slug = "teste_aro"
        bpy.ops.senna.new_rim()
        diameter, width = (value * INCH for value in CONV.rim_model())
        cylinder = cylinder_x("rim-teste_aro", (0, 0, 0), diameter, width, "rim")
        bpy.context.scene.collection.objects.unlink(cylinder)
        props.kit.objects.link(cylinder)
        glb, data = exporter.export_kit(props.kit, self.out, CONV, senna_carkit.ADDON_VERSION)
        self.assertTrue(glb.endswith(exporter.RIM_FILE))
        self.assertEqual("rim", data["kind"])

        props.part_slot = "spoiler"
        props.part_slug = "asa_teste"
        bpy.ops.senna.new_universal_part()
        wing = box("spoiler-asa_teste", (0, 0, 0.1), (1.4, 0.25, 0.04), collection=props.kit)
        self.assertEqual("spoiler-asa_teste", wing.name)
        out = os.path.join(self.out, "asa")
        glb, data = exporter.export_kit(props.kit, out, CONV, senna_carkit.ADDON_VERSION)
        self.assertEqual("part", data["kind"])
        self.assertEqual([{"slot": "spoiler", "variant": "asa_teste", "triangles": 12}], data["parts"])

    def test_preview_rim_toggles(self):
        make_car()
        bpy.ops.senna.preview_rim()
        self.assertIn("preview_rim_FL", bpy.data.objects)
        self.assertNotIn("preview_rim_FL", {o.name for o in scene_info.kit_objects(bpy.context.scene.senna.kit)})
        bpy.ops.senna.preview_rim()
        self.assertNotIn("preview_rim_FL", bpy.data.objects)


def main() -> int:
    reset_scene()
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    import test_pure

    suite.addTests(loader.loadTestsFromModule(test_pure))
    suite.addTests(loader.loadTestsFromTestCase(CarKitOperators))
    result = unittest.TextTestRunner(verbosity=2, stream=sys.stdout).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    code = main()
    sys.stdout.flush()
    sys.exit(code)
