class_name PhysicsLab
extends RefCounted
## Headless driving lab: a huge flat floor, one [Vehicle] and a scripted driver.
## Runs physics faster than real time keeping the 1/120 s step: the tick rate and
## the time scale go up together (delta = time_scale / ticks).

const SPEEDUP: float = 8.0
const BASE_TICKS: int = 120
const FLOOR_SIZE: float = 6000.0

var root: Node3D = null
var vehicle: Vehicle = null
var driver: ScriptedDriver = null
var time: float = 0.0

var _tree: SceneTree = null
var _saved_ticks: int = 120
var _saved_scale: float = 1.0
var _saved_max_steps: int = 8


## Fills [VehicleInput] from a Callable `func(input: VehicleInput, vehicle: Vehicle, time: float)`.
class ScriptedDriver:
	extends VehicleDriver
	var program: Callable = Callable()
	var time: float = 0.0

	func drive(input: VehicleInput, delta: float, vehicle: Vehicle) -> void:
		time += delta
		if program.is_valid():
			program.call(input, vehicle, time)


func _init(tree: SceneTree, parent: Node) -> void:
	_tree = tree
	root = Node3D.new()
	root.name = "PhysicsLab"
	parent.add_child(root)
	var floor: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor.add_child(shape)
	root.add_child(floor)


## Spawns [param car_id] at [param position] (car resting slightly above the floor).
func spawn(
	car_id: String = "car:base/prototipo",
	position: Vector3 = Vector3(0.0, 0.05, -FLOOR_SIZE * 0.45),
	assists: Dictionary = {},
	config: CarConfig = null
) -> Vehicle:
	var car: CarDef = ContentDB.get_car(car_id)
	vehicle = Vehicle.create(car, config, assists)
	driver = ScriptedDriver.new()
	vehicle.driver = driver
	root.add_child(vehicle)
	vehicle.global_position = position
	return vehicle


func speed_up() -> void:
	_saved_ticks = Engine.physics_ticks_per_second
	_saved_scale = Engine.time_scale
	_saved_max_steps = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = int(BASE_TICKS * SPEEDUP)
	Engine.time_scale = SPEEDUP
	Engine.max_physics_steps_per_frame = 64


func restore() -> void:
	Engine.physics_ticks_per_second = _saved_ticks
	Engine.time_scale = _saved_scale
	Engine.max_physics_steps_per_frame = _saved_max_steps


## Runs physics for [param seconds] of simulated time, or until
## `stop.call(vehicle, time)` returns true. Returns the simulated time used.
func run(seconds: float, stop: Callable = Callable()) -> float:
	var started: float = time
	var step: float = 1.0 / BASE_TICKS
	while time - started < seconds:
		await _tree.physics_frame
		time += step
		if stop.is_valid() and stop.call(vehicle, time - started):
			break
	return time - started


func free_all() -> void:
	root.queue_free()
