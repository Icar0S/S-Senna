"""Tests of the pure modules of the add-on (no Blender needed).

Run: python -m unittest discover -s tools/blender/tests -p "test_pure.py"
(also run inside Blender by run_tests.py).
"""

from __future__ import annotations

import copy
import os
import sys
import unittest

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))

import update_car_json  # noqa: E402
from senna_carkit import geometry, manifest, naming, validator  # noqa: E402
from senna_carkit.conventions import Conventions  # noqa: E402
from senna_carkit.validator import ObjInfo, SceneInfo  # noqa: E402

CONV = Conventions.load()
R = 0.31


def mesh(name, bbox_min, bbox_max, materials=("paint_body",), triangles=500, **kwargs) -> ObjInfo:
    return ObjInfo(
        name=name,
        kind="MESH",
        bbox_min=bbox_min,
        bbox_max=bbox_max,
        materials=list(materials),
        triangles=triangles,
        **kwargs,
    )


def empty(name, location, **props) -> ObjInfo:
    return ObjInfo(name=name, kind="EMPTY", location=location, bbox_min=location, bbox_max=location, props=props)


def good_car() -> SceneInfo:
    """A valid car: 4300 x 1760 x 1250 mm, front toward -Y."""
    objects = [
        mesh("body-stock", (-0.88, -2.1, 0.18), (0.88, 2.1, 1.25), ("paint_body", "trim_black", "light_head")),
        mesh("bumper_front-stock", (-0.84, -2.15, 0.2), (0.84, -2.0, 0.5)),
        mesh("bumper_front-kit01", (-0.85, -2.2, 0.15), (0.85, -2.0, 0.5)),
        mesh("glass-stock", (-0.7, -0.5, 0.8), (0.7, 0.9, 1.2), ("glass",)),
        mesh("rim-stock", (0.67, -1.5, 0.08), (0.87, -1.04, 0.54), ("rim", "rim_accent")),
        empty("wheel-FL", (0.77, -1.275, R), radius_m=R),
        empty("wheel-FR", (-0.77, -1.275, R), radius_m=R),
        empty("wheel-RL", (0.77, 1.275, R), radius_m=R),
        empty("wheel-RR", (-0.77, 1.275, R), radius_m=R),
    ]
    for socket in CONV.recommended_sockets():
        objects.append(empty(f"socket-{socket}", (0.0, 0.0, 0.5)))
    return SceneInfo(
        kind="car",
        slug="teste",
        dims_mm={"length": 4300, "width": 1760, "height": 1250, "wheelbase": 2550},
        objects=objects,
    )


def find(scene: SceneInfo, name: str) -> ObjInfo:
    return next(obj for obj in scene.objects if obj.name == name)


def codes(scene: SceneInfo, severity: str | None = None) -> set[str]:
    return {issue.code for issue in validator.validate(scene, CONV) if severity is None or issue.severity == severity}


