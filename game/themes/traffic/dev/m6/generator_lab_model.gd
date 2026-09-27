extends RefCounted
## DEV-ONLY M6 Generator Lab model: holds normalized candidate/batch shapes and
## projects a candidate preview onto Traffic presentation DTOs for debug
## rendering. Read-only; it never generates, solves or mutates gameplay.

const Contract := preload("res://themes/traffic/dev/m6/generator_lab_contract.gd")
const LevelModel := preload("res://themes/traffic/dev/m5/level_lab_model.gd")
const BoardData := preload("res://themes/traffic/model_board_view_data.gd")

var candidates: Array = []
var batch: Dictionary = {}
## "" means "all"; otherwise an exact bucket / decision match.
var filter_bucket: String = ""
var filter_decision: String = ""


func _init() -> void:
	clear()


func clear() -> void:
	candidates = []
	batch = Contract.normalize_batch({})
	filter_bucket = ""
	filter_decision = ""


func set_candidates(raw: Array) -> void:
	candidates = []
	for entry: Variant in raw:
		if typeof(entry) == TYPE_DICTIONARY:
			var source: Dictionary = entry
			candidates.append(Contract.normalize_candidate(source))


func set_batch(raw: Variant) -> void:
	batch = Contract.normalize_batch(raw)


func set_filter(bucket: String, decision: String) -> void:
	filter_bucket = bucket if bucket != "ALL" else ""
	filter_decision = decision if decision != "ALL" else ""


func total_count() -> int:
	return candidates.size()


func filtered_count() -> int:
	return filtered_indices().size()


## Absolute indices into `candidates` that match the current filter.
func filtered_indices() -> Array[int]:
	var result: Array[int] = []
	for index in candidates.size():
		var candidate: Dictionary = candidates[index]
		if not filter_bucket.is_empty() and str(candidate.get("difficulty", {}).get("bucket", "UNKNOWN")) != filter_bucket:
			continue
		var status: String = str(candidate.get("decision", {}).get("status", ""))
		if not filter_decision.is_empty() and status != filter_decision:
			continue
		result.append(index)
	return result


## Absolute-index access ({} when out of range).
func candidate_at(index: int) -> Dictionary:
	if index < 0 or index >= candidates.size():
		return {}
	var candidate: Dictionary = candidates[index]
	return candidate


func build_board_data(candidate: Dictionary) -> BoardData:
	var level_model = LevelModel.new()
	var preview: Variant = candidate.get("preview", {})
	level_model.load_preview(preview if typeof(preview) == TYPE_DICTIONARY else {})
	return level_model.build_board_data()


func preview_paths(candidate: Dictionary) -> Array:
	var level_model = LevelModel.new()
	var preview: Variant = candidate.get("preview", {})
	level_model.load_preview(preview if typeof(preview) == TYPE_DICTIONARY else {})
	return level_model.paths()


func histogram() -> Dictionary:
	var buckets: Variant = batch.get("buckets", {})
	if typeof(buckets) == TYPE_DICTIONARY:
		var source: Dictionary = buckets
		return source.duplicate(true)
	return {}


func batch_counts() -> Dictionary:
	return batch
