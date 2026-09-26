class_name Serialization
extends RefCounted
## Stable, deterministic serialization helpers for logical state.
##
## Rules:
## - Only JSON-safe primitives are allowed: bool, int, float, String, Array,
##   Dictionary (String keys). StringName is normalized to String.
## - Dictionaries are canonicalized with sorted keys so two logically equal
##   values always produce byte-identical output regardless of insertion order.
## - Integral floats are normalized to int. JSON has a single number type and
##   Godot's JSON parser returns floats for every number, so this convention is
##   what keeps serialized roundtrips logically stable (2 and 2.0 are the same
##   logical value in the serialized contract).
## - No presentation or engine-object types (Node, Resource, Vector2, ...).

const MAX_EXACT_INT_AS_FLOAT := 9007199254740992.0  # 2^53
##
## This is the stable comparable representation used by roundtrip tests and
## future save/replay/solver conversion. Logical hashing is a milestone M6
## concern (blueprint §22) and is intentionally not implemented here.

const SUPPORTED_TYPES := "bool, int, float, String, Array, Dictionary"


static func canonicalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			return _normalize_float(value)
		TYPE_STRING_NAME:
			return String(value)
		TYPE_DICTIONARY:
			return _canonicalize_dictionary(value)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			var items: Array = []
			for item in value:
				items.append(canonicalize(item))
			return items
		_:
			return null


static func to_json(value: Variant) -> String:
	return JSON.stringify(canonicalize(value))


static func from_json(json_text: String) -> Variant:
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return null
	return json.data


static func values_equal(left: Variant, right: Variant) -> bool:
	var a: Variant = canonicalize(left)
	var b: Variant = canonicalize(right)
	return _deep_equal(a, b)


static func is_primitive_tree(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item in value:
				if not is_primitive_tree(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value.keys():
				if typeof(key) != TYPE_STRING:
					return false
				if not is_primitive_tree(value[key]):
					return false
			return true
		_:
			return false


static func _canonicalize_dictionary(value: Dictionary) -> Dictionary:
	var pairs: Array = []
	for key in value.keys():
		pairs.append([String(key), key])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	var result := {}
	for pair in pairs:
		result[pair[0]] = canonicalize(value[pair[1]])
	return result


static func _normalize_float(value: float) -> Variant:
	if is_finite(value) and abs(value) <= MAX_EXACT_INT_AS_FLOAT and value == floor(value):
		return int(value)
	return value


static func _deep_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	match typeof(a):
		TYPE_DICTIONARY:
			if a.size() != b.size():
				return false
			for key in a.keys():
				if not b.has(key):
					return false
				if not _deep_equal(a[key], b[key]):
					return false
			return true
		TYPE_ARRAY:
			if a.size() != b.size():
				return false
			for index in a.size():
				if not _deep_equal(a[index], b[index]):
					return false
			return true
		_:
			return a == b
