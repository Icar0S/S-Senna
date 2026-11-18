extends SceneTree
## Generates the procedural test/placeholder content, following every convention
## of doc 03 §4 and doc 04 §2 (Godot space: +Z front, +X left, +Y up, wheels on Y=0):
##
## - Fixture car `car:fixture/cunha` (simple wedge) -> godot/tests/fixtures/packs/fixture/
## - Rims `wheel:base/basica_5` and `wheel:base/disco` (18" x 8", face toward +X)
## - Universal spoiler `part:base/universal/spoiler/asa_simples`
##
## The prototype car `car:base/prototipo` is made by the Blender add-on since Etapa 05
## (tools/blender/make_prototipo_v2.py).
##
## Cars get `model.glb` + `car.json` (the parts/sockets/wheels sections come from the
## same numbers as the geometry). Rims and the spoiler get only the `.glb`; their JSON
## is written by hand.
##
## Run from the repository root:  tools/fixtures/make_test_car.sh

const FIXTURE_PACK_DIR: String = "res://tests/fixtures/packs/fixture"
const BASE_PACK_DIR: String = "res://content/packs/base"
const RIM_RADIUS: float = 0.2286  # 18" / 2
const RIM_HALF_WIDTH: float = 0.1016  # 8" / 2
const FLAT: int = 0xFFFFFFFF  # SurfaceTool smooth group for flat faces
const ROUND_DIGITS: float = 1000.0

var _materials: Dictionary = {}
var _failures: int = 0


func _init() -> void:
	_make_car(_cunha_spec())
	_make_rim(BASE_PACK_DIR.path_join("wheels/basica_5/rim.glb"), "basica_5", false)
	_make_rim(BASE_PACK_DIR.path_join("wheels/disco/rim.glb"), "disco", true)
	_make_universal_spoiler(
		BASE_PACK_DIR.path_join("parts/universal/spoiler/asa_simples/model.glb")
	)
	print("make_test_car: %s" % ("OK" if _failures == 0 else "%d falha(s)" % _failures))
	quit(0 if _failures == 0 else 1)


# --- Car specs -------------------------------------------------------------------------


## Simple wedge used by the automated tests. Only some nodes carry metadata, so the
## scanner's name fallback is exercised too.
func _cunha_spec() -> Dictionary:
	return {
		"slug": "cunha",
		"pack": "fixture",
		"dir": FIXTURE_PACK_DIR.path_join("cars/cunha"),
		"display_name": "Cunha de Teste",
		"manufacturer": "S-Senna",
		"year": 2026,
		"country": "BR",
		"category": "outro",
		"metadata": "partial",
		"axle_z": [1.25, -1.25],
		"wheel_x": 0.76,
		"tire_d": 0.62,
		"rear_z": -2.05,
		# [z, sill height]
		"stations":
		[
			[2.05, 0.24],
			[1.65, 0.2],
			[1.58, 0.66],
			[0.92, 0.66],
			[0.85, 0.2],
			[-0.85, 0.2],
			[-0.92, 0.66],
			[-1.58, 0.66],
			[-1.65, 0.22],
			[-2.05, 0.26],
		],
		"top": [[2.05, 0.62], [1.0, 0.8], [0.3, 1.2], [-0.9, 1.2], [-1.6, 0.86], [-2.05, 0.84]],
		"belt": [[2.05, 0.6], [1.0, 0.78], [-1.6, 0.84], [-2.05, 0.82]],
		"half_width": [[2.05, 0.82], [1.6, 0.86], [-2.05, 0.86]],
		"windshield": [1.0, 0.3],
		"rear_window": [-0.9, -1.6],
		"bumpers":
		[
			{
				"variant": "stock",
				"rings": [[2.0, 0.84, 0.22, 0.47], [2.2, 0.8, 0.26, 0.44]],
			},
			{
				"variant": "kit01",
				"name": "Kit Teste",
				"price": 1500,
				"style_points": 2,
				"rings": [[2.0, 0.85, 0.16, 0.47], [2.26, 0.82, 0.16, 0.42]],
			},
		],
		"hoods": [{"variant": "stock", "finishes": ["paint", "carbon"], "bulge": 0.0}],
		"sockets":
		["spoiler", "exhaust_L", "exhaust_R", "lip_front", "neon", "light_head_L", "light_head_R"],
		"collision": true,
		"stats":
		{
			"power_hp": 150,
			"torque_nm": 200,
			"redline_rpm": 7000,
			"mass_kg": 1150,
			"weight_front_pct": 55,
			"drivetrain": "FWD",
			"gears": 5,
			"top_speed_kmh": 190,
			"grip": 0.6,
			"handling": 0.6,
			"braking": 0.6,
		},
		"price": 5000,
		"unlock": "never",
		"paint": {"finish": "solid", "color": "#2E7DD7"},
	}


