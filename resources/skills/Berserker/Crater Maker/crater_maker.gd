extends Skill
class_name Crater_Maker

@export var leap_distance: int = 3

func begin(
	grid_field: GridField,
	_unit: Unit
) -> void:
	if grid_field.energy <= 0:
		grid_field.end_turn()
		return
	grid_field.targeting_skill = true
	
func update_preview(
	grid_field: GridField,
	unit: Unit
) -> void:
	grid_field.show_attack_range(self, unit, Vector2i.ZERO, leap_distance)
	
func get_target_tiles(
	grid_field: GridField,
	unit: Unit,
	_direction: Vector2i,
	distance: int = 3
) -> Array[Vector2i]:
	var target_positions: Array[Vector2i] = []

	var directions: Array[Vector2i] = [
		Vector2i.DOWN,
		Vector2i.UP,
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, -1),
		Vector2i(-1, -1)
	]

	for direction in directions:
		for step in range(1, distance + 1):
			var target_position := (
				unit.grid_position
				+ direction * step
			)

			if not grid_field.tiles.has(target_position):
				break

			target_positions.append(target_position)

	return target_positions
	
func get_impact_tiles(
	grid_field: GridField,
	landing_pos: Vector2i
) -> Array[Vector2i]:
	var impact_tiles: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			var pos := landing_pos + Vector2i(x, y)
			if grid_field.tiles.has(pos):
				impact_tiles.append(pos)
	return impact_tiles
	
func execute(grid_field: GridField, unit: Unit, target_positions: Array[Vector2i], _direction: Vector2i, _distance: int) -> void:
	var all_units = (grid_field.player_units + grid_field.enemy_units)
	var targets := grid_field.get_units_on_tiles(target_positions, all_units)
	for target in targets:
		if target == unit:
			continue
		target.take_damage(damage)
		target.shake()
		
func on_tile_clicked(
	grid_field: GridField,
	unit: Unit,
	pos: Vector2i
) -> void:
	if not grid_field.tiles.has(pos):
		return

	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return

	grid_field.targeting_skill = false
	grid_field.clear_skill_state()
	unit.grid_position = pos
	var tween := unit.create_tween()

	tween.tween_property(unit, "global_position", grid_field.get_tile_center(pos), 0.1)
	await tween.finished
	var impact_tiles := get_impact_tiles(grid_field, unit.grid_position)
	await grid_field.play_skill_presentation(self, impact_tiles)
	execute(grid_field, unit, impact_tiles, Vector2i.ZERO, leap_distance)
	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()
