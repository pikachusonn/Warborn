extends SceneTree
## Run two processes with --script res://tests/netplay_session.gd -- host / client.
const TEST_PORT := 27951

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(25.0).timeout.connect(func():
		push_error("Network test timed out")
		quit(1))
	root.size = Vector2i(1280, 900)
	var session = root.get_node("Netplay")
	var args := OS.get_cmdline_user_args()
	var client := "client" in args
	if client:
		await create_timer(1.0).timeout
		assert(session.join("127.0.0.1", TEST_PORT) == OK)
	else:
		assert(session.host(TEST_PORT) == OK)
	var deadline := Time.get_ticks_msec() + 12000
	while not session.board_started and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(session.board_started, "Both peers must complete the board-ready handshake")
	var grid: GridField = session.grid
	while grid.active_unit == null:
		await process_frame
	assert(grid.player_units.size() == 4 and grid.enemy_units.size() == 4)
	assert(is_equal_approx(absf(grid.rotation), PI if client else 0.0))
	var team: Array[Unit] = grid.enemy_units if client else grid.player_units
	for unit in team:
		assert(unit.global_position.y > root.size.y / 2.0, "Local team must be at the bottom")
		assert(is_zero_approx(unit.global_rotation), "Unit art and labels must stay upright")
		var logical := grid.to_local(unit.global_position) / GridField.TILE_SIZE
		assert(Vector2i(logical.floor()) == unit.grid_position, "View transform must preserve logical coordinates")
	# CanvasLayer transforms do not appear in Node2D.global_rotation.
	assert(is_zero_approx((grid.radial_menu_layer.transform * grid.radial_menu.transform).get_rotation()))
	var active := grid.active_unit
	var turn := grid.turn_index
	if client:
		grid.handle_radial_move()
		grid.open_radial_skills()
		grid.handle_radial_end_turn()
	grid.handle_unit_clicked(team[0])
	assert(grid.active_unit == active and grid.turn_index == turn)
	assert(grid.current_action == GridField.Action.NONE and not grid.radial_skills_open)
	assert(session.can_input() == not client)
	print("PASS: %s connected, correct perspective, upright UI, turn ownership" % ["client" if client else "host"])
	if client:
		await create_timer(1.0).timeout
		session.leave()
		await process_frame
		await process_frame
		assert(not session.is_networked() and not paused)
		assert(current_scene.scene_file_path == "res://network/lobby.tscn")
		print("PASS: client returns to lobby")
	else:
		deadline = Time.get_ticks_msec() + 12000
		while session.running and Time.get_ticks_msec() < deadline:
			await process_frame
		assert(not session.running and paused, "Disconnect must pause the remaining board")
		session.leave()
		await process_frame
		await process_frame
		assert(not paused and not session.is_networked())
		assert(session.host(TEST_PORT) == OK, "Port must be reusable after leaving")
		session.close_session()
		assert(session.join("127.0.0.1", TEST_PORT + 1) == OK)
		session._process(session.CONNECTION_TIMEOUT)
		assert(not session.connecting and not session.is_networked())
		assert("timed out" in session.status)
		print("PASS: disconnect pauses, leave cleans up, rehost and timeout recovery work")
	quit()
