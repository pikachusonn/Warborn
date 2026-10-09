extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1290, 720)
	var grid := load("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
	await process_frame

	assert(is_instance_valid(grid.offscreen_hud))
	var offscreen_hud := grid.offscreen_hud

	# Verify event-driven idle state (NOT processing every frame when idle)
	assert(not offscreen_hud.is_processing())

	# Initially, check clusters exist
	assert(offscreen_hud.clusters.has(OffscreenHUD.Direction.LEFT))
	assert(offscreen_hud.clusters.has(OffscreenHUD.Direction.MIDDLE))
	assert(offscreen_hud.clusters.has(OffscreenHUD.Direction.RIGHT))

	# Test 1: Full-board zoom (Archer or Quagmire active)
	# When full-board camera is active, all 10x10 tiles are inside the viewport.
	grid.active_unit = grid.player_units[1] # Archer
	grid.update_board_layout()
	await process_frame
	await process_frame

	# All clusters should be hidden because no living units are off-screen
	var left_data: Dictionary = offscreen_hud.clusters[OffscreenHUD.Direction.LEFT]
	var mid_data: Dictionary = offscreen_hud.clusters[OffscreenHUD.Direction.MIDDLE]
	var right_data: Dictionary = offscreen_hud.clusters[OffscreenHUD.Direction.RIGHT]
	assert(not left_data["root"].visible)
	assert(not mid_data["root"].visible)
	assert(not right_data["root"].visible)

	# Test 2: Direction classification math relative to board span
	var board_left := 200.0
	var board_width := 1000.0 # spans 200 to 1200
	# Quagmire at column 1 (x ~ 300 -> norm ~ 0.10)
	assert(offscreen_hud._classify_direction(Vector2(300, -50), board_left, board_width) == OffscreenHUD.Direction.LEFT)
	# Breacher at column 3 (x ~ 500 -> norm ~ 0.30..0.35)
	assert(offscreen_hud._classify_direction(Vector2(550, -50), board_left, board_width) == OffscreenHUD.Direction.MIDDLE)
	# Archer at column 5 (x ~ 700 -> norm ~ 0.50)
	assert(offscreen_hud._classify_direction(Vector2(700, -50), board_left, board_width) == OffscreenHUD.Direction.MIDDLE)
	# Berserker at column 7 (x ~ 950 -> norm ~ 0.75) -> MUST be RIGHT, not MIDDLE
	assert(offscreen_hud._classify_direction(Vector2(950, -50), board_left, board_width) == OffscreenHUD.Direction.RIGHT)

	# Test 3: Overlap rules and Lane Groups
	var vp_size := Vector2(1290, 720)
	var board_right := board_left + board_width

	# Case A: 1 unit in Left (Quagmire)
	var dummy_left: Array[Unit] = [grid.enemy_units[3]] # Quagmire
	var dummy_pos_left: Array[Vector2] = [Vector2(300, -50)]
	offscreen_hud._update_cluster(OffscreenHUD.Direction.LEFT, dummy_left, dummy_pos_left, vp_size, board_left, board_right, board_width)
	assert(left_data["root"].visible)
	var left_cards: Control = left_data["cards_holder"]
	assert(left_cards.get_child_count() == 1)
	assert((left_cards.get_child(0) as Control).position.x == 0.0)
	assert((left_data["arrow"] as Label).text == "▲")

	# Case B: Exactly 2 units in Middle (Breacher + Archer)
	var dummy_mid: Array[Unit] = [grid.enemy_units[0], grid.enemy_units[1]] # Breacher, Archer
	var dummy_pos_mid: Array[Vector2] = [Vector2(550, -50), Vector2(700, -50)]
	offscreen_hud._update_cluster(OffscreenHUD.Direction.MIDDLE, dummy_mid, dummy_pos_mid, vp_size, board_left, board_right, board_width)
	assert(mid_data["root"].visible)
	var mid_cards: Control = mid_data["cards_holder"]
	assert(mid_cards.get_child_count() == 2)
	var card0 := mid_cards.get_child(0) as Control
	var card1 := mid_cards.get_child(1) as Control
	assert(card0.position.x == 0.0)
	# 40% overlap means offset is 60% of CARD_SIZE.x (38 * 0.6 = 22.8)
	assert(is_equal_approx(card1.position.x, 22.8))
	assert(card1.z_index == 1)
	assert((mid_data["arrow"] as Label).text == "▲")

	# Case C: Exactly 1 unit in Right (Berserker)
	var dummy_right: Array[Unit] = [grid.enemy_units[2]] # Berserker
	var dummy_pos_right: Array[Vector2] = [Vector2(950, -50)]
	offscreen_hud._update_cluster(OffscreenHUD.Direction.RIGHT, dummy_right, dummy_pos_right, vp_size, board_left, board_right, board_width)
	assert(right_data["root"].visible)
	var right_cards: Control = right_data["cards_holder"]
	assert(right_cards.get_child_count() == 1)
	assert((right_cards.get_child(0) as Control).position.x == 0.0)
	assert((right_data["arrow"] as Label).text == "▲")

	# Case D: More than 2 units in Middle (e.g. 4 units) shows 1 card + 1 "+3" badge
	var dummy_units4: Array[Unit] = [grid.enemy_units[0], grid.enemy_units[1], grid.player_units[2], grid.player_units[3]]
	var dummy_pos4: Array[Vector2] = [Vector2(500, -50), Vector2(600, -50), Vector2(700, -50), Vector2(800, -50)]
	offscreen_hud._update_cluster(OffscreenHUD.Direction.MIDDLE, dummy_units4, dummy_pos4, vp_size, board_left, board_right, board_width)
	assert(mid_data["root"].visible)
	assert(mid_cards.get_child_count() == 2)
	card0 = mid_cards.get_child(0) as Control
	var badge := mid_cards.get_child(1) as Control
	assert(card0.position.x == 0.0)
	assert(is_equal_approx(badge.position.x, 22.8))
	assert(badge.z_index == 1)
	assert((badge.get_child(0) as Label).text == "+3")

	# Test 4: Down arrow for units below screen
	var dummy_down_pos: Array[Vector2] = [Vector2(600, 800)]
	offscreen_hud._update_cluster(OffscreenHUD.Direction.MIDDLE, [grid.enemy_units[0]], dummy_down_pos, vp_size, board_left, board_right, board_width)
	assert((mid_data["arrow"] as Label).text == "▼")
	assert(mid_data["root"].position.y == vp_size.y - 72.0)

	# Test 4b: _is_unit_offscreen threshold accuracy
	assert(offscreen_hud._is_unit_offscreen(Vector2(600, 70), vp_size)) # Under top HUD
	assert(offscreen_hud._is_unit_offscreen(Vector2(600, vp_size.y - 45.0), vp_size)) # Row 8 cutoff at bottom
	assert(not offscreen_hud._is_unit_offscreen(Vector2(600, 360), vp_size)) # Middle of screen

	# Test 5: Zero units hides cluster
	offscreen_hud._update_cluster(OffscreenHUD.Direction.LEFT, [], [], vp_size, board_left, board_right, board_width)
	assert(not left_data["root"].visible)

	# Test 6: Event-driven activation and settling
	offscreen_hud.on_turn_started(grid.active_unit)
	assert(offscreen_hud.is_processing())
	assert(offscreen_hud.refresh_timer > 0.0)
	# Advance time past duration to settle
	offscreen_hud._process(1.5)
	assert(not offscreen_hud.is_processing())
	assert(offscreen_hud.refresh_timer == 0.0)

	offscreen_hud.on_active_unit_moved(grid.active_unit)
	assert(offscreen_hud.is_processing())
	assert(offscreen_hud.refresh_timer > 0.0)
	offscreen_hud._process(1.5)
	assert(not offscreen_hud.is_processing())

	# Test 7: Switching to full board view hides all tooltips
	grid.active_unit = grid.player_units[0] # Breacher
	grid.force_full_board_zoom = false
	offscreen_hud.request_refresh()
	# Switch to full board view
	grid.force_full_board_zoom = true
	assert(offscreen_hud.is_full_board_view())
	assert(not left_data["root"].visible)
	assert(not mid_data["root"].visible)
	assert(not right_data["root"].visible)
	assert(not offscreen_hud.is_processing())

	# Switch back to default zoom
	grid.force_full_board_zoom = false
	assert(not offscreen_hud.is_full_board_view())
	assert(offscreen_hud.is_processing())
	offscreen_hud._process(1.5)
	assert(not offscreen_hud.is_processing())

	grid.queue_free()
	print("PASS: OffscreenHUD tests passed successfully!")
	quit()
