extends Control
class_name TopCaptureHUD

var capture_zone: CaptureZoneManager

# Node references
var panel: PanelContainer
var player_label: Label
var enemy_label: Label
var player_points_container: HBoxContainer
var enemy_points_container: HBoxContainer
var status_label: Label
var step_nodes: Array[Control] = []
var step_labels: Array[Label] = []
var step_lines: Array[ColorRect] = []

const COLOR_PLAYER := Color(0.25, 0.75, 1.0, 1.0)
const COLOR_PLAYER_DIM := Color(0.12, 0.25, 0.4, 0.6)
const COLOR_ENEMY := Color(1.0, 0.35, 0.25, 1.0)
const COLOR_ENEMY_DIM := Color(0.4, 0.15, 0.15, 0.6)
const COLOR_NEUTRAL_STEP := Color(0.2, 0.24, 0.3, 0.7)
const COLOR_NEUTRAL_TEXT := Color(0.65, 0.7, 0.78, 1.0)

class PointBall extends Control:
	var filled := false
	var team_color := Color.WHITE
	var dim_color := Color.DARK_GRAY

	func _init(size_px := 18.0) -> void:
		custom_minimum_size = Vector2(size_px, size_px)

	func set_state(is_filled: bool, active_color: Color, inactive_color: Color) -> void:
		filled = is_filled
		team_color = active_color
		dim_color = inactive_color
		queue_redraw()

	func _draw() -> void:
		var radius := size.x / 2.0
		var center := Vector2(radius, radius)
		if filled:
			# Soft glow
			draw_circle(center, radius + 2.0, Color(team_color.r, team_color.g, team_color.b, 0.3))
			# Main ball
			draw_circle(center, radius, team_color)
			# Highlight reflection
			draw_circle(center + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.35, Color(1, 1, 1, 0.6))
		else:
			draw_circle(center, radius, dim_color)
			draw_arc(center, radius - 1.0, 0, TAU, 24, Color(team_color.r, team_color.g, team_color.b, 0.35), 1.5)

class StepPip extends Control:
	var active := false
	var completed := false
	var team_color := Color.WHITE

	func _init(size_px := 20.0) -> void:
		custom_minimum_size = Vector2(size_px, size_px)

	func set_state(is_completed: bool, is_active: bool, color: Color) -> void:
		completed = is_completed
		active = is_active
		team_color = color
		queue_redraw()

	func _draw() -> void:
		var radius := size.x / 2.0
		var center := Vector2(radius, radius)
		if completed or active:
			var fill := team_color if completed else Color(team_color, 0.45)
			draw_circle(center, radius, fill)
			draw_arc(center, radius, 0, TAU, 32, team_color, 2.0)
			if completed:
				draw_circle(center, radius + 2.5, Color(team_color.r, team_color.g, team_color.b, 0.3))
		else:
			draw_circle(center, radius, COLOR_NEUTRAL_STEP)
			draw_arc(center, radius, 0, TAU, 32, Color(0.4, 0.45, 0.55, 0.4), 1.5)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH

	var center_box := CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center_box.offset_top = 10
	center_box.offset_bottom = 85
	center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center_box)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 62)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.22, 0.26, 0.4)
	panel_style.set_border_width_all(0)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	center_box.add_child(panel)

	var main_row := HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_theme_constant_override("separation", 20)
	main_row.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(main_row)

	# --- Left Section: Player Team & Points (under name) ---
	var player_box := VBoxContainer.new()
	player_box.custom_minimum_size.x = 80
	player_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_box.add_theme_constant_override("separation", 4)
	player_box.mouse_filter = MOUSE_FILTER_IGNORE
	main_row.add_child(player_box)

	player_label = Label.new()
	player_label.text = "ALLIES"
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_color_override("font_color", COLOR_PLAYER)
	player_label.add_theme_font_size_override("font_size", 15)
	player_box.add_child(player_label)

	player_points_container = HBoxContainer.new()
	player_points_container.alignment = BoxContainer.ALIGNMENT_CENTER
	player_points_container.add_theme_constant_override("separation", 6)
	player_points_container.mouse_filter = MOUSE_FILTER_IGNORE
	for i in range(2):
		var ball := PointBall.new(16.0)
		ball.set_state(false, COLOR_PLAYER, COLOR_PLAYER_DIM)
		player_points_container.add_child(ball)
	player_box.add_child(player_points_container)

	# --- Center Section: 3-step Capture Progress ---
	var center_col := VBoxContainer.new()
	center_col.custom_minimum_size.x = 230
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 5)
	center_col.mouse_filter = MOUSE_FILTER_IGNORE
	main_row.add_child(center_col)

	var progress_row := HBoxContainer.new()
	progress_row.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_row.add_theme_constant_override("separation", 0)
	progress_row.mouse_filter = MOUSE_FILTER_IGNORE
	center_col.add_child(progress_row)

	step_nodes.clear()
	step_lines.clear()

	for i in range(3):
		if i > 0:
			var line := ColorRect.new()
			line.custom_minimum_size = Vector2(28, 3)
			line.color = Color(0.3, 0.35, 0.45, 0.5)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			progress_row.add_child(line)
			step_lines.append(line)

		var pip := StepPip.new(20.0)
		progress_row.add_child(pip)
		step_nodes.append(pip)

	status_label = Label.new()
	status_label.text = "ZONE NEUTRAL"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", COLOR_NEUTRAL_TEXT)
	center_col.add_child(status_label)

	# --- Right Section: Enemy Team & Points (under name) ---
	var enemy_box := VBoxContainer.new()
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_box.add_theme_constant_override("separation", 4)
	enemy_box.mouse_filter = MOUSE_FILTER_IGNORE
	main_row.add_child(enemy_box)

	enemy_label = Label.new()
	enemy_label.text = "ENEMIES"
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.add_theme_color_override("font_color", COLOR_ENEMY)
	enemy_label.add_theme_font_size_override("font_size", 15)
	enemy_box.add_child(enemy_label)

	enemy_points_container = HBoxContainer.new()
	enemy_points_container.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_points_container.add_theme_constant_override("separation", 6)
	enemy_points_container.mouse_filter = MOUSE_FILTER_IGNORE
	for i in range(2):
		var ball := PointBall.new(16.0)
		ball.set_state(false, COLOR_ENEMY, COLOR_ENEMY_DIM)
		enemy_points_container.add_child(ball)
	enemy_box.add_child(enemy_points_container)

