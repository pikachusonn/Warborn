extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 900)
	var session = root.get_node("Netplay")
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
	var codec := preload("res://network/combat_state.gd").new(grid)
	for unit: Unit in grid.player_units + grid.enemy_units:
		unit.clear_health_preview()
		unit.set_hovered(false)
	var state := codec.capture()
	session.set_process(false)
	session.mode = session.Mode.CLIENT
	session.grid = grid
	session.running = true
	session.board_started = true
	session.state_codec = codec
	codec.apply(state)
	for unit: Unit in grid.player_units + grid.enemy_units:
		assert(not unit.hp_bar.visible, "Idle replicas must not force health bars visible")
		assert(unit.effects_wrapper.position == Vector2(-32, -52))
	state.unit_0.hp_visible = true
	codec.apply(state)
	assert(grid.player_units[0].hp_bar.visible)
	assert(not grid.enemy_units[0].hp_bar.visible)
	state.unit_0.hp_visible = false
	state.unit_0.preview_damage = 15
	codec.apply(state)
	assert(grid.player_units[0].health_preview_active)
	assert(grid.player_units[0].hp_bar.visible)
	assert(grid.player_units[0].preview_amount_label.text == "-15")
	state.unit_0.preview_damage = 0
	codec.apply(state)
	assert(not grid.player_units[0].hp_bar.visible)
	assert(not grid.player_units[0].preview_amount_label.visible)
	grid.radial_skills_open = true
	grid.update_radial_menu()
	assert(grid.radial_menu.modulate.a < 1.0 and grid.radial_menu.modulate.r < 1.0)
	var wheel = grid.radial_menu.get_node("WheelBackGround")
	var point := Vector2.from_angle(deg_to_rad(112.5)) * 80.0
	wheel.update_hover_from_point(point)
	assert(wheel.hovered_segment == -1, "Observer hover must not light up the menu")
	assert(wheel.skill_tooltip.panel.visible, "Observer must retain private skill inspection")
	assert(wheel.skill_tooltip.panel.modulate == Color.WHITE)
	var cancel = grid.radial_menu.get_node("MoveCancel")
	cancel.hovered = true
	cancel._process(0.0)
	assert(not cancel.hovered)
	# Ownership changes must restore the menu without affecting tooltip inspection.
	session.mode = session.Mode.HOST
	grid.update_radial_menu()
	assert(grid.radial_menu.modulate == Color.WHITE)
	wheel.update_hover_from_point(point)
	assert(wheel.hovered_segment == 0)
	session.mode = session.Mode.LOCAL
	grid.update_radial_menu()
	assert(grid.radial_menu.modulate == Color.WHITE)
	session.close_session()
	print("PASS: guest health visibility and previews, dim observer menu, private tooltips, active hover restored")
	quit()
