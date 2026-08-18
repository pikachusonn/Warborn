extends Skill
class_name Bullwark

func instant_cast() -> bool:
	return true

func show_preview(
	grid: GridField,
	unit: Unit,
	direction: Vector2i
):
	var center := unit.grid_position

	var shield_y = clamp(center.y - 1, 0, 9)

	var left_tile := Vector2i(center.x - 1, shield_y)
	var right_tile := Vector2i(center.x + 1, shield_y)

	if not grid.tiles.has(left_tile):
		return

	if not grid.tiles.has(right_tile):
		return

	var left_position = (
		grid.tiles[left_tile].global_position
		+ Vector2(32, 32)
	)

	var right_position = (
		grid.tiles[right_tile].global_position
		+ Vector2(32, 32)
	)
	left_position.x -= 32
	right_position.x += 32
	# Move the line closer to Breacher
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
	grid.skill_preview_nodes.append(shield_line)

func execute(
	grid: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	direction: Vector2i,
	distance: int
):
	var center := unit.grid_position

	# Three tiles wide, positioned one tile above Breacher.
	var left_tile := center + Vector2i(-1, 1)
	var right_tile := center + Vector2i(1, 1)

	# Make sure both edge tiles exist before creating the visual.
	if not grid.tiles.has(left_tile):
		return

	if not grid.tiles.has(right_tile):
		return

	var left_position: Vector2 = (
		grid.tiles[left_tile].global_position
		+ Vector2(32, 32)
	)

	var right_position: Vector2 = (
		grid.tiles[right_tile].global_position
		+ Vector2(32, 32)
	)

	# Create the shield line.
	var shield_line := Line2D.new()

	shield_line.width = 8.0
	shield_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shield_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	shield_line.add_point(left_position)
	shield_line.add_point(right_position)

	grid.add_child(shield_line)