func setup(cz: CaptureZoneManager) -> void:
	capture_zone = cz
	if not capture_zone.capture_state_changed.is_connected(update_display):
		capture_zone.capture_state_changed.connect(update_display)
	update_display()

func update_display() -> void:
	if capture_zone == null:
		return

	# Update Player Points
	var player_pts: int = capture_zone.team_capture_points.get(Unit.Side.PLAYER, 0)
	for i in range(player_points_container.get_child_count()):
		var ball := player_points_container.get_child(i) as PointBall
		ball.set_state(i < player_pts, COLOR_PLAYER, COLOR_PLAYER_DIM)

	# Update Enemy Points
	var enemy_pts: int = capture_zone.team_capture_points.get(Unit.Side.ENEMY, 0)
	for i in range(enemy_points_container.get_child_count()):
		var ball := enemy_points_container.get_child(i) as PointBall
		ball.set_state(i < enemy_pts, COLOR_ENEMY, COLOR_ENEMY_DIM)

	# Update 3-step progress
	var is_capturing := capture_zone.state == CaptureZoneManager.CaptureState.CAPTURING
	var active_color := COLOR_PLAYER if capture_zone.capturing_team == Unit.Side.PLAYER else COLOR_ENEMY
	var turns_done := capture_zone.capture_turns_completed

	if is_capturing:
		var team_str := "ALLIES" if capture_zone.capturing_team == Unit.Side.PLAYER else "ENEMIES"
		status_label.text = "CAPTURING: TURN %d/3 · %s" % [turns_done, team_str]
		status_label.add_theme_color_override("font_color", active_color)
	else:
		status_label.text = "ZONE NEUTRAL"
		status_label.add_theme_color_override("font_color", COLOR_NEUTRAL_TEXT)

	for i in range(3):
		var pip := step_nodes[i] as StepPip
		var completed := is_capturing and (turns_done > i)
		var is_active := is_capturing and (turns_done == i + 1)
		pip.set_state(completed, is_active, active_color)

	for i in range(step_lines.size()):
		var line := step_lines[i]
		if is_capturing and turns_done > i + 1:
			line.color = active_color
		else:
			line.color = Color(0.3, 0.35, 0.45, 0.5)
