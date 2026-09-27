extends RefCounted
## DEV-ONLY M6 Generator Lab plain-data contract.
##
## The presentation-side boundary for generation-engine output. Cross-integration
## adapts AGENT-1's generator/difficulty/solver/dedupe results into these flat,
## JSON-safe shapes. Nothing from the generator/solver/levels/core is imported:
## only primitives, dictionaries and arrays cross the boundary.
##
## Every entry point is a lenient static normalizer; malformed or partial input
## must never crash a debug surface.

const LevelContract := preload("res://themes/traffic/dev/m5/level_lab_contract.gd")

const BUCKETS: Array[String] = ["EASY", "MEDIUM", "HARD", "EXPERT"]


## Upper-cases and validates a difficulty bucket; unknown -> "UNKNOWN".
static func normalize_bucket(value: Variant) -> String:
	var text := str(value).to_upper()
	if BUCKETS.has(text):
		return text
	return "UNKNOWN"


static func normalize_generation(raw: Variant) -> Dictionary:
	var constraints: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		var source: Dictionary = raw
		var value: Variant = source.get("constraints", source)
		if typeof(value) == TYPE_DICTIONARY:
			constraints = _as_dictionary(value)
	return {"constraints": constraints}


static func normalize_difficulty(raw: Variant) -> Dictionary:
	var score := 0.0
	var bucket := "UNKNOWN"
	var components: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		var source: Dictionary = raw
		score = clampf(_read_float(source, ["score", "difficulty", "value"], 0.0), 0.0, 1.0)
		bucket = normalize_bucket(_read_value(source, ["bucket", "tier"]))
		var parts: Variant = _read_value(source, ["components", "parts", "weights"])
		if typeof(parts) == TYPE_DICTIONARY:
			var raw_parts: Dictionary = parts
			for key: Variant in raw_parts.keys():
				components[str(key)] = float(raw_parts[key])
	return {"score": score, "bucket": bucket, "components": components}


static func normalize_dedupe(raw: Variant) -> Dictionary:
	var fingerprint := ""
	var duplicate := false
	var of := ""
	if typeof(raw) == TYPE_DICTIONARY:
		var source: Dictionary = raw
		fingerprint = _read_string(source, ["fingerprint", "hash", "hash_id"], "")
		duplicate = _read_bool(source, ["duplicate", "is_duplicate"], false)
		of = _read_string(source, ["of", "duplicate_of", "original"], "")
	return {"fingerprint": fingerprint, "duplicate": duplicate, "of": of}


static func normalize_decision(raw: Variant) -> Dictionary:
	var status := ""
	var reasons: Array = []
	if typeof(raw) == TYPE_BOOL:
		status = "ACCEPTED" if raw else "REJECTED"
	elif typeof(raw) == TYPE_DICTIONARY:
		var source: Dictionary = raw
		var explicit := _read_string(source, ["status", "decision", "result"], "").to_upper()
		if explicit == "ACCEPTED" or explicit == "REJECTED":
			status = explicit
		else:
			var has_accept: bool = source.has("accepted") or source.has("valid")
			var accepted: bool = _read_bool(source, ["accepted", "valid"], false)
			if has_accept:
				status = "ACCEPTED" if accepted else "REJECTED"
		var raw_reasons: Variant = _read_value(source, ["reasons", "rejection_reasons"])
		if typeof(raw_reasons) == TYPE_ARRAY:
			for entry: Variant in raw_reasons:
				reasons.append(str(entry))
	return {"status": status, "reasons": reasons}


