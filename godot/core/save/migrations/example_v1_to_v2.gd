class_name ExampleMigrationV1ToV2
extends SaveMigration
## TEMPLATE / EXAMPLE — not registered in [constant Migrations.REGISTRY].
##
## Shows the shape of a real migration and is exercised by the tests against the
## v1 golden file: renames `player_prefs.camera` to `player_prefs.camera_mode` and
## adds `wallet.tokens` (with a default), keeping every other field untouched.


func from_version() -> int:
	return 1


func migrate(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var prefs: Dictionary = result.get("player_prefs", {})
	if prefs.has("camera"):
		prefs["camera_mode"] = prefs["camera"]
		prefs.erase("camera")
	result["player_prefs"] = prefs
	var wallet: Dictionary = result.get("wallet", {})
	if not wallet.has("tokens"):
		wallet["tokens"] = 0
	result["wallet"] = wallet
	return result
