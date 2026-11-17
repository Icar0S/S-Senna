class_name CarAssembler
extends RefCounted
## Builds a [CarVisual] from a car definition and a player configuration
## (doc 02 §6.2): model (cached by [ModelLoader]) -> classify nodes -> materials by
## name -> parts per slot -> wheels -> paint. Same code for game, garage and Studio.


## The car [param car] dressed with [param config] (stock when null). Returns null
## when the model can't be loaded.
static func build(
	car: CarDef, config: CarConfig = null, library: ContentLibrary = null
) -> CarVisual:
	var content: ContentLibrary = library if library != null else ContentDB.get_library()
	var model: Node3D = ModelLoader.load_model(car.model_path)
	if model == null:
		return null
	var visual: CarVisual = CarVisual.new()
	visual.setup(car, model, content)
	var shown: CarConfig = config if config != null else CarConfig.create_default(car, "showroom")
	visual.apply_config(shown)
	return visual


## Same as [method build], looking the car up by ID.
static func build_by_id(
	car_id: String, config: CarConfig = null, library: ContentLibrary = null
) -> CarVisual:
	var content: ContentLibrary = library if library != null else ContentDB.get_library()
	var car: CarDef = content.get_car(car_id)
	if car == null:
		return null
	return build(car, config, content)
