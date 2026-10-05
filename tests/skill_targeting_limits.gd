extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
	grid.set_process(false)
	var caster: Unit = grid.player_units[2]
	caster.grid_position = Vector2i(4, 4)
	var ally: Unit = grid.player_units[0]
	ally.grid_position = Vector2i(4, 5)
	var enemy: Unit = grid.enemy_units[0]
	enemy.grid_position = Vector2i(5, 4)
	grid.movement_blockers[Vector2i(3, 4)] = ally
	var crater := caster.skills[1] as Crater_Maker
	var targets := crater.get_target_tiles(grid, caster, Vector2i.ZERO)
	assert(Vector2i(4, 5) not in targets)
	assert(Vector2i(5, 4) not in targets)
	assert(Vector2i(3, 4) not in targets)
	assert(Vector2i(4, 6) in targets, "Leaping over occupied tiles must remain possible")
	grid.energy = 1
	grid.targeting_skill = true
	grid.target_tiles.assign([grid.tiles[ally.grid_position]])
	await crater.on_tile_clicked(grid, caster, ally.grid_position)
	assert(caster.grid_position == Vector2i(4, 4))
	assert(grid.energy == 1 and grid.targeting_skill, "Stale occupied targets cannot commit a leap")
	grid.movement_blockers.clear()
	grid.clear_skill_state()
	var quagmire_unit: Unit = grid.player_units[3]
	grid.active_unit = quagmire_unit
	grid.free_movement = true
	var pillar := quagmire_unit.skills[0] as Mud_Pillar
	var quagmire := quagmire_unit.skills[1] as Quagmire
	pillar.create_pillar_visual(grid, Vector2i(7, 7))
	pillar.create_pillar_visual(grid, Vector2i(8, 7))
	quagmire.begin(grid, quagmire_unit)
	quagmire.cancel(grid, quagmire_unit)
	assert(quagmire.cooldown_remaining == 0, "Cancelling must not start cooldown")
	quagmire.begin(grid, quagmire_unit)
	quagmire.on_tile_clicked(grid, quagmire_unit, Vector2i(7, 7))
	assert(quagmire.cooldown == 2 and quagmire.cooldown_remaining == 0)
	assert(not grid.can_use_skill(1), "Quagmire cannot be recast while an active zone exists")
	quagmire.on_tile_clicked(grid, quagmire_unit, Vector2i(8, 7))
	assert(pillar.active_pillars.has(Vector2i(8, 7)), "Active zone must prevent consuming another pillar")
	# Zone lasts 3 caster turns
	quagmire.on_owner_turn_start(grid) # 2 turns left
	assert(not grid.can_use_skill(1))
	quagmire.on_owner_turn_start(grid) # 1 turn left
	assert(not grid.can_use_skill(1))
	quagmire.on_owner_turn_start(grid) # 0 turns left -> zone clears, cooldown starts (2)
	assert(quagmire.cooldown_remaining == 2)
	assert(not grid.can_use_skill(1))
	quagmire.on_owner_turn_start(grid) # 1 turn remaining
	assert(quagmire.cooldown_remaining == 1)
	assert(not grid.can_use_skill(1))
	quagmire.on_owner_turn_start(grid) # 0 turns remaining -> usable!
	assert(quagmire.cooldown_remaining == 0)
	assert(grid.can_use_skill(1))
	print("PASS: Crater Maker excludes occupied landings; Quagmire cooldown starts 2 turns after zone expires")
	quit()
