extends Skill
class_name Cleave

const HEALING_TIERS := [0.0, 0.50, 0.55, 0.70, 0.85, 1.0]

func get_stack_healing(stacks: int) -> int:
	return 5 + 5 * stacks if stacks > 0 else 0

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
	var blood_lust := BloodLust.get_blood_lust(unit)
	var is_enhanced: bool = blood_lust != null and blood_lust.is_enhanced("cleave")

	if is_enhanced:
		grid_field.clear_move_range()
		grid_field.clear_target_tiles()
		var targets := get_enhanced_target_tiles(grid_field, unit)
		for target in targets:
			if not grid_field.tiles.has(target):
				continue
			var tile = grid_field.tiles[target]
			tile.set_attackable(true)
			grid_field.target_tiles.append(tile)
		show_preview(grid_field, unit, Vector2i.ZERO)
	else:
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
	if blood_lust != null and blood_lust.is_enhanced("cleave"):
		return get_enhanced_target_tiles(grid_field, unit)
	return get_normal_target_tiles(grid_field, unit, direction)

func get_normal_target_tiles(
	_grid_field: GridField,
	unit: Unit,
	direction: Vector2i
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

func get_enhanced_target_tiles(
	grid_field: GridField,
	unit: Unit
) -> Array[Vector2i]:
	var target_tiles: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var pos := unit.grid_position + Vector2i(x, y)
			if grid_field.tiles.has(pos):
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
		exec_info = blood_lust.get_preview_data("cleave")
	var is_enhanced: bool = exec_info.get("is_enhanced", false)

	var units := (
		grid_field.enemy_units
		if unit in grid_field.player_units
		else grid_field.player_units
	)

	var targets := grid_field.get_units_on_tiles(
		target_positions,
		units
	)

	var total_damage_dealt := 0
	for target in targets:
		var health_before: int = target.current_health
		target.take_damage(damage)
		target.shake()
		var actual_damage: int = (health_before - max(target.current_health, 0))
		total_damage_dealt += actual_damage

	var heal_amount := 0
	if is_enhanced:
		var consumed: int = exec_info.get("stacks", 0)
		var tier: float = HEALING_TIERS[consumed]
		heal_amount = get_stack_healing(consumed) + roundi(tier * float(total_damage_dealt))
	else:
		var current_stacks: int = exec_info.get("stacks", 0)
		heal_amount = get_stack_healing(current_stacks)

	if heal_amount > 0:
		unit.heal(heal_amount)
		unit.shake()
	if blood_lust != null:
		blood_lust.record_execution("cleave", unit)

func get_preview_damage(_grid: GridField, unit: Unit, target: Unit) -> int:
	return damage if target.side != unit.side else 0

func get_preview_healing(grid: GridField, unit: Unit, target: Unit) -> int:
	if target != unit:
		return 0
	var blood_lust := BloodLust.get_blood_lust(unit)
	if blood_lust == null:
		return 0
	var preview_data: Dictionary = blood_lust.get_preview_data("cleave")
	if preview_data.get("is_enhanced", false):
		var s: int = preview_data.get("stacks", 0)
		var tier: float = HEALING_TIERS[s]
		var total_damage_dealt := 0
		var preview_tiles := grid.impact_preview_tiles if not grid.impact_preview_tiles.is_empty() else grid.target_tiles
		var positions: Array[Vector2i] = []
		for tile in preview_tiles:
			positions.append(tile.grid_position)
		var enemies := grid.enemy_units if unit in grid.player_units else grid.player_units
		for enemy in grid.get_units_on_tiles(positions, enemies):
			total_damage_dealt += mini(enemy.current_health, maxi(damage - maxi(enemy.temp_health, 0), 0))
		return get_stack_healing(s) + roundi(tier * float(total_damage_dealt))
	else:
		var s: int = preview_data.get("stacks", 0)
		return get_stack_healing(s)
