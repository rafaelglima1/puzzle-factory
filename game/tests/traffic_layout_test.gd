extends "res://tests/framework/test_base.gd"
## Responsive layout and board-scaling tests. Headless: no viewport required.

const LayoutFit := preload("res://ui/layout_fit.gd")
const BoardView := preload("res://themes/traffic/components/board_view.gd")
const HudShell := preload("res://themes/traffic/components/hud_shell.gd")
const StagingView := preload("res://themes/traffic/components/staging_view.gd")
const StagingData := preload("res://themes/traffic/model_staging_view_data.gd")
const Mock := preload("res://themes/traffic/dev/mock_presentation_state.gd")


func run() -> void:
	_test_board_fit()
	_test_board_view_scales()
	_test_staging_recut()
	_test_hud_chips()
	_test_sandbox_builds()


func _test_board_fit() -> void:
	var cells := Vector2i(8, 10)
	var ratio := 8.0 / 10.0
	var r16 := LayoutFit.fit_board_rect(Vector2(1080, 1920), cells)
	check(is_equal_approx(r16.size.x / r16.size.y, ratio), "16:9 board ratio preserved")
	check(r16.size.x <= 1080.0 and r16.size.y <= 1920.0, "16:9 board fits inside available")
	var r20 := LayoutFit.fit_board_rect(Vector2(1080, 2400), cells)
	check(is_equal_approx(r20.size.y, r16.size.y), "20:9 keeps cell size and adds vertical margin")
	check(r20.position.y > r16.position.y, "20:9 centres the board with extra margin")
	var tablet := LayoutFit.fit_board_rect(Vector2(1600, 2560), cells, 0.0, 720.0)
	check(tablet.size.x <= 720.0 + 0.001, "tablet board width is capped")
	check(is_equal_approx(tablet.position.x, (1600.0 - tablet.size.x) * 0.5), "tablet board is centred")
	var margined := LayoutFit.fit_board_rect(Vector2(1080, 1920), cells, 24.0)
	check(margined.size.x <= 1080.0 - 48.0 + 0.001, "margin respected on both sides")


func _test_board_view_scales() -> void:
	var board = BoardView.new()
	board.set_board_data(Mock.sample_board())
	check_eq(board.entity_view_count(), 4, "board builds one entity view per supplied entity")
	check_eq(board.destination_view_count(), 1, "board builds destination views")
	var rect = board.layout_for_size(Vector2(1080, 1920))
	check(rect.size.x > 0.0 and rect.size.y > 0.0, "board layout produces a rect")
	check(is_equal_approx(rect.size.x / rect.size.y, 8.0 / 10.0), "board keeps the supplied cell ratio")
	var entity = board.entity_view(&"e_compact_a")
	check(entity != null, "board exposes an entity view by id")
	if entity != null:
		check(entity.position.x > 0.0 and entity.position.y > 0.0, "entity positioned from its supplied cell")
	var tall = board.layout_for_size(Vector2(1080, 2400))
	check(tall.size.y >= rect.size.y, "board size is stable or grows on a taller viewport")
	board.free()


func _test_staging_recut() -> void:
	var staging = StagingView.new()
	staging.set_staging_data(StagingData.new(2))
	check_eq(staging.slot_count(), 2, "two slots rendered")
	staging.set_staging_data(StagingData.new(8))
	check_eq(staging.slot_count(), 8, "eight slots rendered after recut")
	staging.free()


func _test_hud_chips() -> void:
	var hud = HudShell.new()
	hud.set_objective_chips([&"COLOR_A", &"COLOR_B", &"COLOR_D"])
	check_eq(hud.chip_count(), 3, "objective chips created")
	check_eq(hud.chip_color_keys(), [&"COLOR_A", &"COLOR_B", &"COLOR_D"], "chip keys preserved")
	hud.set_objective_chips([])
	check_eq(hud.chip_count(), 0, "chips cleared")
	hud.free()


func _test_sandbox_builds() -> void:
	var packed: Variant = load("res://themes/traffic/dev/traffic_sandbox.tscn")
	check(packed is PackedScene, "sandbox scene loads as a PackedScene")
	if not (packed is PackedScene):
		return
	var sandbox: Node = packed.instantiate()
	check(sandbox != null, "sandbox instantiates")
	if sandbox == null:
		return
	sandbox.build()
	sandbox.layout_for(Vector2(1080, 2400))
	check(sandbox.board_view != null, "sandbox builds the board view")
	check(sandbox.staging_view != null, "sandbox builds the staging view")
	check(sandbox.hud_shell != null, "sandbox builds the HUD shell")
	check(sandbox.get_node_or_null("BoardView") != null, "board view is present in the sandbox tree")
	check(sandbox.demo_select(&"e_compact_a"), "sandbox select hook works")
	check(sandbox.demo_match(&"e_compact_a"), "sandbox match hook works")
	sandbox.free()