static func normalize_candidate(raw: Dictionary) -> Dictionary:
	var source: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var candidate_id := _read_string(source, ["candidate_id", "id", "candidateId"], "")
	var seed := _read_int(source, ["seed"], 0)
	var preview_raw: Variant = _read_value(source, ["preview", "level", "level_preview"])
	var preview: Dictionary = LevelContract.normalize_preview(
		preview_raw if typeof(preview_raw) == TYPE_DICTIONARY else {}
	)
	var validation: Dictionary = LevelContract.normalize_validation(_read_value(source, ["validation"]))
	var solver: Dictionary = LevelContract.normalize_solver(_read_value(source, ["solver"]))
	return {
		"candidate_id": candidate_id,
		"seed": seed,
		"preview": preview,
		"generation": normalize_generation(_read_value(source, ["generation", "constraints"])),
		"validation": validation,
		"solver": solver,
		"difficulty": normalize_difficulty(_read_value(source, ["difficulty"])),
		"dedupe": normalize_dedupe(_read_value(source, ["dedupe"])),
		"decision": normalize_decision(_read_value(source, ["decision"])),
	}


static func normalize_batch(raw: Variant) -> Dictionary:
	var buckets: Dictionary = {}
	var generated := 0
	var invalid := 0
	var unsolvable := 0
	var duplicates := 0
	var accepted := 0
	if typeof(raw) == TYPE_DICTIONARY:
		var source: Dictionary = raw
		generated = _read_int(source, ["generated", "total"], 0)
		invalid = _read_int(source, ["invalid", "invalid_count"], 0)
		unsolvable = _read_int(source, ["unsolvable", "unsolvable_count"], 0)
		duplicates = _read_int(source, ["duplicates", "duplicate_count"], 0)
		accepted = _read_int(source, ["accepted", "accepted_count"], 0)
		var raw_buckets: Variant = _read_value(source, ["buckets", "histogram", "difficulty_buckets"])
		if typeof(raw_buckets) == TYPE_DICTIONARY:
			var source_buckets: Dictionary = raw_buckets
			for key: Variant in source_buckets.keys():
				buckets[normalize_bucket(key)] = int(source_buckets[key])
	return {
		"generated": generated,
		"invalid": invalid,
		"unsolvable": unsolvable,
		"duplicates": duplicates,
		"accepted": accepted,
		"buckets": buckets,
	}


# --- internal helpers (lenient readers) -------------------------------------

static func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		return source.duplicate(true)
	return {}


static func _read_value(source: Dictionary, keys: Array) -> Variant:
	for key: Variant in keys:
		var key_string: String = str(key)
		if source.has(key_string):
			return source[key_string]
	return null


static func _read_int(source: Dictionary, keys: Array, default_value: int = 0) -> int:
	var value: Variant = _read_value(source, keys)
	var value_type: int = typeof(value)
	if value_type == TYPE_INT:
		return int(value)
	if value_type == TYPE_FLOAT:
		return int(value)
	if value_type == TYPE_BOOL:
		return 1 if value else 0
	if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
		var text: String = str(value)
		if text.is_valid_int():
			return text.to_int()
	return default_value


static func _read_float(source: Dictionary, keys: Array, default_value: float = 0.0) -> float:
	var value: Variant = _read_value(source, keys)
	var value_type: int = typeof(value)
	if value_type == TYPE_FLOAT:
		return float(value)
	if value_type == TYPE_INT:
		return float(value)
	if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
		var text: String = str(value)
		if text.is_valid_float():
			return text.to_float()
	return default_value


static func _read_string(source: Dictionary, keys: Array, default_value: String = "") -> String:
	var value: Variant = _read_value(source, keys)
	var value_type: int = typeof(value)
	if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
		return str(value)
	if value_type == TYPE_INT or value_type == TYPE_FLOAT or value_type == TYPE_BOOL:
		return str(value)
	return default_value


static func _read_bool(source: Dictionary, keys: Array, default_value: bool = false) -> bool:
	var value: Variant = _read_value(source, keys)
	var value_type: int = typeof(value)
	if value_type == TYPE_BOOL:
		return bool(value)
	if value_type == TYPE_INT or value_type == TYPE_FLOAT:
		return int(value) != 0
	if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
		var text: String = str(value).to_lower()
		return text == "true" or text == "1" or text == "yes"
	return default_value
