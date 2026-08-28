extends Skill
class_name Bullwark

var active_shield: Line2D = null
var owner: Unit = null
var blocked_tiles: Array[Vector2i] = []

func instant_cast() -> bool:
	return true

func begin(
	grid: GridField,
	unit: Unit
) -> void:
	if(grid.energy == 0):
		grid.end_turn()
		return
	grid.targeting_skill = true
	show_preview(grid, unit, Vector2i.ZERO)


func update_preview(
	_grid: GridField,
	_unit: Unit
) -> void:
	pass


func on_tile_clicked(
	grid: GridField,
	unit: Unit,
	_pos: Vector2i
) -> void:
	grid.targeting_skill = false
	print("hehehe")
	await execute(grid, unit, [], Vector2i.ZERO, 1)
	grid.energy -= 1
	grid.unit_panel.update_energy(grid.energy)

	clear_preview(grid)

	grid.clean_up_skill()
	grid.unit_panel.clear_skill_active()


func cancel(
	grid: GridField,
	_unit: Unit
) -> void:
	clear_preview(grid)
	grid.clear_skill_state()


func show_preview(
	grid: GridField,
	unit: Unit,
	_direction: Vector2i
) -> void:
	clear_preview(grid)

	var shield_line := create_shield_visual(
		grid,
		unit,
		false
	)

	if shield_line == null:
		return

	grid.skill_preview_nodes.append(shield_line)


func execute(
	grid: GridField,
	unit: Unit,
	_target_positions: Array[Vector2i],
	_direction: Vector2i,
	_distance: int
) -> void:
	clear_bulwark(grid)

	owner = unit

	active_shield = create_shield_visual(
		grid,
		unit,
		true
	)


func create_shield_visual(
	grid: GridField,
	unit: Unit,
	register_blocker: bool
) -> Line2D:
	var center := unit.grid_position
	var is_ally := unit in grid.player_units

	var shield_y: int

	if is_ally:
		shield_y = center.y - 1
	else:
		shield_y = center.y

	shield_y = clamp(shield_y, 0, GridField.HEIGHT - 1)

	var left_tile := Vector2i(
		center.x - 1,
		shield_y if not is_ally else shield_y + 1
	)

	var right_tile := Vector2i(
		center.x + 1,
		shield_y if not is_ally else shield_y + 1
	)

	var current_blocked_tiles: Array[Vector2i] = [
		left_tile,
		center,
		right_tile
	]

	if not grid.tiles.has(left_tile):
		return null

	if not grid.tiles.has(right_tile):
		return null

	if register_blocker:
		blocked_tiles = current_blocked_tiles

		for tile in blocked_tiles:
			grid.add_projectile_blocker(
				tile,
				self
			)

	var left_position := (
		grid.tiles[left_tile].global_position
		+ Vector2(32, 32)
	)

	var right_position := (
		grid.tiles[right_tile].global_position
		+ Vector2(32, 32)
	)

	left_position.x -= 32
	right_position.x += 32

	if is_ally:
		left_position.y -= 32
		right_position.y -= 32
	else:
		left_position.y += 32
		right_position.y += 32

	var shield_line := Line2D.new()

	shield_line.width = 5.0
	shield_line.default_color = Color(1.0, 0.8, 0.3)
	shield_line.z_index = 999
	shield_line.top_level = true

	shield_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shield_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	shield_line.add_point(left_position)
	shield_line.add_point(right_position)

	grid.add_child(shield_line)

	return shield_line


func clear_bulwark(
	grid: GridField
) -> void:
	if is_instance_valid(active_shield):
		active_shield.queue_free()

	for tile in blocked_tiles:
		grid.remove_projectile_blocker(tile)

	blocked_tiles.clear()

	active_shield = null
	owner = null


func clear_preview(
	grid: GridField
) -> void:
	for node in grid.skill_preview_nodes:
		if is_instance_valid(node):
			node.queue_free()

	grid.skill_preview_nodes.clear()


func on_owner_turn_start(
	grid: GridField
) -> void:
	clear_bulwark(grid)
	
func update_position(grid: GridField) -> void:
	if owner == null:
		return
	if not is_instance_valid(active_shield):
		return
	var current_owner := owner
	clear_bulwark(grid)
	owner = current_owner
	active_shield = create_shield_visual(grid, owner, true)
