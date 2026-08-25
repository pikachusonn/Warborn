extends Skill
class_name Rend

func instant_cast() -> bool:
	return true

func execute(
	grid_field: GridField,
	unit: Unit,
	_target_positions: Array[Vector2i],
	_direction: Vector2i,
	_distance: int
):
	var is_ally_archer = unit in grid_field.player_units
	var target_units := (grid_field.enemy_units if is_ally_archer else grid_field.player_units)
	var allies_units := (grid_field.player_units if is_ally_archer else grid_field.enemy_units)
	
	for target in target_units:
		target.take_damage(damage * target.get_status_stacks(Unit.EFFECTS.ENEMY_ARCHER_MARK))
		target.remove_status(Unit.EFFECTS.ENEMY_ARCHER_MARK)
		target.shake()
	for target in allies_units:
		target.heal(5 * target.get_status_stacks(Unit.EFFECTS.ALLY_ARCHER_MARK))
		target.remove_status(Unit.EFFECTS.ALLY_ARCHER_MARK)
		target.shake()
