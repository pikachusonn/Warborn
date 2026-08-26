extends Skill
class_name Unstoppable_force


func begin(
	grid_field: GridField,
	_unit: Unit
) -> void:
	grid_field.targeting_skill = true


func update_preview(
	grid_field: GridField,
	unit: Unit
) -> void:
	var direction := grid_field.get_direction_to_mouse(unit)
	var distance := grid_field.get_skill_distance(unit)

	grid_field.show_attack_range(
		self,
		unit,
		direction,
		distance
	)


func on_tile_clicked(
	grid_field: GridField,
	unit: Unit,
	pos: Vector2i
) -> void:
	var direction := grid_field.get_direction_to_mouse(unit)
	var distance := grid_field.get_skill_distance(unit)

	var target_positions := get_target_tiles(
		grid_field,
		unit,
		direction,
		distance
	)

	if not grid_field.tiles.has(pos):
		return

	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return

	grid_field.targeting_skill = false

	await grid_field.play_skill_presentation(
		self,
		target_positions
	)

	await execute(grid_field, unit, target_positions, direction, distance)
	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()


func cancel(
	grid_field: GridField,
	_unit: Unit
) -> void:
	grid_field.clear_skill_state()


func get_target_tiles(
	_grid_field: GridField,
	unit: Unit,
	direction: Vector2i,
	distance: int = 1
) -> Array[Vector2i]:
	var target_tiles: Array[Vector2i] = []
	var side_direction: Vector2i

	if direction == Vector2i.UP or direction == Vector2i.DOWN:
		side_direction = Vector2i.RIGHT
	else:
		side_direction = Vector2i.DOWN

	for forward in range(1, distance + 1):
		for side in range(-1, 2):
			var target := (
				unit.grid_position
				+ direction * forward
				+ side_direction * side
			)

			target_tiles.append(target)

	return target_tiles
	
func get_displacement_direction(
	unit: Unit,
	target: Unit,
	direction: Vector2i
) -> Vector2i:
	if direction == Vector2i.UP:
		if target.grid_position.x < unit.grid_position.x:
			return Vector2i.LEFT
		elif target.grid_position.x > unit.grid_position.x:
			return Vector2i.RIGHT
		else:
			return Vector2i.UP

	elif direction == Vector2i.DOWN:
		if target.grid_position.x < unit.grid_position.x:
			return Vector2i.LEFT
		elif target.grid_position.x > unit.grid_position.x:
			return Vector2i.RIGHT
		else:
			return Vector2i.DOWN

	elif direction == Vector2i.LEFT:
		if target.grid_position.y < unit.grid_position.y:
			return Vector2i.UP
		elif target.grid_position.y > unit.grid_position.y:
			return Vector2i.DOWN
		else:
			return Vector2i.LEFT

	else:
		if target.grid_position.y < unit.grid_position.y:
			return Vector2i.UP
		elif target.grid_position.y > unit.grid_position.y:
			return Vector2i.DOWN
		else:
			return Vector2i.RIGHT
		
func execute(
	grid: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	direction: Vector2i,
	distance: int
) -> void:
	var units = (
		grid.enemy_units
		if unit in grid.player_units
		else grid.player_units
	)

	var destination := unit.grid_position

	for step in range(1, distance + 1):
		var next_position := destination + direction

		if not grid.tiles.has(next_position):
			break

		var units_on_next_tile := grid.get_units_on_tiles(
			[next_position],
			units
		)

		if not units_on_next_tile.is_empty():
			break

		destination = next_position

	unit.grid_position = destination
	unit.global_position = (
		grid.tiles[destination].global_position
		+ Vector2(32, 32)
	)

	var targets := grid.get_units_on_tiles(
		target_positions,
		units
	)

	for target in targets:
		target.take_damage(damage)

		var displacement := get_displacement_direction(
			unit,
			target,
			direction
		)

		var new_position: Vector2i

		if displacement == direction:
			new_position = target.grid_position + direction
		else:
			new_position = target.grid_position + displacement

		if grid.tiles.has(new_position):
			target.grid_position = new_position
			target.global_position = (
				grid.tiles[new_position].global_position
				+ Vector2(32, 32)
			)

		target.shake()
