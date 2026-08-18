extends Node2D
class_name Unit

enum Side {
	PLAYER,
	ENEMY
}

@export var data: UnitData
var side: Side
var current_health: int
var grid_position: Vector2i
var is_selected := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: UnitClickArea = $ClickArea

@onready var hp_bar: ProgressBar = $HPBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hp_bar.hide()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(pos: Vector2i, unit_data: UnitData, unit_side):
	grid_position = pos
	data = unit_data
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
	if(hovered):
		update_hp_bar()
	hp_bar.visible = hovered

func shake():
	var original_position := position
	for i in range(4):
		position = original_position + Vector2(randf_range(-3, 3), 0)
		await get_tree().create_timer(0.04).timeout
	position = original_position
	set_hovered(true)
	await get_tree().create_timer(1.0).timeout
	set_hovered(false)
