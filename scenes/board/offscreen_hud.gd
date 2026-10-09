extends Control
class_name OffscreenHUD

enum Direction {
	LEFT,
	MIDDLE,
	RIGHT
}

const CARD_SIZE := Vector2(38.0, 38.0)
# The later tooltip overlaps 40% of the first one -> visible shift is 60%
const OVERLAP_RATIO := 0.40
const OFFSET_X := CARD_SIZE.x * (1.0 - OVERLAP_RATIO) # 22.8 px

const COLOR_PLAYER := Color(0.35, 0.65, 1.0, 1.0)
const COLOR_ENEMY := Color(1.0, 0.35, 0.35, 1.0)
const COLOR_BG := Color(0.08, 0.10, 0.14, 0.95)
const COLOR_COUNT_BG := Color(0.12, 0.15, 0.22, 0.95)
const COLOR_TEXT := Color(0.9, 0.92, 0.96, 1.0)
const COLOR_ARROW := Color(0.85, 0.88, 0.95, 0.9)

const REFRESH_DURATION := 1.0

var grid: GridField = null
var clusters: Dictionary = {} # Direction -> Dictionary of nodes
var refresh_timer := 0.0

func _is_unit_offscreen(screen_pos: Vector2, vp_size: Vector2) -> bool:
	var margin_top := 80.0
	var margin_side := 32.0
	var has_bottom_hud := is_instance_valid(grid) and is_instance_valid(grid.unit_panel) and grid.unit_panel.visible
	var margin_bottom := 200.0 if has_bottom_hud else 65.0
	return (
		screen_pos.x < margin_side or
		screen_pos.x > vp_size.x - margin_side or
		screen_pos.y < margin_top or
		screen_pos.y > vp_size.y - margin_bottom
	)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_build_ui()

func setup(grid_field: GridField) -> void:
	grid = grid_field
	refresh_indicators()

func on_turn_started(_unit: Unit) -> void:
	request_refresh()

func on_active_unit_moved(_unit: Unit) -> void:
	request_refresh()

func on_zoom_changed() -> void:
	if is_full_board_view():
		refresh_timer = 0.0
		set_process(false)
		_hide_all()
	else:
		request_refresh()

func is_full_board_view() -> bool:
	if not is_instance_valid(grid):
		return false
	return grid.force_full_board_zoom or grid.is_full_board_camera_active()

func request_refresh(duration: float = REFRESH_DURATION) -> void:
	if is_full_board_view():
		refresh_timer = 0.0
		set_process(false)
		_hide_all()
		return
	refresh_timer = maxf(refresh_timer, duration)
	set_process(true)
	refresh_indicators()

func refresh_indicators() -> void:
	_update_indicators()

func _build_ui() -> void:
	for dir in [Direction.LEFT, Direction.MIDDLE, Direction.RIGHT]:
		var root_control := Control.new()
		root_control.name = "Cluster_%s" % _direction_name(dir)
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_control.visible = false
		add_child(root_control)

		var cards_holder := Control.new()
		cards_holder.name = "CardsHolder"
		cards_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_control.add_child(cards_holder)

		var arrow_label := Label.new()
		arrow_label.name = "ArrowLabel"
		arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_label.add_theme_font_size_override("font_size", 14)
		arrow_label.add_theme_color_override("font_color", COLOR_ARROW)
		arrow_label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1.0))
		arrow_label.add_theme_constant_override("outline_size", 2)
		root_control.add_child(arrow_label)

		clusters[dir] = {
			"root": root_control,
			"cards_holder": cards_holder,
			"arrow": arrow_label,
			"direction": dir,
			"units": []
		}

func _direction_name(dir: Direction) -> String:
	match dir:
		Direction.LEFT:
			return "Left"
		Direction.MIDDLE:
			return "Middle"
		Direction.RIGHT:
			return "Right"
	return "Unknown"

func _process(delta: float) -> void:
	refresh_timer -= delta
	_update_indicators()
	if refresh_timer <= 0.0:
		refresh_timer = 0.0
		set_process(false)

