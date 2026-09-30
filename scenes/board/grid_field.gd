extends Node2D
class_name GridField
# ================================
# BOARD
# ================================
const WIDTH := 10
const HEIGHT := 10
const TILE_SIZE := 64
var tiles: Dictionary[Vector2i, TileScene] = {}
var hovered_tile: TileScene
var target_tiles: Array[TileScene] = []
@export var tile_scene: PackedScene
# ================================
# UNITS
# ================================
var players_characters = []
var enemies_characters = []
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
@export var unit_scene: PackedScene
@export var breacher_data: UnitData
@export var archer_data: UnitData
@export var quagmire_data: UnitData
@export var berserker_data: UnitData
# ================================
# TURN
# ================================
enum Turn {
	PLAYER,
	ENEMY
}
var turn_order: Array[Unit] = []
var turn_index := 0
var active_unit: Unit
var energy := 0
var free_movement := false
var resolving_turn_start := false
var presenting_skill := false
var radial_skills_open := false
var radial_menu_owner: Unit
var network_handler_busy := false
var remote_skill_availability: Array[bool] = []
# ================================
# SKILLS / TARGETING
# ================================
var active_skill: Skill = null
var targeting_skill := false
var locked_skill_direction: Vector2i
var skill_preview_nodes: Array[Node] = []
var impact_preview_tiles: Array = []
var current_action := Action.NONE
var projectile_blockers: Dictionary = {}
var movement_blockers: Dictionary = {}
var bouncing_pads: Dictionary[Vector2i, Hunter_kit] = {}
var active_aoe_effects: Array = []
var aoe_tile_owners: Dictionary = {}
var aoe_hover_glow: Node2D
var suppressed_aoe_hover_tiles: Array[Vector2i] = []

enum Action {
	MOVE,
	SKILL1,
	SKILL2,
	SKILL3,
	SKILL4,
	NONE
}
# ================================
# UI
# ================================
var hovered_unit: Unit
var capture_zone: CaptureZoneManager
var match_ended := false
var winning_team: int = -1
var win_reason: String = ""
var top_capture_hud: TopCaptureHUD = null
var match_end_modal: MatchEndModal = null

@onready var netplay: Node = get_node("/root/Netplay")
@onready var unit_panel: UnitPanel = $CanvasLayer/BottomHUD
@onready var skill_cutscene: Control = $CanvasLayer/SkillCutscene
@onready var radial_menu: Node2D = $RadialActionMenu

func _ready() -> void:
	update_board_layout()
	get_viewport().size_changed.connect(update_board_layout)
	players_characters = [
		{
			"data": breacher_data,
			"position": Vector2i(6, 8),
			"side": Unit.Side.PLAYER
		},
		{
			"data": archer_data,
			"position": Vector2i(4, 9),
			"side": Unit.Side.PLAYER
		},
		{
			"data": berserker_data,
			"position": Vector2i(2, 8),
			"side": Unit.Side.PLAYER
		},
		{
			"data": quagmire_data,
			"position": Vector2i(8, 9),
			"side": Unit.Side.PLAYER
		}
	]
	enemies_characters = [
		{
			"data": breacher_data,
			"position": Vector2i(3, 1),
			"side": Unit.Side.ENEMY
		},
		{
			"data": archer_data,
			"position": Vector2i(5, 0),
			"side": Unit.Side.ENEMY
		},
		{
			"data": berserker_data,
			"position": Vector2i(7, 1),
			"side": Unit.Side.ENEMY
		},
		{
			"data": quagmire_data,
			"position": Vector2i(1, 0),
			"side": Unit.Side.ENEMY
		}
	]
	generate_grid()
	capture_zone = preload("res://scenes/board/capture_zone_manager.gd").new()
	capture_zone.name = "CaptureZoneManager"
	add_child(capture_zone)
	capture_zone.setup(self)

	top_capture_hud = $CanvasLayer.get_node_or_null("TopCaptureHUD") as TopCaptureHUD
	if top_capture_hud:
		top_capture_hud.setup(capture_zone)

	match_end_modal = $CanvasLayer.get_node_or_null("MatchEndModal") as MatchEndModal

	spawn_team(players_characters)
	spawn_team(enemies_characters)
	update_unit_visuals()
	unit_panel.move_pressed.connect(handle_move_pressed)
	unit_panel.skill1_pressed.connect(handle_skill_pressed.bind(0, Action.SKILL1))
	unit_panel.skill2_pressed.connect(handle_skill_pressed.bind(1, Action.SKILL2))
	unit_panel.skill3_pressed.connect(handle_skill_pressed.bind(2, Action.SKILL3))
	unit_panel.skill4_pressed.connect(handle_skill_pressed.bind(3, Action.SKILL4))
	unit_panel.capture_pressed.connect(handle_radial_capture)
	unit_panel.end_turn_pressed.connect(handle_radial_end_turn)
	radial_menu.get_node("WheelBackGround").end_turn_pressed.connect(handle_radial_end_turn)
	radial_menu.get_node("WheelBackGround").move_pressed.connect(handle_radial_move)
	radial_menu.get_node("WheelBackGround").action_pressed.connect(open_radial_skills)
	radial_menu.get_node("WheelBackGround").skill_pressed.connect(select_radial_skill)
	radial_menu.get_node("WheelBackGround").capture_pressed.connect(handle_radial_capture)
	radial_menu.get_node("MoveCancel").cancel_pressed.connect(cancel_radial_movement)
	if netplay.is_networked():
		netplay.attach_board(self)
	else:
		start_combat()

