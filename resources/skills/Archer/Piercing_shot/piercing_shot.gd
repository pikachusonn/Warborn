extends Skill
class_name Piercing_shot

var free_cast := false

func set_free_cast(value: bool) -> void:
	free_cast = value

func begin(grid_field: GridField, unit: Unit) -> void:
	grid_field.targeting_skill = true

func get_target_tiles(
	grid_field: GridField ,
	unit: Unit,
	direction: Vector2i,
	_distance: int = 1,
) -> Array[Vector2i]:
	var target_tiles:Array[Vector2i] = []
	var step := direction.sign()
	var pos := unit.grid_position + step
	while pos.x >= 0 and pos.x < GridField.WIDTH and pos.y >= 0 and pos.y < GridField.HEIGHT:
		if direction.x == 0 and grid_field.get_projectile_blocker(pos, unit):
			break
		target_tiles.append(pos)
		pos += step
	return target_tiles
	
func update_preview(grid_field: GridField, unit: Unit) -> void:
	var direction := grid_field.get_direction_to_mouse(unit)
	grid_field.show_attack_range(self, unit, direction, 1)

func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	var direction := grid_field.get_direction_to_mouse(unit)
	var target_positions := get_target_tiles(grid_field, unit, direction)
	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return
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
