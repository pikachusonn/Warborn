extends RefCounted
## Only the host runs rules. These snapshots give the client state to display,
## including legal target tiles; they never deserialize Objects or execute skills.
const SKILL_FIELDS := ["cooldown_remaining", "damage", "execute_damage_bonus", "deployed", "stage", "free_cast", "stacks", "last_attack"]
var grid: GridField
var markers: Node2D
var health_views: Dictionary = {}
var replica_zones: Array[Dictionary] = []
var replica_clouds: Dictionary = {}

func _init(board: GridField) -> void:
	grid = board

func capture() -> Dictionary:
	var units: Array = grid.player_units + grid.enemy_units
	var state: Dictionary = {}
	var active_id := grid.active_unit.network_id if grid.active_unit else -1
	var skill_index := grid.active_unit.skills.find(grid.active_skill) if grid.active_unit else -1
	var availability: Array[bool] = []
	for index in 4:
		availability.append(grid.can_use_skill(index))
	state["combat"] = {
		"active": active_id, "turn": grid.turn_index, "round": grid.round_number, "energy": grid.energy,
		"free": grid.free_movement, "action": grid.current_action,
		"skill": skill_index, "targeting": grid.targeting_skill,
		"resolving": grid.resolving_turn_start, "presenting": grid.presenting_skill,
		"menu": grid.radial_skills_open, "availability": availability,
		"targets": _positions(grid.target_tiles), "impact": _positions(grid.impact_preview_tiles),
	}
	for unit: Unit in units:
		var skills: Array = []
		for skill in unit.skills:
			var fields: Dictionary = {}
			for key in SKILL_FIELDS:
				var value = skill.get(key)
				if value != null:
					fields[key] = value
			skills.append(fields)
		state["unit_%d" % unit.network_id] = {
			"tile": unit.grid_position, "position": unit.position,
			"health": unit.current_health, "shield": unit.temp_health,
			"statuses": unit.status_effects.duplicate(), "skills": skills,
			"selected": unit.is_selected, "modulate": unit.modulate,
			"sprite_modulate": unit.sprite.modulate, "sprite_visible": unit.sprite.visible,
			"z": unit.z_index,
			"preview_damage": unit.preview_damage, "preview_healing": unit.preview_healing,
			"has_captured": unit.has_completed_capture,
		}
	var tile_states: Array = []
	for x in GridField.WIDTH:
		for y in GridField.HEIGHT:
			var tile: TileScene = grid.tiles[Vector2i(x, y)]
			tile_states.append([tile.modulate, tile.quagmire_overlay.visible,
				tile.quagmire_overlay.texture.resource_path if tile.quagmire_overlay.texture else "",
				tile.quagmire_overlay.modulate, tile.aoe_overlay.visible, tile.aoe_base_color,
				tile.highlight_color])
	state["tiles"] = tile_states
	state["markers"] = _capture_markers()
	if grid.capture_zone != null:
		state["capture"] = {
			"state": grid.capture_zone.state,
			"unit": grid.capture_zone.capturing_unit.network_id if is_instance_valid(grid.capture_zone.capturing_unit) else -1,
			"team": grid.capture_zone.capturing_team,
			"progress": grid.capture_zone.capture_turns_completed,
			"points": grid.capture_zone.team_capture_points.duplicate(),
			"ended": grid.match_ended,
			"winner": grid.winning_team,
			"win_reason": grid.win_reason
		}
	# Canonical world facts are useful to inspect without rerunning client rules.
	var world: Dictionary = {"movement_blockers": grid.movement_blockers.keys(), "projectile_blockers": grid.projectile_blockers.keys(), "pads": grid.bouncing_pads.keys(), "zones": []}
	for effect in grid.active_aoe_effects:
		for zone in effect.active_zones:
			var zone_state := {"owner": effect.owner.network_id, "skill": effect.owner.skills.find(effect), "tiles": zone.tiles.duplicate(), "turns": zone.turns}
			if effect is OdinBlessing:
				zone_state["kind"] = "odin_cloud"
				zone_state["id"] = zone.get("id", 0)
				zone_state["center"] = zone.get("center", zone.tiles[0])
			world.zones.append(zone_state)
	state["world"] = world
	return state