func open_radial_skills() -> void:
	if netplay.intercept("skills"):
		return
	if resolving_turn_start or not is_instance_valid(active_unit):
		return
	if active_skill != null:
		return
	radial_skills_open = true
	update_radial_menu()

func select_radial_skill(index: int) -> void:
	if netplay.intercept("skill", index):
		return
	if resolving_turn_start or not is_instance_valid(active_unit):
		return
	if not can_use_skill(index):
		return
	if active_skill != null and not targeting_skill:
		return
	handle_skill_pressed(index, [Action.SKILL1, Action.SKILL2, Action.SKILL3, Action.SKILL4][index])
	update_radial_menu()

func can_use_skill(index: int) -> bool:
	if netplay.is_client():
		return index >= 0 and index < remote_skill_availability.size() and remote_skill_availability[index]
	if not is_instance_valid(active_unit) or index < 0 or index >= active_unit.skills.size():
		return false
	var skill: Skill = active_unit.skills[index]
	return not skill.is_passive \
		and skill.cooldown_remaining <= 0 \
		and energy >= skill.get_action_cost() \
		and skill.has_usable_target(active_unit) \
		and (not skill.is_mobile or not are_mobility_skills_blocked(active_unit))

func has_usable_skill() -> bool:
	if not is_instance_valid(active_unit) or active_unit.is_defeated():
		return false
	for index in range(active_unit.skills.size()):
		if can_use_skill(index):
			return true
	return false

func cancel_radial_movement() -> void:
	if netplay.intercept("cancel"):
		return
	if resolving_turn_start:
		return
	if active_skill != null and not targeting_skill:
		return
	if current_action != Action.MOVE and not radial_skills_open and not targeting_skill:
		return
	var return_to_skills := targeting_skill
	if active_skill != null:
		active_skill.cancel(self, active_unit)
		active_skill = null
	radial_skills_open = return_to_skills
	clear_move_range()
	clear_skill_state()
	unit_panel.clear_skill_active()
	update_radial_menu()

func handle_radial_move() -> void:
	if netplay.intercept("move"):
		return
	if resolving_turn_start or not is_instance_valid(active_unit):
		return
	if active_unit.is_defeated() or (energy <= 0 and not free_movement):
		return
	if active_skill != null and not targeting_skill:
		return
	if active_skill != null:
		active_skill.cancel(self, active_unit)
		active_skill = null
	clear_skill_state()
	unit_panel.clear_skill_active()
	handle_move_pressed()

func handle_radial_end_turn() -> void:
	if netplay.intercept("end"):
		return
	if resolving_turn_start or not is_instance_valid(active_unit):
		return
	# Don't interrupt a skill that is already playing its attack presentation.
	if active_skill != null and not targeting_skill:
		return
	if active_skill != null:
		active_skill.cancel(self, active_unit)
		active_skill = null
	unit_panel.clear_skill_active()
	end_turn()
	update_radial_menu()

func update_board_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var board_size := viewport_size.y * 0.80
	scale = Vector2.ONE * board_size / (HEIGHT * TILE_SIZE)
	# Leave 11% above the board and 9% below.
	position = Vector2((viewport_size.x - board_size) / 2.0, viewport_size.y * 0.11)
	# Both peers retain the same logical coordinates. Only the guest's view rotates.
	rotation = PI if netplay.is_client() else 0.0
	if netplay.is_client():
		position += Vector2.ONE * board_size
	for child in get_children():
		if child is Unit or child == radial_menu:
			child.rotation = -rotation

