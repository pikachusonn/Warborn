extends Node2D
class_name Unit

enum Side {
	PLAYER,
	ENEMY
}

const EFFECTS = {
	ALLY_ARCHER_MARK = 'ally_archer_mark',
	ENEMY_ARCHER_MARK = 'enemy_archer_mark',
	STUNNED = 'stunned'
}

@export var data: UnitData
@export var skills: Array[Skill]
var side: Side
var current_health: int
var grid_position: Vector2i
var is_selected := false
var status_effects: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: UnitClickArea = $ClickArea
@onready var hp_bar: ProgressBar = $HPBar
@onready var ally_archer_mark: TextureRect = $StatusEffects/HunterMark
@onready var enemy_archer_mark: TextureRect = $StatusEffects/EnemyHunterMark
@onready var stun_icon: TextureRect = $StatusEffects/Stun
@onready var effects_wrapper: HBoxContainer = $StatusEffects

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hp_bar.hide()
	effects_wrapper.set_position(Vector2i(-32, -52))
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(pos: Vector2i, unit_data: UnitData, unit_side):
	grid_position = pos
	data = unit_data
	skills = []
	for skill in unit_data.skills:
		var skill_copy = skill.duplicate(true)
		skills.append(skill_copy)
	side = unit_side
	current_health = data.health
	sprite.texture = data.texture
	position = Vector2(pos) * 64 + Vector2(32, 32)
	
	var tex_size = sprite.texture.get_size()

	var scale_factor = max(
		64.0 / tex_size.x,
		64.0 / tex_size.y
	)

	sprite.scale = Vector2.ONE * scale_factor
	sprite.region_enabled = true

	var visible_width = 64.0 / scale_factor
	var visible_height = 64.0 / scale_factor

	sprite.region_rect = Rect2(
		(tex_size.x - visible_width) / 2.0,
		(tex_size.y - visible_height) / 2.0,
		visible_width,
		visible_height
	)
	
func set_active(active: bool):
	if active:
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = Color(0.4, 0.4, 0.4)
		
func set_selected(selected: bool):
	is_selected = selected
	queue_redraw()
	
func _draw():
	if not is_selected:
		return

	draw_circle(
		Vector2.ZERO,
		50.0,
		Color(0.3, 0.8, 1.0, 0.15)
	)

	draw_circle(
		Vector2.ZERO,
		30.0,
		Color(0.3, 0.8, 1.0, 0.25)
	)

	draw_arc(
		Vector2.ZERO,
		30.0,
		0.0,
		TAU,
		32,
		Color(0.4, 0.85, 1.0, 0.9),
		3.0
	)
func update_hp_bar():
	hp_bar.max_value = data.health
	hp_bar.value = current_health
	
func take_damage(amount: int):
	current_health -= amount;
	current_health = max(current_health, 0)
	print(data.unit_name, " took ", amount, " damage. HP: ", current_health)

func set_hovered(hovered: bool):
	hp_bar.visible = hovered
	if(hovered):
		update_hp_bar()
		effects_wrapper.set_position(Vector2i(-32, -82))
	else:
		effects_wrapper.set_position(Vector2i(-32, -52))

func shake():
	var original_position := position
	for i in range(4):
		position = original_position + Vector2(randf_range(-3, 3), 0)
		await get_tree().create_timer(0.04).timeout
	position = original_position
	set_hovered(true)
	await get_tree().create_timer(1.0).timeout
	set_hovered(false)

func add_status(status: String, stacks: int = 1):
	status_effects[status] = status_effects.get(status, 0) + stacks
	update_status_icons()

func remove_status(status: String):
	status_effects.erase(status)
	update_status_icons()

func has_status(status: String) -> bool:
	return status_effects.has(status)

func get_status_stacks(status: String) -> int:
	return status_effects.get(status, 0)
	
func deduct_status_stack(status: String):
	if not status_effects.has(status):
		return
	status_effects[status] -= 1
	if status_effects[status] <= 0:
		remove_status(status)

func update_status_icons():
	ally_archer_mark.visible = has_status(EFFECTS.ALLY_ARCHER_MARK)
	stun_icon.visible = has_status(EFFECTS.STUNNED)
	enemy_archer_mark.visible = has_status(EFFECTS.ENEMY_ARCHER_MARK)
