extends Skill
class_name Piercing_shot

var free_cast := false

func set_free_cast(value: bool) -> void:
	free_cast = value

func begin(grid_field: GridField, unit: Unit) -> void:
	grid_field.targeting_skill = true

func get_target_tiles(grid_field: GridField, unit: Unit, direction: Vector2i, _distance: int = 1) -> Array[Vector2i]:
	var target_tiles := get_line_tiles(grid_field, unit, unit.grid_position, direction)
	print("SHOT LINE: ", target_tiles)
	print("PADS: ", grid_field.bouncing_pads)

	var pad_position: Variant = null
	for pos in target_tiles:
		print("checking ", pos, " pad: ", grid_field.get_bouncing_pad(pos))
		if grid_field.get_bouncing_pad(pos):
			pad_position = pos
			break

	print("FOUND PAD: ", pad_position)
	if pad_position == null:
		return target_tiles

	var bounce_directions := get_bounce_directions(direction)
	for bounce_direction in bounce_directions:
		var bounce_tiles := get_line_tiles(grid_field, unit, pad_position, bounce_direction)
		print("BOUNCE: ", bounce_direction, " ", bounce_tiles)
		for tile in bounce_tiles:
			if tile not in target_tiles:
				target_tiles.append(tile)

	return target_tiles
	
func update_preview(grid_field: GridField, unit: Unit) -> void:
	var direction := grid_field.get_direction_to_mouse(unit, true)
	grid_field.show_attack_range(self, unit, direction, 1)

func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	var direction := grid_field.get_direction_to_mouse(unit, true)
	var target_positions := get_target_tiles(grid_field, unit, direction)
	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return
	grid_field.targeting_skill = false
	await grid_field.play_skill_presentation(self, target_positions)
	await execute(grid_field, unit, target_positions, direction, 1)
	if not free_cast:
		grid_field.energy -= 1
		grid_field.unit_panel.update_energy(grid_field.energy)
	free_cast = false
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()
	
func execute(
	grid_field: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	direction: Vector2i,
	distance: int
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
	var pos := start + direction
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