func _process(_delta: float) -> void:
	update_radial_menu()
	if netplay.is_networked():
		var enabled: bool = netplay.can_input()
		unit_panel.move_button.disabled = not enabled or (energy <= 0 and not free_movement)
		unit_panel.end_turn_button.disabled = not enabled
		var buttons := [unit_panel.skill1_button, unit_panel.skill2_button, unit_panel.skill3_button, unit_panel.skill4_button]
		for index in buttons.size():
			buttons[index].disabled = not enabled or not can_use_skill(index)
		if is_instance_valid(unit_panel.capture_button):
			var in_zone := capture_zone.is_inside_capture_zone(active_unit.grid_position) if is_instance_valid(active_unit) else false
			var can_cap := capture_zone.can_unit_capture(active_unit) if is_instance_valid(active_unit) else false
			unit_panel.capture_button.visible = in_zone
			unit_panel.capture_button.disabled = not enabled or not can_cap
	else:
		if is_instance_valid(unit_panel.capture_button):
			var in_zone := capture_zone.is_inside_capture_zone(active_unit.grid_position) if is_instance_valid(active_unit) else false
			var can_cap := capture_zone.can_unit_capture(active_unit) if is_instance_valid(active_unit) else false
			unit_panel.capture_button.visible = in_zone
			unit_panel.capture_button.disabled = not can_cap
	if netplay.is_client():
		if netplay.state_codec != null:
			netplay.state_codec.update_health_display()
		update_local_hover()
		return
	if netplay.is_networked() and not netplay.owns_turn():
		update_local_hover()
		return
	refresh_target_preview()

func is_sharing_target_preview() -> bool:
	return targeting_skill or current_action == Action.MOVE

func get_target_mouse_position() -> Vector2:
	if netplay.is_networked() and (netplay.dispatching or netplay.executing_command or not netplay.owns_turn()):
		return to_global(netplay.pointer)
	return get_global_mouse_position()

func refresh_target_preview() -> void:
	var mouse_pos := get_target_mouse_position()
	var local_mouse = to_local(mouse_pos)
	var grid_pos = Vector2i(floori(local_mouse.x / TILE_SIZE), floori(local_mouse.y / TILE_SIZE))
	if not tiles.has(grid_pos):
		suppressed_aoe_hover_tiles.clear()
		clear_hover()
		if hovered_unit:
			hovered_unit.set_hovered(false)
			hovered_unit = null
		if targeting_skill and active_skill and active_unit:
			active_skill.update_preview(self, active_unit)
		update_health_previews()
		return
	var tile = tiles[grid_pos]
	# Update the hovered tile before skills such as Crater Maker read it.
	if tile != hovered_tile:
		clear_hover()
		hovered_tile = tile
		hovered_tile.set_hovered(true)
		update_hovered_unit(tile)
	if active_skill and active_unit and targeting_skill:
		active_skill.update_preview(self, active_unit)
	update_health_previews()
	update_aoe_hover(grid_pos)

func refresh_remote_target_preview(cursor: Vector2) -> void:
	# Remote aim affects authoritative target/impact data, but never the host's
	# private tile, character, zone, or cloud hover.
	var previous_hovered_tile = hovered_tile
	var grid_pos := Vector2i(floori(cursor.x / TILE_SIZE), floori(cursor.y / TILE_SIZE))
	hovered_tile = tiles.get(grid_pos)
	if targeting_skill and active_skill and active_unit:
		active_skill.update_preview(self, active_unit)
	update_health_previews()
	hovered_tile = previous_hovered_tile

func update_local_hover() -> void:
	var local_mouse := to_local(get_global_mouse_position())
	var grid_pos := Vector2i(floori(local_mouse.x / TILE_SIZE), floori(local_mouse.y / TILE_SIZE))
	if not tiles.has(grid_pos):
		clear_hover()
		if hovered_unit:
			hovered_unit.set_hovered(false)
			hovered_unit = null
		return
	var tile: TileScene = tiles[grid_pos]
	if tile != hovered_tile:
		clear_hover()
		hovered_tile = tile
		hovered_tile.set_hovered(true)
		update_hovered_unit(tile)
	update_aoe_hover(grid_pos)

func clear_hover() -> void:
	update_zone_cloud_hover([])
	if is_instance_valid(aoe_hover_glow):
		for position in aoe_hover_glow.positions:
			if tiles.has(position):
				tiles[position].set_aoe_hovered(false)
		aoe_hover_glow.set_tiles([])
	if hovered_tile:
		hovered_tile.set_hovered(false)
		hovered_tile = null

