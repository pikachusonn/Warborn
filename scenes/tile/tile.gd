extends Node2D
class_name TileScene
const TILE_SIZE := 64;
var is_hovered := false;
var quagmire_base_color := Color.WHITE
var aoe_base_color := Color.WHITE

static func get_team_aoe_color(side) -> Color:
	return Color(0.576, 0.609, 0.99, 0.8) if side == Unit.Side.PLAYER else Color(1.0, 0.667, 0.749, 1.0)
signal tile_clicked(position: Vector2i)

@export var grid_position: Vector2i;

@onready var clicked_area = $ClickArea
@onready var quagmire_overlay: Sprite2D = $QuagmireOverlay
@onready var aoe_overlay: Polygon2D = $AoeOverlay

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
	
func show_quagmire(side, texture: Texture2D):
	quagmire_overlay.texture = texture
	quagmire_overlay.scale = Vector2(TILE_SIZE, TILE_SIZE) / texture.get_size()
	quagmire_base_color = get_team_aoe_color(side)
	quagmire_overlay.modulate = quagmire_base_color
	quagmire_overlay.visible = true

func set_aoe_hovered(value: bool) -> void:
	if aoe_overlay.visible:
		aoe_overlay.color = aoe_base_color
		if value:
			aoe_overlay.color = Color.from_hsv(aoe_base_color.h, minf(aoe_base_color.s * 1.15, 1.0), aoe_base_color.v * 1.1, 0.55)
	if value and quagmire_overlay.visible:
		quagmire_overlay.modulate = Color.from_hsv(
			quagmire_base_color.h,
			minf(quagmire_base_color.s * 1.35, 1.0),
			quagmire_base_color.v * 1.3,
			1.0
		)
	else:
		quagmire_overlay.modulate = quagmire_base_color

func clear_quagmire():
	quagmire_overlay.visible = false
	quagmire_overlay.texture = null

func show_aoe(color: Color, opacity: float) -> void:
	color.a = opacity
	aoe_base_color = color
	aoe_overlay.color = color
	aoe_overlay.visible = true

func clear_aoe() -> void:
	aoe_overlay.visible = false

func get_aoe_color() -> Color:
	return aoe_base_color if aoe_overlay.visible else quagmire_base_color
