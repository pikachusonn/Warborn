extends Node2D
class_name TileScene
const TILE_SIZE := 64;
@export var grid_position: Vector2i;
var is_hovered := false;

signal tile_clicked(position: Vector2i)

@onready var clicked_area = $ClickArea

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	clicked_area.clicked.connect(_on_clicked)

func set_hovered(val: bool) -> void:
	if(is_hovered == val):
		return
	is_hovered = val;
	
func setup(cord: Vector2i): 
	grid_position = cord;
	position = Vector2(grid_position) * TILE_SIZE;
	
func _draw() -> void:
	var fill = Color.WHITE if is_hovered else Color.DARK_SLATE_GRAY
	var border = Color.WHITE
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(TILE_SIZE, TILE_SIZE)), 
		fill, 
		true
	)
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(TILE_SIZE, TILE_SIZE)), 
		border, 
		false, 
		2.0
	)

func set_moveable(val: bool):
	if val:
		modulate = Color(0.5, 0.8, 1)
	else: 
		modulate = Color.WHITE
		
func set_attackable(val: bool):
	if val:
		modulate = Color(1.0, 0.8, 0.3)
	else:
		modulate = Color.WHITE
		
func set_attack_preview():
	modulate = Color(1.0, 0.8, 0.3)

func set_attack_warning():
	modulate = Color(1.0, 0.2, 0.2)

func clear_attack():
	modulate = Color.WHITE
		
func _on_clicked():
	tile_clicked.emit(grid_position)
