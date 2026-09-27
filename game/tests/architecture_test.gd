extends "res://tests/framework/test_base.gd"
## Architecture guards for M1 (blueprint §8.1, §8.3, §78).
##
## Automated enforcement of two rules that are easy to break by accident:
## 1. Core/puzzle code must stay theme-independent and presentation-free.
## 2. Simulation must not depend on the scene tree.

const SCAN_ROOTS: Array[String] = ["res://core", "res://puzzle", "res://themes/base"]

## Theme vocabulary that must never appear in generic layers. Matched as whole
## words (case-insensitive) so legitimate words like "constraint" are safe.
const FORBIDDEN_TERMS: Array[String] = [
	"bus",
	"vehicle",
	"passenger",
	"airport",
	"train",
	"taxi",
	"ship",
	"warehouse",
	"traffic",
	"station",
	"luggage",
	"cargo",
	"forklift",
	"aircraft",
	"subway",
]

## Presentation/theme asset references that core must not reach into.
const FORBIDDEN_REFERENCES: Array[String] = [
	"res://themes/traffic",
	"res://ui/",
	"res://audio/",
	"res://haptics/",
	"game/themes/traffic",
]

var _files: Array[String] = []


func run() -> void:
	_collect_scripts()
	check(_files.size() >= 15, "core script set collected (%d files)" % _files.size())
	_no_theme_terminology()
	_no_presentation_references()
	_no_scene_tree_usage()
	_generic_layers_ignore_integration()
	_integration_layer_is_product_specific()
	_persistence_layer_is_product_free()
	_m5_platform_layers_are_product_free()
	_solver_layer_is_product_free()


func _collect_scripts() -> void:
	_files.clear()
	for root in SCAN_ROOTS:
		_collect_scripts_at(root)


func _collect_scripts_at(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd"):
			_files.append(path.path_join(file))
	for directory in DirAccess.get_directories_at(path):
		_collect_scripts_at(path.path_join(directory))


## Dependency direction: generic layers must not reach into the product
## integration layer (ADR-013). Integration may import both sides.
func _generic_layers_ignore_integration() -> void:
	var violations: Array[String] = []
	for file in _files:
		var text := FileAccess.get_file_as_string(file)
		if text.contains("res://integration") or text.contains("integration/traffic"):
			violations.append(file)
	check(violations.is_empty(), "generic layers do not depend on the product integration layer (%s)" % ", ".join(violations))


## The integration layer is where product vocabulary is allowed to live.
func _integration_layer_is_product_specific() -> void:
	var scripts := _collect_gd("res://integration/traffic")
	check(scripts.size() >= 2, "product integration layer exists (%d scripts)" % scripts.size())
	var mentions_product_terms := false
	for path: String in scripts:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("vehicle") or text.contains("passenger") or text.contains("station"):
			mentions_product_terms = true
	check(mentions_product_terms, "product integration layer owns the product vocabulary")


func _collect_gd(path: String) -> Array[String]:
	var scripts: Array[String] = []
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd"):
			scripts.append(path.path_join(file))
	for directory in DirAccess.get_directories_at(path):
		scripts.append_array(_collect_gd(path.path_join(directory)))
	return scripts


func _no_theme_terminology() -> void:
	var violations: Array[String] = []
	for file in _files:
		var text := FileAccess.get_file_as_string(file)
		for term in FORBIDDEN_TERMS:
			if _contains_word(text, term):
				violations.append("%s contains '%s'" % [file, term])
	check(violations.is_empty(), "generic layers contain no theme terminology (%s)" % ", ".join(violations))


func _no_presentation_references() -> void:
	var violations: Array[String] = []
	for file in _files:
		var text := FileAccess.get_file_as_string(file)
		for reference in FORBIDDEN_REFERENCES:
			if text.contains(reference):
				violations.append("%s references '%s'" % [file, reference])
	check(violations.is_empty(), "generic layers reference no presentation assets (%s)" % ", ".join(violations))


func _no_scene_tree_usage() -> void:
	var violations: Array[String] = []
	for file in _files:
		var text := FileAccess.get_file_as_string(file)
		if text.contains("extends Node") or text.contains("get_tree()") or text.contains("SceneTree"):
			violations.append(file)
	check(violations.is_empty(), "simulation code is scene-tree free (%s)" % ", ".join(violations))


func _contains_word(text: String, word: String) -> bool:
	var pattern := RegEx.new()
	if pattern.compile("(?i)\\b%s\\b" % word) != OK:
		return false
	return pattern.search(text) != null


## Persistence is generic infrastructure: product vocabulary belongs to the
## integration/theme layers, so `game/persistence/**` must stay product-free
## (M3 progress store included).
func _persistence_layer_is_product_free() -> void:
	var scripts := _collect_gd("res://persistence")
	check(scripts.size() >= 1, "persistence layer present (%d scripts)" % scripts.size())
	var violations: Array[String] = []
	for path: String in scripts:
		var text := FileAccess.get_file_as_string(path)
		for term in FORBIDDEN_TERMS:
			if _contains_word(text, term):
				violations.append("%s contains '%s'" % [path, term])
	check(violations.is_empty(), "persistence stays product-free (%s)" % ", ".join(violations))


## M5 content platform: `game/levels/**` is generic schema/loader/validator/
## migration/pack infrastructure and must stay product-free (no theme term) and
## must not reach into the product integration or content layers.
func _m5_platform_layers_are_product_free() -> void:
	var scripts := _collect_gd("res://levels")
	check(scripts.size() >= 6, "level platform present (%d scripts)" % scripts.size())
	var violations: Array[String] = []
	for path: String in scripts:
		var text := FileAccess.get_file_as_string(path)
		for term in FORBIDDEN_TERMS:
			if _contains_word(text, term):
				violations.append("%s contains '%s'" % [path, term])
		if text.contains("res://integration") or text.contains("res://content/"):
			violations.append("%s depends on product content/integration" % path)
	check(violations.is_empty(), "level platform stays product-free (%s)" % ", ".join(violations))


## M5 solver: `game/solver/**` is generic search over a domain adapter and must
## stay product-free, scene-tree-free and independent of theme/integration.
func _solver_layer_is_product_free() -> void:
	var scripts := _collect_gd("res://solver")
	check(scripts.size() >= 5, "solver present (%d scripts)" % scripts.size())
	var violations: Array[String] = []
	for path: String in scripts:
		var text := FileAccess.get_file_as_string(path)
		for term in FORBIDDEN_TERMS:
			if _contains_word(text, term):
				violations.append("%s contains '%s'" % [path, term])
		if text.contains("res://integration") or text.contains("res://themes") or text.contains("res://content/"):
			violations.append("%s depends on product/theme layer" % path)
		if text.contains("extends Node") or text.contains("get_tree()"):
			violations.append("%s uses the scene tree" % path)
	check(violations.is_empty(), "solver stays product-free and scene-tree-free (%s)" % ", ".join(violations))