# --- Car -------------------------------------------------------------------------------


func _make_car(spec: Dictionary) -> void:
	var root: Node3D = Node3D.new()
	root.name = spec["slug"]
	var all_metadata: bool = spec["metadata"] == "all"

	var body: Dictionary = _body_triangles(spec)
	_add_mesh(
		root,
		"body-stock",
		body["paint"],
		{"role": "part", "slot": "body", "variant": "stock"},
		true
	)
	_add_mesh(root, "glass-stock", body["glass"], {"role": "fixed"}, all_metadata)

	var parts: Array = [{"slot": "body", "variant": "stock"}]
	for bumper: Dictionary in spec["bumpers"]:
		var tris: Dictionary = {}
		_loft_rects(tris, bumper["rings"], "paint_body", "trim_black")
		var meta: Dictionary = {
			"role": "part", "slot": "bumper_front", "variant": bumper["variant"]
		}
		_add_mesh(root, "bumper_front-" + bumper["variant"], tris, meta, true)
		parts.append(_part_entry("bumper_front", bumper))
	for hood: Dictionary in spec["hoods"]:
		var meta: Dictionary = {"role": "part", "slot": "hood", "variant": hood["variant"]}
		_add_mesh(
			root,
			"hood-" + hood["variant"],
			_hood_triangles(spec, hood["bulge"]),
			meta,
			all_metadata
		)
		parts.append(_part_entry("hood", hood))

	var sockets: Dictionary = _socket_positions(spec)
	var spoiler_at: Vector3 = sockets["spoiler"][0]
	_add_mesh(
		root,
		"spoiler-stock",
		_spoiler_triangles(spoiler_at, 1.2, 0.1, 0.2),
		{"role": "part", "slot": "spoiler", "variant": "stock"},
		all_metadata
	)
	parts.append({"slot": "spoiler", "variant": "stock", "accepts_universal": true})

	var socket_json: Dictionary = {}
	for socket: String in spec["sockets"]:
		var info: Array = sockets[socket]
		var params: Dictionary = info[1]
		var meta: Dictionary = {"ss_role": "socket", "ss_slot": socket}
		meta.merge(params)
		_add_empty(root, "socket-" + socket, info[0], meta if all_metadata else {})
		socket_json[socket] = params

	var anchors: Dictionary = _wheel_anchors(spec)
	var anchors_json: Dictionary = {}
	for position: String in Conventions.wheel_positions():
		var meta: Dictionary = {"ss_role": "wheel", "ss_slot": position}
		_add_empty(root, "wheel-" + position, anchors[position], meta if all_metadata else {})
		anchors_json[position] = _vec_json(anchors[position])

	var rim_tris: Dictionary = _rim_triangles(false)
	var rim: MeshInstance3D = _add_mesh(root, "rim-stock", rim_tris, {"role": "rim"}, all_metadata)
	rim.position = anchors["FL"]

	if spec["collision"]:
		var box: Dictionary = {}
		var hw: float = _interp(spec["half_width"], 0.0)
		_loft_rects(box, [[2.1, hw, 0.2, 1.15], [-2.05, hw, 0.2, 1.15]], "trim_black", "trim_black")
		_add_mesh(root, "collision-1", box, {}, false)

	var bounds: AABB = _bounds_of(
		root, ["body-stock", "glass-stock", "bumper_front-stock", "hood-stock"]
	)
	var dir: String = spec["dir"]
	_export_gltf(root, dir.path_join("model.glb"))
	var car_json: Dictionary = _car_json(spec, parts, socket_json, anchors_json, bounds)
	# Keep what the F2 tuning panel saved for this car.
	var car_file: String = dir.path_join("car.json")
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(car_file))
	if previous is Dictionary and (previous as Dictionary).has("tuning_overrides"):
		car_json["tuning_overrides"] = previous["tuning_overrides"]
	_write_json(car_file, car_json)
	root.free()


