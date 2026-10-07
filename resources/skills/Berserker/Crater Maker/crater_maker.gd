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
			# Leap over obstructions, but never land on a unit or movement blocker.
			if grid_field.is_tile_occupied(target_position, unit):
				continue

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

func show_preview(
	grid_field: GridField,
	_unit: Unit,
	_direction: Vector2i
) -> void:
	if grid_field.hovered_tile == null or grid_field.hovered_tile not in grid_field.target_tiles:
		grid_field.clear_impact_preview()
		return
	grid_field.show_impact_preview(get_impact_tiles(grid_field, grid_field.hovered_tile.grid_position))
	
func execute(grid_field: GridField, unit: Unit, target_positions: Array[Vector2i], _direction: Vector2i, _distance: int) -> void:
	var all_units = (grid_field.player_units + grid_field.enemy_units)
	var targets := grid_field.get_units_on_tiles(target_positions, all_units)
	for target in targets:
		if target.side == unit.side:
			continue
		target.take_damage(damage)
		target.shake()
	clear_hazards_and_objects(grid_field, target_positions)

func clear_hazards_and_objects(grid_field: GridField, positions: Array[Vector2i]) -> void:
	var all_units = grid_field.player_units + grid_field.enemy_units
	for pos in positions:
		# 1. Clear persistent hazard / AoE zones (Quagmire, Odin's cloud, etc.)
		var effect = grid_field.aoe_tile_owners.get(pos)
		if effect != null:
			if effect.has_method("remove_aoe_position"):
				effect.remove_aoe_position(grid_field, pos)
			else:
				grid_field.release_aoe_position(effect, pos)
				if grid_field.tiles.has(pos):
					grid_field.tiles[pos].clear_aoe()
		elif grid_field.tiles.has(pos):
			grid_field.tiles[pos].clear_aoe()

		# 2. Clear Mud Pillars
		for u in all_units:
			for s in u.skills:
				if s is Mud_Pillar:
					s.remove_pillar(grid_field, pos)

		var blocker = grid_field.movement_blockers.get(pos)
		if blocker != null:
			grid_field.remove_movement_blocker(pos, blocker)
			if is_instance_valid(blocker):
				blocker.queue_free()

		# 3. Clear Hunter's Kit (bouncing pads)
		var pad: Hunter_kit = grid_field.bouncing_pads.get(pos, null)
		if pad != null:
			grid_field.remove_bouncing_pad(pos)
			if is_instance_valid(pad.pad_visual):
				pad.pad_visual.queue_free()
			pad.deployed = false
		
func has_usable_target(_unit: Unit) -> bool:
	return cooldown_remaining <= 0

func on_tile_clicked(
	grid_field: GridField,
	unit: Unit,
	pos: Vector2i
) -> void:
	if cooldown_remaining > 0:
		return
	if not grid_field.tiles.has(pos):
		return

	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return
	# Revalidate at commit time in case the displayed target list is stale.
	if grid_field.is_tile_occupied(pos, unit):
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
	cooldown_remaining = cooldown
	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()

func on_owner_turn_start(_grid: GridField) -> void:
	if cooldown_remaining > 0:
		cooldown_remaining -= 1