func _update_indicators() -> void:
	if not is_instance_valid(grid) or grid.match_ended or is_full_board_view():
		_hide_all()
		return

	var vp_rect := get_viewport_rect()
	var vp_size := vp_rect.size
	var center := vp_size / 2.0

	var living_units: Array[Unit] = []
	for u in grid.player_units + grid.enemy_units:
		if is_instance_valid(u) and not u.is_defeated():
			living_units.append(u)

	var dir_buckets: Dictionary = {
		Direction.LEFT: [],
		Direction.MIDDLE: [],
		Direction.RIGHT: []
	}

	var board_center_screen := grid.to_global(Vector2(GridField.WIDTH * GridField.TILE_SIZE, GridField.HEIGHT * GridField.TILE_SIZE) * 0.5)
	var board_half_width := (GridField.WIDTH * GridField.TILE_SIZE * 0.5) * grid.scale.x
	var board_left := board_center_screen.x - board_half_width
	var board_right := board_center_screen.x + board_half_width
	var board_total_width := board_half_width * 2.0

	for u in living_units:
		var screen_pos := grid.to_global(u.position)
		if not _is_unit_offscreen(screen_pos, vp_size):
			continue

		var dir := _classify_direction(screen_pos, board_left, board_total_width)
		dir_buckets[dir].append({
			"unit": u,
			"screen_pos": screen_pos,
			"dist": screen_pos.distance_to(center)
		})

	for dir in dir_buckets.keys():
		var items: Array = dir_buckets[dir]
		# Sort closest to screen center first
		items.sort_custom(func(a, b): return a["dist"] < b["dist"])
		var sorted_units: Array[Unit] = []
		var screen_positions: Array[Vector2] = []
		for item in items:
			sorted_units.append(item["unit"])
			screen_positions.append(item["screen_pos"])

		_update_cluster(dir, sorted_units, screen_positions, vp_size, board_left, board_right, board_total_width)

func _classify_direction(screen_pos: Vector2, board_left: float, board_total_width: float) -> Direction:
	var norm_x := (screen_pos.x - board_left) / board_total_width if board_total_width > 0.0 else 0.5
	if norm_x < 0.30:
		return Direction.LEFT
	elif norm_x > 0.70:
		return Direction.RIGHT
	else:
		return Direction.MIDDLE

func _update_cluster(
	dir: Direction,
	units: Array[Unit],
	screen_positions: Array[Vector2],
	vp_size: Vector2,
	board_left: float = 0.0,
	board_right: float = 0.0,
	board_total_width: float = 0.0
) -> void:
	var data: Dictionary = clusters[dir]
	var root_control: Control = data["root"]
	var cards_holder: Control = data["cards_holder"]
	var arrow: Label = data["arrow"]

	var prev_units: Array = data["units"]

	if units.is_empty():
		data["units"] = []
		root_control.visible = false
		for child in cards_holder.get_children():
			child.queue_free()
		return

	root_control.visible = true

	var units_changed := not _units_match(prev_units, units)
	if units_changed:
		data["units"] = units.duplicate()
		for child in cards_holder.get_children():
			child.queue_free()

		var total_count := units.size()
		if total_count == 1:
			var card0 := _create_character_card(units[0])
			card0.position = Vector2.ZERO
			card0.z_index = 0
			cards_holder.add_child(card0)
		elif total_count == 2:
			var card0 := _create_character_card(units[0])
			card0.position = Vector2.ZERO
			card0.z_index = 0
			cards_holder.add_child(card0)

			var card1 := _create_character_card(units[1])
			card1.position = Vector2(OFFSET_X, 0)
			card1.z_index = 1
			cards_holder.add_child(card1)
		else:
			var card0 := _create_character_card(units[0])
			card0.position = Vector2.ZERO
			card0.z_index = 0
			cards_holder.add_child(card0)

			var extra_units := units.slice(1)
			var badge := _create_count_badge(total_count - 1, extra_units)
			badge.position = Vector2(OFFSET_X, 0)
			badge.z_index = 1
			cards_holder.add_child(badge)

	var total_count := units.size()
	var cluster_cards_width := CARD_SIZE.x if total_count == 1 else (CARD_SIZE.x + OFFSET_X)

	if board_total_width <= 0.0:
		board_total_width = vp_size.x
		board_left = 0.0
		board_right = vp_size.x

	_position_cluster(dir, root_control, cards_holder, arrow, cluster_cards_width, screen_positions, vp_size, board_left, board_right, board_total_width)

