extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1290, 720)
	var grid := load("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
	await process_frame
	var hud := grid.top_capture_hud
	assert(hud != null)
	assert(grid.turn_order.size() == 8)
	assert(hud.progress_row.global_position.y > hud.player_points_container.global_position.y)
	assert(hud.progress_row.global_position.y > hud.enemy_points_container.global_position.y)
	assert(hud.progress_row.size.x >= hud.panel.size.x - 24.0)
	assert(hud.player_label.global_position.x < hud.enemy_label.global_position.x)
	assert(hud.enemy_label.global_position.x + hud.enemy_label.size.x <= hud.panel.global_position.x + hud.panel.size.x)
	assert(hud.round_label.global_position.y - hud.panel.global_position.y < 16.0)
	_assert_window(hud, grid, 0, 0, 4, 0, 4)
	_assert_window(hud, grid, 4, 3, 7, 3, 1)
	_assert_window(hud, grid, 7, 4, 8, 4, 0)
	grid.queue_free()
	print("PASS: full-width capture progress sits below the scores and turn order shows four units with hidden counts")
	quit()


func _assert_window(hud: TopCaptureHUD, grid: GridField, turn: int, first: int, last: int, previous: int, later: int) -> void:
	grid.turn_index = turn
	grid.active_unit = grid.turn_order[turn]
	hud._process(0.0)
	var visible_count := 0
	for i in range(hud.unit_order_nodes.size()):
		var visible: bool = hud.unit_order_nodes[i].panel.visible
		assert(visible == (i >= first and i < last))
		if visible:
			visible_count += 1
	assert(visible_count == 4)
	assert(hud.previous_count_label.visible == (previous > 0))
	assert(hud.later_count_label.visible == (later > 0))
	assert(hud.previous_count_label.text == "+%d" % previous)
	assert(hud.later_count_label.text == "+%d" % later)
