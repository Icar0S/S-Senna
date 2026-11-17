class_name SaveValues
extends RefCounted
## Small helpers shared by the save data classes.


## Recursively turns whole-number floats into ints. JSON brings every number back
## as float; free-form parts of a save (records, events...) are normalized so a
## save -> load -> save round trip produces the same data.
static func normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			if is_finite(number) and number == floorf(number) and absf(number) < 9.0e15:
				return int(number)
			return number
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key: Variant in value:
				result[key] = normalize(value[key])
			return result
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(normalize(item))
			return items
	return value


## A free-form object field: `{}` when missing or not an object.
static func dict_or_empty(value: Variant) -> Dictionary:
	return normalize(value) if value is Dictionary else {}


## Merges preserved unknown fields back into [param data] (known fields win).
static func with_extra(data: Dictionary, extra: Dictionary) -> Dictionary:
	for key: Variant in extra:
		if not data.has(key):
			data[key] = extra[key]
	return data


static func strings(value: PackedStringArray) -> Array:
	return Array(value)