func _units_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

func _position_cluster(
	dir: Direction,
	root_control: Control,
	cards_holder: Control,
	arrow: Label,
	cluster_cards_width: float,
	screen_positions: Array[Vector2],
	vp_size: Vector2,
	board_left: float,
	board_right: float,
	board_total_width: float
) -> void:
	var avg_y := 0.0
	var avg_x := 0.0
	for p in screen_positions:
		avg_x += p.x
		avg_y += p.y
	avg_x /= float(screen_positions.size())
	avg_y /= float(screen_positions.size())

	var has_bottom_hud := is_instance_valid(grid) and is_instance_valid(grid.unit_panel) and grid.unit_panel.visible
	var bottom_target_y := (vp_size.y - 210.0) if has_bottom_hud else (vp_size.y - 72.0)
	var bottom_thresh := (vp_size.y - 220.0) if has_bottom_hud else (vp_size.y - 120.0)

	var is_top := avg_y < 120.0
	var is_bottom := avg_y > bottom_thresh

	if is_top:
		var target_y := 88.0
		var min_x := maxf(16.0, board_left + 8.0)
		var max_x := minf(vp_size.x - cluster_cards_width - 16.0, board_right - cluster_cards_width - 8.0)
		match dir:
			Direction.LEFT:
				max_x = minf(max_x, board_left + board_total_width * 0.35 - cluster_cards_width)
			Direction.MIDDLE:
				min_x = maxf(min_x, board_left + board_total_width * 0.30)
				max_x = minf(max_x, board_left + board_total_width * 0.70 - cluster_cards_width)
			Direction.RIGHT:
				min_x = maxf(min_x, board_left + board_total_width * 0.65)

		if min_x > max_x:
			var mid := (min_x + max_x) / 2.0
			min_x = mid - 1.0
			max_x = mid + 1.0

		var root_x := clampf(avg_x - cluster_cards_width / 2.0, min_x, max_x)
		root_control.position = Vector2(root_x, target_y)
		cards_holder.position = Vector2.ZERO
		arrow.text = "▲"
		arrow.position = Vector2((cluster_cards_width - 16.0) / 2.0, -18.0)

	elif is_bottom:
		var target_y := bottom_target_y
		var min_x := maxf(16.0, board_left + 8.0)
		var max_x := minf(vp_size.x - cluster_cards_width - 16.0, board_right - cluster_cards_width - 8.0)
		match dir:
			Direction.LEFT:
				max_x = minf(max_x, board_left + board_total_width * 0.35 - cluster_cards_width)
			Direction.MIDDLE:
				min_x = maxf(min_x, board_left + board_total_width * 0.30)
				max_x = minf(max_x, board_left + board_total_width * 0.70 - cluster_cards_width)
			Direction.RIGHT:
				min_x = maxf(min_x, board_left + board_total_width * 0.65)

		if min_x > max_x:
			var mid := (min_x + max_x) / 2.0
			min_x = mid - 1.0
			max_x = mid + 1.0

		var root_x := clampf(avg_x - cluster_cards_width / 2.0, min_x, max_x)
		root_control.position = Vector2(root_x, target_y)
		cards_holder.position = Vector2.ZERO
		arrow.text = "▼"
		arrow.position = Vector2((cluster_cards_width - 16.0) / 2.0, CARD_SIZE.y + 2.0)

	else:
		match dir:
			Direction.LEFT:
				var root_x := maxf(16.0, board_left + 8.0)
				root_control.position = Vector2(root_x, avg_y - CARD_SIZE.y / 2.0)
				cards_holder.position = Vector2(16.0, 0.0)
				arrow.text = "◀"
				arrow.position = Vector2(0.0, (CARD_SIZE.y - 18.0) / 2.0)

			Direction.RIGHT:
				var root_x := minf(vp_size.x - cluster_cards_width - 32.0, board_right - cluster_cards_width - 8.0)
				root_control.position = Vector2(root_x, avg_y - CARD_SIZE.y / 2.0)
				cards_holder.position = Vector2.ZERO
				arrow.text = "▶"
				arrow.position = Vector2(cluster_cards_width + 4.0, (CARD_SIZE.y - 18.0) / 2.0)

			Direction.MIDDLE:
				var is_above := avg_y < vp_size.y * 0.5
				var target_y := 88.0 if is_above else bottom_target_y
				var root_x := clampf(avg_x - cluster_cards_width / 2.0, board_left + board_total_width * 0.30, board_left + board_total_width * 0.70 - cluster_cards_width)
				root_control.position = Vector2(root_x, target_y)
				cards_holder.position = Vector2.ZERO
				arrow.text = "▲" if is_above else "▼"
				arrow.position = Vector2((cluster_cards_width - 16.0) / 2.0, -18.0 if is_above else (CARD_SIZE.y + 2.0))

