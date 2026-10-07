extends Skill
class_name Chop

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
	var direction := grid_field.get_direction_to_mouse(unit.global_position)
	var blood_lust := BloodLust.get_blood_lust(unit)
	var is_enhanced: bool = blood_lust != null and blood_lust.is_enhanced("chop")
	var distance := 5 if is_enhanced else 3

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
	if not grid_field.tiles.has(pos):
		return

	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return

	var direction := grid_field.get_direction_to_mouse(unit.global_position)
	var target_positions := get_target_tiles(
		grid_field,
		unit,
		direction
	)

	grid_field.targeting_skill = false

	await grid_field.play_skill_presentation(
		self,
		target_positions
	)

	execute(
		grid_field,
		unit,
		target_positions,
		direction,
		1
	)

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
	var blood_lust := BloodLust.get_blood_lust(unit)
	var range_len := 5 if (blood_lust != null and blood_lust.is_enhanced("chop")) else 3
	var target_tiles: Array[Vector2i] = []

	for step in range(1, range_len + 1):
		var pos := unit.grid_position + direction * step
		if not grid_field.tiles.has(pos):
			break
		target_tiles.append(pos)

	return target_tiles

func execute(
	grid_field: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	_direction: Vector2i,
	_distance: int
) -> void:
	var blood_lust := BloodLust.get_blood_lust(unit)
	var exec_info: Dictionary = {}
	if blood_lust != null:
		exec_info = blood_lust.get_preview_data("chop")
	var is_enhanced: bool = exec_info.get("is_enhanced", false)

	var bonus_damage := 0
	if is_enhanced:
		var consumed: int = exec_info.get("stacks", 0)
		var tier: float = exec_info.get("tier_percent", 0.0)
		var max_health: int = unit.data.health if unit.data != null else 100
		var missing_hp: int = max(0, max_health - unit.current_health)
		bonus_damage = 5 * consumed + roundi(tier * float(missing_hp))
	else:
		var current_stacks: int = exec_info.get("stacks", 0)
		bonus_damage = 5 * current_stacks

	var total_damage: int = damage + bonus_damage

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
		target.take_damage(total_damage)
		target.shake()
	if blood_lust != null:
		blood_lust.record_execution("chop", unit)

func get_preview_damage(_grid: GridField, unit: Unit, target: Unit) -> int:
	if target.side == unit.side:
		return 0
	var blood_lust := BloodLust.get_blood_lust(unit)
	if blood_lust == null:
		return damage
	var preview_data: Dictionary = blood_lust.get_preview_data("chop")
	if preview_data.get("is_enhanced", false):
		var s: int = preview_data.get("stacks", 0)
		var tier: float = preview_data.get("tier_percent", 0.0)
		var max_health: int = unit.data.health if unit.data != null else 100
		var missing_hp: int = max(0, max_health - unit.current_health)
		return damage + 5 * s + roundi(tier * float(missing_hp))
	else:
		var s: int = preview_data.get("stacks", 0)
		return damage + 5 * s

func get_preview_healing(_grid: GridField, _unit: Unit, _target: Unit) -> int:
	return 0