func _part_entry(slot: String, source: Dictionary) -> Dictionary:
	var entry: Dictionary = {"slot": slot, "variant": source["variant"]}
	for key: String in ["name", "price", "style_points", "finishes"]:
		if source.has(key):
			entry[key] = source[key]
	return entry


func _car_json(
	spec: Dictionary, parts: Array, sockets: Dictionary, anchors: Dictionary, bounds: AABB
) -> Dictionary:
	var axle_z: Array = spec["axle_z"]
	return {
		"schema": "car",
		"schema_version": 1,
		"id": "car:%s/%s" % [spec["pack"], spec["slug"]],
		"display_name": spec["display_name"],
		"manufacturer": spec["manufacturer"],
		"year": spec["year"],
		"country": spec["country"],
		"category": spec["category"],
		"model": "model.glb",
		"dimensions_mm":
		{
			"length": roundi(bounds.size.z * 1000.0),
			"width": roundi(bounds.size.x * 1000.0),
			"height": roundi(bounds.end.y * 1000.0),
			"wheelbase": roundi((float(axle_z[0]) - float(axle_z[1])) * 1000.0),
		},
		"parts": parts,
		"sockets": sockets,
		"wheels":
		{
			"anchors": anchors,
			"tire_outer_diameter_m": spec["tire_d"],
			"stock": {"rim": "rim-stock", "rim_in": 16, "width_in": 7.5},
			"rim_in_min": 15,
			"rim_in_max": 19,
			"width_in_min": 6.5,
			"width_in_max": 10.0,
			"max_offset_mm": 30,
			"max_camber_deg": 8,
		},
		"paint": {"zones": ["paint_body"], "default": {"paint_body": spec["paint"]}},
		"stats": spec["stats"],
		"economy": {"price": spec["price"], "unlock": spec["unlock"]},
		"camera": {"garage_distance_m": 5.2},
		"collection": {"has_miniature": false},
		"credits":
		{
			"model_author": "S-Senna (gerado por script)",
			"license": "CC-BY-NC-SA-4.0",
			"source": "tools/fixtures/make_test_car.gd",
		},
	}


## Body loft: one ring per station (6 points: sill, belt and roof on each side).
## Returns {"paint": tris, "glass": tris}; side windows, windshield and rear window
## go to glass so they can become the separate `glass-stock` piece.
func _body_triangles(spec: Dictionary) -> Dictionary:
	var paint: Dictionary = {}
	var glass: Dictionary = {}
	var rings: Array[PackedVector3Array] = []
	var stations: Array = spec["stations"]
	for station: Array in stations:
		rings.append(_body_ring(spec, station[0], station[1]))
	var windshield: Array = spec["windshield"]
	var rear_window: Array = spec["rear_window"]
	for s: int in rings.size() - 1:
		var a: PackedVector3Array = rings[s]
		var b: PackedVector3Array = rings[s + 1]
		var z_mid: float = (a[0].z + b[0].z) / 2.0
		var cabin: bool = (a[2].y - a[1].y) > 0.1 and (b[2].y - b[1].y) > 0.1
		var in_windshield: bool = z_mid < windshield[0] and z_mid > windshield[1]
		var in_rear_window: bool = z_mid < rear_window[0] and z_mid > rear_window[1]
		var center: Vector3 = (_centroid(a) + _centroid(b)) / 2.0
		for edge: int in 6:
			var next: int = (edge + 1) % 6
			var material: String = "paint_body"
			var target: Dictionary = paint
			if edge == 5:
				material = "trim_black"
			elif (edge == 1 or edge == 3) and cabin:
				material = "glass"
				target = glass
			elif edge == 2 and (in_windshield or in_rear_window):
				material = "glass"
				target = glass
			_quad(target, material, a[edge], a[next], b[next], b[edge], center, edge)
	_cap(paint, rings[0], "paint_body", Vector3.BACK)
	_cap(paint, rings[rings.size() - 1], "paint_body", Vector3.FORWARD)
	_add_lights(paint, spec)
	return {"paint": paint, "glass": glass}


