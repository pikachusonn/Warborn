extends Skill
class_name Bullwark

var active_shield: Line2D = null
var owner: Unit = null
var blocked_tiles: Array[Vector2i]

func instant_cast() -> bool:
	return true

func show_preview(
	grid: GridField,
	unit: Unit,
	direction: Vector2i
):
	# Remove any existing preview first.
	clear_preview(grid)

	var shield_line := create_shield_visual(grid, unit)

	if shield_line == null:
		return

	grid.skill_preview_nodes.append(shield_line)


func execute(
	grid: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	direction: Vector2i,
	distance: int
):
	# Remove this Breacher's previous Bulwark.
	clear_bulwark(grid)

	owner = unit
	active_shield = create_shield_visual(grid, unit)


func create_shield_visual(
	grid: GridField,
	unit: Unit
) -> Line2D:
	var center := unit.grid_position

	# Grid Y increases downward.
	# Therefore y - 1 is visually above Breacher.
	var shield_y: int
	var is_ally = unit in grid.player_units
	if is_ally:
		shield_y = center.y - 1
	else:
		shield_y = center.y

	shield_y = clamp(shield_y, 0, 9)

	var left_tile := Vector2i(
		center.x - 1,
		shield_y if !is_ally else shield_y + 1
	)

	var right_tile := Vector2i(
		center.x + 1,
		shield_y if !is_ally else shield_y + 1
	)
	blocked_tiles = [left_tile, center, right_tile]
	for tile in blocked_tiles:
		grid.add_projectile_blocker(tile, self)
	if not grid.tiles.has(left_tile):
		return null

	if not grid.tiles.has(right_tile):
		return null

	var left_position = (
		grid.tiles[left_tile].global_position
		+ Vector2(32, 32)
	)

	var right_position = (
		grid.tiles[right_tile].global_position
		+ Vector2(32, 32)
	)

	# Extend to the outer edges of the 3 tiles.
	left_position.x -= 32
	right_position.x += 32

	# Move the line closer to Breacher.
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


func clear_bulwark(grid: GridField):
	if is_instance_valid(active_shield):
		active_shield.queue_free()
	for tile in blocked_tiles:
		grid.remove_projectile_blocker(tile)
	blocked_tiles = []
	active_shield = null
	owner = null

func clear_preview(grid: GridField):
	for node in grid.skill_preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	grid.skill_preview_nodes.clear()

func on_owner_turn_start(grid: GridField):
	clear_bulwark(grid)
