extends Skill
class_name Piercing_shot

enum  Stage {
	SHOT,
	BOUNCE
}

var free_cast := false
var stage := Stage.SHOT
var active_pad_position: Vector2i

func set_free_cast(value: bool) -> void:
	free_cast = value

func begin(grid_field: GridField, unit: Unit) -> void:
	if(grid_field.energy == 0):
		grid_field.end_turn()
		return
	stage = Stage.SHOT
	grid_field.targeting_skill = true
	
func get_target_tiles(grid_field: GridField, unit: Unit, direction: Vector2i, _distance: int = 1) -> Array[Vector2i]:
	return get_line_tiles(grid_field, unit, unit.grid_position, direction)

func update_preview(grid_field: GridField, unit: Unit) -> void:
	if stage == Stage.SHOT:
		var direction := grid_field.get_direction_to_mouse(unit.global_position, true)
		grid_field.show_attack_range(self, unit, direction, 1)
	elif stage == Stage.BOUNCE:
		show_bounce_preview(grid_field, unit)

func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	if stage == Stage.SHOT:
		await handle_first_shot(grid_field, unit, pos)
	elif stage == Stage.BOUNCE:
		await handle_bounce_shot(grid_field, unit, pos)

func show_line_preview(grid_field: GridField, target_positions: Array[Vector2i]) -> void:
	grid_field.clear_target_tiles()
	for target in target_positions:
		if not grid_field.tiles.has(target):
			continue
		var tile = grid_field.tiles[target]
		tile.set_attackable(true)
		grid_field.target_tiles.append(tile)

func handle_first_shot(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	var direction := grid_field.get_direction_to_mouse(unit.global_position, true)
	var target_positions := get_target_tiles(grid_field, unit, direction)
	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return
	var pad := find_pad_on_path(grid_field, unit, target_positions)
	grid_field.targeting_skill = false
	await grid_field.play_skill_presentation(self, target_positions)
	await execute(grid_field, unit, target_positions, direction, 1)

	if pad:
		stage = Stage.BOUNCE
		grid_field.clear_skill_state()
		grid_field.targeting_skill = true
		return
	finish_skill(grid_field)
	
func show_bounce_preview(grid_field: GridField, unit: Unit) -> void:
	var pad_world_position := grid_field.get_tile_center(active_pad_position)
	var direction := grid_field.get_direction_to_mouse(pad_world_position, true)
	var opposite_direction := -direction
	var first_line := get_line_tiles(grid_field, unit, active_pad_position, direction)
	var second_line := get_line_tiles(grid_field, unit, active_pad_position, opposite_direction)
	var target_positions := first_line + second_line
	show_line_preview(grid_field, target_positions)
	
func handle_bounce_shot(grid_field: GridField, unit: Unit, _pos: Vector2i) -> void:
	var pad_world_position := grid_field.get_tile_center(active_pad_position)
	var direction := grid_field.get_direction_to_mouse(pad_world_position, true)
	var opposite_direction := -direction
	var first_line := get_line_tiles(grid_field, unit, active_pad_position, direction)
	var second_line := get_line_tiles(grid_field, unit, active_pad_position, opposite_direction)
	var target_positions := first_line + second_line
	grid_field.targeting_skill = false
	await grid_field.play_skill_presentation(self, target_positions)
	await execute(grid_field, unit, target_positions, direction, 1)
	finish_skill(grid_field)

func finish_skill(grid_field: GridField) -> void:
	if not free_cast:
		grid_field.energy -= 1
		grid_field.unit_panel.update_energy(grid_field.energy)

	free_cast = false
	stage = Stage.SHOT

	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()

func execute(
	grid_field: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	_direction: Vector2i,
	_distance: int
):
	var target_units := (grid_field.enemy_units if unit in grid_field.player_units else grid_field.player_units)
	var allies_units := (grid_field.player_units if unit in grid_field.player_units else grid_field.enemy_units)
	var targets := grid_field.get_units_on_tiles(target_positions, target_units)
	var allies := grid_field.get_units_on_tiles(target_positions, allies_units)
	for ally in allies:
		ally.add_status(Unit.EFFECTS.ALLY_ARCHER_MARK)
		ally.shake()
	for enemy in targets:
		enemy.take_damage(damage)
		enemy.add_status(Unit.EFFECTS.ENEMY_ARCHER_MARK)
		enemy.shake()
	
func get_line_tiles(grid_field: GridField, unit: Unit, start: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	print("direction: ", direction, " step: ", direction.sign())
	var pos := start + direction.sign()
	while (pos.x >= 0 and pos.x < GridField.WIDTH and pos.y >= 0 and pos.y < GridField.HEIGHT):
		if direction.y != 0 and grid_field.get_projectile_blocker(pos, unit):
			break
		result.append(pos)
		pos += direction
	return result

func get_bounce_directions(
	direction: Vector2i
) -> Array[Vector2i]:
	return [Vector2i(-direction.y, direction.x), Vector2i(direction.y, -direction.x)]
		
func cancel(grid_field: GridField, _unit: Unit) -> void:
	grid_field.clear_skill_state()
	free_cast = false

func find_pad_on_path(grid_field: GridField, unit: Unit, target_positions: Array[Vector2i]) -> Hunter_kit:
	for pos in target_positions:
		var pad := grid_field.get_bouncing_pad(pos, unit)
		if pad:
			active_pad_position = pos
			return pad
	return null
