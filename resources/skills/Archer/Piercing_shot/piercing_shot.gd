extends Skill
class_name Piercing_shot

func get_target_tiles(
	unit: Unit,
	direction: Vector2i,
	_distance: int = 1
) -> Array[Vector2i]:
	var target_tiles:Array[Vector2i] = []
	var step := direction.sign()
	var pos := unit.grid_position + step
	while pos.x >= 0 and pos.x < GridField.WIDTH and pos.y >= 0 and pos.y < GridField.HEIGHT:
		target_tiles.append(pos)
		pos += step
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