class ValidatorRules(unittest.TestCase):
    """Each rule: the good car passes, a mutated car fails with that rule."""

    def assert_fails(self, scene: SceneInfo, code: str, severity: str = validator.ERROR) -> None:
        self.assertIn(code, codes(scene, severity), msg=[i.message for i in validator.validate(scene, CONV)])

    def test_good_car_passes(self):
        issues = validator.validate(good_car(), CONV)
        self.assertEqual([], [issue.message for issue in issues])

    def test_duplicate_suffix(self):
        scene = good_car()
        find(scene, "glass-stock").name = "glass-stock.001"
        self.assert_fails(scene, "duplicate_suffix")

    def test_forbidden_suffix(self):
        scene = good_car()
        scene.objects.append(mesh("hood-col", (0, 0, 0), (1, 1, 1)))
        self.assert_fails(scene, "forbidden_suffix")

    def test_unknown_name(self):
        scene = good_car()
        scene.objects.append(mesh("Cube", (0, 0, 0), (1, 1, 1)))
        self.assert_fails(scene, "unknown_name")

    def test_negative_scale(self):
        scene = good_car()
        find(scene, "glass-stock").scale = (-1.0, 1.0, 1.0)
        self.assert_fails(scene, "negative_scale")

    def test_unapplied_transform_is_a_warning(self):
        scene = good_car()
        find(scene, "glass-stock").scale = (2.0, 2.0, 2.0)
        self.assert_fails(scene, "unapplied_transform", validator.WARNING)
        self.assertNotIn("unapplied_transform", codes(scene, validator.ERROR))

    def test_unknown_material(self):
        scene = good_car()
        find(scene, "body-stock").materials.append("Material.001")
        self.assert_fails(scene, "unknown_material")
        find(scene, "body-stock").materials[-1] = "tex_grade"
        self.assertNotIn("unknown_material", codes(scene))

    def test_face_without_material(self):
        scene = good_car()
        find(scene, "body-stock").faces_without_material = 3
        self.assert_fails(scene, "face_without_material")

    def test_missing_body(self):
        scene = good_car()
        find(scene, "body-stock").name = "body-wide01"
        self.assert_fails(scene, "missing_body")

    def test_missing_stock_variant(self):
        scene = good_car()
        find(scene, "bumper_front-stock").name = "bumper_front-kit02"
        self.assert_fails(scene, "missing_stock")

    def test_missing_wheel(self):
        scene = good_car()
        scene.objects.remove(find(scene, "wheel-RR"))
        self.assert_fails(scene, "missing_wheel")

    def test_wheel_radius_missing(self):
        scene = good_car()
        find(scene, "wheel-FL").props = {}
        self.assert_fails(scene, "wheel_radius_missing")

    def test_wheels_must_touch_the_ground(self):
        scene = good_car()
        for name in ("wheel-FL", "wheel-FR"):
            obj = find(scene, name)
            obj.location = (obj.location[0], obj.location[1], R + 0.05)
        self.assert_fails(scene, "wheel_ground")

    def test_front_must_be_minus_y(self):
        scene = good_car()
        for position in ("FL", "FR", "RL", "RR"):
            obj = find(scene, f"wheel-{position}")
            obj.location = (obj.location[0], -obj.location[1], obj.location[2])
        self.assert_fails(scene, "front_axis")

    def test_car_rotated_90_degrees(self):
        scene = good_car()
        body = find(scene, "body-stock")
        body.bbox_min, body.bbox_max = (-2.1, -0.88, 0.18), (2.1, 0.88, 1.25)
        self.assert_fails(scene, "front_axis")

    def test_left_wheels_on_plus_x(self):
        scene = good_car()
        for position in ("FL", "FR", "RL", "RR"):
            obj = find(scene, f"wheel-{position}")
            obj.location = (-obj.location[0], obj.location[1], obj.location[2])
        self.assert_fails(scene, "left_side")

    def test_wheels_symmetric(self):
        scene = good_car()
        obj = find(scene, "wheel-FR")
        obj.location = (-0.80, obj.location[1], obj.location[2])
        self.assert_fails(scene, "wheel_asymmetric")

    def test_dimensions_within_2_percent(self):
        scene = good_car()
        scene.dims_mm["length"] = 4600
        self.assert_fails(scene, "dimensions")
        scene.dims_mm["length"] = 4330
        self.assertNotIn("dimensions", codes(scene))

    def test_budget_per_object(self):
        scene = good_car()
        find(scene, "bumper_front-kit01").triangles = CONV.budget("part_tris") + 1
        self.assert_fails(scene, "budget_object")

    def test_budget_total(self):
        scene = good_car()
        find(scene, "body-stock").triangles = CONV.budget("body_tris")
        find(scene, "rim-stock").triangles = CONV.budget("rim_tris")
        self.assert_fails(scene, "budget_total")

    def test_recommended_sockets_are_warnings(self):
        scene = good_car()
        scene.objects.remove(find(scene, "socket-neon"))
        self.assert_fails(scene, "socket_missing", validator.WARNING)
        self.assertFalse(validator.has_errors(validator.validate(scene, CONV)))

    def test_rim_kit(self):
        inch = 0.0254
        rim = mesh("rim-raios", (-4 * inch, -9 * inch, -9 * inch), (4 * inch, 9 * inch, 9 * inch), ("rim",), 1500)
        scene = SceneInfo(kind="rim", slug="raios", objects=[rim])
        self.assertEqual(set(), codes(scene))
        rim.bbox_max = (4 * inch, 7 * inch, 7 * inch)
        self.assert_fails(scene, "rim_size")
        self.assert_fails(SceneInfo(kind="rim", objects=[]), "rim_count")

    def test_universal_part_kit(self):
        part = mesh("spoiler-asa", (-0.7, -0.1, 0.0), (0.7, 0.1, 0.2), ("paint_body",), 800)
        scene = SceneInfo(kind="part", slug="asa", objects=[part])
        self.assertEqual(set(), codes(scene))
        part.triangles = CONV.budget("part_tris") + 1
        self.assert_fails(scene, "budget_object")
        self.assert_fails(SceneInfo(kind="part", objects=[]), "part_count")


class Naming(unittest.TestCase):
    def test_classify(self):
        self.assertEqual(("part", "bumper_front", "kit01"), self._c("bumper_front-kit01"))
        self.assertEqual(("socket", "exhaust_L", ""), self._c("socket-exhaust_L"))
        self.assertEqual(("wheel", "RR", ""), self._c("wheel-RR"))
        self.assertEqual(("rim", "", "stock"), self._c("rim-stock"))
        self.assertEqual(("fixed", "glass", "stock"), self._c("glass-stock"))
        for bad in ("Cube", "socket-asa", "wheel-XX", "body-Kit01", "porta-esquerda"):
            self.assertIsNone(naming.classify(bad, CONV).role, bad)

    def _c(self, name):
        info = naming.classify(name, CONV)
        return (info.role, info.slot, info.variant)

    def test_next_variant_and_mirror(self):
        names = ["bumper_front-stock", "bumper_front-kit01", "bumper_front-kit03", "hood-kit01"]
        self.assertEqual("kit02", naming.next_variant("bumper_front", names, CONV))
        self.assertEqual("kit01", naming.next_variant("side_skirts", names, CONV))
        self.assertEqual("socket-exhaust_R", naming.mirror_name("socket-exhaust_L"))
        self.assertIsNone(naming.mirror_name("socket-neon"))
        self.assertTrue(naming.has_duplicate_suffix("body-stock.001"))
        self.assertTrue(naming.has_forbidden_suffix("hood-colonly", CONV))


