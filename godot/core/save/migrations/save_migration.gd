class_name SaveMigration
extends RefCounted
## One migration step of a save format: `data` of version N -> version N + 1.
##
## How to add one (see `example_v1_to_v2.gd`):
## 1. Create `core/save/migrations/<schema>_v<N>_to_v<N+1>.gd` extending this class.
## 2. Register it in [constant Migrations.REGISTRY] and bump the current version.
## 3. Add a golden file of version N in `tests/fixtures/saves/` and a test.


## Version this step reads.
func from_version() -> int:
	return 0


## Returns the migrated data. Must not fail: fill new fields with defaults.
func migrate(data: Dictionary) -> Dictionary:
	return data
