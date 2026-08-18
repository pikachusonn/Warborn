extends Node2D
class_name GridField
enum Turn {
	PLAYER,
	ENEMY
}

const WIDTH := 10
const HEIGHT := 10
const TILE_SIZE := 64

var tiles := {}
var hovered_tile: TileScene
var hovered_unit: Unit
var target_tiles: Array[TileScene] = []

@export var tile_scene: PackedScene
@export var unit_scene: PackedScene
@export var breacher_data: UnitData
@export var archer_data: UnitData

var players_characters = []
var enemies_characters = []

var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []

var active_unit: Unit
var active_side := Turn.PLAYER
var energy := 4

var active_skill: Skill = null
var targeting_skill := false
var locked_skill_direction: Vector2i

@onready var unit_panel: UnitPanel = $CanvasLayer/BottomHUD
@onready var skill_cutscene: Control = $CanvasLayer/SkillCutscene

enum Action {
	MOVE,
	SKILL1,
	SKILL2,
	SKILL3,
	SKILL4,
	NONE
}

var current_action := Action.NONE

func _ready() -> void:
	var t: TileScene
	position = get_viewport_rect().size / 2
	position -= Vector2(WIDTH, HEIGHT) * TILE_SIZE / 2
	players_characters = [
		{
			"data": breacher_data,
			"position": Vector2i(6, 9),
			"side": Unit.Side.PLAYER
		},
		{
			"data": breacher_data,
			"position": Vector2i(4, 9),
			"side": Unit.Side.PLAYER
		}
	]
	enemies_characters = [
		{
			"data": archer_data,
			"position": Vector2i(5, 0),
			"side": Unit.Side.ENEMY
		},
		{
			"data": archer_data,
			"position": Vector2i(7, 0),
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
	unit_panel.end_turn_pressed.connect(handle_deselect)
	
func _process(_delta: float) -> void:

	var mouse_pos = get_global_mouse_position()

	var local_mouse = to_local(mouse_pos)

	var grid_pos = Vector2i(local_mouse / TILE_SIZE)

	if not tiles.has(grid_pos):
		clear_hover()
		if hovered_unit:
			hovered_unit.set_hovered(false)
			hovered_unit = null
		return

	var tile = tiles[grid_pos]

	if tile == hovered_tile:
		return
	clear_hover()
	hovered_tile = tile
	hovered_tile.set_hovered(true)
	update_hovered_unit(tile)
	if targeting_skill and active_skill and active_unit:
		var direction := get_direction_to_mouse(active_unit)
		var distance := get_skill_distance(active_unit)
		show_attack_range(
			active_skill,
			active_unit,
			direction,
			distance
		)


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

#func _unhandled_input(event):
	#if active_unit == null:
		#return
#
	#var dir := Vector2i.ZERO
#
	#if event.is_action_pressed("move_up"):
		#dir = Vector2i.UP
	#elif event.is_action_pressed("move_down"):
		#dir = Vector2i.DOWN
	#elif event.is_action_pressed("move_left"):
		#dir = Vector2i.LEFT
	#elif event.is_action_pressed("move_right"):
		#dir = Vector2i.RIGHT
	#if dir != Vector2i.ZERO:
		#move_unit(active_unit, dir)
		
func move_unit(unit: Unit, target_pos: Vector2i):
	if energy <= 0:
		return
	if !tiles.has(target_pos):
		return
	unit.grid_position = target_pos
	unit.position = (Vector2(target_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2))
	energy -= 1
	unit_panel.update_energy(energy)
	clear_move_range()
	#unit_panel.hide()
	current_action = Action.NONE
	if energy == 0:
		end_turn()
		
func end_turn():
	active_unit.set_selected(false)
	if(active_side == Turn.PLAYER):
		active_side = Turn.ENEMY
	else:
		active_side = Turn.PLAYER
	energy = 4
	unit_panel.update_energy(4)
	active_unit = null
	unit_panel.hide()
	update_unit_visuals()
	
func handle_unit_clicked(unit: Unit):
	if(targeting_skill):
		return
	if(unit.side != active_side):
		active_unit = null
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
	if(tiles[pos] not in target_tiles):
		print("invalid position: ", tiles[pos], pos)
		return;
	match current_action:
		Action.MOVE:
			move_unit(active_unit, pos)
			current_action = Action.NONE
			unit_panel.clear_skill_active()
		Action.SKILL1:
			execute_skill()
		Action.SKILL2:
			execute_skill()
		Action.SKILL3:
			print("Skill 3")
		Action.SKILL4:
			print("Skill 4")
	
func update_unit_visuals():
	for unit in player_units:
		unit.set_active(
			active_side == Turn.PLAYER
		)
	for unit in enemy_units:
		unit.set_active(
			active_side == Turn.ENEMY
		)

func clear_move_range():
	for tile in target_tiles:
		tile.set_moveable(false)
	target_tiles.clear()

func clean_up_skill():
	for tile in target_tiles:
		tile.set_moveable(false)
		tile.set_attackable(false)
	active_skill = null
	targeting_skill = false
	target_tiles.clear()
	current_action = Action.NONE
	if energy == 0:
		end_turn()
	
func calculate_move_range(unit: Unit):
	clear_move_range()
	var current_pos := unit.grid_position
	var mobility := unit.data.mobility
	
	var directions = [
		Vector2i.DOWN,
		Vector2i.UP,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]
	
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
	var target_positions: Array[Vector2i] = skill.get_target_tiles(unit, direction, distance)
	for target in target_positions:
		if not tiles.has(target):
			continue

		var tile = tiles[target]
		tile.set_attackable(true)
		target_tiles.append(tile)

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
	
func handle_move_pressed(): 
	if active_unit == null:
		return
	clean_up_skill()
	clear_move_range()
	current_action = Action.MOVE
	calculate_move_range(active_unit)

func handle_skill_pressed(skill_number: int, action: Action):
	if active_unit == null:
		return
	clear_move_range()
	current_action = action
	targeting_skill = true
	active_skill = active_unit.data.skills[skill_number]

func handle_deselect():
	if(active_unit):
		active_unit.set_selected(false)
		active_unit = null
		current_action = Action.NONE
		clear_move_range()
		clean_up_skill()
		unit_panel.hide()
			
func get_direction_to_mouse(unit: Unit) -> Vector2i:
	var mouse_pos := get_global_mouse_position()
	var unit_pos := unit.global_position
	var delta := mouse_pos - unit_pos

	if abs(delta.x) > abs(delta.y):
		return Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT
	else:
		return Vector2i.DOWN if delta.y > 0 else Vector2i.UP

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
	
func execute_skill():
	if not active_skill or not active_unit:
		return
	locked_skill_direction = get_direction_to_mouse(active_unit)
	var locked_distance = get_skill_distance(active_unit)
	var target_positions: Array[Vector2i] = active_skill.get_target_tiles(
		active_unit,
		locked_skill_direction,
		locked_distance
	)
	targeting_skill = false
	show_locked_tiles(target_positions)
	await get_tree().create_timer(0.5).timeout
	if(active_skill.cutscene_texture):
		show_skill_cutscene(active_skill.cutscene_texture)
		await get_tree().create_timer(1).timeout
	if(active_skill.cutscene_video):
		var cutscene_player = show_skill_cutscene_video(active_skill.cutscene_video)
		await get_tree().create_timer(3).timeout
		cutscene_player.stop()
		cutscene_player.stream = null
	skill_cutscene.hide()
	show_affected_tiles(target_positions)
	await get_tree().create_timer(0.5).timeout
	await active_skill.execute(self, active_unit, target_positions, locked_skill_direction, locked_distance)
	energy -= 1
	unit_panel.update_energy(energy)
	clean_up_skill()
	unit_panel.clear_skill_active()

func show_skill_cutscene(texture: Texture2D):
	skill_cutscene.get_node("TextureRect").texture = texture
	skill_cutscene.show()
	
func show_skill_cutscene_video(video: VideoStream):
	var video_player: VideoStreamPlayer = skill_cutscene.get_node("VideoStreamPlayer")
	video_player.stream = video
	video_player.play()
	skill_cutscene.show()
	return video_player
	