func _create_character_card(unit: Unit) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_ally := unit.side == Unit.Side.PLAYER
	var team_color := COLOR_PLAYER if is_ally else COLOR_ENEMY

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_corner_radius_all(5)
	style.set_border_width_all(2)
	style.border_color = team_color
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel", style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = CARD_SIZE - Vector2(4.0, 4.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = get_face_texture(unit)
	panel.add_child(icon_rect)

	var team_str := "ALLIES" if is_ally else "ENEMIES"
	var unit_name := get_unit_name(unit)
	var max_health: int = unit.data.health if is_instance_valid(unit.data) else 100
	panel.tooltip_text = "%s (%s)\nHP: %d/%d" % [unit_name, team_str, unit.current_health, max_health]

	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_unit_clicked(unit)
	)

	return panel

func _create_count_badge(remaining_count: int, extra_units: Array[Unit]) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_COUNT_BG
	style.set_corner_radius_all(5)
	style.set_border_width_all(2)
	style.border_color = Color(0.65, 0.72, 0.85, 0.85)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "+%d" % remaining_count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	var tooltip_lines: Array[String] = ["+%d more off-screen:" % remaining_count]
	for u in extra_units:
		if is_instance_valid(u):
			var side_str := "Ally" if u.side == Unit.Side.PLAYER else "Enemy"
			var max_h: int = u.data.health if is_instance_valid(u.data) else 100
			tooltip_lines.append("• %s (%s, HP: %d/%d)" % [get_unit_name(u), side_str, u.current_health, max_h])
	panel.tooltip_text = "\n".join(tooltip_lines)

	return panel

func _on_unit_clicked(unit: Unit) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(grid):
		return
	if grid.camera_move_pending:
		return
	grid.lead_camera_to_tile(grid.active_unit, unit.grid_position)
	request_refresh()

func get_face_texture(unit: Unit) -> Texture2D:
	if not is_instance_valid(unit):
		return null
	if is_instance_valid(grid) and is_instance_valid(grid.top_capture_hud):
		var tex = grid.top_capture_hud.get_face_texture(unit)
		if tex != null:
			return tex
	if is_instance_valid(unit.sprite) and unit.sprite.sprite_frames:
		if unit.sprite.sprite_frames.has_animation("idle"):
			return unit.sprite.sprite_frames.get_frame_texture("idle", 0)
	return null

func get_unit_name(unit: Unit) -> String:
	if not is_instance_valid(unit) or unit.data == null:
		return "Unit"
	var res_path := unit.data.resource_path.get_file().get_basename()
	if not res_path.is_empty():
		return res_path.capitalize()
	return "Unit"

func _hide_all() -> void:
	for data in clusters.values():
		var root_control: Control = data["root"]
		root_control.visible = false
