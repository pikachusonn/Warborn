extends Control
class_name TeamHealthHUD

@export var enemy_team := false

var grid: GridField = null

var panel: PanelContainer
var header_label: Label
var rows_container: VBoxContainer
var zoom_button: Button

var unit_rows: Array[Dictionary] = []

const COLOR_HEALTH_FILL := Color(0.24, 0.72, 0.32, 1.0)
const COLOR_HEALTH_BG := Color(0.12, 0.14, 0.18, 0.95)
const COLOR_SHIELD := Color(0.3, 0.75, 1.0, 0.85)
const COLOR_BORDER_DEFAULT := Color(0.25, 0.32, 0.45, 0.8)
const COLOR_BORDER_ACTIVE := Color(1.0, 0.85, 0.25, 1.0)
const COLOR_BORDER_DEFEATED := Color(0.3, 0.3, 0.3, 0.4)
const COLOR_NAME_DEFAULT := Color(0.9, 0.92, 0.96, 1.0)
const COLOR_NAME_ACTIVE := Color(1.0, 0.88, 0.35, 1.0)
const COLOR_NAME_DEFEATED := Color(0.5, 0.5, 0.5, 0.6)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func setup(grid_field: GridField) -> void:
	grid = grid_field
	_rebuild_rows()

func _build_ui() -> void:
	# Positioned on the left side of the screen, below the "Leave match" header (Vector2(20, 16)).
	if enemy_team:
		anchor_left = 1.0
		anchor_right = 1.0
		offset_left = -232.0
		offset_right = -20.0
		offset_top = 160.0
		offset_bottom = 390.0
	else:
		position = Vector2(20, 160)
	custom_minimum_size = Vector2(212, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel = PanelContainer.new()
	panel.name = "HUDPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.12, 0.16, 0.82)
	panel_style.border_color = Color(0.25, 0.3, 0.42, 0.6)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(main_vbox)

	header_label = Label.new()
	header_label.text = "YOUR TEAM"
	header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0, 0.85))
	header_label.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.12, 1.0))
	header_label.add_theme_constant_override("outline_size", 2)
	main_vbox.add_child(header_label)

	rows_container = VBoxContainer.new()
	rows_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_container.add_theme_constant_override("separation", 8)
	main_vbox.add_child(rows_container)
	if not enemy_team:
		zoom_button = Button.new()
		zoom_button.name = "ZoomToggleButton"
		zoom_button.custom_minimum_size = Vector2(190, 30)
		zoom_button.focus_mode = Control.FOCUS_NONE
		zoom_button.mouse_filter = Control.MOUSE_FILTER_STOP
		zoom_button.text = "Full board view"
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color(0.16, 0.22, 0.31, 0.95)
		button_style.border_color = COLOR_BORDER_DEFAULT
		button_style.set_border_width_all(1)
		button_style.set_corner_radius_all(5)
		zoom_button.add_theme_stylebox_override("normal", button_style)
		var hover_style := button_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.23, 0.33, 0.45, 1.0)
		zoom_button.add_theme_stylebox_override("hover", hover_style)
		zoom_button.pressed.connect(_on_zoom_button_pressed)
		main_vbox.add_child(zoom_button)

func _on_zoom_button_pressed() -> void:
	if is_instance_valid(grid):
		grid.force_full_board_zoom = not grid.force_full_board_zoom
		_update_zoom_button_text()

func _update_zoom_button_text() -> void:
	if zoom_button != null and is_instance_valid(grid):
		zoom_button.text = "Default zoom" if grid.force_full_board_zoom else "Full board view"

func get_team_units() -> Array[Unit]:
	if not is_instance_valid(grid):
		return []
	var session := get_node_or_null("/root/Netplay")
	var is_client: bool = session != null and session.is_client()
	var source: Array[Unit] = grid.enemy_units if enemy_team != is_client else grid.player_units
	var result: Array[Unit] = []
	for u in source:
		if is_instance_valid(u):
			result.append(u)
	return result

func _rebuild_rows() -> void:
	if rows_container == null:
		return

	for child in rows_container.get_children():
		child.queue_free()
	unit_rows.clear()

	var team_units := get_team_units()
	for unit in team_units:
		var row_dict := _create_unit_row(unit)
		rows_container.add_child(row_dict.row_container)
		unit_rows.append(row_dict)