func update_radial_menu() -> void:
	radial_menu.modulate = Color(0.55, 0.55, 0.55, 0.5) if netplay.is_networked() and not netplay.owns_turn() else Color.WHITE
	if radial_menu_owner != active_unit:
		radial_skills_open = false
		radial_menu_owner = active_unit
	var moving := current_action == Action.MOVE
	var skill_resolving := active_skill != null and not targeting_skill
	var cancel_visible := (moving or radial_skills_open or targeting_skill) and not presenting_skill and not skill_resolving
	for unit in player_units + enemy_units:
		unit.set_move_targeting(cancel_visible and unit == active_unit)
	if not is_instance_valid(active_unit) or match_ended:
		radial_menu.hide()
		return
	if active_unit.is_defeated():
		radial_menu.hide()
		return
	radial_menu.show()
	radial_menu.position = active_unit.position
	radial_menu.get_node("MoveCancel").visible = cancel_visible
	var resources = radial_menu.get_node("TurnResources")
	resources.visible = not presenting_skill and not skill_resolving
	resources.set_resources(energy > 0, free_movement)
	var wheel = radial_menu.get_node("WheelBackGround")
	wheel.set_skills_mode(radial_skills_open)
	var in_zone := capture_zone.is_inside_capture_zone(active_unit.grid_position) if (is_instance_valid(active_unit) and capture_zone != null) else false
	var can_cap := capture_zone.can_unit_capture(active_unit) if (is_instance_valid(active_unit) and capture_zone != null) else false
	wheel.set_capture_mode(in_zone, can_cap)
	var availability: Array[bool] = []
	if radial_skills_open:
		for index in range(4):
			availability.append(can_use_skill(index))
	wheel.set_skill_availability(availability)
	wheel.visible = not moving and not targeting_skill and not presenting_skill and not skill_resolving
	for node_name in ["Action", "Move", "EndTurn", "Capture"]:
		var btn = radial_menu.get_node_or_null(node_name)
		if btn:
			var should_show = wheel.visible and not radial_skills_open
			if node_name == "Capture":
				should_show = should_show and in_zone
			btn.visible = should_show

func update_health_previews() -> void:
	var preview_positions: Array[Vector2i] = []
	var preview_tiles := impact_preview_tiles if not impact_preview_tiles.is_empty() else target_tiles
	for tile in preview_tiles:
		preview_positions.append(tile.grid_position)
	for unit in player_units + enemy_units:
		unit.clear_health_preview()
		if not targeting_skill or active_skill == null or active_unit == null:
			continue
		if unit.grid_position not in preview_positions:
			continue
		var preview_damage := active_skill.get_preview_damage(self, active_unit, unit)
		var preview_healing := active_skill.get_preview_healing(self, active_unit, unit)
		unit.show_health_preview(preview_damage, preview_healing)

func update_aoe_hover(position: Vector2i) -> void:
	var highlighted: Array[Vector2i] = []
	var effect = aoe_tile_owners.get(position)
	if position not in suppressed_aoe_hover_tiles:
		suppressed_aoe_hover_tiles.clear()
	if effect != null and effect in active_aoe_effects:
		var candidates: Array = []
		if effect.has_method("get_aoe_zone_tiles"):
			candidates = effect.get_aoe_zone_tiles(position)
		else:
			candidates = aoe_tile_owners.keys()
		for candidate in candidates:
			if tiles.has(candidate) and aoe_tile_owners.get(candidate) == effect:
				highlighted.append(candidate)
	elif netplay.is_client() and netplay.state_codec != null:
		highlighted.assign(netplay.state_codec.get_replica_zone_tiles(position))
	var local_targeting: bool = (not netplay.is_networked() or netplay.owns_turn()) and (targeting_skill or current_action == Action.MOVE)
	if local_targeting:
		# Remember the entire zone until the cursor leaves, even after targeting ends.
		suppressed_aoe_hover_tiles.assign(highlighted)
		highlighted.clear()
	elif position in suppressed_aoe_hover_tiles:
		highlighted.clear()
	update_zone_cloud_hover(highlighted)
	if not is_instance_valid(aoe_hover_glow):
		if highlighted.is_empty():
			return
		aoe_hover_glow = preload("res://scenes/board/aoe_hover_glow.gd").new()
		aoe_hover_glow.z_index = 1
		add_child(aoe_hover_glow)
	for previous_position in aoe_hover_glow.positions:
		if previous_position not in highlighted and tiles.has(previous_position):
			tiles[previous_position].set_aoe_hovered(false)
	for highlighted_position in highlighted:
		tiles[highlighted_position].set_aoe_hovered(true)
	var color := Color.WHITE
	if not highlighted.is_empty():
		color = tiles[position].get_aoe_color()
	aoe_hover_glow.set_tiles(highlighted, color)

func suppress_aoe_hover(positions: Array[Vector2i]) -> void:
	suppressed_aoe_hover_tiles.assign(positions)
	clear_hover()

func update_zone_cloud_hover(positions: Array[Vector2i]) -> void:
	if netplay.is_client() and netplay.state_codec != null:
		netplay.state_codec.set_replica_zone_hover(positions)
		return
	for effect in active_aoe_effects:
		if effect.has_method("set_zone_hover"):
			effect.set_zone_hover(positions)


