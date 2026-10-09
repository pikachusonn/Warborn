extends Control
class_name TopCaptureHUD

var capture_zone: CaptureZoneManager
var grid: GridField = null

# Node references
var panel: PanelContainer
var left_box: MarginContainer
var round_label: Label
var turn_order_row: HBoxContainer
var unit_order_nodes: Array[Dictionary] = []
var previous_count_label: Label
var later_count_label: Label

var player_label: Label
var enemy_label: Label
var player_points_container: HBoxContainer
var enemy_points_container: HBoxContainer
var progress_row: HBoxContainer
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

const COLOR_ROUND_TEXT := Color(1.0, 0.86, 0.35, 1.0)
const COLOR_ACTIVE_BORDER := Color(1.0, 0.88, 0.25, 1.0)
const COLOR_DEFEATED_BORDER := Color(0.25, 0.25, 0.28, 0.4)
const VISIBLE_TURNS := 4

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
	z_index = 0
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	z_index = 0

	left_box = MarginContainer.new()
	left_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left_box.offset_left = 20
	left_box.offset_top = 4
	left_box.offset_right = 232
	left_box.offset_bottom = 148
	left_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(left_box)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(212, 144)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.14, 0.18, 0.82)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.25, 0.3, 0.4, 0.5)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 6
	panel_style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	left_box.add_child(panel)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel_vbox.add_theme_constant_override("separation", 4)
	panel_vbox.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(panel_vbox)

	# --- Tier 1: Initiative Ribbon & Round Counter ---
	var initiative_row := HBoxContainer.new()
	initiative_row.alignment = BoxContainer.ALIGNMENT_CENTER
	initiative_row.add_theme_constant_override("separation", 10)
	initiative_row.mouse_filter = MOUSE_FILTER_IGNORE
	panel_vbox.add_child(initiative_row)

	round_label = Label.new()
	round_label.text = "ROUND 1"
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 12)
	round_label.add_theme_color_override("font_color", COLOR_ROUND_TEXT)
	round_label.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.12, 1.0))
	round_label.add_theme_constant_override("outline_size", 2)
	round_label.mouse_filter = MOUSE_FILTER_IGNORE
	initiative_row.add_child(round_label)

	turn_order_row = HBoxContainer.new()
	turn_order_row.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_order_row.add_theme_constant_override("separation", 3)
	turn_order_row.mouse_filter = MOUSE_FILTER_IGNORE
	panel_vbox.add_child(turn_order_row)

	# --- Tier 2: Existing Scoreboard & Capture Zone Status ---
	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 4)
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.mouse_filter = MOUSE_FILTER_IGNORE
	panel_vbox.add_child(main_row)

	# Left Section: Player Team & Points
	var player_box := VBoxContainer.new()
	player_box.custom_minimum_size.x = 44
	player_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_box.add_theme_constant_override("separation", 4)
	player_box.mouse_filter = MOUSE_FILTER_IGNORE
	main_row.add_child(player_box)

	player_label = Label.new()
	player_label.text = "ALLIES"
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_color_override("font_color", COLOR_PLAYER)
	player_label.add_theme_font_size_override("font_size", 11)
	player_box.add_child(player_label)

	player_points_container = HBoxContainer.new()
	player_points_container.alignment = BoxContainer.ALIGNMENT_CENTER
	player_points_container.add_theme_constant_override("separation", 4)
	player_points_container.mouse_filter = MOUSE_FILTER_IGNORE
	for i in range(2):
		var ball := PointBall.new(14.0)
		ball.set_state(false, COLOR_PLAYER, COLOR_PLAYER_DIM)
		player_points_container.add_child(ball)
	player_box.add_child(player_points_container)

	var score_spacer := Control.new()
	score_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_spacer.mouse_filter = MOUSE_FILTER_IGNORE
	main_row.add_child(score_spacer)

	# Capture progress sits below the scores and stretches across the panel.

	progress_row = HBoxContainer.new()
	progress_row.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_theme_constant_override("separation", 0)
	progress_row.mouse_filter = MOUSE_FILTER_IGNORE
	panel_vbox.add_child(progress_row)

	step_nodes.clear()
	step_lines.clear()

	for i in range(3):
		if i > 0:
			var line := ColorRect.new()
			line.custom_minimum_size = Vector2(4, 3)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.color = Color(0.3, 0.35, 0.45, 0.5)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			progress_row.add_child(line)
			step_lines.append(line)

		var pip := StepPip.new(14.0)
		progress_row.add_child(pip)
		step_nodes.append(pip)

	status_label = Label.new()
	status_label.text = "ZONE NEUTRAL"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", COLOR_NEUTRAL_TEXT)
	panel_vbox.add_child(status_label)

	# Right Section: Enemy Team & Points
	var enemy_box := VBoxContainer.new()
	enemy_box.custom_minimum_size.x = 54
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_box.add_theme_constant_override("separation", 4)
	enemy_box.mouse_filter = MOUSE_FILTER_IGNORE
	main_row.add_child(enemy_box)

	enemy_label = Label.new()
	enemy_label.text = "ENEMIES"
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.add_theme_color_override("font_color", COLOR_ENEMY)
	enemy_label.add_theme_font_size_override("font_size", 11)
	enemy_box.add_child(enemy_label)

	enemy_points_container = HBoxContainer.new()
	enemy_points_container.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_points_container.add_theme_constant_override("separation", 4)
	enemy_points_container.mouse_filter = MOUSE_FILTER_IGNORE
	for i in range(2):
		var ball := PointBall.new(14.0)
		ball.set_state(false, COLOR_ENEMY, COLOR_ENEMY_DIM)
		enemy_points_container.add_child(ball)
	enemy_box.add_child(enemy_points_container)

