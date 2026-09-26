extends RefCounted
## ColorKey -> (color + symbol) resolution for the Traffic theme.
##
## Logical identity is symbol-backed (blueprint §14, §59): gameplay uses stable
## keys such as COLOR_A, never literal names like BLUE or RED. Unknown keys fall
## back to a neutral color and the fallback symbol so presentation never breaks,
## and matching never depends on hue alone.

const SYMBOL_CIRCLE := &"circle"
const SYMBOL_TRIANGLE := &"triangle"
const SYMBOL_SQUARE := &"square"
const SYMBOL_STAR := &"star"

const FALLBACK_SYMBOL := SYMBOL_CIRCLE
const FALLBACK_COLOR := Color(0.42, 0.45, 0.52, 1.0)

## Placeholder design colors. These are presentation values, not gameplay ids.
const DEFAULT_ENTRIES := {
	&"COLOR_A": {"color": Color(0.24, 0.47, 0.90, 1.0), "symbol": &"circle"},
	&"COLOR_B": {"color": Color(0.95, 0.63, 0.13, 1.0), "symbol": &"triangle"},
	&"COLOR_C": {"color": Color(0.60, 0.33, 0.86, 1.0), "symbol": &"square"},
	&"COLOR_D": {"color": Color(0.13, 0.68, 0.60, 1.0), "symbol": &"star"},
}

var _entries: Dictionary = {}


func _init(entries: Dictionary = {}) -> void:
	if entries.is_empty():
		_entries = DEFAULT_ENTRIES.duplicate(true)
	else:
		_entries = entries.duplicate(true)


func has_key(color_key: StringName) -> bool:
	return _entries.has(color_key)


func color_for(color_key: StringName) -> Color:
	if _entries.has(color_key):
		return _entries[color_key]["color"]
	return FALLBACK_COLOR


func symbol_for(color_key: StringName) -> StringName:
	if _entries.has(color_key):
		var symbol: Variant = _entries[color_key].get("symbol", FALLBACK_SYMBOL)
		if symbol != null:
			return symbol
	return FALLBACK_SYMBOL


func all_keys() -> Array:
	var keys: Array = _entries.keys()
	keys.sort()
	return keys


func entry_count() -> int:
	return _entries.size()
