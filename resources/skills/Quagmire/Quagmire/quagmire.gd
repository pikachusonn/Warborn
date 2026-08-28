extends Skill
class_name Quagmire

var mud_pillar_skill: Mud_Pillar
var owner: Unit = null
var hovered_pillar: Vector2i = Vector2i(-1, -1)
var active_zones: Array[Dictionary] = []
var zone_duration := 3
var zone_damage := 10

func begin(grid_field: GridField, unit: Unit) -> void:
	grid_field.targeting_skill = true
	owner = unit
	for skill in unit.skills:
		if skill is Mud_Pillar:
			mud_pillar_skill = skill
			break
	if mud_pillar_skill == null:
		return
	for pos in mud_pillar_skill.active_pillars:
		mud_pillar_skill.highlight_pillar(pos, true)
		
func cancel(grid_field: GridField, _unit: Unit) -> void:
	clear_pillar_highlights()
	grid_field.clear_target_tiles()
	grid_field.clear_skill_state()
	
func clear_pillar_highlights() -> void:
	for pos in mud_pillar_skill.active_pillars:
		mud_pillar_skill.highlight_pillar(pos, false)
		
func get_zone_tiles(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			result.append(center + Vector2i(x, y))
	return result
	
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
		
func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	if not mud_pillar_skill.active_pillars.has(pos):
		return
	var zone_tiles := get_zone_tiles(pos)
	mud_pillar_skill.remove_pillar(grid_field, pos)
	clear_pillar_highlights()
	grid_field.clear_target_tiles()
	create_quagmire_zone(grid_field, zone_tiles)
	grid_field.targeting_skill = false
	grid_field.clean_up_skill()
	grid_field.unit_panel.clear_skill_active()
	
func create_quagmire_zone(grid_field: GridField, zone_tiles: Array[Vector2i]) -> void:
	active_zones.append({ "tiles": zone_tiles, "turns": zone_duration })
	grid_field.add_aoe_effect(self)
	for pos in zone_tiles:
		if grid_field.tiles.has(pos):
			grid_field.tiles[pos].show_quagmire()

func on_owner_turn_start(grid_field: GridField) -> void:
	var expired: Array[Dictionary] = []
	for zone in active_zones:
		zone["turns"] -= 1
		if zone["turns"] <= 0:
			expired.append(zone)
	for zone in expired:
		clear_zone(grid_field, zone)
		
func clear_zone(grid_field: GridField, zone: Dictionary) -> void:
	for pos in zone["tiles"]:
		if grid_field.tiles.has(pos):
			grid_field.tiles[pos].clear_quagmire()

	active_zones.erase(zone)
	
func is_position_in_quagmire(pos: Vector2i) -> bool:
	for zone in active_zones:
		if pos in zone["tiles"]:
			return true
	return false
	
func affects_position(pos: Vector2i) -> bool:
	for zone in active_zones:
		if pos in zone["tiles"]:
			return true
	return false

func on_unit_turn_start(_grid_field: GridField, unit: Unit) -> void:
	if owner == null:
		return
	var same_team := unit.side == owner.side
	if not same_team:
		unit.take_damage(zone_damage)
		unit.shake()
		
func get_mobility(unit: Unit, current_mobility: int) -> int:
	if affects_position(unit.grid_position):
		return min(current_mobility, 1)
	return current_mobility

func blocks_mobility_skills(unit: Unit) -> bool:
	return affects_position(unit.grid_position)