func setup(cz: CaptureZoneManager, grid_ref: GridField = null) -> void:
	capture_zone = cz
	if grid_ref != null:
		grid = grid_ref
	elif grid == null:
		var parent = get_parent()
		if parent and parent.get_parent() is GridField:
			grid = parent.get_parent()
	if not capture_zone.capture_state_changed.is_connected(update_display):
		capture_zone.capture_state_changed.connect(update_display)
	update_display()
	_rebuild_turn_order_ribbon()

func _rebuild_turn_order_ribbon() -> void:
	if turn_order_row == null:
		return
	for child in turn_order_row.get_children():
		child.queue_free()
	unit_order_nodes.clear()

	if grid == null or grid.turn_order.is_empty():
		return
	previous_count_label = _make_hidden_count_label()
	turn_order_row.add_child(previous_count_label)

	for i in range(grid.turn_order.size()):
		var unit: Unit = grid.turn_order[i]
		if not is_instance_valid(unit):
			continue

		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(18, 18)
		icon_panel.mouse_filter = MOUSE_FILTER_IGNORE

		var border_style := StyleBoxFlat.new()
		border_style.bg_color = Color(0.06, 0.08, 0.11, 0.95)
		border_style.set_corner_radius_all(4)
		var is_ally: bool = unit.side == Unit.Side.PLAYER
		var team_color: Color = COLOR_PLAYER if is_ally else COLOR_ENEMY
		border_style.border_color = team_color
		border_style.set_border_width_all(1)
		icon_panel.add_theme_stylebox_override("panel", border_style)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(18, 18)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
		icon_rect.texture = get_idle_frame_texture(unit)
		icon_panel.add_child(icon_rect)

		turn_order_row.add_child(icon_panel)
		unit_order_nodes.append({
			"unit": unit,
			"index": i,
			"panel": icon_panel,
			"border_style": border_style,
			"icon_rect": icon_rect,
			"team_color": team_color
		})
	later_count_label = _make_hidden_count_label()
	turn_order_row.add_child(later_count_label)

func _make_hidden_count_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 22
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_NEUTRAL_TEXT)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.visible = false
	return label

