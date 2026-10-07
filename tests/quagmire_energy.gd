extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	get_tree().root.add_child(grid)
	await get_tree().process_frame
	grid.set_process(false)
	var caster: Unit = grid.player_units[3]
	grid.active_unit = caster
	grid.free_movement = true
	var pillar := caster.skills[0] as Mud_Pillar
	var quagmire := caster.skills[1] as Quagmire
	var rupture := caster.skills[2] as Rupture
	var shifting := caster.skills[3] as ShiftingSand
	assert(quagmire.get_action_cost() == 1 and rupture.get_action_cost() == 1)
	assert(shifting.get_action_cost() == 0)
	pillar.create_pillar_visual(grid, Vector2i(7, 7))
	pillar.create_pillar_visual(grid, Vector2i(8, 7))
	grid.energy = 0
	assert(not grid.can_use_skill(1) and not grid.can_use_skill(2))
	quagmire.begin(grid, caster)
	assert(not grid.targeting_skill)
	rupture.begin(grid, caster)
	assert(not grid.targeting_skill)
	grid.energy = 2
	quagmire.begin(grid, caster)
	quagmire.on_tile_clicked(grid, caster, Vector2i(7, 7))
	assert(grid.energy == 1 and not quagmire.active_zones.is_empty())
	assert(not pillar.active_pillars.has(Vector2i(7, 7)))
	rupture.begin(grid, caster)
	grid.energy = 0
	await rupture.on_tile_clicked(grid, caster, Vector2i(8, 7))
	assert(pillar.active_pillars.has(Vector2i(8, 7)))
	grid.energy = 1
	await rupture.on_tile_clicked(grid, caster, Vector2i(8, 7))
	assert(grid.energy == 0 and rupture.cooldown_remaining == rupture.cooldown)
	assert(not pillar.active_pillars.has(Vector2i(8, 7)))
	var target: Unit = grid.enemy_units[0]
	target.grid_position = Vector2i(2, 5)
	var positions: Array[Vector2i] = [target.grid_position]
	await shifting.execute(grid, caster, positions, Vector2i.RIGHT, 5)
	assert(target.grid_position == Vector2i(5, 5), "Push is capped at three tiles")
	grid.movement_blockers[Vector2i(7, 5)] = caster
	positions.assign([target.grid_position])
	await shifting.execute(grid, caster, positions, Vector2i.RIGHT, 3)
	assert(target.grid_position == Vector2i(6, 5), "Push still stops before blockers")
	print("PASS: Quagmire and Rupture energy costs; Shifting Sand three-tile push")
	get_tree().quit()