func generate_grid() -> void:
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var tile: TileScene = tile_scene.instantiate()
			add_child(tile)
			var grid_pos = Vector2i(x, y)
			tile.setup(grid_pos)
			tile.tile_clicked.connect(handle_tile_clicked)
			tiles[grid_pos] = tile

func update_hovered_unit(tile: TileScene):
	if hovered_unit:
		hovered_unit.set_hovered(false)

	hovered_unit = null
	var all_units = player_units + enemy_units
	for unit in all_units:
		if not unit.is_defeated() and unit.grid_position == tile.grid_position:
			hovered_unit = unit
			hovered_unit.set_hovered(true)
			return
	
func spawn_character(data: UnitData, pos: Vector2i, side: Unit.Side):
	var unit_instance: Unit = unit_scene.instantiate()
	unit_instance.network_id = player_units.size() + enemy_units.size()
	add_child(unit_instance)
	unit_instance.setup(
		pos,
		data,
		side
	)
	unit_instance.rotation = -rotation
	unit_instance.play_spawn_effect()
	unit_instance.click_area.unit_clicked.connect(handle_unit_clicked)
	unit_instance.position_changed.connect(capture_zone.on_unit_position_changed)
	unit_instance.defeated.connect(capture_zone.on_unit_defeated)
	if side == Unit.Side.PLAYER:
		player_units.append(unit_instance)
	else:
		enemy_units.append(unit_instance)
	
func spawn_team(team):
	for character in team:
		var data: UnitData = character["data"]
		var pos: Vector2i = character["position"]
		var side: Unit.Side = character["side"]
		spawn_character(data, pos, side)
		
func get_mouse_grid_position() -> Vector2i:
	var mouse_position := to_local(get_target_mouse_position())
	return Vector2i(floori(mouse_position.x / 64.0), floori(mouse_position.y / 64.0))
	
func clear_impact_preview() -> void:
	for tile in impact_preview_tiles:
		if tile in target_tiles:
			tile.set_attackable(true)
		else:
			tile.set_attackable(false)
	impact_preview_tiles.clear()
	
func show_impact_preview(positions: Array[Vector2i]) -> void:
	clear_impact_preview()
	for position in positions:
		if not tiles.has(position):
			continue
		var tile = tiles[position]
		tile.set_attack_warning()
		impact_preview_tiles.append(tile)
		
func move_unit(unit: Unit, target_pos: Vector2i):
	if not tiles.has(target_pos):
		return
	if is_tile_occupied(target_pos, unit):
		return
	#First movement is free
	if free_movement:
		free_movement = false
	elif energy > 0:
		energy -= 1
	else:
		return
	
	unit.grid_position = target_pos
	unit.position = (Vector2(target_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2))
	for skill in unit.skills:
		if skill is Bullwark:
			skill.update_position(self)
	unit_panel.update_energy(energy)
	clear_move_range()
	#unit_panel.hide()
	current_action = Action.NONE
	if energy == 0:
		end_turn()
		
func end_turn():
	if netplay.is_client():
		return
	if resolving_turn_start:
		return
	clear_skill_state()
	if active_unit:
		active_unit.set_selected(false)
	active_unit = null
	unit_panel.hide()
	if not advance_to_next_living_unit():
		update_unit_visuals()
		return
	update_unit_visuals()
	start_unit_turn(turn_order[turn_index])

func advance_to_next_living_unit() -> bool:
	for offset in range(1, turn_order.size() + 1):
		var candidate_index := (turn_index + offset) % turn_order.size()
		if not turn_order[candidate_index].is_defeated():
			turn_index = candidate_index
			return true
	return false
	
func handle_unit_clicked(unit: Unit):
	# Unit selection must never replace the initiative owner in network play.
	# Target clicks are handled by the tile below the unit, as in local targeting.
	if netplay.is_networked():
		return
	if resolving_turn_start:
		return
	if(targeting_skill):
		return
	if unit.is_defeated():
		return
	if(active_unit):
		active_unit.set_selected(false)	
	active_unit = unit
	unit_panel.show_unit(unit)
	unit_panel.update_energy(energy)
	active_unit.set_selected(true)
	
func handle_tile_clicked(pos: Vector2i):
	if netplay.intercept("tile", -1, pos):
		return
	if not tiles.has(pos):
		return
	if resolving_turn_start:
		return
	if(active_unit == null):
		return
	if tiles[pos] not in target_tiles && (active_skill == null || !active_skill.instant_cast()):
		print("invalid position: ", tiles[pos], pos)
		if targeting_skill:
			active_unit.show_speech("Can't reach there")
		return;
	match current_action:
		Action.MOVE:
			move_unit(active_unit, pos)
			current_action = Action.NONE
			unit_panel.clear_skill_active()
		_:
			if active_skill:
				await active_skill.on_tile_clicked(self, active_unit, pos)
	
