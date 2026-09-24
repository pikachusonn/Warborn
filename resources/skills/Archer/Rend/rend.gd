extends Skill
class_name Rend

func begin(grid_field: GridField, unit: Unit) -> void:
	if(grid_field.energy == 0):
		grid_field.end_turn()
		return
	grid_field.targeting_skill = true
	var is_ally_archer := unit in grid_field.player_units
	var enemies := grid_field.enemy_units if is_ally_archer else grid_field.player_units
	var allies := grid_field.player_units if is_ally_archer else grid_field.enemy_units
	grid_field.target_tiles.clear()
	#Enemies marks
	for target in enemies:
		if target.is_defeated():
			continue
		var stacks := target.get_status_stacks(Unit.EFFECTS.ENEMY_ARCHER_MARK)
		if stacks <= 0:
			continue
		target.set_attackable()
		grid_field.target_tiles.append(grid_field.tiles[target.grid_position])
	
	#Allies marks
	for target in allies:
		if target.is_defeated():
			continue
		var stacks := target.get_status_stacks(Unit.EFFECTS.ALLY_ARCHER_MARK)
		if stacks <= 0:
			continue
		target.set_heal()
		grid_field.target_tiles.append(grid_field.tiles[target.grid_position])

func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	if not grid_field.tiles.has(pos):
		return
	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return
	grid_field.targeting_skill = false
	await execute(grid_field, unit, [], Vector2i.ZERO, 1)
	reset_targets_visuals(grid_field, unit)
	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()

func execute(
	grid_field: GridField,
	unit: Unit,
	_target_positions: Array[Vector2i],
	_direction: Vector2i,
	_distance: int
):
	var is_ally_archer = unit in grid_field.player_units
	var target_units := (grid_field.enemy_units if is_ally_archer else grid_field.player_units)
	var allies_units := (grid_field.player_units if is_ally_archer else grid_field.enemy_units)
	
	for target in target_units:
		if target.is_defeated():
			continue
		var stacks := target.get_status_stacks(Unit.EFFECTS.ENEMY_ARCHER_MARK)
		if stacks <= 0:
			continue
		target.take_damage(damage * stacks)
		target.remove_status(Unit.EFFECTS.ENEMY_ARCHER_MARK)
		target.shake()
	for target in allies_units:
		if target.is_defeated():
			continue
		var stacks := target.get_status_stacks(Unit.EFFECTS.ALLY_ARCHER_MARK)
		if stacks <= 0:
			continue
		target.heal(5 * stacks)
		target.remove_status(Unit.EFFECTS.ALLY_ARCHER_MARK)
		target.shake()

func get_preview_damage(_grid: GridField, unit: Unit, target: Unit) -> int:
	if target.side == unit.side:
		return 0
	return damage * target.get_status_stacks(Unit.EFFECTS.ENEMY_ARCHER_MARK)

func get_preview_healing(_grid: GridField, unit: Unit, target: Unit) -> int:
	if target.side != unit.side:
		return 0
	return 5 * target.get_status_stacks(Unit.EFFECTS.ALLY_ARCHER_MARK)
		
		
func reset_targets_visuals(grid_field: GridField, unit: Unit) -> void:
	var targets: Array[Unit] = grid_field.player_units + grid_field.enemy_units
	for target in targets:
		target.set_active(false)
	unit.set_active(true)
		
func cancel(grid_field: GridField, unit: Unit) -> void:
	reset_targets_visuals(grid_field, unit)
	unit.set_active(true)