class Geometry(unittest.TestCase):
    def boxes(self, offset=0.0):
        wheels = {"a": (0.77, -1.3), "b": (-0.75, -1.27), "c": (0.78, 1.25), "d": (-0.77, 1.26)}
        return [
            (name, (x - 0.1, y - R, 0.0 + offset), (x + 0.1, y + R, 2 * R + offset)) for name, (x, y) in wheels.items()
        ]

    def test_detect_wheels(self):
        wheels = geometry.detect_wheels(self.boxes())
        self.assertEqual({"FL", "FR", "RL", "RR"}, set(wheels))
        self.assertEqual("a", wheels["FL"]["source"])
        self.assertAlmostEqual(R, wheels["FL"]["radius"])
        with self.assertRaises(ValueError):
            geometry.detect_wheels(self.boxes()[:3])

    def test_symmetrize(self):
        wheels = geometry.symmetrize(geometry.detect_wheels(self.boxes(offset=0.02)))
        self.assertAlmostEqual(wheels["FL"]["center"][0], -wheels["FR"]["center"][0])
        self.assertAlmostEqual(wheels["FL"]["center"][1], wheels["FR"]["center"][1])
        self.assertAlmostEqual(wheels["FL"]["center"][2], wheels["FL"]["radius"])

    def test_godot_axes(self):
        self.assertEqual((1.0, 3.0, -2.0), geometry.to_godot((1.0, 2.0, 3.0)))


class Manifest(unittest.TestCase):
    def test_manifest_in_godot_axes(self):
        scene = good_car()
        find(scene, "socket-spoiler").props = {"width_m": 1.3}
        find(scene, "socket-spoiler").location = (0.0, 1.9, 0.9)
        data = manifest.build(scene, CONV, "0.1.0")
        self.assertEqual("carkit_manifest", data["schema"])
        self.assertEqual([0.77, R, 1.275], data["wheels"]["FL"]["position"])
        self.assertEqual(R, data["wheels"]["FL"]["radius_m"])
        self.assertEqual({"position": [0.0, 0.9, -1.9], "width_m": 1.3}, data["sockets"]["spoiler"])
        self.assertIn({"slot": "bumper_front", "variant": "kit01", "triangles": 500}, data["parts"])
        self.assertEqual("rim-stock", data["rim"])
        self.assertEqual(["glass-stock"], data["fixed"])
        # Measured over the stock configuration (kit variants don't count).
        self.assertEqual({"length": 4250, "width": 1760, "height": 1250}, data["measured_mm"])

    def test_update_car_json(self):
        data = manifest.build(good_car(), CONV, "0.1.0")
        car = {
            "id": "car:base/teste",
            "parts": [
                {"slot": "bumper_front", "variant": "kit01", "name": "Kit", "price": 1500},
                {"slot": "hood", "variant": "stock"},
            ],
            "sockets": {"spoiler": {"width_m": 1.2}},
            "wheels": {
                "anchors": {},
                "tire_outer_diameter_m": 0.6,
                "stock": {"rim": "rim-stock", "rim_in": 16, "width_in": 7.5},
            },
            "tuning_overrides": {"tire_mu": 1.5},
        }
        updated = update_car_json.update(copy.deepcopy(car), data)
        self.assertEqual(2550, updated["dimensions_mm"]["wheelbase"])
        self.assertEqual(4250, updated["dimensions_mm"]["length"])  # measured on the model
        # Order kept (kit01 first, as in car.json); new parts go to the end; hood was removed.
        self.assertEqual(
            [("bumper_front", "kit01"), ("body", "stock"), ("bumper_front", "stock")],
            [(p["slot"], p["variant"]) for p in updated["parts"]],
        )
        self.assertEqual("Kit", updated["parts"][0]["name"])
        self.assertEqual("spoiler", next(iter(updated["sockets"])))
        self.assertEqual({"width_m": 1.2}, updated["sockets"]["spoiler"])
        self.assertEqual([-0.77, R, -1.275], updated["wheels"]["anchors"]["RR"])
        self.assertEqual(0.62, updated["wheels"]["tire_outer_diameter_m"])
        self.assertEqual(16, updated["wheels"]["stock"]["rim_in"])
        self.assertEqual({"tire_mu": 1.5}, updated["tuning_overrides"])


if __name__ == "__main__":
    unittest.main()
