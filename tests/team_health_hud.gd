extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1290, 720)
	var session = root.get_node("Netplay")
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame

	var hud: TeamHealthHUD = grid.team_health_hud
	assert(hud != null, "team_health_hud should be instantiated and set up on GridField")

	# Test 1: In local mode (not networked), HUD should be hidden
	session.mode = session.Mode.LOCAL
	hud._process(0.016)
	assert(not hud.visible, "HUD must be hidden in local mode")

	# Test 2: In multiplayer Host mode, HUD shows player_units
	session.mode = session.Mode.HOST
	hud._process(0.016)
	assert(hud.visible, "HUD must be visible in multiplayer mode")
	var team_units := hud.get_team_units()
	assert(team_units.size() == 4, "Host team should have 4 units")
	for i in range(4):
		assert(team_units[i] == grid.player_units[i], "Host team should match player_units")

	# Verify row creation and idle frame textures
	assert(hud.unit_rows.size() == 4, "HUD should create 4 unit rows")
	for i in range(4):
		var row_dict: Dictionary = hud.unit_rows[i]
		var unit: Unit = team_units[i]
		assert(row_dict.unit == unit, "Row unit must match team unit")
		assert(row_dict.icon_rect.texture != null, "Icon must have idle frame texture")
		var expected_tex := unit.sprite.sprite_frames.get_frame_texture("idle", 0)
		assert(row_dict.icon_rect.texture == expected_tex, "Icon texture must be the first frame of idle animation")
		assert(row_dict.hp_bar.max_value == unit.data.health, "HP bar max value should match unit health")
		assert(row_dict.hp_bar.value == unit.current_health, "HP bar value should match unit current health")

	# Test 3: Health updates and Shield display
	var test_unit := grid.player_units[0]
	test_unit.current_health = 60
	test_unit.temp_health = 20
	hud._process(0.016)
	var first_row: Dictionary = hud.unit_rows[0]
	assert(first_row.hp_bar.value == 60, "HP bar value should update to 60")
	assert(first_row.temp_overlay.visible, "Shield overlay must be visible when temp_health > 0")
	assert(first_row.hp_label.text == "80 / %d" % test_unit.data.health, "HP label should display health + shield")

	# Test 4: Active turn indicator
	grid.active_unit = test_unit
	hud._process(0.016)
	assert(first_row.turn_badge.visible, "Turn badge should be visible for active unit")

	# Test 5: Defeated unit display
	test_unit.current_health = 0
	test_unit.temp_health = 0
	hud._process(0.016)
	assert(first_row.hp_bar.value == 0, "Defeated unit HP bar should be 0")
	assert(first_row.hp_label.text == "FALLEN", "Defeated unit should show FALLEN label")
	assert(not first_row.turn_badge.visible, "Defeated unit should not show turn badge")

	# Test 6: In Client mode, HUD shows enemy_units
	session.mode = session.Mode.CLIENT
	hud._process(0.016)
	assert(hud.visible, "HUD must be visible in client multiplayer mode")
	var client_team := hud.get_team_units()
	assert(client_team.size() == 4, "Client team should have 4 units")
	for i in range(4):
		assert(client_team[i] == grid.enemy_units[i], "Client team should match enemy_units")
		var expected_client_tex := grid.enemy_units[i].sprite.sprite_frames.get_frame_texture("idle", 0)
		assert(hud.unit_rows[i].icon_rect.texture == expected_client_tex, "Client row must use enemy unit idle frame")

	print("PASS: TeamHealthHUD unit icons, health bars, shields, defeat state, and multiplayer host/client switching")
	quit()
