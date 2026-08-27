extends Skill
class_name Cleave


func begin(
	grid_field: GridField,
	_unit: Unit
) -> void:
	grid_field.targeting_skill = true


func update_preview(
	grid_field: GridField,
	unit: Unit
) -> void:
	var direction := grid_field.get_direction_to_mouse(unit.global_position)

	grid_field.show_attack_range(
		self,
		unit,
		direction,
		1
	)


func on_tile_clicked(
	grid_field: GridField,
	unit: Unit,
	pos: Vector2i
) -> void:
	var direction := grid_field.get_direction_to_mouse(unit.global_position)
	var target_positions := get_target_tiles(grid_field, unit, direction)
	if not grid_field.tiles.has(pos):
		return
	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return
	grid_field.targeting_skill = false
	await grid_field.play_skill_presentation(self, target_positions)
	await execute(grid_field, unit, target_positions, direction, 1)
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
	grid_field: GridField,
	unit: Unit,
	direction: Vector2i,
	_distance: int = 1
) -> Array[Vector2i]:
	var target_tiles: Array[Vector2i] = []

	if direction == Vector2i.UP:
		target_tiles = [
			unit.grid_position + Vector2i(-1, -1),
			unit.grid_position + Vector2i(0, -1),
			unit.grid_position + Vector2i(1, -1)
		]

	elif direction == Vector2i.DOWN:
		target_tiles = [
			unit.grid_position + Vector2i(-1, 1),
			unit.grid_position + Vector2i(0, 1),
			unit.grid_position + Vector2i(1, 1)
		]

	elif direction == Vector2i.LEFT:
		target_tiles = [
			unit.grid_position + Vector2i(-1, -1),
			unit.grid_position + Vector2i(-1, 0),
			unit.grid_position + Vector2i(-1, 1)
		]

	elif direction == Vector2i.RIGHT:
		target_tiles = [
			unit.grid_position + Vector2i(1, -1),
			unit.grid_position + Vector2i(1, 0),
			unit.grid_position + Vector2i(1, 1)
		]

	return target_tiles

func execute(
	grid_field: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	_direction: Vector2i,
	_distance: int
) -> void:
	var units := (
		grid_field.enemy_units
		if unit in grid_field.player_units
		else grid_field.player_units
	)

	var targets := grid_field.get_units_on_tiles(
		target_positions,
		units
	)

	for target in targets:
		target.take_damage(damage)
		target.shake()
