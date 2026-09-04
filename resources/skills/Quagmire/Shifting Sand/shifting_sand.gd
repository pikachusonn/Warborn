extends Skill
class_name ShiftingSand

enum Stage { PILLAR, DIRECTION }

var mud_pillar_skill: Mud_Pillar
var owner: Unit = null
var stage := Stage.PILLAR
var selected_pillar := Vector2i(-1, -1)
var hovered_pillar := Vector2i(-1, -1)

func begin(grid_field: GridField, unit: Unit) -> void:
	grid_field.targeting_skill = true
	owner = unit
	stage = Stage.PILLAR
	selected_pillar = Vector2i(-1, -1)
	hovered_pillar = Vector2i(-1, -1)

	for skill in unit.skills:
		if skill is Mud_Pillar:
			mud_pillar_skill = skill
			break

	if mud_pillar_skill == null:
		return

	for pos in mud_pillar_skill.active_pillars:
		mud_pillar_skill.highlight_pillar(pos, true)

func update_preview(grid_field: GridField, _unit: Unit) -> void:
	if mud_pillar_skill == null:
		return

	if stage == Stage.PILLAR:
		update_pillar_preview(grid_field)
	else:
		update_direction_preview(grid_field)

func update_pillar_preview(grid_field: GridField) -> void:
	var mouse_pos := grid_field.get_global_mouse_position()
	var local_mouse := grid_field.to_local(mouse_pos)
	var grid_pos := Vector2i(local_mouse / GridField.TILE_SIZE)

	if not mud_pillar_skill.active_pillars.has(grid_pos):
		if hovered_pillar != Vector2i(-1, -1):
			grid_field.clear_target_tiles()
			hovered_pillar = Vector2i(-1, -1)
		return

	if hovered_pillar == grid_pos:
		return

	hovered_pillar = grid_pos
	grid_field.clear_target_tiles()

	var tile = grid_field.tiles[grid_pos]
	tile.set_attackable(true)
	grid_field.target_tiles.append(tile)

func update_direction_preview(grid_field: GridField) -> void:
	var direction := get_pillar_direction(grid_field)
	var line_tiles := get_line_tiles(grid_field, direction)

	grid_field.clear_target_tiles()

	for pos in line_tiles:
		var tile = grid_field.tiles[pos]
		tile.set_attackable(true)
		grid_field.target_tiles.append(tile)

func get_pillar_direction(grid_field: GridField) -> Vector2i:
	var pillar_world := grid_field.get_tile_center(selected_pillar)
	return grid_field.get_direction_to_mouse(pillar_world)

func get_line_tiles(grid_field: GridField, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if direction.x != 0:
		for x in range(GridField.WIDTH):
			var pos := Vector2i(x, selected_pillar.y)
			if grid_field.tiles.has(pos):
				result.append(pos)
	else:
		for y in range(GridField.HEIGHT):
			var pos := Vector2i(selected_pillar.x, y)
			if grid_field.tiles.has(pos):
				result.append(pos)
	return result
	
func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	if stage == Stage.PILLAR:
		if mud_pillar_skill == null:
			return
		if not mud_pillar_skill.active_pillars.has(pos):
			return

		selected_pillar = pos
		stage = Stage.DIRECTION
		grid_field.clear_target_tiles()

		for pillar_pos in mud_pillar_skill.active_pillars:
			mud_pillar_skill.highlight_pillar(pillar_pos, false)

		return

	if stage == Stage.DIRECTION:
		var direction := get_pillar_direction(grid_field)
		var line_tiles := get_line_tiles(grid_field, direction)

		if pos not in line_tiles:
			return

		grid_field.targeting_skill = false
		grid_field.clear_target_tiles()

		mud_pillar_skill.remove_pillar(grid_field, selected_pillar)

		await execute(grid_field, unit, line_tiles, direction, 5)

		grid_field.clean_up_skill()
		grid_field.unit_panel.clear_skill_active()
		
func execute(grid_field: GridField, _unit: Unit, target_positions: Array[Vector2i], direction: Vector2i, distance: int) -> void:
	var all_units = grid_field.player_units + grid_field.enemy_units

	for target in all_units:
		if target.grid_position not in target_positions:
			continue
		var destination = target.grid_position
		for step in range(distance):
			var next_pos = destination + direction
			if not grid_field.tiles.has(next_pos):
				break
			var occupied := false
			for other in all_units:
				if other != target && other.grid_position == next_pos:
					occupied = true
					break
			if occupied:
				break
			destination = next_pos
		if destination == target.grid_position:
			continue
		target.grid_position = destination
		target.global_position = grid_field.get_tile_center(destination)
