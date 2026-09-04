extends Skill
class_name Rupture

var mud_pillar_skill: Mud_Pillar
var hovered_pillar: Vector2i = Vector2i(-1, -1)
@export var temp_health := 30
func begin(grid_field: GridField, unit: Unit) -> void:
	grid_field.targeting_skill = true
	for skill in unit.skills:
		if skill is Mud_Pillar:
			mud_pillar_skill = skill
			break
	if mud_pillar_skill == null:
		return
	for pos in mud_pillar_skill.active_pillars:
		mud_pillar_skill.highlight_pillar(pos, true)    
		
func update_preview(grid_field: GridField, _unit: Unit) -> void:
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
	var zone_tiles := get_zone_tiles(grid_pos)
	for pos in zone_tiles:
		if not grid_field.tiles.has(pos):
			continue
		var tile = grid_field.tiles[pos]
		tile.set_attackable(true)
		grid_field.target_tiles.append(tile)
		
func get_zone_tiles(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			result.append(center + Vector2i(x, y))
	return result

func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	if mud_pillar_skill == null:
		return
	if not mud_pillar_skill.active_pillars.has(pos):
		return
	var target_positions := get_zone_tiles(pos)
	grid_field.targeting_skill = false
	mud_pillar_skill.remove_pillar(grid_field, pos)
	await grid_field.play_skill_presentation(self, target_positions)
	await execute(grid_field, unit, target_positions, Vector2i.ZERO, 1)
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()

func execute(grid_field: GridField, unit: Unit, target_positions: Array[Vector2i], _direction: Vector2i, _distance: int) -> void:
	var all_units = grid_field.player_units + grid_field.enemy_units
	for target in all_units:
		if target.grid_position not in target_positions:
			continue
		if target.side == unit.side:
			target.add_temp_health(temp_health, grid_field)
		else:
			target.take_damage(damage)
		target.shake()
