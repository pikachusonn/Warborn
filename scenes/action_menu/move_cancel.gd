extends Node2D

signal cancel_pressed
const ICON = preload("res://assets/icons/action_menu/cancel.png")
const RADIUS := 30.0
var hovered := false

func _process(_delta: float) -> void:
	var next_hovered: bool = get_node("/root/Netplay").can_input() and get_local_mouse_position().length() <= RADIUS
	if next_hovered != hovered:
		hovered = next_hovered
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not get_node("/root/Netplay").can_input():
		return
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if get_local_mouse_position().length() > RADIUS:
			return
		get_viewport().set_input_as_handled()
		if event.pressed:
			cancel_pressed.emit()

func _draw() -> void:
	var tint := Color(1.0, 0.4, 0.45)
	draw_circle(Vector2.ZERO, RADIUS, Color(tint, 0.65 if hovered else 0.35))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 64, Color(tint, 0.15), 8.0, true)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 64, Color(tint, 0.9), 2.0, true)
	draw_texture_rect(ICON, Rect2(-32, -32, 64, 64), false, Color(1, 1, 1, 1.0 if hovered else 0.8))
