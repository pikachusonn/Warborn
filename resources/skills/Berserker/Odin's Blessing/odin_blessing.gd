extends Skill
class_name OdinBlessing

const TARGET_RADIUS: int = 2

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
	grid_field.show_attack_range(self, unit, Vector2i.ZERO, TARGET_RADIUS)
	
func get_target_tiles(grid_field: GridField, unit: Unit, _direction: Vector2i, _distance: int = TARGET_RADIUS) -> Array[Vector2i]:
	var target_positions: Array[Vector2i] = []
	for x in range(-TARGET_RADIUS, TARGET_RADIUS + 1):
		for y in range(-TARGET_RADIUS, TARGET_RADIUS + 1):
			var target_position := (unit.grid_position + Vector2i(x, y))
			if grid_field.tiles.has(target_position):
				target_positions.append(target_position)
	return target_positions
	
func show_preview(
	grid_field: GridField,
	_unit: Unit,
	_direction: Vector2i
) -> void:
	if grid_field.hovered_tile == null:
		grid_field.clear_impact_preview()
		return
	if grid_field.hovered_tile not in grid_field.target_tiles:
		grid_field.clear_impact_preview()
		return
	var center := grid_field.hovered_tile.grid_position
	var impact_positions := get_impact_tiles(grid_field, center)
	grid_field.show_impact_preview(impact_positions)
	
func get_impact_tiles(grid_field: GridField, center: Vector2i) -> Array[Vector2i]:
	var impact_positions: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			var position := center + Vector2i(x, y)

			if grid_field.tiles.has(position):
				impact_positions.append(position)
	return impact_positions
	
func cancel(grid_field: GridField, _unit: Unit) -> void:
	grid_field.clear_skill_state()
