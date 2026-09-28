extends Node2D

const ENERGY_ICON := preload("res://assets/ui/skill_tooltip/energy.png")
const MOVE_ICON := preload("res://assets/icons/action_menu/boots.png")
const INNER_RADIUS := 30.0
const OUTER_RADIUS := 68.0
const ICON_RADIUS := 49.0
const FILL := Color(0.16, 0.25, 0.4, 0.65)
const BORDER := Color(0.55, 0.75, 1.0, 0.7)
var icon_positions := [
	Vector2.from_angle(deg_to_rad(-30.0)) * ICON_RADIUS,
	Vector2.from_angle(deg_to_rad(30.0)) * ICON_RADIUS,
]

var energy_icon: Sprite2D
var movement_icon: Sprite2D
var has_energy := true
var has_free_movement := true

func _ready() -> void:
	energy_icon = make_icon(ENERGY_ICON, icon_positions[0])
	movement_icon = make_icon(MOVE_ICON, icon_positions[1])

func make_icon(texture: Texture2D, icon_position: Vector2) -> Sprite2D:
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = texture.get_image().get_used_rect()
	var icon := Sprite2D.new()
	icon.texture = cropped
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = icon_position
	icon.scale = Vector2.ONE * (25.0 / maxf(cropped.get_size().x, cropped.get_size().y))
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform bool inactive = false; void fragment() { vec4 color = texture(TEXTURE, UV); if (inactive) { float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114)); color.rgb = vec3(gray * 0.65); color.a *= 0.48; } COLOR = color; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	icon.material = material
	add_child(icon)
	return icon

func set_resources(energy_available: bool, free_movement_available: bool) -> void:
	if has_energy == energy_available and has_free_movement == free_movement_available:
		return
	has_energy = energy_available
	has_free_movement = free_movement_available
	energy_icon.material.set_shader_parameter("inactive", not has_energy)
	movement_icon.material.set_shader_parameter("inactive", not has_free_movement)
	queue_redraw()

func _draw() -> void:
	for index in range(2):
		var start := deg_to_rad(-60.0 + index * 60.0)
		var end := start + deg_to_rad(60.0)
		var points := PackedVector2Array()
		for step in range(17):
			points.append(Vector2.from_angle(lerpf(start, end, step / 16.0)) * OUTER_RADIUS)
		for step in range(16, -1, -1):
			points.append(Vector2.from_angle(lerpf(start, end, step / 16.0)) * INNER_RADIUS)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_colored_polygon(points, FILL)
		draw_polyline(outline, Color(BORDER, 0.12), 6.0, true)
		draw_polyline(outline, BORDER, 1.5, true)
