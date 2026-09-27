extends Node
## M5 CROSS-INTEGRATION dev app — OWNER: M5-INTEGRATOR.
##
## Boots AGENT-2's Level Lab from the REAL official content pack by wiring the
## integration controller. This is a DEV-ONLY scene: it is not `run/main_scene`
## and is not reachable from production navigation. Open it manually
## (`res://integration/traffic/dev/m5/traffic_level_lab_app.tscn`) or run it
## headless for debugging.

const ControllerScript := preload("res://integration/traffic/dev/m5/traffic_level_lab_controller.gd")
const LabScript := preload("res://themes/traffic/dev/m5/level_lab.gd")

var _lab: Variant = null
var _controller: Variant = null


func _ready() -> void:
	_lab = LabScript.new()
	_lab.name = "LevelLab"
	add_child(_lab)
	_lab.call("build")
	_lab.call("layout_for", get_viewport().get_visible_rect().size)

	_controller = ControllerScript.new(_lab)
	if not _controller.call("is_enabled"):
		push_warning("TrafficLevelLabApp: debug gate is off; no content loaded")
		return
	var loaded := int(_controller.call("load_official_levels"))
	if loaded == 0:
		push_error("TrafficLevelLabApp: no official levels loaded")
		return
	_controller.call("feed_lab")
	_controller.call("prepare_playback")
	_controller.call("refresh_visual_state")
	print("TrafficLevelLabApp: loaded %d official levels" % loaded)


func _on_viewport_resized() -> void:
	if _lab != null:
		_lab.call("layout_for", get_viewport().get_visible_rect().size)
