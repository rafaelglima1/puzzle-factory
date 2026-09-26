extends "res://tests/framework/test_base.gd"
## Architecture boundary check for the AGENT-2 presentation layer.
##
## Presentation must not import simulation/core, must not ship third-party
## binary assets, and must not leak dev mocks into reusable components
## (blueprint §8.2, ADR-003, §3).

const PRESENTATION_DIRS := [
	"res://themes/traffic",
	"res://ui",
	"res://audio",
	"res://haptics",
]

const FORBIDDEN_MARKERS := [
	"res://core/",
	"res://puzzle/",
	"res://levels/",
	"res://solver/",
	"res://generator/",
	"res://persistence/",
]

const BINARY_ASSET_EXTENSIONS := [
	".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp",
	".wav", ".ogg", ".mp3",
	".ttf", ".otf",
]

const DEV_MOCK_MARKER := "res://themes/traffic/dev/"


func run() -> void:
	var scripts := _collect(PRESENTATION_DIRS, [".gd"])
	check(scripts.size() >= 10, "presentation scripts discovered")

	var violations := 0
	for path: String in scripts:
		var text := _read(path)
		for marker: String in FORBIDDEN_MARKERS:
			if text.contains(marker):
				violations += 1
				check(false, "presentation file references simulation path '%s': %s" % [marker, path])
		if not path.contains("/dev/") and text.contains(DEV_MOCK_MARKER):
			violations += 1
			check(false, "reusable presentation file references dev mock: %s" % path)
	check_eq(violations, 0, "presentation layer has no simulation imports or mock leaks")

	var binaries := _collect(PRESENTATION_DIRS, BINARY_ASSET_EXTENSIONS)
	check_eq(binaries.size(), 0, "no downloaded/binary assets in presentation dirs (procedural placeholders only)")

	check(FileAccess.file_exists("res://themes/traffic/dev/traffic_sandbox.tscn"), "dev sandbox scene exists")
	check(FileAccess.file_exists("res://themes/traffic/bridge/presentation_event_router.gd"), "presentation bridge adapter exists")


func _collect(roots: Array, extensions: Array) -> Array:
	var files: Array = []
	for root: String in roots:
		_collect_dir(root, extensions, files)
	return files


func _collect_dir(path: String, extensions: Array, files: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_collect_dir(full, extensions, files)
		else:
			for extension: String in extensions:
				if entry.ends_with(extension):
					files.append(full)
					break
		entry = dir.get_next()
	dir.list_dir_end()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