func _positions(tiles: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile in tiles:
		result.append(tile.grid_position)
	return result

func apply(state: Dictionary) -> void:
	var combat: Dictionary = state.combat
	var units: Array = grid.player_units + grid.enemy_units
	var previous_active: Unit = grid.active_unit
	grid.active_unit = units[combat.active] if combat.active >= 0 else null
	if previous_active != grid.active_unit and is_instance_valid(grid.offscreen_hud):
		grid.offscreen_hud.on_turn_started(grid.active_unit)
	grid.radial_menu_owner = grid.active_unit
	grid.turn_index = combat.turn
	if combat.has("round"):
		grid.round_number = combat.round
	grid.energy = combat.energy
	grid.free_movement = combat.free
	grid.current_action = combat.action
	grid.active_skill = grid.active_unit.skills[combat.skill] if grid.active_unit and combat.skill >= 0 else null
	grid.targeting_skill = combat.targeting
	if GridField.is_mobile():
		if grid.targeting_skill and grid.active_skill and is_instance_valid(grid.active_unit):
			var names := [grid.active_unit.data.skill1_name, grid.active_unit.data.skill2_name, grid.active_unit.data.skill3_name, grid.active_unit.data.skill4_name]
			var display_name: String = names[combat.skill] if combat.skill < names.size() else grid.active_skill.skill_name
			grid.show_mobile_skill_tooltip(grid.active_skill, display_name)
		elif not grid.targeting_skill:
			grid.hide_mobile_skill_tooltip()
	grid.resolving_turn_start = combat.resolving
	if not grid.presenting_skill:
		grid.presenting_skill = combat.presenting
	grid.radial_skills_open = combat.menu
	grid.remote_skill_availability.assign(combat.availability)
	if not grid.presenting_skill:
		grid.target_tiles.clear()
		for pos in combat.targets:
			grid.target_tiles.append(grid.tiles[pos])
		grid.impact_preview_tiles.clear()
		for pos in combat.impact:
			grid.impact_preview_tiles.append(grid.tiles[pos])
	for unit: Unit in units:
		var data: Dictionary = state["unit_%d" % unit.network_id]
		var previous_health := unit.current_health
		unit.grid_position = data.tile
		if not unit.is_shaking:
			unit.position = data.position
		unit.current_health = data.health
		unit.temp_health = data.shield
		unit.status_effects = data.statuses.duplicate()
		for index in unit.skills.size():
			for key in data.skills[index]:
				if key in SKILL_FIELDS:
					unit.skills[index].set(key, data.skills[index][key])
		unit.modulate = data.modulate
		unit.sprite.modulate = data.sprite_modulate
		unit.sprite.visible = data.sprite_visible
		unit.z_index = data.z
		unit.set_selected(data.selected)
		unit.update_status_icons()
		unit.has_completed_capture = data.get("has_captured", false)
		health_views[unit.network_id] = data
		if previous_health > 0 and data.health < previous_health:
			unit.shake()
	update_health_display()
	if state.has("capture") and grid.capture_zone != null:
		var cap: Dictionary = state.capture
		grid.capture_zone.state = cap.state
		grid.capture_zone.capturing_unit = units[cap.unit] if (cap.unit >= 0 and cap.unit < units.size()) else null
		grid.capture_zone.capturing_team = cap.team
		grid.capture_zone.capture_turns_completed = cap.progress
		grid.capture_zone.team_capture_points = {
			Unit.Side.PLAYER: int(cap.points.get(Unit.Side.PLAYER, cap.points.get("0", 0))),
			Unit.Side.ENEMY: int(cap.points.get(Unit.Side.ENEMY, cap.points.get("1", 0)))
		}
		grid.capture_zone.update_zone_visuals()
		grid.capture_zone.capture_state_changed.emit()
		if cap.ended and not grid.match_ended:
			grid.end_match(cap.winner, cap.win_reason)
	var index := 0
	for x in GridField.WIDTH:
		for y in GridField.HEIGHT:
			var tile: TileScene = grid.tiles[Vector2i(x, y)]
			var data: Array = state.tiles[index]
			index += 1
			if not grid.presenting_skill:
				tile.modulate = data[0]
			if data[1]:
				if tile.quagmire_overlay.texture == null or tile.quagmire_overlay.texture.resource_path != data[2]:
					tile.show_quagmire(Unit.Side.PLAYER, load(data[2]))
			tile.quagmire_overlay.visible = data[1]
			tile.quagmire_overlay.modulate = data[3]
			tile.aoe_overlay.visible = data[4]
			tile.aoe_base_color = data[5]
			tile.aoe_overlay.color = data[5]
			tile.highlight_color = data[6]
			tile.queue_redraw()
	grid.update_radial_menu()
	if grid.active_unit:
		grid.unit_panel.show_unit(grid.active_unit)
		grid.unit_panel.update_energy(grid.energy)
		grid.unit_panel.clear_skill_active()
		if combat.skill >= 0:
			grid.unit_panel.set_skill_active([grid.unit_panel.skill1_button, grid.unit_panel.skill2_button, grid.unit_panel.skill3_button, grid.unit_panel.skill4_button][combat.skill])
		elif combat.action == GridField.Action.MOVE:
			grid.unit_panel.set_skill_active(grid.unit_panel.move_button)
	else:
		grid.unit_panel.hide()
	if not is_instance_valid(markers):
		markers = preload("res://network/replica_markers.gd").new()
		grid.add_child(markers)
	markers.set_markers(state.markers)
	_sync_replica_zones(state.world.zones)

func _sync_replica_zones(zones: Array) -> void:
	replica_zones.clear()
	var live_clouds: Dictionary = {}
	for zone_value in zones:
		var zone: Dictionary = zone_value
		replica_zones.append(zone.duplicate(true))
		if zone.get("kind", "") != "odin_cloud":
			continue
		var key := "%d:%d:%d" % [zone.owner, zone.skill, zone.get("id", 0)]
		var cloud = replica_clouds.get(key)
		if not is_instance_valid(cloud):
			cloud = preload("res://scenes/board/odin_cloud.gd").new()
			grid.add_child(cloud)
			cloud.setup(zone.center, zone.tiles)
			replica_clouds[key] = cloud
		else:
			cloud.set_tiles(zone.tiles)
		cloud.set_rounds_left(zone.turns)
		live_clouds[key] = true
	for key in replica_clouds.keys():
		if not live_clouds.has(key):
			var cloud = replica_clouds[key]
			if is_instance_valid(cloud):
				cloud.queue_free()
			replica_clouds.erase(key)

func get_replica_zone_tiles(position: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for zone in replica_zones:
		if position in zone.tiles:
			result.assign(zone.tiles)
			break
	return result

func set_replica_zone_hover(positions: Array[Vector2i]) -> void:
	for index in replica_zones.size():
		var zone := replica_zones[index]
		if zone.get("kind", "") != "odin_cloud":
			continue
		var key := "%d:%d:%d" % [zone.owner, zone.skill, zone.get("id", 0)]
		var cloud = replica_clouds.get(key)
		if not is_instance_valid(cloud):
			continue
		var hovered := false
		for position in positions:
			if position in zone.tiles:
				hovered = true
				break
		cloud.set_hovered(hovered)

func update_health_display() -> void:
	# Mirror shared combat feedback, while allowing private local unit inspection.
	var local_mouse := grid.to_local(grid.get_local_mouse_board_position())
	var hovered_tile := Vector2i((local_mouse / GridField.TILE_SIZE).floor())
	if not grid.tiles.has(hovered_tile):
		hovered_tile = Vector2i(-1000, -1000)
	for unit: Unit in grid.player_units + grid.enemy_units:
		if not health_views.has(unit.network_id):
			continue
		var data: Dictionary = health_views[unit.network_id]
		if not unit.is_shaking:
			unit.set_hovered(unit.grid_position == hovered_tile)
		unit.show_health_preview(data.preview_damage, data.preview_healing)

func _capture_markers() -> Array:
	var result: Array = []
	for node in grid.get_children():
		if node.is_queued_for_deletion():
			continue
		if node is Polygon2D:
			var transform: Transform2D = grid.global_transform.affine_inverse() * node.global_transform
			result.append({"kind": "polygon", "points": node.polygon, "color": node.color, "transform": transform, "upright": node in grid.movement_blockers.values(), "z": node.z_index})
		elif node is Line2D:
			var points := PackedVector2Array()
			for point in node.points:
				points.append(grid.to_local(node.to_global(point)))
			result.append({"kind": "line", "points": points, "color": node.default_color, "width": node.width / grid.scale.x if node.top_level else node.width, "z": node.z_index})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a.z < b.z)
	return result
