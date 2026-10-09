extends Skill
class_name Unstoppable_force


func begin(
	grid_field: GridField,
	_unit: Unit
) -> void:
	if(grid_field.energy == 0):
		grid_field.end_turn()
		return
	grid_field.targeting_skill = true


func update_preview(
	grid_field: GridField,
	unit: Unit
) -> void:
	var direction := grid_field.get_direction_to_mouse(unit.global_position)
	var distance := grid_field.get_skill_distance(unit)

	grid_field.show_attack_range(
		self,
		unit,
		direction,
		distance
	)


func has_usable_target(_unit: Unit) -> bool:
	return cooldown_remaining <= 0

func on_tile_clicked(
	grid_field: GridField,
	unit: Unit,
	pos: Vector2i
) -> void:
	if cooldown_remaining > 0:
		return
	var direction := grid_field.get_direction_to_mouse(unit.global_position)
	var distance := clampi(_forward_distance(unit.grid_position, pos, direction), 1, 3)

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
	var landing_position := unit.grid_position + direction * distance
	while not grid_field.tiles.has(landing_position) and landing_position != unit.grid_position:
		landing_position -= direction
	grid_field.lead_camera_to_tile(unit, landing_position)

	await grid_field.play_skill_presentation(
		self,
		target_positions
	)

	await execute(grid_field, unit, target_positions, direction, distance)
	grid_field.clear_camera_lead(unit)
	cooldown_remaining = cooldown
	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()

func on_owner_turn_start(_grid: GridField) -> void:
	if cooldown_remaining > 0:
		cooldown_remaining -= 1


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
		
func execute(grid: GridField, unit: Unit, target_positions: Array[Vector2i], direction: Vector2i, distance: int) -> void:
	var enemies = grid.enemy_units if unit in grid.player_units else grid.player_units
	var start_position := unit.grid_position
	var destination := start_position + direction * clampi(distance, 1, 3)
	while not grid.tiles.has(destination) and destination != start_position:
		destination -= direction
	var targets := grid.get_units_on_tiles(target_positions, grid.player_units + grid.enemy_units)
	targets.erase(unit)
	# Resolve the farthest units first so a charge can push a line of units.
	targets.sort_custom(func(a: Unit, b: Unit) -> bool:
		return _forward_distance(start_position, a.grid_position, direction) > _forward_distance(start_position, b.grid_position, direction)
	)
	for target in targets:
		if target in enemies:
			target.take_damage(damage)
		var displacement := get_displacement_direction_from_position(start_position, target, direction)
		if displacement == direction:
			var desired_position := destination + direction * 2
			var push_distance := maxi(0, _forward_distance(target.grid_position, desired_position, direction))
			for _step in range(push_distance):
				var next_position := target.grid_position + direction
				if not grid.tiles.has(next_position) or grid.is_tile_occupied(next_position, target):
					break
				_move_target_to_tile(grid, target, next_position)
		else:
			var next_position := target.grid_position + displacement
			if grid.tiles.has(next_position) and not grid.is_tile_occupied(next_position, target):
				_move_target_to_tile(grid, target, next_position)
		target.shake()
	while destination != start_position and grid.is_tile_occupied(destination, unit):
		destination -= direction
	unit.grid_position = destination
	unit.global_position = grid.get_tile_center(destination)
	Crater_Maker.new().clear_hazards_and_objects(grid, target_positions)


func _move_target_to_tile(grid: GridField, target: Unit, tile_position: Vector2i) -> void:
	target.grid_position = tile_position
	target.global_position = grid.get_tile_center(tile_position)


func _forward_distance(from_position: Vector2i, to_position: Vector2i, direction: Vector2i) -> int:
	var offset := to_position - from_position
	return offset.x * direction.x + offset.y * direction.y
		
func get_displacement_direction_from_position(start_position: Vector2i, target: Unit, direction: Vector2i) -> Vector2i:
	if direction == Vector2i.UP or direction == Vector2i.DOWN:
		if target.grid_position.x < start_position.x:
			return Vector2i.LEFT
		elif target.grid_position.x > start_position.x:
			return Vector2i.RIGHT
		return direction

	if target.grid_position.y < start_position.y:
		return Vector2i.UP
	elif target.grid_position.y > start_position.y:
		return Vector2i.DOWN
	return direction