func _body_ring(spec: Dictionary, z: float, sill: float) -> PackedVector3Array:
	var top: float = _interp(spec["top"], z)
	var belt: float = minf(_interp(spec["belt"], z), top)
	var half_width: float = _interp(spec["half_width"], z)
	var cabin_amount: float = clampf((top - belt - 0.02) / 0.3, 0.0, 1.0)
	var roof_width: float = lerpf(half_width * 0.97, half_width * 0.74, cabin_amount)
	var bottom_width: float = half_width * 0.95
	return PackedVector3Array(
		[
			Vector3(bottom_width, sill, z),
			Vector3(half_width, belt, z),
			Vector3(roof_width, top, z),
			Vector3(-roof_width, top, z),
			Vector3(-half_width, belt, z),
			Vector3(-bottom_width, sill, z),
		]
	)


func _add_lights(tris: Dictionary, spec: Dictionary) -> void:
	var front_z: float = float((spec["stations"] as Array)[0][0])
	var rear_z: float = spec["rear_z"]
	for side: float in [1.0, -1.0]:
		var head_y: float = _interp(spec["belt"], front_z) - 0.06
		_box(
			tris,
			"light_head",
			Vector3(0.6 * side, head_y, front_z - 0.03),
			Vector3(0.14, 0.035, 0.04)
		)
		var tail_y: float = _interp(spec["belt"], rear_z) - 0.06
		_box(
			tris,
			"light_tail",
			Vector3(0.62 * side, tail_y, rear_z + 0.01),
			Vector3(0.16, 0.04, 0.02)
		)


func _hood_triangles(spec: Dictionary, bulge: float) -> Dictionary:
	var tris: Dictionary = {}
	var windshield: Array = spec["windshield"]
	var z_front: float = float((spec["stations"] as Array)[0][0]) - 0.05
	var z_back: float = float(windshield[0]) + 0.02
	var rings: Array[PackedVector3Array] = []
	for i: int in 6:
		var z: float = lerpf(z_front, z_back, i / 5.0)
		var y: float = _interp(spec["top"], z) + 0.004
		var w: float = _interp(spec["half_width"], z) * 0.8
		var rise: float = bulge * sin(PI * i / 5.0) if i > 0 else 0.0
		(
			rings
			. append(
				PackedVector3Array(
					[
						Vector3(w, y, z),
						Vector3(w * 0.35, y + 0.012 + rise, z),
						Vector3(-w * 0.35, y + 0.012 + rise, z),
						Vector3(-w, y, z),
						Vector3(-w, y - 0.01, z),
						Vector3(w, y - 0.01, z),
					]
				)
			)
		)
	_loft(tris, rings, "paint_body", "paint_body")
	return tris


## Wing on two posts. [param at] is the mounting point (base of the posts).
func _spoiler_triangles(at: Vector3, width: float, height: float, chord: float) -> Dictionary:
	var tris: Dictionary = {}
	for side: float in [1.0, -1.0]:
		_box(
			tris,
			"trim_black",
			at + Vector3(width * 0.32 * side, height / 2.0, 0.0),
			Vector3(0.025, height / 2.0, 0.04)
		)
	var y: float = at.y + height
	var half: float = width / 2.0
	var rings: Array[PackedVector3Array] = []
	for x: float in [half, -half]:
		(
			rings
			. append(
				PackedVector3Array(
					[
						Vector3(x, y, at.z + chord * 0.55),
						Vector3(x, y + 0.03, at.z + chord * 0.2),
						Vector3(x, y + 0.025, at.z - chord * 0.45),
						Vector3(x, y - 0.005, at.z - chord * 0.45),
					]
				)
			)
		)
	_loft(tris, rings, "paint_body", "paint_body")
	return tris


