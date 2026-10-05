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
	assert(not state.unit_0.has("hp_visible"), "Private character hover must not enter snapshots")
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
	state.unit_0.preview_damage = 15
	codec.apply(state)
	assert(grid.player_units[0].health_preview_active)
	assert(grid.player_units[0].hp_bar.visible)
	assert(grid.player_units[0].preview_amount_label.text == "-15")
	state.unit_0.preview_damage = 0
	codec.apply(state)
	assert(not grid.player_units[0].hp_bar.visible)
	assert(not grid.player_units[0].preview_amount_label.visible)
	# Persistent cloud state is shared, but hovering it is private to this peer.
	var zone_tiles: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 3)]
	state.world.zones = [{
		"owner": 0, "skill": 3, "id": 7, "kind": "odin_cloud",
		"center": Vector2i(2, 2), "tiles": zone_tiles, "turns": 2,
	}]
	codec.apply(state)
	assert(codec.replica_clouds.size() == 1)
	var cloud = codec.replica_clouds.values()[0]
	assert(cloud.countdown.text == "2")
	assert(not cloud.is_hovered)
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(cloud.is_hovered, "Replica cloud hover should react to the local pointer path")
	assert(grid.aoe_hover_glow.positions == zone_tiles)
	grid.update_aoe_hover(Vector2i(8, 8))
	assert(not cloud.is_hovered, "Leaving a zone should clear only this peer's hover")
	state.world.zones.clear()
	codec.apply(state)
	assert(codec.replica_clouds.is_empty(), "Removed authoritative zones must remove replica clouds")
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
