extends TileScene
class_name TileIsoScene

# Equal ground axes, projected with strong vertical foreshortening.
# Shared with the board so picking and drawing use identical geometry.
const VEC_X := Vector2(60.0, 22.0)
const VEC_Y := Vector2(-60.0, 22.0)

var is_active_tile := false
var active_team := -1

static func get_diamond_points() -> PackedVector2Array:
	var c_tl := (-VEC_X - VEC_Y) * 0.5
	var c_tr := (VEC_X - VEC_Y) * 0.5
	var c_br := (VEC_X + VEC_Y) * 0.5
	var c_bl := (-VEC_X + VEC_Y) * 0.5
	return PackedVector2Array([c_tl, c_tr, c_br, c_bl])

static func get_diamond_outline() -> PackedVector2Array:
	var c_tl := (-VEC_X - VEC_Y) * 0.5
	var c_tr := (VEC_X - VEC_Y) * 0.5
	var c_br := (VEC_X + VEC_Y) * 0.5
	var c_bl := (-VEC_X + VEC_Y) * 0.5
	return PackedVector2Array([c_tl, c_tr, c_br, c_bl, c_tl])

func get_unit_offset() -> Vector2:
	return Vector2.ZERO

func setup(cord: Vector2i) -> void:
	grid_position = cord
	position = cord.x * VEC_X + cord.y * VEC_Y

func set_active_tile(val: bool, team := -1) -> void:
	if is_active_tile != val or active_team != team:
		is_active_tile = val
		active_team = team
		queue_redraw()

func _draw() -> void:
	var points := get_diamond_points()
	var outline := get_diamond_outline()

	# 1. Base angled grid tile face on dark space
	# Lighter cool-slate ground gives unit silhouettes and the upcoming cast
	# shadows enough contrast while preserving the dark arena presentation.
	var base_fill := Color(0.16, 0.19, 0.23, 0.96)
	draw_colored_polygon(points, base_fill)

	# 2. Angled grid border line matching demo style
	var grid_line_color := Color(0.34, 0.43, 0.53, 0.72)
	draw_polyline(outline, grid_line_color, 1.2, true)

	# 3. Highlighted tiles:
	if highlight_color.a > 0.0:
		draw_colored_polygon(points, highlight_color)
		var hl_line := Color(
			minf(highlight_color.r * 1.3, 1.0),
			minf(highlight_color.g * 1.3, 1.0),
			minf(highlight_color.b * 1.3, 1.0),
			minf(highlight_color.a + 0.45, 1.0)
		)
		draw_polyline(outline, hl_line, 2.0, true)

	# 4. Active unit: tint the projected ground tile with its team color.
	if is_active_tile:
		var team_color := Color(0.18, 0.68, 1.0, 0.34) if active_team == Unit.Side.PLAYER else Color(1.0, 0.26, 0.20, 0.34)
		draw_colored_polygon(points, team_color)
		team_color.a = 0.95
		draw_polyline(outline, team_color, 2.4, true)

	# 5. Cursor hover highlight
	if is_hovered:
		draw_colored_polygon(points, Color(0.85, 0.92, 1.0, 0.22))
		draw_polyline(outline, Color(0.95, 0.98, 1.0, 0.95), 2.2, true)
