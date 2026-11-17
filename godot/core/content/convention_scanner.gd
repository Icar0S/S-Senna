class_name ConventionScanner
extends RefCounted
## Classifies the nodes of a car model (doc 03 §4.3, doc 04 §2): body and parts
## (`<slot>-<variant>`), sockets, wheel anchors, stock rim, collisions and fixed
## pieces; lists materials and counts triangles. Shared by the game and the Studio.
##
## Metadata written by the Blender add-on (glTF `extras`: `ss_role`, `ss_slot`,
## `ss_variant`) wins over the node name; the name is the fallback.

enum Role { PART, SOCKET, WHEEL, RIM, COLLISION, FIXED, UNKNOWN }

## Role names as written in metadata; must match `metadata_roles` in conventions.json.
const ROLE_NAMES: PackedStringArray = ["part", "socket", "wheel", "rim", "collision", "fixed"]
## Godot stores glTF `extras` in this node metadata entry.
const GLTF_EXTRAS_META: String = "extras"


## What [method classify] found for one node.
class Classification:
	extends RefCounted
	var role: Role = Role.UNKNOWN
	## Part: slot. Socket: socket name. Wheel: position (`FL`...).
	var slot: String = ""
	## Part, rim, fixed and collision: the text after the separator.
	var variant: String = ""
	## Why the node could not be classified ("" when it was).
	var problem: String = ""
	## True when the classification came from metadata.
	var from_metadata: bool = false


class ScanResult:
	extends RefCounted
	## Slot -> { variant -> Node3D } (the body is slot `body`).
	var parts: Dictionary = {}
	## Socket name -> Node3D.
	var sockets: Dictionary = {}
	## Socket name -> numeric metadata (`width_m`, `length_m`...).
	var socket_params: Dictionary = {}
	## Wheel position -> Node3D.
	var wheel_anchors: Dictionary = {}
	var rim: Node3D = null
	var collisions: Array[Node3D] = []
	## Name -> Node3D (e.g. `glass-stock`).
	var fixed: Dictionary = {}
	## Material name -> number of surfaces using it.
	var materials: Dictionary = {}
	## Classified node name -> triangles of its meshes (descendants included).
	var triangles: Dictionary = {}
	var total_triangles: int = 0
	## Problems found (pt-BR), e.g. unknown names or materials.
	var issues: PackedStringArray = []

	func has_part(slot: String, variant: String) -> bool:
		return parts.has(slot) and (parts[slot] as Dictionary).has(variant)

	func get_part(slot: String, variant: String) -> Node3D:
		if not has_part(slot, variant):
			return null
		return parts[slot][variant]

	## `<slot>-<variant>` names of all parts found, sorted.
	func part_names() -> PackedStringArray:
		var names: PackedStringArray = []
		for slot: String in parts:
			for variant: String in parts[slot]:
				names.append(slot + Conventions.name_separator() + variant)
		names.sort()
		return names


## Scans the descendants of [param root] (the root itself is the model's container).
static func scan(root: Node) -> ScanResult:
	var result: ScanResult = ScanResult.new()
	for child: Node in root.get_children():
		_scan_node(child, "", result)
	return result


## Classifies one node by its metadata or, if it has none, by its name.
static func classify(node: Node) -> Classification:
	var extras: Variant = node.get_meta(GLTF_EXTRAS_META, {})
	if extras is Dictionary and (extras as Dictionary).has(Conventions.metadata_key("role")):
		return _classify_metadata(extras, String(node.name))
	return classify_name(String(node.name))


## Classifies a node name such as `bumper_front-kit01`, `socket-spoiler` or `wheel-FL`.
static func classify_name(node_name: String) -> Classification:
	var result: Classification = Classification.new()
	var separator: String = Conventions.name_separator()
	var cut: int = node_name.find(separator)
	if cut <= 0 or cut == node_name.length() - 1:
		result.problem = "nome fora do padrão <tipo>%s<nome>: '%s'" % [separator, node_name]
		return result
	var prefix: String = node_name.substr(0, cut)
	var suffix: String = node_name.substr(cut + 1)
	if Conventions.is_slot(prefix):
		_set_role(result, Role.PART, prefix, suffix)
	elif prefix == Conventions.node_prefix("socket"):
		_set_role(result, Role.SOCKET, suffix, "")
	elif prefix == Conventions.node_prefix("wheel"):
		_set_role(result, Role.WHEEL, suffix, "")
	elif prefix == Conventions.node_prefix("rim"):
		_set_role(result, Role.RIM, "", suffix)
	elif prefix == Conventions.node_prefix("collision"):
		_set_role(result, Role.COLLISION, "", suffix)
	elif Conventions.fixed_prefixes().has(prefix):
		_set_role(result, Role.FIXED, prefix, suffix)
	else:
		result.problem = "prefixo desconhecido '%s' em '%s'" % [prefix, node_name]
	_validate(result, node_name)
	return result


