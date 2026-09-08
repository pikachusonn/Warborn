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
@export var cooldown: int
@export var status_tooltip_scene: PackedScene

var side: Side
var current_health: int
var temp_health: int
var grid_position: Vector2i
var is_selected := false
var status_effects: Dictionary = {}
var status_tooltip: StatusTooltip

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var ally_sprite_frames: SpriteFrames
@export var enemy_sprite_frames: SpriteFrames
@onready var click_area: UnitClickArea = $ClickArea
@onready var hp_bar: ProgressBar = $HPBar
@onready var ally_archer_mark: status_effect_icon = $StatusEffects/HunterMark
@onready var enemy_archer_mark: status_effect_icon = $StatusEffects/EnemyHunterMark
@onready var stun_icon: status_effect_icon = $StatusEffects/Stun
@onready var effects_wrapper: HBoxContainer = $StatusEffects
@onready var speech_bubble: PanelContainer = $SpeechBubble
@onready var speech_label: Label = $SpeechBubble/Label
@onready var temp_hp_overlay: ColorRect = $HPBar/TempHPOverlay
@onready var hp_label: Label = $HPBar/HPLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hp_bar.hide()
	effects_wrapper.set_position(Vector2i(-32, -52))
	status_tooltip = status_tooltip_scene.instantiate()
	add_child(status_tooltip)
	ally_archer_mark.setup(status_tooltip, self)
	enemy_archer_mark.setup(status_tooltip, self)
	stun_icon.setup(status_tooltip, self)
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
	if side == Side.PLAYER:
		sprite.sprite_frames = data.ally_sprite_frames
	else:
		sprite.sprite_frames = data.enemy_sprite_frames
	position = Vector2(pos) * 64 + Vector2(32, 32)
	sprite.play("idle")
	var frame_texture := sprite.sprite_frames.get_frame_texture("idle", 0)
	var tex_size := frame_texture.get_size()
	var scale_factor = min(
		64.0 / tex_size.x,
		64.0 / tex_size.y
	)
	sprite.scale = Vector2.ONE * scale_factor * 1.8
	
func set_active(active: bool):
	if active:
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = Color(0.4, 0.4, 0.4)
	
func set_attackable():
	sprite.modulate = Color(1.0, 0.631, 0.61, 1.0)

func set_heal():
	sprite.modulate = Color(0.746, 0.982, 0.593, 1.0)
		
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
func update_hp_bar() -> void:
	var max_health := data.health
	var real_health = clamp(current_health, 0, max_health)
	var shield_health = max(temp_health, 0)

	hp_bar.max_value = max_health
	hp_bar.value = real_health

	var bar_width := hp_bar.size.x
	var bar_height := hp_bar.size.y

	var health_ratio := float(real_health) / float(max_health)
	var temp_ratio := float(shield_health) / float(max_health)

	var temp_width = bar_width * min(temp_ratio, health_ratio)

	temp_hp_overlay.position = Vector2(0, 0)
	temp_hp_overlay.size = Vector2(temp_width, bar_height)
	temp_hp_overlay.visible = shield_health > 0
	
	hp_label.text = "%d/%d" % [real_health + shield_health, max_health]
	
func take_damage(amount: int) -> void:
	if temp_health > 0:
		var absorbed = min(temp_health, amount)
		temp_health -= absorbed
		amount -= absorbed
	if amount > 0:
		current_health -= amount
	update_hp_bar()

func heal(amount: int):
	print('pre-heal: ', current_health)
	current_health += amount;
	current_health = min(current_health, data.health)
	print(data.unit_name, " healed ", amount, " HP. HP: ", current_health)
	
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
	
func show_speech(text: String, duration := 1.5) -> void:
	speech_label.text = text
	speech_bubble.show()
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(speech_bubble):
		speech_bubble.hide()
	
func add_temp_health(amount: int, grid: GridField) -> void:
	temp_health += amount
	update_hp_bar()
	if (self == grid.active_unit):
		grid.unit_panel.update_health(grid.active_unit)
	