## Mount point (and JSON parameters) of every socket.
func _socket_positions(spec: Dictionary) -> Dictionary:
	var front_z: float = float((spec["stations"] as Array)[0][0])
	var rear_z: float = spec["rear_z"]
	var spoiler_z: float = rear_z + 0.22
	var belt_front: float = _interp(spec["belt"], front_z)
	var belt_rear: float = _interp(spec["belt"], rear_z)
	var half_width: float = _interp(spec["half_width"], 0.0)
	return {
		"spoiler":
		[Vector3(0, _r(_interp(spec["top"], spoiler_z)), _r(spoiler_z)), {"width_m": 1.3}],
		"exhaust_L": [Vector3(0.45, 0.26, _r(rear_z - 0.02)), {}],
		"exhaust_R": [Vector3(-0.45, 0.26, _r(rear_z - 0.02)), {}],
		"lip_front": [Vector3(0, 0.2, _r(front_z + 0.2)), {"width_m": 1.6}],
		"lip_rear": [Vector3(0, 0.3, _r(rear_z)), {"width_m": 1.6}],
		"canard_L": [Vector3(_r(half_width - 0.03), 0.36, _r(front_z + 0.08)), {}],
		"canard_R": [Vector3(_r(-half_width + 0.03), 0.36, _r(front_z + 0.08)), {}],
		"hood_scoop": [Vector3(0, _r(_interp(spec["top"], 1.45) + 0.02), 1.45), {}],
		"roof_scoop": [Vector3(0, _r(_interp(spec["top"], -0.3)), -0.3), {}],
		"plate_front": [Vector3(0, 0.4, _r(front_z + 0.18)), {}],
		"plate_rear": [Vector3(0, _r(belt_rear - 0.3), _r(rear_z - 0.01)), {}],
		"neon": [Vector3(0, 0.18, 0), {"length_m": 3.6, "width_m": 1.5}],
		"cam_hood": [Vector3(0, _r(_interp(spec["top"], 1.2) + 0.15), 1.2), {}],
		"cam_bumper": [Vector3(0, 0.45, _r(front_z + 0.22)), {}],
		"light_head_L": [Vector3(0.6, _r(belt_front - 0.06), _r(front_z)), {}],
		"light_head_R": [Vector3(-0.6, _r(belt_front - 0.06), _r(front_z)), {}],
		"light_tail_L": [Vector3(0.62, _r(belt_rear - 0.06), _r(rear_z)), {}],
		"light_tail_R": [Vector3(-0.62, _r(belt_rear - 0.06), _r(rear_z)), {}],
	}


func _wheel_anchors(spec: Dictionary) -> Dictionary:
	var x: float = spec["wheel_x"]
	var y: float = _r(float(spec["tire_d"]) / 2.0)
	var axles: Array = spec["axle_z"]
	return {
		"FL": Vector3(x, y, axles[0]),
		"FR": Vector3(-x, y, axles[0]),
		"RL": Vector3(x, y, axles[1]),
		"RR": Vector3(-x, y, axles[1]),
	}


# --- Rims and universal parts ------------------------------------------------------------


func _make_rim(path: String, root_name: String, disc: bool) -> void:
	var root: Node3D = Node3D.new()
	root.name = root_name
	_add_mesh(root, "rim-" + root_name, _rim_triangles(disc), {"role": "rim"}, true)
	_export_gltf(root, path)
	root.free()


