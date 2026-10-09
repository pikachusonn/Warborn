extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 900)
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
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
	assert(not grid.target_tiles.is_empty())
	var target: Vector2i = grid.target_tiles[0].grid_position
	await mud_pillar.on_tile_clicked(grid, quagmire_unit, target)
	for _turn in range(5):
		await mud_pillar.on_owner_turn_start(grid)
	assert(mud_pillar.active_pillars.has(target), "Pillars should not expire on caster turns")
	assert(grid.movement_blockers.has(target))
	mud_pillar.remove_pillar(grid, target)
	assert(not mud_pillar.active_pillars.has(target) and not grid.movement_blockers.has(target))
	assert(not grid.targeting_skill)
	assert(grid.radial_skills_open)
	assert(grid.radial_menu.get_node("WheelBackGround").visible)
	assert(grid.radial_menu.get_node("MoveCancel").visible)
	print("PASS: Mud Pillar returns directly to the skill list")
	quit()
