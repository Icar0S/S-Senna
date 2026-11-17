class_name TireMeshBuilder
extends RefCounted
## Procedural wheel meshes shared by every car (cached by parameters, so equal
## wheels never duplicate memory):
## - tire: keeps the OUTER diameter fixed; a bigger rim makes a lower profile;
## - brake disc and caliper (the caliper surface is named `caliper`, so it gets
##   the car's caliper paint).
## Built around the X axis (the wheel's axle), outer side toward +X.

const INCH: float = 0.0254
const SEGMENTS: int = 40
## Tires are a little wider than the rim.
const EXTRA_WIDTH_M: float = 0.02
const MIN_SIDEWALL_M: float = 0.02
const DISC_THICKNESS_M: float = 0.028

static var _tires: Dictionary = {}
static var _discs: Dictionary = {}
static var _calipers: Dictionary = {}
static var _surface_materials: Dictionary = {}


## Tire with outer diameter [param outer_diameter_m] for a [param rim_in]" x [param width_in]" rim.
static func build(outer_diameter_m: float, rim_in: int, width_in: float) -> ArrayMesh:
	var key: String = "%.4f|%d|%.3f" % [outer_diameter_m, rim_in, width_in]
	if _tires.has(key):
		return _tires[key]
	var outer: float = outer_diameter_m / 2.0
	var bead: float = minf(rim_in * INCH / 2.0, outer - MIN_SIDEWALL_M)
	var half: float = (width_in * INCH + EXTRA_WIDTH_M) / 2.0
	var height: float = outer - bead
	# Cross-section from the inner bead, over the tread, to the outer bead: (x, radius).
	var profile: PackedVector2Array = [
		Vector2(-half * 0.9, bead),
		Vector2(-half, bead + height * 0.3),
		Vector2(-half * 1.03, bead + height * 0.62),
		Vector2(-half * 0.97, outer - height * 0.14),
		Vector2(-half * 0.82, outer),
		Vector2(half * 0.82, outer),
		Vector2(half * 0.97, outer - height * 0.14),
		Vector2(half * 1.03, bead + height * 0.62),
		Vector2(half, bead + height * 0.3),
		Vector2(half * 0.9, bead),
	]
	var mesh: ArrayMesh = _revolve(profile, SEGMENTS, "rubber", true)
	mesh.resource_name = "tire_" + key
	_tires[key] = mesh
	return mesh


## Brake disc sized for a [param rim_in]" rim.
static func disc(rim_in: int) -> ArrayMesh:
	if _discs.has(rim_in):
		return _discs[rim_in]
	var radius: float = disc_radius(rim_in)
	var t: float = DISC_THICKNESS_M / 2.0
	var profile: PackedVector2Array = [
		Vector2(-t, radius * 0.35),
		Vector2(-t, radius),
		Vector2(t, radius),
		Vector2(t, radius * 0.35),
	]
	var mesh: ArrayMesh = _revolve(profile, 28, "metal_dark", false)
	mesh.resource_name = "brake_disc_%d" % rim_in
	_discs[rim_in] = mesh
	return mesh


## Caliper (a block hugging the top-rear of the disc).
static func caliper(rim_in: int) -> ArrayMesh:
	if _calipers.has(rim_in):
		return _calipers[rim_in]
	var radius: float = disc_radius(rim_in)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size: Vector3 = Vector3(0.07, radius * 0.5, 0.11)
	var center: Vector3 = Vector3(0.0, radius * 0.72, -radius * 0.25)
	for face: Array in _box_faces(center, size / 2.0):
		var face_center: Vector3 = (face[0] + face[1] + face[2]) / 3.0
		_add_facing(st, face[0], face[1], face[2], face_center - center)
	st.generate_normals()
	st.set_material(_named_material("caliper"))
	var mesh: ArrayMesh = st.commit()
	mesh.resource_name = "brake_caliper_%d" % rim_in
	_calipers[rim_in] = mesh
	return mesh


static func disc_radius(rim_in: int) -> float:
	return minf(rim_in * INCH / 2.0 * 0.78, 0.2)


## Number of different tire meshes created so far (memory check in tests).
static func cached_tire_count() -> int:
	return _tires.size()


static func _revolve(
	profile: PackedVector2Array, segments: int, material_name: String, smooth: bool
) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0 if smooth else 0xFFFFFFFF)
	for i: int in segments:
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		for k: int in profile.size() - 1:
			var p00: Vector3 = _ring_point(profile[k], a0)
			var p01: Vector3 = _ring_point(profile[k], a1)
			var p10: Vector3 = _ring_point(profile[k + 1], a0)
			var p11: Vector3 = _ring_point(profile[k + 1], a1)
			_add_tri(st, p00, p10, p11)
			_add_tri(st, p00, p11, p01)
	st.generate_normals()
	st.set_material(_named_material(material_name))
	return st.commit()


## Adds a triangle facing away from the axle (Godot front faces are clockwise).
static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var center: Vector3 = (a + b + c) / 3.0
	_add_facing(st, a, b, c, Vector3(center.x * 4.0, center.y, center.z))


## Adds a triangle whose front face points along [param outward].
static func _add_facing(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3
) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	var ordered: Array[Vector3] = [a, b, c]
	if normal.dot(outward) >= 0.0:
		ordered = [a, c, b]
	for p: Vector3 in ordered:
		st.set_uv(Vector2(p.x, atan2(p.z, p.y)))
		st.add_vertex(p)


static func _ring_point(point: Vector2, angle: float) -> Vector3:
	return Vector3(point.x, cos(angle) * point.y, sin(angle) * point.y)


## Triangles of a box (orientation fixed by [method _add_facing]).
static func _box_faces(c: Vector3, h: Vector3) -> Array:
	var p: Array[Vector3] = []
	for corner: int in 8:
		var sx: float = h.x if corner & 1 else -h.x
		var sy: float = h.y if corner & 2 else -h.y
		var sz: float = h.z if corner & 4 else -h.z
		p.append(c + Vector3(sx, sy, sz))
	var quads: Array = [
		[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]
	]
	var faces: Array = []
	for q: Array in quads:
		faces.append([p[q[0]], p[q[1]], p[q[2]]])
		faces.append([p[q[0]], p[q[2]], p[q[3]]])
	return faces


## Placeholder material carrying the NAME; [CarVisual] swaps it for the real one.
static func _named_material(material_name: String) -> StandardMaterial3D:
	if not _surface_materials.has(material_name):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.resource_name = material_name
		_surface_materials[material_name] = material
	return _surface_materials[material_name]