## Rim modeled at 18" x 8": axis X, outer face toward +X, origin at the center.
func _rim_triangles(disc: bool) -> Dictionary:
	var tris: Dictionary = {}
	var segments: int = 24
	# Barrel (faces inward: the tire covers the outside).
	var barrel: Array[PackedVector3Array] = []
	for profile: Vector2 in [
		Vector2(-RIM_HALF_WIDTH, RIM_RADIUS),
		Vector2(-RIM_HALF_WIDTH * 0.85, RIM_RADIUS * 0.93),
		Vector2(RIM_HALF_WIDTH * 0.85, RIM_RADIUS * 0.93),
		Vector2(RIM_HALF_WIDTH, RIM_RADIUS),
	]:
		barrel.append(_circle(profile.x, profile.y, segments))
	for s: int in barrel.size() - 1:
		for i: int in segments:
			var j: int = (i + 1) % segments
			var a: Vector3 = barrel[s][i]
			var inward: Vector3 = -Vector3(0, a.y, a.z)
			_quad(tris, "rim", a, barrel[s][j], barrel[s + 1][j], barrel[s + 1][i], a + inward, 1)
	# Outer lip (accent ring facing +X).
	var lip_outer: PackedVector3Array = _circle(RIM_HALF_WIDTH, RIM_RADIUS, segments)
	var lip_inner: PackedVector3Array = _circle(RIM_HALF_WIDTH, RIM_RADIUS * 0.9, segments)
	_ring_band(tris, "rim_accent", lip_outer, lip_inner, Vector3.RIGHT, 2)
	# Hub.
	var hub_back: PackedVector3Array = _circle(RIM_HALF_WIDTH * 0.4, 0.065, 8)
	var hub_front: PackedVector3Array = _circle(RIM_HALF_WIDTH * 0.95, 0.055, 8)
	_loft(tris, [hub_back, hub_front], "metal_dark", "metal_dark", false, true)
	if disc:
		var inner: PackedVector3Array = _circle(RIM_HALF_WIDTH * 0.55, 0.065, segments)
		var outer: PackedVector3Array = _circle(RIM_HALF_WIDTH * 0.85, RIM_RADIUS * 0.91, segments)
		_ring_band(tris, "rim", outer, inner, Vector3.RIGHT, 3)
		for k: int in 10:
			_spoke(tris, TAU * k / 10.0, 0.08, 0.2, RIM_HALF_WIDTH * 0.8, 0.012, 0.012)
	else:
		for k: int in 5:
			_spoke(tris, TAU * k / 5.0, 0.06, 0.205, RIM_HALF_WIDTH * 0.7, 0.05, 0.03)
	return tris


func _spoke(
	tris: Dictionary, angle: float, r0: float, r1: float, x: float, w0: float, w1: float
) -> void:
	var radial: Vector3 = Vector3(0, cos(angle), sin(angle))
	var side: Vector3 = Vector3(0, -sin(angle), cos(angle))
	var rings: Array[PackedVector3Array] = []
	for step: Array in [[r0, w0], [r1, w1]]:
		var r: float = step[0]
		var w: float = step[1] / 2.0
		var c: Vector3 = radial * r
		(
			rings
			. append(
				PackedVector3Array(
					[
						c + Vector3(x + 0.012, 0, 0) + side * w,
						c + Vector3(x + 0.012, 0, 0) - side * w,
						c + Vector3(x - 0.018, 0, 0) - side * w,
						c + Vector3(x - 0.018, 0, 0) + side * w,
					]
				)
			)
		)
	_loft(tris, rings, "rim", "rim")