func update_unit_visuals():
	for unit in turn_order:
		unit.set_active(unit == active_unit)

func clear_move_range():
	for tile in target_tiles:
		tile.set_moveable(false)
	target_tiles.clear()
	for node in skill_preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	skill_preview_nodes.clear()

func clean_up_skill(retain = false):
	clear_move_range()
	clear_skill_state()
	active_skill = null
	if not has_usable_skill():
		radial_skills_open = false
		if free_movement or retain:
			update_radial_menu()
		else:
			end_turn()
	else:
		radial_skills_open = true
		update_radial_menu()

func clear_target_tiles():
	for tile in target_tiles:
		tile.set_moveable(false)
		tile.set_attackable(false)
	target_tiles.clear()

func clear_skill_state():
	clear_impact_preview()
	clear_target_tiles()
	targeting_skill = false
	current_action = Action.NONE
	update_health_previews()
	
func calculate_move_range(unit: Unit, diagonal = false):
	clear_move_range()
	var current_pos := unit.grid_position
	var mobility := get_unit_mobility(unit)
	
	var directions = [
		Vector2i.DOWN,
		Vector2i.UP,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]
	
	if diagonal:
		directions.append_array([
			Vector2i(1, 1),   # down-right
			Vector2i(-1, 1),  # down-left
			Vector2i(1, -1),  # up-right
			Vector2i(-1, -1)  # up-left
		])
	
	for direction in directions:
		for step in range(1, mobility + 1):
			var target = current_pos + direction * step
			if not tiles.has(target):
				break
			if is_tile_occupied(target, unit):
				break
			var tile = tiles[target]
			tile.set_moveable(true)
			target_tiles.append(tile)
			
func show_attack_range(skill: Skill, unit: Unit, direction: Vector2i, distance: int = 1):
	clear_move_range()
	var target_positions: Array[Vector2i] = skill.get_target_tiles(self, unit, direction, distance)
	for target in target_positions:
		if not tiles.has(target):
			continue
		var tile = tiles[target]
		tile.set_attackable(true)
		target_tiles.append(tile)
	skill.show_preview(self, unit, direction)

func show_locked_tiles(target_positions: Array[Vector2i]):
	for target in target_positions:
		if not tiles.has(target):
			continue
		var tile = tiles[target]
		tile.set_attack_preview()
		target_tiles.append(tile)
		
func show_affected_tiles(target_positions: Array[Vector2i]):
	for target in target_positions:
		if not tiles.has(target):
			continue
		tiles[target].set_attack_warning()
	
func handle_move_pressed(is_skill = false): 
	if not is_skill and netplay.intercept("move"):
		return
	if resolving_turn_start:
		return
	if active_unit == null:
		return
	if not is_skill:
		if active_skill != null:
			active_skill.cancel(self, active_unit)
			active_skill = null
		clear_skill_state()
	clear_move_range()
	current_action = Action.MOVE
	calculate_move_range(active_unit)

func handle_skill_pressed(skill_number: int, action: Action):
	if netplay.intercept("skill", skill_number):
		return
	if resolving_turn_start:
		return
	if active_unit == null:
		return
	var skill := active_unit.skills[skill_number]
	if skill.cooldown_remaining > 0:
		clear_skill_state()
		return
	if skill.is_mobile && are_mobility_skills_blocked(active_unit):
		active_unit.show_speech("Can't use that here!")
		clear_skill_state()
		return
	if active_skill:
		active_skill.cancel(self, active_unit)
	clear_skill_state()
	active_skill = skill
	current_action = action
	active_skill.begin(self, active_unit)
			
func get_direction_to_mouse(position: Vector2, diagonal = false) -> Vector2i:
	var mouse_pos := get_target_mouse_position()
	var delta := mouse_pos - position
	# Normal 4-direction aiming
	if not diagonal:
		if abs(delta.x) > abs(delta.y):
			return Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT
		else:
			return Vector2i.DOWN if delta.y > 0 else Vector2i.UP
	
	# 8-direction aiming
	var angle := delta.angle()
	if angle >= -PI / 8 and angle < PI / 8:
		return Vector2i.RIGHT
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return Vector2i(1, 1)
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return Vector2i.DOWN
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return Vector2i(-1, 1)
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return Vector2i.LEFT
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return Vector2i(-1, -1)
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return Vector2i.UP
	else:
		return Vector2i(1, -1)

func get_skill_distance(unit: Unit) -> int:
	var mouse_pos := get_target_mouse_position()
	var unit_pos := unit.global_position
	var delta := to_local(mouse_pos) - to_local(unit_pos)
	var tile_distance = max(abs(delta.x), abs(delta.y)) / TILE_SIZE
	return clampi(roundi(tile_distance), 1, 3)
	
