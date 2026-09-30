extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 900)
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame

	var cz: CaptureZoneManager = grid.capture_zone
	assert(cz != null, "CaptureZoneManager should be initialized")

	# ========================================================
	# 1. ZONE LAYOUT VERIFICATION (Rows 4 and 5, size 2x10)
	# ========================================================
	for x in range(10):
		assert(cz.is_inside_capture_zone(Vector2i(x, 4)), "Row 4 should be inside capture zone")
		assert(cz.is_inside_capture_zone(Vector2i(x, 5)), "Row 5 should be inside capture zone")
		assert(not cz.is_inside_capture_zone(Vector2i(x, 3)), "Row 3 must not be inside capture zone")
		assert(not cz.is_inside_capture_zone(Vector2i(x, 6)), "Row 6 must not be inside capture zone")

	# ========================================================
	# 2. CAPTURE ACTION REQUIREMENTS
	# ========================================================
	var player_unit: Unit = grid.player_units[0]
	player_unit.grid_position = Vector2i(4, 4)
	grid.active_unit = player_unit
	grid.energy = 1
	assert(cz.can_unit_capture(player_unit), "Unit inside zone with energy and neutral state should be able to capture")

	# Outside zone
	player_unit.grid_position = Vector2i(4, 3)
	assert(not cz.can_unit_capture(player_unit), "Unit outside zone cannot capture")
	player_unit.grid_position = Vector2i(4, 4)

	# 0 energy
	grid.energy = 0
	assert(not cz.can_unit_capture(player_unit), "Unit with 0 energy cannot capture")
	grid.energy = 1

	# ========================================================
	# 3. STARTING CAPTURE
	# ========================================================
	cz.start_capture(player_unit)
	assert(grid.energy == 0, "Capture must cost 1 energy")
	assert(cz.state == CaptureZoneManager.CaptureState.CAPTURING, "Zone state should be CAPTURING")
	assert(cz.capturing_unit == player_unit, "Capturing unit should be recorded")
	assert(cz.capturing_team == Unit.Side.PLAYER, "Capturing team should be recorded")
	assert(cz.capture_turns_completed == 1, "Capture progress should start at Turn 1")

	# Another unit cannot capture while zone is capturing
	var other_unit: Unit = grid.player_units[1]
	other_unit.grid_position = Vector2i(5, 5)
	grid.energy = 1
	assert(not cz.can_unit_capture(other_unit), "Other unit cannot capture while zone is already capturing")

	# ========================================================
	# 4. IMMEDIATE CANCELLATION (Movement / Displacement)
	# ========================================================
	# Move capturing unit outside zone
	player_unit.grid_position = Vector2i(4, 6)
	assert(cz.state == CaptureZoneManager.CaptureState.NEUTRAL, "Moving outside zone must immediately cancel capture")
	assert(cz.capturing_unit == null, "Capturing unit should be cleared on cancel")
	assert(cz.capture_turns_completed == 0, "Progress should reset to 0 on cancel")
	assert(not player_unit.has_completed_capture, "Cancelled capture must not consume completion eligibility")

	# ========================================================
	# 5. TIMELINE: TURN 1 -> TURN 2 -> TURN 3 -> COMPLETION
	# ========================================================
	player_unit.grid_position = Vector2i(4, 4)
	grid.energy = 1
	cz.start_capture(player_unit)
	assert(cz.capture_turns_completed == 1)

	# Enemy turn starts: capture must NOT advance
	var enemy_unit: Unit = grid.enemy_units[0]
	cz.on_unit_turn_start(enemy_unit)
	assert(cz.capture_turns_completed == 1, "Other unit's turn must not advance capture progress")

	# Capturing unit's next turn starts: advances to Turn 2
	cz.on_unit_turn_start(player_unit)
	assert(cz.capture_turns_completed == 2, "Capturing unit's next turn start must advance progress to Turn 2")
	assert(cz.team_capture_points[Unit.Side.PLAYER] == 0, "Points awarded only on completion")

	# Capturing unit's following turn starts: Turn 3 -> complete capture!
	cz.on_unit_turn_start(player_unit)
	assert(cz.team_capture_points[Unit.Side.PLAYER] == 1, "Should award 1 Capture Point on Turn 3")
	assert(player_unit.has_completed_capture, "Unit should be marked as having completed capture")
	assert(cz.state == CaptureZoneManager.CaptureState.NEUTRAL, "Zone should reset to NEUTRAL after completion")

	# Same unit cannot begin another capture
	grid.energy = 1
	assert(not cz.can_unit_capture(player_unit), "Unit that completed capture cannot capture again")

	# ========================================================
	# 6. SECOND CAPTURE & VICTORY CONDITION (2 Points)
	# ========================================================
	# Second player unit captures to win
	other_unit.grid_position = Vector2i(3, 4)
	grid.active_unit = other_unit
	grid.energy = 1
	assert(cz.can_unit_capture(other_unit), "Second unit should be able to capture")

	cz.start_capture(other_unit)
	cz.on_unit_turn_start(other_unit) # Turn 2
	cz.on_unit_turn_start(other_unit) # Turn 3 -> completes 2nd capture

	assert(cz.team_capture_points[Unit.Side.PLAYER] == 2, "Allies should have 2 capture points")
	assert(grid.match_ended, "Match should end when a team reaches 2 capture points")
	assert(grid.winning_team == Unit.Side.PLAYER, "Player should be the winner")
	assert(grid.win_reason == "Capture", "Win reason should be Capture")

	# ========================================================
	# 7. ELIMINATION VICTORY CONDITION
	# ========================================================
	grid.match_ended = false
	grid.winning_team = -1
	for enemy in grid.enemy_units:
		enemy.current_health = 0
		enemy.set_defeated_visual()
	grid.check_elimination_victory()
	assert(grid.match_ended, "Eliminating all enemy units should end match")
	assert(grid.winning_team == Unit.Side.PLAYER, "Player should win by elimination")
	assert(grid.win_reason == "Elimination", "Win reason should be Elimination")

	print("PASS: Capture Zone blueprint tests completed successfully")
	quit()
