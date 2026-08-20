extends Skill
class_name Unstoppable_force

func get_target_tiles(
	grid_field: GridField,
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
	else: # RIGHT
		if target.grid_position.y < unit.grid_position.y:
			return Vector2i.UP
		elif target.grid_position.y > unit.grid_position.y:
			return Vector2i.DOWN
		else:
			return Vector2i.RIGHT

	return Vector2i.ZERO

func execute(
	grid: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	direction: Vector2i,
	distance: int
):
	# Get opposing units
	var units = (
		grid.enemy_units
		if unit in grid.player_units
		else grid.player_units
	)

	# Calculate the furthest valid destination for Breacher.
	# Breacher cannot move onto an occupied enemy tile.
	var destination := unit.grid_position

	for step in range(1, distance + 1):
		var next_position := destination + direction

		# Stop if the tile is outside the board
		if not grid.tiles.has(next_position):
			break

		# Stop before an enemy
		var units_on_next_tile := grid.get_units_on_tiles(
			[next_position],
			units
		)

		if not units_on_next_tile.is_empty():
			break

		destination = next_position

	# Move Breacher
	unit.grid_position = destination
	unit.global_position = (
		grid.tiles[destination].global_position
		+ Vector2(32, 32)
	)

	# Get enemies inside the affected area
	var targets := grid.get_units_on_tiles(
		target_positions,
		units
	)

	for target in targets:
		# Always deal damage, even if displacement is impossible
		target.take_damage(damage)

		var displacement := get_displacement_direction(
			unit,
			target,
			direction
		)

		var new_position: Vector2i

		if displacement == direction:
			# Head-on:
			# Push the enemy one tile in the charge direction
			new_position = target.grid_position + direction
		else:
			# Side hit:
			# Move one tile sideways from the enemy's current position
			new_position = target.grid_position + displacement

		# Only displace if the destination exists on the board
		if grid.tiles.has(new_position):
			target.grid_position = new_position
			target.global_position = (
				grid.tiles[new_position].global_position
				+ Vector2(32, 32)
			)

		# Shake regardless of whether displacement was possible
		target.shake()
