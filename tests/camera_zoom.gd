extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1290, 720)
	var grid := load("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
	await process_frame
	assert(is_instance_valid(grid.active_unit))
	assert(is_equal_approx(grid.top_capture_hud.panel.global_position.x, 20.0))
	assert(grid.top_capture_hud.turn_order_row.global_position.x + grid.top_capture_hud.turn_order_row.size.x <= grid.top_capture_hud.panel.global_position.x + grid.top_capture_hud.panel.size.x)
	assert(grid.top_capture_hud.status_label.global_position.y + grid.top_capture_hud.status_label.size.y <= grid.top_capture_hud.panel.global_position.y + grid.top_capture_hud.panel.size.y)
	assert(grid.team_health_hud.global_position.y >= grid.top_capture_hud.panel.global_position.y + grid.top_capture_hud.panel.size.y)
	assert(is_equal_approx(grid.team_health_hud.global_position.y, (grid.get_node("CanvasLayer/EnemyTeamHealthHUD") as TeamHealthHUD).global_position.y))
	_assert_focus_centered(grid)
	_assert_background_aligned(grid)
	assert(grid.get_camera_attack_range(grid.player_units[0]) == 3)
	assert(grid.get_camera_attack_range(grid.player_units[1]) == 9)
	assert(grid.get_camera_attack_range(grid.player_units[2]) == 5)
	assert(grid.get_camera_attack_range(grid.player_units[3]) == 9)
	assert(is_equal_approx(grid.scale.x, 720.0 / (10.0 * GridField.TILE_SIZE)))
	var original_scale := 720.0 * GridField.ORIGINAL_BOARD_HEIGHT_RATIO / (GridField.HEIGHT * GridField.TILE_SIZE)
	grid.force_full_board_zoom = true
	grid.update_board_layout()
	assert(grid.top_capture_hud.panel.global_position.x + grid.top_capture_hud.panel.size.x < grid.to_global(Vector2.ZERO).x)
	assert(is_equal_approx(grid.get_camera_board_scale(root.get_visible_rect().size), original_scale))
	assert(grid.get_camera_target_position() == Vector2(GridField.WIDTH, GridField.HEIGHT) * GridField.TILE_SIZE / 2.0)
	grid.force_full_board_zoom = false
	assert(is_equal_approx(grid.get_camera_board_scale(root.get_visible_rect().size), 720.0 / (10.0 * GridField.TILE_SIZE)))
	for unit in [grid.player_units[2], grid.player_units[3]]:
		grid.active_unit = unit
		grid.update_board_layout()
		_assert_focus_centered(grid)
		assert(is_equal_approx(grid.scale.x, original_scale))
		if unit == grid.player_units[3]:
			assert(grid.get_camera_target_position() == Vector2(GridField.WIDTH, GridField.HEIGHT) * GridField.TILE_SIZE / 2.0)
	grid.active_unit = grid.player_units[1]
	grid.active_skill = null
	grid.update_board_layout()
	assert(is_equal_approx(grid.scale.x, original_scale))
	var board_center := Vector2(GridField.WIDTH, GridField.HEIGHT) * GridField.TILE_SIZE / 2.0
	assert(grid.to_global(board_center).distance_to(root.get_visible_rect().size / 2.0) < 0.01)
	assert(grid.to_global(Vector2.ZERO).y >= 0.0)
	assert(grid.to_global(Vector2(0, GridField.HEIGHT * GridField.TILE_SIZE)).y <= root.get_visible_rect().size.y)
	for skill in grid.active_unit.skills:
		grid.active_skill = skill
		assert(is_equal_approx(grid.get_camera_board_scale(root.get_visible_rect().size), original_scale))
		assert(grid.get_camera_target_position() == board_center)
	grid.active_skill = null
	assert(grid.get_camera_target_position() == board_center)
	grid.free_movement = true
	grid.move_unit(grid.active_unit, Vector2i(4, 8))
	assert(grid.active_unit.grid_position == Vector2i(4, 8))
	assert(not grid.camera_move_pending)
	grid.active_unit = grid.player_units[0]
	grid.update_board_layout()
	grid.active_unit.position = Vector2(32, 32)
	var distance_before_follow := grid.to_global(grid.active_unit.position).distance_to(root.get_visible_rect().size / 2.0)
	await process_frame
	await process_frame
	var distance_after_follow := grid.to_global(grid.active_unit.position).distance_to(root.get_visible_rect().size / 2.0)
	assert(distance_after_follow > 0.0 and distance_after_follow < distance_before_follow)
	grid.update_board_layout()
	_assert_focus_centered(grid)
	_assert_background_aligned(grid)
	var unit_position := grid.active_unit.position
	grid.lead_camera_to_tile(grid.active_unit, Vector2i(1, 1))
	await process_frame
	assert(grid.active_unit.position == unit_position)
	assert(grid.camera_focus_position.distance_to(grid.camera_lead_position) < unit_position.distance_to(grid.camera_lead_position))
	grid.clear_camera_lead(grid.active_unit)
	grid.active_unit.grid_position = Vector2i(0, 0)
	grid.active_unit.position = Vector2(32, 32)
	grid.update_board_layout()
	grid.free_movement = true
	grid.move_unit(grid.active_unit, Vector2i(1, 1))
	await process_frame
	assert(grid.camera_move_pending and grid.active_unit.grid_position == Vector2i(0, 0))
	assert(grid.camera_focus_position.distance_to(Vector2(96, 96)) < Vector2(32, 32).distance_to(Vector2(96, 96)))
	await create_timer(0.2).timeout
	assert(not grid.camera_move_pending and grid.active_unit.grid_position == Vector2i(1, 1))
	assert(grid.get_node("DarkSpace/Fill").color.a == 1.0)
	root.size = Vector2i(800, 1000)
	grid.update_board_layout()
	_assert_focus_centered(grid)
	_assert_background_aligned(grid)
	var netplay := root.get_node("Netplay")
	netplay.mode = netplay.Mode.CLIENT
	grid.update_board_layout()
	_assert_focus_centered(grid)
	_assert_background_aligned(grid)
	assert(is_equal_approx(grid.rotation, PI))
	grid.active_unit = grid.enemy_units[1]
	grid.active_skill = grid.active_unit.skills[0]
	grid.update_board_layout()
	assert(grid.to_global(board_center).distance_to(root.get_visible_rect().size / 2.0) < 0.01)
	assert(is_equal_approx(grid.scale.x, root.get_visible_rect().size.y * GridField.ORIGINAL_BOARD_HEIGHT_RATIO / (GridField.HEIGHT * GridField.TILE_SIZE)))
	grid.active_skill = null
	netplay.mode = netplay.Mode.LOCAL
	grid.queue_free()
	print("PASS: camera follows movement and shows the full board throughout Huntress and Quagmire turns")
	quit()


func _assert_focus_centered(grid: GridField) -> void:
	var viewport_center := root.get_visible_rect().size / 2.0
	var target := grid.get_camera_target_position()
	assert(grid.to_global(target).distance_to(viewport_center) < 0.01)
	assert(grid.get_node("BackgroundLayer").transform == grid.transform)


func _assert_background_aligned(grid: GridField) -> void:
	var artwork := grid.get_node("BackgroundLayer/CavernBackground") as TextureRect
	var artwork_scale := artwork.size / GridField.BAKED_BACKGROUND_SIZE
	var board_origin_y := GridField.BAKED_BOARD_ORIGIN.y
	if artwork.flip_v:
		board_origin_y = GridField.BAKED_BACKGROUND_SIZE.y - GridField.BAKED_BOARD_ORIGIN.y - GridField.BAKED_BOARD_SIZE.y
	var baked_board_start := artwork.position + Vector2(GridField.BAKED_BOARD_ORIGIN.x, board_origin_y) * artwork_scale
	var baked_board_end := baked_board_start + GridField.BAKED_BOARD_SIZE * artwork_scale
	assert(baked_board_start.distance_to(Vector2.ZERO) < 0.01)
	assert(baked_board_end.distance_to(Vector2(GridField.WIDTH, GridField.HEIGHT) * GridField.TILE_SIZE) < 0.01)
