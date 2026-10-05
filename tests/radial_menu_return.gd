extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 900)
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame

	# 1. Test: executing a skill when free movement remains and no usable skills left -> back to action menu.
	var breacher: Unit = grid.player_units[0]
	grid.active_unit = breacher
	grid.radial_menu_owner = breacher
	grid.energy = 1
	grid.free_movement = true
	grid.radial_skills_open = true
	grid.update_radial_menu()
	assert(grid.radial_skills_open)

	# Enemy placed right next to breacher so Cleave can hit
	grid.enemy_units[0].grid_position = breacher.grid_position + Vector2i.RIGHT
	grid.enemy_units[0].position = grid.get_tile_center(grid.enemy_units[0].grid_position)

	var cleave: Skill = breacher.skills[0]
	grid.handle_skill_pressed(0, GridField.Action.SKILL1)
	await cleave.on_tile_clicked(grid, breacher, grid.enemy_units[0].grid_position)

	assert(grid.active_unit == breacher, "Turn should not end because free movement is still available")
	assert(not grid.radial_skills_open, "Radial menu should return to action menu")
	assert(grid.free_movement, "Free movement should still be available")
	assert(grid.radial_menu.get_node("WheelBackGround").visible, "Wheel should be visible")
	assert(not grid.radial_menu.get_node("MoveCancel").visible, "MoveCancel should be hidden in action menu")
	assert(grid.radial_menu.get_node("Move").visible, "Move button should be visible in action menu")

	# 2. Test: executing a skill when free movement is already used and no usable skills left -> ends turn immediately.
	grid.turn_index = 0
	grid.active_unit = breacher
	grid.radial_menu_owner = breacher
	grid.energy = 1
	grid.free_movement = false
	grid.radial_skills_open = true
	grid.update_radial_menu()

	grid.handle_skill_pressed(0, GridField.Action.SKILL1)
	await cleave.on_tile_clicked(grid, breacher, grid.enemy_units[0].grid_position)

	assert(grid.active_unit != breacher, "Turn should end immediately when free movement was already used")

	# 3. Test: executing a skill when character still has usable skills left (Mud Pillar) -> stays in skill list menu.
	var quagmire_unit: Unit
	for unit in grid.player_units:
		if unit.skills.any(func(skill: Skill): return skill is Mud_Pillar):
			quagmire_unit = unit
			break
	assert(quagmire_unit != null)
	grid.active_unit = quagmire_unit
	grid.energy = 1
	grid.free_movement = true
	grid.update_radial_menu()

	var mud_pillar: Mud_Pillar
	for skill in quagmire_unit.skills:
		if skill is Mud_Pillar:
			mud_pillar = skill
			break
	grid.handle_skill_pressed(quagmire_unit.skills.find(mud_pillar), GridField.Action.SKILL1)
	var target: Vector2i = grid.target_tiles[0].grid_position
	await mud_pillar.on_tile_clicked(grid, quagmire_unit, target)

	assert(grid.radial_skills_open, "Should stay in skill list menu when character still has usable skills")
	assert(grid.radial_menu.get_node("MoveCancel").visible, "MoveCancel should be visible in skill list menu")

	print("PASS: radial menu return state tests passed successfully")
	quit()
