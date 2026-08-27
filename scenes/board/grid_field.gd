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
# ================================
# SKILLS / TARGETING
# ================================
var active_skill: Skill = null
var targeting_skill := false
var locked_skill_direction: Vector2i
var skill_preview_nodes: Array[Node] = []
var current_action := Action.NONE
var projectile_blockers: Dictionary = {}
var bouncing_pads: Dictionary[Vector2i, Hunter_kit] = {}
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
@onready var unit_panel: UnitPanel = $CanvasLayer/BottomHUD
@onready var skill_cutscene: Control = $CanvasLayer/SkillCutscene

func _ready() -> void:
	var t: TileScene
	position = get_viewport_rect().size / 2
	position -= Vector2(WIDTH, HEIGHT) * TILE_SIZE / 2
	position.y -= 100
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
			"data": quagmire_data,
			"position": Vector2i(1, 0),
			"side": Unit.Side.ENEMY
		}
	]
	generate_grid()
	spawn_team(players_characters)
	spawn_team(enemies_characters)
	update_unit_visuals()
	unit_panel.move_pressed.connect(handle_move_pressed)
	unit_panel.skill1_pressed.connect(handle_skill_pressed.bind(0, Action.SKILL1))
	unit_panel.skill2_pressed.connect(handle_skill_pressed.bind(1, Action.SKILL2))
	unit_panel.skill3_pressed.connect(handle_skill_pressed.bind(2, Action.SKILL3))
	unit_panel.skill4_pressed.connect(handle_skill_pressed.bind(3, Action.SKILL4))
	unit_panel.end_turn_pressed.connect(end_turn)
	start_combat()
	
func _process(_delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var local_mouse = to_local(mouse_pos)
	var grid_pos = Vector2i(local_mouse / TILE_SIZE)
	if not tiles.has(grid_pos):
		clear_hover()
		if hovered_unit:
			hovered_unit.set_hovered(false)
			hovered_unit = null
		if targeting_skill and active_skill and active_unit:
			active_skill.update_preview(self, active_unit)
		return
	if active_skill and active_unit and targeting_skill:
		active_skill.update_preview(self, active_unit)
	var tile = tiles[grid_pos]
	if tile == hovered_tile:
		return
	clear_hover()
	hovered_tile = tile
	hovered_tile.set_hovered(true)
	update_hovered_unit(tile)

func clear_hover() -> void:
	if hovered_tile:
		hovered_tile.set_hovered(false)
		hovered_tile = null


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
		if unit.grid_position == tile.grid_position:
			hovered_unit = unit
			hovered_unit.set_hovered(true)
			return
	
func spawn_character(data: UnitData, pos: Vector2i, side: Unit.Side):
	var unit_instance: Unit = unit_scene.instantiate()
	add_child(unit_instance)
	unit_instance.setup(
		pos,
		data,
		side
	)
	unit_instance.click_area.unit_clicked.connect(handle_unit_clicked)
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
		
func move_unit(unit: Unit, target_pos: Vector2i):
	if not tiles.has(target_pos):
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
	clear_skill_state()
	active_unit.set_selected(false)
	active_unit = null
	unit_panel.hide()
	turn_index += 1
	if turn_index >= turn_order.size():
		turn_index = 0
	update_unit_visuals()
	start_unit_turn(turn_order[turn_index])
	
func handle_unit_clicked(unit: Unit):
	if(targeting_skill):
		return
	if(active_unit):
		active_unit.set_selected(false)	
	active_unit = unit
	unit_panel.show_unit(unit)
	unit_panel.update_energy(energy)
	active_unit.set_selected(true)
	
func handle_tile_clicked(pos: Vector2i):
	if(active_unit == null):
		return
	if tiles[pos] not in target_tiles && (active_skill == null || !active_skill.instant_cast()):
		print("invalid position: ", tiles[pos], pos)
		return;
	match current_action:
		Action.MOVE:
			move_unit(active_unit, pos)
			current_action = Action.NONE
			unit_panel.clear_skill_active()
		_:
			if active_skill:
				active_skill.on_tile_clicked(self, active_unit, pos)
	
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

func clean_up_skill():
	clear_move_range()
	active_skill = null
	if energy == 0 && !free_movement:
		end_turn()

func clear_target_tiles():
	for tile in target_tiles:
		tile.set_moveable(false)
		tile.set_attackable(false)
	target_tiles.clear()

func clear_skill_state():
	clear_target_tiles()
	targeting_skill = false
	current_action = Action.NONE
	
func calculate_move_range(unit: Unit, diagonal = false):
	clear_move_range()
	var current_pos := unit.grid_position
	var mobility := unit.data.mobility
	
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
	if active_unit == null:
		return
	if not is_skill:
		clean_up_skill()
	clear_move_range()
	current_action = Action.MOVE
	calculate_move_range(active_unit)

func handle_skill_pressed(skill_number: int, action: Action):
	if active_unit == null:
		return
	var skill := active_unit.skills[skill_number]
	if skill.cooldown_remaining > 0:
		clear_skill_state()
		return
	if active_skill:
		active_skill.cancel(self, active_unit)
	clear_skill_state()
	active_skill = skill
	current_action = action
	active_skill.begin(self, active_unit)
			
func get_direction_to_mouse(position: Vector2, diagonal = false) -> Vector2i:
	var mouse_pos := get_global_mouse_position()
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
	var mouse_pos := get_global_mouse_position()
	var unit_pos := unit.global_position
	var delta := mouse_pos - unit_pos
	var tile_distance = max(abs(delta.x), abs(delta.y)) / TILE_SIZE
	return clampi(roundi(tile_distance), 1, 3)
	
func get_units_on_tiles(target_positions: Array[Vector2i], units: Array[Unit]) -> Array[Unit]:
	var targets: Array[Unit] = []
	for unit in units:
		if unit.grid_position in target_positions:
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
	
func start_combat():
	initialize_turn_order()
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
	active_unit = unit
	if unit.get_status_stacks(Unit.EFFECTS.STUNNED) > 0:
		unit.remove_status(Unit.EFFECTS.STUNNED)
		unit.shake()
		await get_tree().create_timer(0.5).timeout
		end_turn()
		return
	energy = 1
	free_movement = true
	active_unit.set_selected(true)
	unit_panel.update_energy(energy)
	update_unit_visuals()
	unit_panel.show_unit(unit)
	for skill in unit.skills:
		skill.on_owner_turn_start(self)

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
	return tiles[pos].global_position + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	
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