func get_units_on_tiles(target_positions: Array[Vector2i], units: Array[Unit]) -> Array[Unit]:
	var targets: Array[Unit] = []
	for unit in units:
		if not unit.is_defeated() and unit.grid_position in target_positions:
			targets.append(unit)
	return targets
	
func show_skill_cutscene(texture: Texture2D):
	skill_cutscene.get_node("TextureRect").texture = texture
	skill_cutscene.show()
	
func show_skill_cutscene_video(video: VideoStream):
	var video_player: VideoStreamPlayer = skill_cutscene.get_node("VideoStreamPlayer")
	video_player.stream = video
	video_player.play()
	skill_cutscene.show()
	return video_player

func play_skill_presentation(
	skill: Skill,
	target_positions: Array[Vector2i]
) -> void:
	presenting_skill = true
	update_radial_menu()
	show_locked_tiles(target_positions)
	await get_tree().create_timer(0.5).timeout
	if skill.cutscene_texture:
		show_skill_cutscene(skill.cutscene_texture)
		await get_tree().create_timer(1.0).timeout
	if skill.cutscene_video:
		var cutscene_player = show_skill_cutscene_video(skill.cutscene_video)
		await get_tree().create_timer(3.0).timeout
		cutscene_player.stop()
		cutscene_player.stream = null
	skill_cutscene.hide()
	show_affected_tiles(target_positions)
	await get_tree().create_timer(0.5).timeout
	presenting_skill = false
	update_radial_menu()
	
func start_combat():
	initialize_turn_order()
	if not turn_order.is_empty():
		start_unit_turn(turn_order[turn_index])

func initialize_turn_order():
	turn_order.clear()
	turn_order.append_array(player_units)
	turn_order.append_array(enemy_units)
	turn_order.sort_custom(
		func(a: Unit, b: Unit):
			return a.data.speed > b.data.speed
	)
	turn_index = 0

func start_unit_turn(unit: Unit):
	if netplay.is_client():
		return
	if netplay.is_networked():
		netplay.turn_epoch += 1
	if unit.is_defeated():
		if advance_to_next_living_unit():
			start_unit_turn(turn_order[turn_index])
		return
	resolving_turn_start = true
	active_unit = unit
	active_unit.clear_temp_health()
	for skill in unit.skills:
		await skill.on_owner_turn_start(self)
	capture_zone.on_unit_turn_start(unit)
	resolving_turn_start = false
	if match_ended:
		return
	if unit.is_defeated():
		end_turn()
		return
	
	if unit.get_status_stacks(Unit.EFFECTS.STUNNED) > 0:
		unit.remove_status(Unit.EFFECTS.STUNNED)
		unit.shake()
		resolving_turn_start = true
		await get_tree().create_timer(0.5).timeout
		resolving_turn_start = false
		end_turn()
		return
		
	apply_aoe_effects(unit)
	if unit.is_defeated():
		end_turn()
		return
	
	energy = 1
	free_movement = true
	active_unit.set_selected(true)
	unit_panel.update_energy(energy)
	update_unit_visuals()
	unit_panel.show_unit(unit)

func add_projectile_blocker(tile: Vector2i, blocker):
	projectile_blockers[tile] = blocker
	
func remove_projectile_blocker(tile: Vector2i):
	projectile_blockers.erase(tile)
	
func get_projectile_blocker(tile: Vector2i, unit: Unit):
	var blocker = projectile_blockers.get(tile)
	if blocker == null:
		return null
	if unit in (player_units if blocker.owner in player_units else enemy_units):
		return null
	return blocker

func get_tile_center(pos: Vector2i) -> Vector2:
	return tiles[pos].to_global(Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0))

func add_movement_blocker(pos: Vector2i, blocker) -> void:
	movement_blockers[pos] = blocker

func remove_movement_blocker(pos: Vector2i, blocker = null) -> void:
	if blocker != null and movement_blockers.get(pos) != blocker:
		return
	movement_blockers.erase(pos)

func is_tile_occupied(
	pos: Vector2i,
	ignored_unit: Unit = null,
	include_active_area := false
) -> bool:
	for unit in player_units + enemy_units:
		if unit != ignored_unit and not unit.is_defeated() and unit.grid_position == pos:
			return true
	if movement_blockers.has(pos):
		return true
	return include_active_area and aoe_tile_owners.has(pos)
	
func add_bouncing_pad(pos: Vector2i, pad: Hunter_kit) -> void:
	bouncing_pads[pos] = pad

func remove_bouncing_pad(pos: Vector2i) -> void:
	bouncing_pads.erase(pos)

func get_bouncing_pad(pos: Vector2i, unit: Unit) -> Hunter_kit:
	var pad: Hunter_kit = bouncing_pads.get(pos, null)
	if pad == null:
		return null
	if unit in (player_units if pad.owner in player_units else enemy_units):
		return pad
	return null
	
