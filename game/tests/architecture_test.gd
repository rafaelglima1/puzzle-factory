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
