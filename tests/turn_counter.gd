extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1290, 720)
	var session = root.get_node("Netplay")
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame

	var hud: TopCaptureHUD = grid.top_capture_hud
	assert(hud != null, "TopCaptureHUD should be present on GridField")

	# Test 1: Start combat and verify initial initiative order
	grid.start_combat()
	assert(grid.round_number == 1, "Round should start at 1")
	assert(grid.turn_order.size() == 8, "Turn order should contain 8 units")
	for i in range(grid.turn_order.size() - 1):
		assert(grid.turn_order[i].data.speed >= grid.turn_order[i + 1].data.speed, "Units must be sorted by speed descending")

	# Test 2: HUD ribbon initialization
	hud._process(0.016)
	assert(hud.round_label.text == "ROUND 1", "Round label must show ROUND 1")
	assert(hud.unit_order_nodes.size() == 8, "Turn order ribbon should have 8 unit slots")

	# Verify each slot has the correct unit, texture, and team color
	for i in range(8):
		var slot: Dictionary = hud.unit_order_nodes[i]
		var unit: Unit = grid.turn_order[i]
		assert(slot.unit == unit, "Slot unit must match turn_order unit")
		assert(slot.icon_rect.texture != null, "Slot icon texture must not be null")
		var expected_tex := hud.get_face_texture(unit)
		assert(slot.icon_rect.texture == expected_tex, "Icon must match zoomed face texture")
		var expected_color := hud.COLOR_PLAYER if unit.side == Unit.Side.PLAYER else hud.COLOR_ENEMY
		assert(slot.team_color == expected_color, "Slot team color must match unit side")

	# Test 3: Active unit highlight
	var active_slot: Dictionary = hud.unit_order_nodes[grid.turn_index]
	assert(grid.active_unit == grid.turn_order[grid.turn_index], "Active unit must be turn_order[turn_index]")
	assert(active_slot.border_style.border_color == hud.COLOR_ACTIVE_BORDER, "Active unit slot must have gold active border")

	# Test 4: Turn progression within same round
	var first_unit: Unit = grid.turn_order[0]
	grid.advance_to_next_living_unit()
	assert(grid.round_number == 1, "Advancing within same cycle should remain in Round 1")
	assert(grid.turn_index == 1, "turn_index should advance to 1")
	hud._process(0.016)
	var first_slot: Dictionary = hud.unit_order_nodes[0]
	assert(first_slot.icon_rect.modulate.a < 1.0, "Completed unit should be dimmed")

	# Test 5: Cycle wrap-around increments round_number
	grid.turn_index = 7
	grid.advance_to_next_living_unit()
	assert(grid.round_number == 2, "Wrapping around candidate_index <= turn_index must increment round_number to 2")
	assert(grid.turn_index == 0, "turn_index should wrap to 0")
	hud._process(0.016)
	assert(hud.round_label.text == "ROUND 2", "Round label must update to ROUND 2")

	# Test 6: Network serialization and synchronization
	var codec := preload("res://network/combat_state.gd").new(grid)
	var snapshot := codec.capture()
	assert(snapshot.combat.has("round"), "Combat snapshot must serialize round")
	assert(snapshot.combat.round == 2, "Snapshot round must match grid round_number (2)")
	assert(snapshot.combat.turn == 0, "Snapshot turn must match grid turn_index (0)")

	# Apply snapshot to client simulation
	grid.round_number = 99
	grid.turn_index = 5
	codec.apply(snapshot)
	assert(grid.round_number == 2, "Applying snapshot must restore round_number to 2")
	assert(grid.turn_index == 0, "Applying snapshot must restore turn_index to 0")

	print("PASS: Turn Order initiative ribbon, round tracking, and network sync tests passed!")
	quit()