func add_aoe_effect(effect, positions: Array[Vector2i]) -> Array[Vector2i]:
	var valid_positions: Array[Vector2i] = []
	for position in positions:
		if not tiles.has(position):
			continue
		var previous_effect = aoe_tile_owners.get(position)
		if previous_effect != null:
			if previous_effect.has_method("remove_aoe_position"):
				previous_effect.remove_aoe_position(self, position)
		valid_positions.append(position)
	# Finish removing old zones before registering new ownership: an emptied
	# zone can unregister its effect, including when that effect is being recast.
	for position in valid_positions:
		aoe_tile_owners[position] = effect
	if not valid_positions.is_empty() and effect not in active_aoe_effects:
		active_aoe_effects.append(effect)
	return valid_positions

func release_aoe_position(effect, position: Vector2i) -> bool:
	if aoe_tile_owners.get(position) != effect:
		return false
	aoe_tile_owners.erase(position)
	return true
	
func remove_aoe_effect(effect) -> void:
	active_aoe_effects.erase(effect)
	var owned_positions := aoe_tile_owners.keys()
	for position in owned_positions:
		if aoe_tile_owners[position] == effect:
			aoe_tile_owners.erase(position)

func apply_aoe_effects(unit: Unit) -> void:
	for effect in active_aoe_effects:
		if effect.affects_position(unit.grid_position):
			effect.on_unit_turn_start(self, unit)
			
func get_unit_mobility(unit: Unit) -> int:
	var mobility := unit.data.mobility
	for effect in active_aoe_effects:
		if effect.has_method("get_mobility"):
			mobility = effect.get_mobility(unit, mobility)
	return mobility

func are_mobility_skills_blocked(unit: Unit) -> bool:
	for effect in active_aoe_effects:
		if effect.has_method("blocks_mobility_skills") && effect.blocks_mobility_skills(unit):
			return true
	return false

func handle_radial_capture() -> void:
	if netplay.intercept("capture"):
		return
	if resolving_turn_start or not is_instance_valid(active_unit) or match_ended:
		return
	if not capture_zone.can_unit_capture(active_unit):
		return
	capture_zone.start_capture(active_unit)
	update_radial_menu()

func end_match(winner: int, reason: String) -> void:
	if match_ended:
		return
	match_ended = true
	winning_team = winner
	win_reason = reason
	clear_skill_state()
	if active_unit:
		active_unit.set_selected(false)
	update_radial_menu()
	if netplay.is_networked():
		netplay.send_snapshot()
	var local_side := Unit.Side.PLAYER if not netplay.is_client() else Unit.Side.ENEMY
	if is_instance_valid(match_end_modal):
		match_end_modal.show_match_end(
			winner,
			reason,
			local_side,
			capture_zone.team_capture_points.get(Unit.Side.PLAYER, 0),
			capture_zone.team_capture_points.get(Unit.Side.ENEMY, 0)
		)

func check_elimination_victory() -> void:
	if match_ended:
		return
	var player_alive := not get_living_units(Unit.Side.PLAYER).is_empty()
	var enemy_alive := not get_living_units(Unit.Side.ENEMY).is_empty()
	if not player_alive and not enemy_alive:
		end_match(-1, "Elimination")
	elif not enemy_alive:
		end_match(Unit.Side.PLAYER, "Elimination")
	elif not player_alive:
		end_match(Unit.Side.ENEMY, "Elimination")

func get_living_units(side: Unit.Side) -> Array[Unit]:
	var units := player_units if side == Unit.Side.PLAYER else enemy_units
	var living: Array[Unit] = []
	for unit in units:
		if not unit.is_defeated():
			living.append(unit)
	return living

func network_command_allowed(action: String, argument: int) -> bool:
	if match_ended:
		return false
	if not is_instance_valid(active_unit) or active_unit.is_defeated() or resolving_turn_start or presenting_skill or network_handler_busy:
		return false
	if active_skill != null and not targeting_skill:
		return false
	match action:
		"skills", "cancel", "end": return true
		"move": return free_movement or energy > 0
		"skill": return can_use_skill(argument)
		"tile": return current_action == Action.MOVE or active_skill != null
		"capture": return capture_zone.can_unit_capture(active_unit)
	return false

func execute_network_command(action: String, argument: int, tile: Vector2i) -> void:
	network_handler_busy = true
	match action:
		"skills": open_radial_skills()
		"cancel": cancel_radial_movement()
		"end": handle_radial_end_turn()
		"move": handle_radial_move()
		"skill": select_radial_skill(argument)
		"tile": await handle_tile_clicked(tile)
		"capture": handle_radial_capture()
	network_handler_busy = false
