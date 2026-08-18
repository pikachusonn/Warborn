extends Skill
class_name Cleave

func get_target_tiles(
	unit: Unit,
	direction: Vector2i,
	_distance: int = 1
) -> Array[Vector2i]:
	var target_tiles:Array[Vector2i] = []
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
	direction: Vector2i,
	distance: int
):
	var units := (grid_field.enemy_units if unit in grid_field.player_units else grid_field.player_units)
	var targets := grid_field.get_units_on_tiles(
		target_positions,
		units
	)

	for target in targets:
		target.take_damage(damage)
		target.shake()
