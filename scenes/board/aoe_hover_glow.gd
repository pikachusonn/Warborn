extends Node2D

var positions: Array[Vector2i] = []
var glow_color := Color.WHITE

func set_tiles(value: Array, color: Color = Color.WHITE) -> void:
	if positions == value and glow_color == color:
		return
	positions.assign(value)
	glow_color = color
	queue_redraw()

func _draw() -> void:
	var size := float(GridField.TILE_SIZE)
	for pos in positions:
		var origin := Vector2(pos) * size
		# Only trace exposed edges, including holes left by overwritten tiles.
		if pos + Vector2i.UP not in positions:
			draw_glow(origin, origin + Vector2(size, 0))
		if pos + Vector2i.RIGHT not in positions:
			draw_glow(origin + Vector2(size, 0), origin + Vector2(size, size))
		if pos + Vector2i.DOWN not in positions:
			draw_glow(origin + Vector2(0, size), origin + Vector2(size, size))
		if pos + Vector2i.LEFT not in positions:
			draw_glow(origin, origin + Vector2(0, size))

func draw_glow(start: Vector2, end: Vector2) -> void:
	draw_line(start, end, Color(glow_color, 0.06), 28.0, true)
	draw_line(start, end, Color(glow_color, 0.10), 20.0, true)
	draw_line(start, end, Color(glow_color, 0.18), 12.0, true)
	draw_line(start, end, Color(glow_color, 0.30), 6.0, true)
	draw_line(start, end, Color(glow_color, 0.85), 2.5, true)