static func _classify_metadata(extras: Dictionary, node_name: String) -> Classification:
	var result: Classification = Classification.new()
	result.from_metadata = true
	var role_name: String = str(extras.get(Conventions.metadata_key("role"), ""))
	var slot: String = str(extras.get(Conventions.metadata_key("slot"), ""))
	var variant: String = str(extras.get(Conventions.metadata_key("variant"), ""))
	var role_index: int = ROLE_NAMES.find(role_name)
	if role_index < 0:
		result.problem = "papel desconhecido '%s' na metadata de '%s'" % [role_name, node_name]
		return result
	# Missing metadata fields are taken from the name.
	var by_name: Classification = classify_name(node_name)
	if slot.is_empty() and by_name.role == role_index:
		slot = by_name.slot
	if variant.is_empty() and by_name.role == role_index:
		variant = by_name.variant
	_set_role(result, role_index as Role, slot, variant)
	_validate(result, node_name)
	return result


static func _set_role(result: Classification, role: Role, slot: String, variant: String) -> void:
	result.role = role
	result.slot = slot
	result.variant = variant


static func _validate(result: Classification, node_name: String) -> void:
	match result.role:
		Role.PART:
			if not Conventions.is_slot(result.slot) or result.variant.is_empty():
				result.problem = "peça sem slot válido ou sem variante: '%s'" % node_name
		Role.SOCKET:
			if not Conventions.is_socket(result.slot):
				result.problem = "soquete desconhecido '%s'" % result.slot
		Role.WHEEL:
			if not Conventions.wheel_positions().has(result.slot):
				result.problem = "posição de roda desconhecida '%s'" % result.slot
	if not result.problem.is_empty():
		result.role = Role.UNKNOWN


static func _scan_node(node: Node, owner_name: String, result: ScanResult) -> void:
	var node_name: String = String(node.name)
	var current_owner: String = owner_name
	if node is Node3D:
		if Conventions.has_forbidden_suffix(node_name):
			result.issues.append("nome termina com sufixo de importação do Godot: '%s'" % node_name)
		var info: Classification = classify(node)
		if info.role != Role.UNKNOWN:
			_record(node as Node3D, info, result)
			current_owner = node_name
		elif owner_name.is_empty() and not info.problem.is_empty():
			result.issues.append(info.problem)
	if node is MeshInstance3D:
		_record_mesh(node as MeshInstance3D, current_owner, result)
	for child: Node in node.get_children():
		_scan_node(child, current_owner, result)


static func _record(node: Node3D, info: Classification, result: ScanResult) -> void:
	match info.role:
		Role.PART:
			if not result.parts.has(info.slot):
				result.parts[info.slot] = {}
			if (result.parts[info.slot] as Dictionary).has(info.variant):
				result.issues.append("peça repetida: %s" % node.name)
			result.parts[info.slot][info.variant] = node
		Role.SOCKET:
			if result.sockets.has(info.slot):
				result.issues.append("soquete repetido: %s" % info.slot)
			result.sockets[info.slot] = node
			result.socket_params[info.slot] = _numeric_extras(node)
		Role.WHEEL:
			if result.wheel_anchors.has(info.slot):
				result.issues.append("âncora de roda repetida: %s" % info.slot)
			result.wheel_anchors[info.slot] = node
		Role.RIM:
			if result.rim != null:
				result.issues.append("mais de um aro original: %s" % node.name)
			result.rim = node
		Role.COLLISION:
			result.collisions.append(node)
		Role.FIXED:
			result.fixed[String(node.name)] = node


static func _record_mesh(mesh_node: MeshInstance3D, owner_name: String, result: ScanResult) -> void:
	var mesh: Mesh = mesh_node.mesh
	if mesh == null:
		return
	var triangle_count: int = mesh.get_faces().size() / 3
	result.total_triangles += triangle_count
	var key: String = owner_name if not owner_name.is_empty() else String(mesh_node.name)
	result.triangles[key] = int(result.triangles.get(key, 0)) + triangle_count
	for surface: int in mesh.get_surface_count():
		var material: Material = mesh_node.get_surface_override_material(surface)
		if material == null:
			material = mesh.surface_get_material(surface)
		var material_name: String = material.resource_name if material != null else ""
		if material_name.is_empty():
			result.issues.append("superfície sem material em '%s'" % mesh_node.name)
			continue
		if not Conventions.is_material_name(material_name):
			result.issues.append(
				"material fora do padrão '%s' em '%s'" % [material_name, mesh_node.name]
			)
		result.materials[material_name] = int(result.materials.get(material_name, 0)) + 1


static func _numeric_extras(node: Node) -> Dictionary:
	var params: Dictionary = {}
	var extras: Variant = node.get_meta(GLTF_EXTRAS_META, {})
	if extras is Dictionary:
		for key: Variant in extras:
			var value: Variant = extras[key]
			if value is float or value is int:
				params[str(key)] = float(value)
	return params
