extends "res://tests/framework/test_base.gd"
## Project bootstrap test: the Godot project must be well-formed for M0.


func run() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://project.godot")
	check_eq(err, OK, "project.godot parses as config file")
	if err != OK:
		return

	check_eq(
		str(cfg.get_value("application", "config/name", "")),
		"Puzzle Factory",
		"application/config/name"
	)
	var icon_path := str(cfg.get_value("application", "config/icon", ""))
	check(icon_path.begins_with("res://"), "project icon configured")
	check(FileAccess.file_exists(icon_path), "project icon file exists")
	check_eq(
		str(cfg.get_value("application", "run/main_scene", "")),
		"res://boot/boot.tscn",
		"main scene is the M0 boot scene"
	)

	var features: PackedStringArray = cfg.get_value(
		"application", "config/features", PackedStringArray()
	)
	check(features.has("4.7"), "project pinned to Godot 4.7 feature tag")

	check_eq(
		int(cfg.get_value("display", "window/handheld/orientation", -1)),
		1,
		"handheld orientation is portrait (1)"
	)
	check_eq(
		int(cfg.get_value("display", "window/size/viewport_width", 0)),
		1080,
		"portrait viewport width"
	)
	check_eq(
		int(cfg.get_value("display", "window/size/viewport_height", 0)),
		1920,
		"portrait viewport height"
	)

	var main_scene_path := str(cfg.get_value("application", "run/main_scene", ""))
	check(FileAccess.file_exists(main_scene_path), "main scene file exists on disk")

	var packed: Variant = load(main_scene_path)
	check(packed is PackedScene, "main scene loads as PackedScene")
	if packed is PackedScene:
		var instance: Node = packed.instantiate()
		check(instance != null, "main scene instantiates")
		if instance != null:
			check(
				_contains_label(instance, "Puzzle Factory"),
				"boot screen displays the 'Puzzle Factory' placeholder title"
			)
			instance.free()

	var presets_ok := FileAccess.file_exists("res://export_presets.cfg")
	check(presets_ok, "export_presets.cfg present (Android Debug configured)")


func _contains_label(node: Node, expected_text: String) -> bool:
	if node is Label and node.text == expected_text:
		return true
	for child: Node in node.get_children():
		if _contains_label(child, expected_text):
			return true
	return false
