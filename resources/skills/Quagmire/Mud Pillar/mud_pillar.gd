extends Skill
class_name Mud_Pillar

var owner: Unit = null
var active_pillars: Dictionary[Vector2i, Node2D] = {}
var max_pillars := 3
var pillar_duration := 3
var range := 5

func begin(grid_field: GridField, unit: Unit) -> void:
	owner = unit
	grid_field.targeting_skill = true
	show_valid_tiles(grid_field, unit)

func show_valid_tiles(grid_field: GridField, unit: Unit) -> void:
	grid_field.clear_target_tiles()
	var max_range := 5
	var all_units = grid_field.player_units + grid_field.enemy_units
	for pos in grid_field.tiles:
		if unit.grid_position.distance_to(pos) > max_range:
			continue
		var occupied := false
		for target in all_units:
			if target.grid_position == pos:
				occupied = true
				break
		if occupied:
			continue
		var tile = grid_field.tiles[pos]
		tile.set_attackable(true)
		grid_field.target_tiles.append(tile)
		
func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	if not grid_field.tiles.has(pos):
		return
	if grid_field.tiles[pos] not in grid_field.target_tiles:
		return
	if active_pillars.size() >= max_pillars:
		return
	await execute(grid_field, unit, [pos], Vector2i.ZERO, 1)
	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()
	
func execute(grid_field: GridField, unit: Unit, target_positions: Array[Vector2i], _direction: Vector2i, _distance: int) -> void:
	if target_positions.is_empty():
		return
	var pos := target_positions[0]
	# add movement blocker to grid
	create_pillar_visual(grid_field, pos)
	
func create_pillar_visual(grid_field: GridField, pos: Vector2i) -> void:
	if not grid_field.tiles.has(pos):
		return
	var pillar := Polygon2D.new()
	pillar.polygon = PackedVector2Array([Vector2(-18, -28), Vector2(18, -28), Vector2(24, 20), Vector2(-24, 20)])
	pillar.color = Color(0.45, 0.28, 0.12)
	pillar.z_index = 500
	grid_field.add_child(pillar)
	pillar.global_position = grid_field.get_tile_center(pos)
	active_pillars[pos] = pillar
