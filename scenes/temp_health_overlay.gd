extends ColorRect

func _draw() -> void:
	# Keep the ColorRect's existing fill and avoid drawing a border at zero width.
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var outline := StyleBoxFlat.new()
	outline.draw_center = false
	outline.set_border_width_all(1)
	outline.border_color = Color(color.lightened(0.35), 1.0)
	outline.shadow_color = Color(color, 0.65)
	outline.shadow_size = 6
	draw_style_box(outline, Rect2(Vector2.ZERO, size))
