class_name SaveScheduler
extends RefCounted
## Groups save requests: the first request of a profile opens a window of
## [member delay_ms]; requests inside it are merged into a single write.
## Time is passed in (milliseconds), so this is tested without waiting.

var delay_ms: int = 1000
var _due: Dictionary = {}


func request(profile_id: String, now_ms: int) -> void:
	if not _due.has(profile_id):
		_due[profile_id] = now_ms + delay_ms


## Profiles whose window has ended (they leave the queue).
func take_due(now_ms: int) -> PackedStringArray:
	var ready: PackedStringArray = []
	for profile_id: String in _due.keys():
		if int(_due[profile_id]) <= now_ms:
			ready.append(profile_id)
	for profile_id: String in ready:
		_due.erase(profile_id)
	return ready


## Every pending profile (used when the game closes).
func take_all() -> PackedStringArray:
	var all: PackedStringArray = []
	for profile_id: String in _due.keys():
		all.append(profile_id)
	_due.clear()
	return all


func is_pending(profile_id: String) -> bool:
	return _due.has(profile_id)


func has_pending() -> bool:
	return not _due.is_empty()