func _make_universal_spoiler(path: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = "asa_simples"
	var tris: Dictionary = _spoiler_triangles(Vector3.ZERO, 1.4, 0.16, 0.26)
	for side: float in [1.0, -1.0]:
		_box(tris, "paint_body", Vector3(0.7 * side, 0.18, 0.0), Vector3(0.006, 0.08, 0.15))
	_add_mesh(
		root,
		"spoiler-asa_simples",
		tris,
		{"role": "part", "slot": "spoiler", "variant": "asa_simples"},
		true
	)
	_export_gltf(root, path)
	root.free()


# --- Geometry helpers --------------------------------------------------------------------


## Loft through rectangular rings `[z, half_width, y_bottom, y_top]` (bumpers, boxes).
func _loft_rects(
	tris: Dictionary, rings_spec: Array, material: String, bottom_material: String
) -> void:
	var rings: Array[PackedVector3Array] = []
	for ring: Array in rings_spec:
		var z: float = ring[0]
		var w: float = ring[1]
		var y0: float = ring[2]
		var y1: float = ring[3]
		rings.append(
			PackedVector3Array(
				[Vector3(w, y0, z), Vector3(w, y1, z), Vector3(-w, y1, z), Vector3(-w, y0, z)]
			)
		)
	_loft(tris, rings, material, material, true, true, bottom_material)


## Joins consecutive rings with quads; optionally closes both ends. The last edge of
## each ring (index n-1 -> 0) uses [param bottom_material] when given.
func _loft(
	tris: Dictionary,
	rings: Array[PackedVector3Array],
	material: String,
	cap_material: String,
	cap_start: bool = true,
	cap_end: bool = true,
	bottom_material: String = ""
) -> void:
	var count: int = rings[0].size()
	for s: int in rings.size() - 1:
		var center: Vector3 = (_centroid(rings[s]) + _centroid(rings[s + 1])) / 2.0
		for edge: int in count:
			var next: int = (edge + 1) % count
			var edge_material: String = material
			if edge == count - 1 and not bottom_material.is_empty():
				edge_material = bottom_material
			_quad(
				tris,
				edge_material,
				rings[s][edge],
				rings[s][next],
				rings[s + 1][next],
				rings[s + 1][edge],
				center,
				edge
			)
	var direction: Vector3 = _centroid(rings[rings.size() - 1]) - _centroid(rings[0])
	if cap_start:
		_cap(tris, rings[0], cap_material, -direction)
	if cap_end:
		_cap(tris, rings[rings.size() - 1], cap_material, direction)


## Axis-aligned box centered at [param center] with [param half] extents.
func _box(tris: Dictionary, material: String, center: Vector3, half: Vector3) -> void:
	var rings: Array[PackedVector3Array] = []
	for dz: float in [half.z, -half.z]:
		(
			rings
			. append(
				PackedVector3Array(
					[
						center + Vector3(half.x, -half.y, dz),
						center + Vector3(half.x, half.y, dz),
						center + Vector3(-half.x, half.y, dz),
						center + Vector3(-half.x, -half.y, dz),
					]
				)
			)
		)
	_loft(tris, rings, material, material)


## Flat band between two concentric rings, facing [param facing].
func _ring_band(
	tris: Dictionary,
	material: String,
	outer: PackedVector3Array,
	inner: PackedVector3Array,
	facing: Vector3,
	group: int
) -> void:
	for i: int in outer.size():
		var j: int = (i + 1) % outer.size()
		var center: Vector3 = (outer[i] + inner[j]) / 2.0
		_quad(tris, material, outer[i], outer[j], inner[j], inner[i], center - facing, group)


## Circle in the YZ plane at [param x] (rims are built around the X axis).
func _circle(x: float, radius: float, segments: int) -> PackedVector3Array:
	var points: PackedVector3Array = []
	for i: int in segments:
		var angle: float = TAU * i / segments
		points.append(Vector3(x, cos(angle) * radius, sin(angle) * radius))
	return points


func _cap(tris: Dictionary, ring: PackedVector3Array, material: String, outward: Vector3) -> void:
	var center: Vector3 = _centroid(ring)
	for i: int in ring.size():
		var j: int = (i + 1) % ring.size()
		_tri(tris, material, center, ring[i], ring[j], outward, FLAT)


## Quad a-b-c-d. [param inside] is a point inside the solid, used to face it outward.
func _quad(
	tris: Dictionary,
	material: String,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	inside: Vector3,
	group: int
) -> void:
	var outward: Vector3 = (a + b + c + d) / 4.0 - inside
	_tri(tris, material, a, b, c, outward, group)
	_tri(tris, material, a, c, d, outward, group)


## Adds one triangle wound so that its front face points along [param outward]
## (Godot's front faces are clockwise as seen from the front).
func _tri(
	tris: Dictionary,
	material: String,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	outward: Vector3,
	group: int
) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 1e-12:
		return
	if not tris.has(material):
		tris[material] = []
	if normal.dot(outward) > 0.0:
		(tris[material] as Array).append([a, c, b, group])
	else:
		(tris[material] as Array).append([a, b, c, group])


func _centroid(points: PackedVector3Array) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	for p: Vector3 in points:
		sum += p
	return sum / points.size()


## Piecewise-linear profile; [param points] is `[[z, value], ...]` sorted by z descending.
func _interp(points: Array, z: float) -> float:
	if z >= float(points[0][0]):
		return points[0][1]
	for i: int in points.size() - 1:
		var z0: float = points[i][0]
		var z1: float = points[i + 1][0]
		if z <= z0 and z >= z1:
			return lerpf(points[i][1], points[i + 1][1], (z0 - z) / (z0 - z1))
	return points[points.size() - 1][1]


# --- Nodes, materials and files ----------------------------------------------------------


func _add_mesh(
	root: Node3D, node_name: String, tris: Dictionary, meta: Dictionary, with_meta: bool
) -> MeshInstance3D:
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.resource_name = node_name
	var material_names: Array = tris.keys()
	material_names.sort()
	for material_name: String in material_names:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tri: Array in tris[material_name]:
			st.set_smooth_group(tri[3])
			for i: int in 3:
				var p: Vector3 = tri[i]
				st.set_uv(Vector2(p.x + p.z, p.y))
				st.add_vertex(p)
		st.generate_normals()
		st.set_material(_material(material_name))
		st.commit(mesh)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	if with_meta and not meta.is_empty():
		var extras: Dictionary = {}
		for key: String in meta:
			extras[Conventions.metadata_key(key)] = meta[key]
		instance.set_meta("extras", extras)
	root.add_child(instance)
	instance.owner = root
	return instance


func _add_empty(root: Node3D, node_name: String, position: Vector3, extras: Dictionary) -> void:
	var node: Node3D = Node3D.new()
	node.name = node_name
	node.position = position
	if not extras.is_empty():
		node.set_meta("extras", extras)
	root.add_child(node)
	node.owner = root


## Preview colors only: the game replaces every material by name.
func _material(material_name: String) -> StandardMaterial3D:
	if _materials.has(material_name):
		return _materials[material_name]
	var colors: Dictionary = {
		"paint_body": Color("#D4421E"),
		"trim_black": Color("#16171A"),
		"glass": Color("#1C2A36"),
		"light_head": Color("#F4F7FF"),
		"light_tail": Color("#C4161C"),
		"rim": Color("#B8BCC2"),
		"rim_accent": Color("#E8E8E8"),
		"metal_dark": Color("#3A3D42"),
	}
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = colors.get(material_name, Color.MAGENTA)
	material.roughness = 0.35 if material_name in ["paint_body", "glass", "rim_accent"] else 0.7
	if material_name.begins_with("light_"):
		material.emission_enabled = true
		material.emission = material.albedo_color
	_materials[material_name] = material
	return material


func _bounds_of(root: Node3D, names: Array) -> AABB:
	var bounds: AABB = AABB()
	var first: bool = true
	for node_name: String in names:
		var node: MeshInstance3D = root.get_node_or_null(node_name)
		if node == null:
			continue
		var box: AABB = node.transform * node.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _export_gltf(root: Node3D, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: Error = document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("make_test_car: não consegui exportar %s (%s)" % [path, error_string(error)])
		_failures += 1
		return
	print("  %s" % path)


func _write_json(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("make_test_car: não consegui gravar %s" % path)
		_failures += 1
		return
	file.store_string(JSON.stringify(data, "  ", false) + "\n")
	print("  %s" % path)


func _vec_json(v: Vector3) -> Array:
	return [_r(v.x), _r(v.y), _r(v.z)]


func _r(value: float) -> float:
	return roundf(value * ROUND_DIGITS) / ROUND_DIGITS
