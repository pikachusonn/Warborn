extends Node

var root: Window

func _ready() -> void:
	root = get_tree().root
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1290, 720)
	var session = root.get_node("Netplay")
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await get_tree().process_frame

	var hud: TeamHealthHUD = grid.team_health_hud
	assert(hud != null, "team_health_hud should be instantiated and set up on GridField")

	# Local teams remain on fixed sides regardless of whose turn it is.
	session.mode = session.Mode.LOCAL
	hud._process(0.016)
	assert(hud.visible, "Player HUD must be visible in local mode")
	var enemy_hud := grid.get_node("CanvasLayer/EnemyTeamHealthHUD") as TeamHealthHUD
	enemy_hud._process(0.016)
	assert(enemy_hud.visible)
	assert(hud.zoom_button != null and enemy_hud.zoom_button == null)
	assert(hud.zoom_button.position.y >= hud.rows_container.position.y + hud.rows_container.size.y)
	hud.zoom_button.pressed.emit()
	assert(grid.force_full_board_zoom and hud.zoom_button.text == "Default zoom")
	var other_view := GridField.new()
	assert(not other_view.force_full_board_zoom, "Zoom is local to each board instance")
	other_view.free()
	assert(hud.get_team_units() == grid.player_units)
	assert(enemy_hud.get_team_units() == grid.enemy_units)
	assert(enemy_hud.position.x > root.size.x / 2.0)
	assert(enemy_hud.header_label.text == "ENEMY TEAM")
	grid.enemy_units[0].current_health = 65
	enemy_hud._process(0.016)
	assert(enemy_hud.unit_rows[0].hp_bar.value == 65)

	# Test 2: In multiplayer Host mode, HUD shows player_units
	session.mode = session.Mode.HOST
	enemy_hud._process(0.016)
	assert(enemy_hud.visible, "Enemy HUD must remain visible in multiplayer")
	assert(enemy_hud.get_team_units() == grid.enemy_units)
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
		var expected_tex := hud.get_face_texture(unit)
		assert(row_dict.icon_rect.texture == expected_tex, "Icon texture must be the zoomed character face")
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
	assert(grid.force_full_board_zoom, "Local zoom choice survives multiplayer role updates")
	hud.zoom_button.pressed.emit()
	assert(not grid.force_full_board_zoom and hud.zoom_button.text == "Full board view")
	var client_team := hud.get_team_units()
	enemy_hud._process(0.016)
	assert(enemy_hud.visible and enemy_hud.get_team_units() == grid.player_units, "Guest enemy HUD must show the host team")
	assert(client_team.size() == 4, "Client team should have 4 units")
	for i in range(4):
		assert(client_team[i] == grid.enemy_units[i], "Client team should match enemy_units")
		var expected_client_tex := hud.get_face_texture(grid.enemy_units[i])
		assert(hud.unit_rows[i].icon_rect.texture == expected_client_tex, "Client row must use zoomed enemy face")

	print("PASS: TeamHealthHUD unit icons, health bars, shields, defeat state, and multiplayer host/client switching")
	get_tree().quit()