func _create_unit_row(unit: Unit) -> Dictionary:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)

	# --- Left: Character Icon (First frame of idle animation) ---
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(40, 40)
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_border_style := StyleBoxFlat.new()
	icon_border_style.bg_color = Color(0.06, 0.08, 0.11, 0.9)
	icon_border_style.set_border_width_all(1)
	icon_border_style.border_color = COLOR_BORDER_DEFAULT
	icon_border_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_border_style)
	row.add_child(icon_panel)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = get_idle_frame_texture(unit)
	icon_panel.add_child(icon_rect)

	# --- Right: Name and Health Bar ---
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(140, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(name_row)

	var name_label := Label.new()
	name_label.text = get_unit_name(unit)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", COLOR_NAME_DEFAULT)
	name_label.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08, 1.0))
	name_label.add_theme_constant_override("outline_size", 2)
	name_row.add_child(name_label)

	var turn_badge := Label.new()
	turn_badge.text = "ACTIVE"
	turn_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_badge.add_theme_font_size_override("font_size", 10)
	turn_badge.add_theme_color_override("font_color", COLOR_NAME_ACTIVE)
	turn_badge.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08, 1.0))
	turn_badge.add_theme_constant_override("outline_size", 2)
	turn_badge.visible = false
	name_row.add_child(turn_badge)

	# Health Bar
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.show_percentage = false
	var max_health: int = unit.data.health if is_instance_valid(unit.data) else 100
	hp_bar.max_value = max_health
	hp_bar.value = unit.current_health

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_HEALTH_BG
	bg_style.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_HEALTH_FILL
	fill_style.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	col.add_child(hp_bar)

	# Shield / Temp HP Overlay
	var temp_overlay := ColorRect.new()
	temp_overlay.set_script(preload("res://scenes/temp_health_overlay.gd"))
	temp_overlay.color = COLOR_SHIELD
	temp_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	temp_overlay.position = Vector2.ZERO
	temp_overlay.size = Vector2.ZERO
	temp_overlay.visible = false
	hp_bar.add_child(temp_overlay)

	# Health Text Label
	var hp_label := Label.new()
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08, 1.0))
	hp_label.add_theme_constant_override("outline_size", 3)
	hp_label.text = "%d / %d" % [unit.current_health, max_health]
	hp_bar.add_child(hp_label)

	return {
		"unit": unit,
		"row_container": row,
		"icon_panel": icon_panel,
		"icon_border_style": icon_border_style,
		"icon_rect": icon_rect,
		"name_label": name_label,
		"turn_badge": turn_badge,
		"hp_bar": hp_bar,
		"temp_overlay": temp_overlay,
		"hp_label": hp_label
	}

func _process(_delta: float) -> void:
	var session := get_node_or_null("/root/Netplay")
	var is_networked: bool = session != null and session.is_networked()
	visible = is_instance_valid(grid)
	if not visible:
		return
	position.y = 212.0 if is_networked else 160.0
	_update_zoom_button_text()
	header_label.text = "ENEMY TEAM" if enemy_team else ("YOUR TEAM" if is_networked else "PLAYER TEAM")

	var current_team := get_team_units()
	var rebuild := unit_rows.size() != current_team.size() or unit_rows.is_empty()
	if not rebuild:
		for index in current_team.size():
			if unit_rows[index].unit != current_team[index]:
				rebuild = true
				break
	if rebuild:
		_rebuild_rows()
	if enemy_team:
		position.x = get_viewport_rect().size.x - panel.size.x - 20.0

	for entry in unit_rows:
		var unit: Unit = entry.unit
		if not is_instance_valid(unit):
			continue

		# Update icon texture if it wasn't available at row creation
		if entry.icon_rect.texture == null:
			entry.icon_rect.texture = get_idle_frame_texture(unit)

		var is_defeated: bool = unit.is_defeated()
		var max_health: int = unit.data.health if is_instance_valid(unit.data) else 100

		if is_defeated:
			entry.icon_rect.modulate = Color(0.35, 0.35, 0.35, 0.5)
			entry.icon_border_style.border_color = COLOR_BORDER_DEFEATED
			entry.icon_border_style.set_border_width_all(1)
			entry.name_label.add_theme_color_override("font_color", COLOR_NAME_DEFEATED)
			entry.turn_badge.visible = false
			entry.hp_bar.value = 0
			entry.temp_overlay.visible = false
			entry.hp_label.text = "FALLEN"
		else:
			entry.icon_rect.modulate = Color.WHITE
			var is_active := is_instance_valid(grid.active_unit) and grid.active_unit == unit
			entry.turn_badge.visible = is_active

			if is_active:
				entry.icon_border_style.border_color = COLOR_BORDER_ACTIVE
				entry.icon_border_style.set_border_width_all(2)
				entry.name_label.add_theme_color_override("font_color", COLOR_NAME_ACTIVE)
			else:
				entry.icon_border_style.border_color = COLOR_BORDER_DEFAULT
				entry.icon_border_style.set_border_width_all(1)
				entry.name_label.add_theme_color_override("font_color", COLOR_NAME_DEFAULT)

			var real_health: int = clampi(unit.current_health, 0, max_health)
			var shield_health: int = maxi(unit.temp_health, 0)
			entry.hp_bar.max_value = max_health
			entry.hp_bar.value = real_health

			# Temp Health / Shield overlay calculation
			var bar_width: float = entry.hp_bar.size.x
			var bar_height: float = entry.hp_bar.size.y
			var health_ratio := float(real_health) / float(max_health)
			var temp_ratio := float(shield_health) / float(max_health)
			var temp_width := bar_width * minf(temp_ratio, health_ratio)
			entry.temp_overlay.position = Vector2.ZERO
			entry.temp_overlay.size = Vector2(temp_width, bar_height)
			entry.temp_overlay.visible = shield_health > 0

			entry.hp_label.text = "%d / %d" % [real_health + shield_health, max_health]

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
