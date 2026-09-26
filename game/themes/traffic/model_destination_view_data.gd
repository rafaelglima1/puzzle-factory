extends RefCounted
## Presentation-only view data for a destination/station (Traffic theme).
##
## Display only: accepted keys, capacity pips and queue tokens are shown as
## supplied. No acceptance, capacity or queue decision is made here
## (blueprint §8.2, ADR-003).

var id: StringName = &""
var destination_type: StringName = &"station"
var accepted_color_keys: Array[StringName] = []
var capacity: int = 0
var occupancy: int = 0
var queue_color_keys: Array[StringName] = []
var state: StringName = &"open"
var cell: Vector2i = Vector2i.ZERO
var footprint: Vector2i = Vector2i(2, 2)
var metadata: Dictionary = {}


func _init(p_id: StringName = &"") -> void:
	id = p_id


func accepted_symbol_count() -> int:
	return accepted_color_keys.size()