func _process(_delta: float) -> void:
	if grid == null:
		var parent = get_parent()
		if parent and parent.get_parent() is GridField:
			grid = parent.get_parent()

	if grid == null:
		return
	var session := get_node_or_null("/root/Netplay")
	var top_offset := 56.0 if session != null and session.is_networked() else 4.0
	if left_box.offset_top != top_offset:
		left_box.offset_top = top_offset
		left_box.offset_bottom = top_offset + 144.0

	# Update Round text
	if round_label:
		round_label.text = "ROUND %d" % grid.round_number

	# Check if turn ribbon needs rebuilding
	if unit_order_nodes.size() != grid.turn_order.size() or unit_order_nodes.is_empty():
		_rebuild_turn_order_ribbon()
	var first_visible := clampi(grid.turn_index - 1, 0, maxi(0, unit_order_nodes.size() - VISIBLE_TURNS))
	var last_visible := mini(unit_order_nodes.size(), first_visible + VISIBLE_TURNS)
	if previous_count_label != null:
		previous_count_label.visible = first_visible > 0
		previous_count_label.text = "+%d" % first_visible
	if later_count_label != null:
		later_count_label.visible = last_visible < unit_order_nodes.size()
		later_count_label.text = "+%d" % (unit_order_nodes.size() - last_visible)

	# Update turn ribbon items
	for i in range(unit_order_nodes.size()):
		var slot_data: Dictionary = unit_order_nodes[i]
		slot_data.panel.visible = i >= first_visible and i < last_visible
		var unit: Unit = slot_data.unit
		if not is_instance_valid(unit):
			continue

		if slot_data.icon_rect.texture == null:
			slot_data.icon_rect.texture = get_idle_frame_texture(unit)

		var is_defeated: bool = unit.is_defeated()
		var is_active: bool = is_instance_valid(grid.active_unit) and grid.active_unit == unit
		var turn_spent: bool = (not is_active) and (i < grid.turn_index)

		if is_defeated:
			slot_data.icon_rect.modulate = Color(0.25, 0.25, 0.25, 0.35)
			slot_data.border_style.border_color = COLOR_DEFEATED_BORDER
			slot_data.border_style.set_border_width_all(1)
		elif is_active:
			slot_data.icon_rect.modulate = Color.WHITE
			slot_data.border_style.border_color = COLOR_ACTIVE_BORDER
			slot_data.border_style.set_border_width_all(2)
		elif turn_spent:
			slot_data.icon_rect.modulate = Color(0.55, 0.55, 0.55, 0.5)
			var dimmed_color: Color = slot_data.team_color
			dimmed_color.a = 0.4
			slot_data.border_style.border_color = dimmed_color
			slot_data.border_style.set_border_width_all(1)
		else:
			# Upcoming turn in this round
			slot_data.icon_rect.modulate = Color.WHITE
			slot_data.border_style.border_color = slot_data.team_color
			slot_data.border_style.set_border_width_all(1)

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

var face_texture_cache: Dictionary = {}

func get_face_texture(unit: Unit) -> Texture2D:
	if not is_instance_valid(unit):
		return null
	if face_texture_cache.has(unit) and face_texture_cache[unit] != null:
		return face_texture_cache[unit]

	var base_tex: Texture2D = null
	if is_instance_valid(unit.sprite) and unit.sprite.sprite_frames:
		if unit.sprite.sprite_frames.has_animation("idle"):
			base_tex = unit.sprite.sprite_frames.get_frame_texture("idle", 0)
	if base_tex == null and is_instance_valid(unit.data):
		var sf: SpriteFrames = unit.data.ally_sprite_frames if unit.side == Unit.Side.PLAYER else unit.data.enemy_sprite_frames
		if sf and sf.has_animation("idle"):
			base_tex = sf.get_frame_texture("idle", 0)

	if base_tex == null:
		return null

	if not (base_tex is AtlasTexture):
		face_texture_cache[unit] = base_tex
		return base_tex

	var atlas_tex := base_tex as AtlasTexture
	var root_texture: Texture2D = atlas_tex.atlas
	var frame_rect: Rect2 = atlas_tex.region

	var unit_name := get_unit_name(unit).to_lower()
	var face_local_rect := Rect2(65, 50, 64, 64)

	if unit_name.contains("berserker"):
		face_local_rect = Rect2(95, 230, 180, 180)
	elif unit_name.contains("quagmire"):
		face_local_rect = Rect2(100, 255, 175, 175)
	elif unit_name.contains("breacher"):
		face_local_rect = Rect2(66, 50, 64, 64)
	elif unit_name.contains("archer"):
		face_local_rect = Rect2(64, 50, 64, 64)
	elif frame_rect.size.y > 300:
		face_local_rect = Rect2(95, 235, 180, 180)
	else:
		face_local_rect = Rect2(frame_rect.size.x * 0.33, frame_rect.size.y * 0.25, frame_rect.size.x * 0.34, frame_rect.size.x * 0.34)

	var face_atlas := AtlasTexture.new()
	face_atlas.atlas = root_texture
	face_atlas.region = Rect2(frame_rect.position + face_local_rect.position, face_local_rect.size)

	face_texture_cache[unit] = face_atlas
	return face_atlas

func get_idle_frame_texture(unit: Unit) -> Texture2D:
	return get_face_texture(unit)

func get_unit_name(unit: Unit) -> String:
	if not is_instance_valid(unit) or unit.data == null:
		return "Unit"
	if not unit.data.unit_name.is_empty():
		return unit.data.unit_name
	var basename := unit.data.resource_path.get_file().get_basename()
	if not basename.is_empty():
		return basename
	return "Unit"
