extends Skill
class_name OdinBlessing

const TARGET_RADIUS: int = 2
@export var zone_duration: int = 2
@export_range(0.0, 1.0) var shield_fraction: float = 0.5
var owner: Unit
var active_zones: Array[Dictionary] = []

func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	if grid_field.energy <= 0 or pos not in get_target_tiles(grid_field, unit, Vector2i.ZERO):
		return
	grid_field.clear_skill_state()
	execute(grid_field, unit, get_impact_tiles(grid_field, pos), pos, 0)
	grid_field.suppress_aoe_hover(get_aoe_zone_tiles(pos))
	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)
	grid_field.unit_panel.clear_skill_active()
	grid_field.clean_up_skill()

func execute(grid_field: GridField, unit: Unit, target_positions: Array[Vector2i], center: Vector2i, _distance: int) -> void:
	owner = unit
	var claimed := grid_field.add_aoe_effect(self, target_positions)
	if claimed.is_empty():
		return
	var cloud := preload("res://scenes/board/odin_cloud.gd").new()
	grid_field.add_child(cloud)
	cloud.setup(center, claimed)
	cloud.set_rounds_left(zone_duration)
	active_zones.append({"tiles": claimed, "turns": zone_duration, "cloud": cloud})
	for pos in claimed:
		grid_field.tiles[pos].show_aoe(TileScene.get_team_aoe_color(unit.side), 0.35)

func remove_aoe_position(grid_field: GridField, pos: Vector2i) -> void:
	for zone in active_zones.duplicate():
		if pos not in zone["tiles"]:
			continue
		zone["tiles"].erase(pos)
		zone["cloud"].set_tiles(zone["tiles"])
		if zone["tiles"].is_empty():
			zone["cloud"].queue_free()
			active_zones.erase(zone)
	if grid_field.tiles.has(pos):
		grid_field.tiles[pos].clear_aoe()
	if active_zones.is_empty():
		grid_field.remove_aoe_effect(self)

func get_aoe_zone_tiles(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for zone in active_zones:
		if pos in zone["tiles"]:
			result.assign(zone["tiles"])
			break
	return result

func affects_position(pos: Vector2i) -> bool:
	return not get_aoe_zone_tiles(pos).is_empty()

func set_zone_hover(positions: Array[Vector2i]) -> void:
	for zone in active_zones:
		var hovered := false
		for pos in positions:
			if pos in zone["tiles"]:
				hovered = true
				break
		zone["cloud"].set_hovered(hovered)

func on_unit_turn_start(_grid_field: GridField, _unit: Unit) -> void:
	pass # Wait through one caster turn, then strike at the following turn start.

func on_owner_turn_start(grid_field: GridField) -> void:
	for zone in active_zones.duplicate():
		zone["turns"] -= 1
		zone["cloud"].set_rounds_left(zone["turns"])
		if zone["turns"] > 0:
			continue
		await grid_field.play_skill_presentation(self, zone["tiles"])
		resolve_zone(grid_field, zone["tiles"])
		grid_field.clear_target_tiles()
		for pos in zone["tiles"]:
			if grid_field.release_aoe_position(self, pos) and grid_field.tiles.has(pos):
				grid_field.tiles[pos].clear_aoe()
		zone["cloud"].queue_free()
		active_zones.erase(zone)
	if active_zones.is_empty():
		grid_field.remove_aoe_effect(self)

func resolve_zone(grid_field: GridField, positions: Array[Vector2i]) -> void:
	if not is_instance_valid(owner):
		return
	for target in grid_field.player_units + grid_field.enemy_units:
		if target.is_defeated() or target == owner or target.grid_position not in positions:
			continue
		if target.side == owner.side:
			continue
		target.take_damage(damage)
		target.shake()
	if not owner.is_defeated() and owner.grid_position in positions:
		owner.add_temp_health(roundi(owner.data.health * shield_fraction), grid_field)
		owner.shake()

func begin(
	grid_field: GridField,
	_unit: Unit
) -> void:
	if(grid_field.energy == 0):
		grid_field.end_turn()
		return
	grid_field.targeting_skill = true
	
func update_preview(
	grid_field: GridField,
	unit: Unit
) -> void:
	grid_field.show_attack_range(self, unit, Vector2i.ZERO, TARGET_RADIUS)
	
func get_target_tiles(grid_field: GridField, unit: Unit, _direction: Vector2i, _distance: int = TARGET_RADIUS) -> Array[Vector2i]:
	var target_positions: Array[Vector2i] = []
	for x in range(-TARGET_RADIUS, TARGET_RADIUS + 1):
		for y in range(-TARGET_RADIUS, TARGET_RADIUS + 1):
			var target_position := (unit.grid_position + Vector2i(x, y))
			if grid_field.tiles.has(target_position):
				target_positions.append(target_position)
	return target_positions
	
func show_preview(
	grid_field: GridField,
	_unit: Unit,
	_direction: Vector2i
) -> void:
	if grid_field.hovered_tile == null:
		grid_field.clear_impact_preview()
		return
	if grid_field.hovered_tile not in grid_field.target_tiles:
		grid_field.clear_impact_preview()
		return
	var center := grid_field.hovered_tile.grid_position
	var impact_positions := get_impact_tiles(grid_field, center)
	grid_field.show_impact_preview(impact_positions)
	
func get_impact_tiles(grid_field: GridField, center: Vector2i) -> Array[Vector2i]:
	var impact_positions: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			var position := center + Vector2i(x, y)

			if grid_field.tiles.has(position):
				impact_positions.append(position)
	return impact_positions
	
func cancel(grid_field: GridField, _unit: Unit) -> void:
	grid_field.clear_skill_state()
