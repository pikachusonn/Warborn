extends Skill
class_name Hunter_kit

var deployed := false
var pad_position: Vector2i
var owner: Unit = null

var cooldown := 0
var pad_visual: Polygon2D = null

func begin(
	grid_field: GridField,
	unit: Unit
) -> void:
	owner = unit
	grid_field.targeting_skill = true
	grid_field.clear_skill_state()

	if not deployed:
		show_deploy_tiles(grid_field)
	else:
		show_reposition_tiles(grid_field)
		pass
		
func show_deploy_tiles(
	grid_field: GridField
) -> void:
	var all_units = grid_field.player_units + grid_field.enemy_units

	for pos in grid_field.tiles:
		var occupied := false
		for unit in all_units:
			if unit.grid_position == pos:
				occupied = true
				break
		if occupied:
			continue
		var tile = grid_field.tiles[pos]
		tile.set_attackable(true)
		grid_field.target_tiles.append(tile)
		
func show_reposition_tiles(grid_field: GridField) -> void:
	show_deploy_tiles(grid_field)
	
func deploy_pad(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	deployed = true
	pad_position = pos
	owner = unit
	cooldown = 3
	create_pad_visual(grid_field)
	grid_field.add_bouncing_pad(pad_position, self)
	# Initial deployment costs the action
	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)

	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()
	
func create_pad_visual(grid_field: GridField) -> void:
	if is_instance_valid(pad_visual):
		pad_visual.queue_free()
	if not grid_field.tiles.has(pad_position):
		return
		
	var pad := Polygon2D.new()

	pad.polygon = PackedVector2Array([
		Vector2(-20, -10),
		Vector2(20, -10),
		Vector2(20, 10),
		Vector2(-20, 10)
	])

	pad.color = Color(0.318, 0.875, 0.13, 1.0)
	pad.z_index = 500
	grid_field.add_child(pad)
	pad.global_position = grid_field.get_tile_center(pad_position)
	pad_visual = pad

func reposition_pad(
	grid_field: GridField,
	pos: Vector2i
) -> void:
	if cooldown > 0:
		return
	grid_field.remove_bouncing_pad(pad_position)
	pad_position = pos
	grid_field.add_bouncing_pad(pad_position, self)
	cooldown = 3
	create_pad_visual(grid_field)
	# NO energy deduction
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()

func execute(
	grid_field: GridField,
	unit: Unit,
	target_positions: Array[Vector2i],
	_direction: Vector2i,
	_distance: int
) -> void:
	if target_positions.is_empty():
		return
	var pos := target_positions[0]
	if not deployed:
		deploy_pad(grid_field, unit, pos)
	else:
		reposition_pad(grid_field, pos)

func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	if not grid_field.tiles.has(pos):
		return
	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return
	await execute(grid_field, unit, [pos], Vector2i.ZERO, 1)
