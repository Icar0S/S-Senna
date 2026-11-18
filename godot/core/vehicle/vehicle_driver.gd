class_name VehicleDriver
extends RefCounted
## Who drives a [Vehicle]: fills [VehicleInput] every physics step.
## [PlayerDriver] reads a player's controls; the AIDriver (Etapa 11) and the
## tests' scripted drivers extend this too.


## Fills [param input] for this step.
func drive(_input: VehicleInput, _delta: float, _vehicle: Vehicle) -> void:
	pass
