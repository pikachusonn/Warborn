extends Control
## Compact parchment-and-iron HUD for the isometric demo only.
## All commands go through the existing network-aware gameplay handlers.

const GOLD := Color("c7aa76")
const INK := Color("181b1cf2")
const MUTED := Color("827a69")
var grid: GridField
var actions: HBoxContainer
var utilities: HBoxContainer
var skills: Array[Button] = []
var move_button: Button
var capture_button: Button
var cancel_button: Button
var end_button: Button
var zoom_button: Button
var teams_open := false
var faces: Dictionary = {}
var movement_icon: TextureRect
var skill_tooltip: CanvasLayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Reuse the original nine-fragment paper and rich skill information.
	skill_tooltip = preload("res://scenes/action_menu/skill_tooltip.gd").new()
	add_child(skill_tooltip)
	movement_icon = TextureRect.new()
	var boot := preload("res://assets/icons/action_menu/boots.png")
	var cropped := AtlasTexture.new()
	cropped.atlas = boot
	cropped.region = boot.get_image().get_used_rect()
	movement_icon.texture = cropped
	movement_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	movement_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	movement_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { COLOR = vec4(COLOR.rgb, COLOR.a * texture(TEXTURE, UV).a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	movement_icon.material = material
	add_child(movement_icon)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	move_button = _button("Move", grid.handle_radial_move, actions)
	# Give the first control a definite closing edge before the skill slots.
	move_button.add_theme_stylebox_override("normal", _style(INK, MUTED, 2))
	move_button.add_theme_stylebox_override("hover", _style(Color("343127"), GOLD, 2))
	move_button.add_theme_stylebox_override("pressed", _style(Color("514532"), GOLD, 2))
	move_button.add_theme_stylebox_override("disabled", _style(Color("161819cc"), Color("49463f"), 2))
	for i in range(4):
		var button := _button(str(i + 1), _select_skill.bind(i), actions)
		button.custom_minimum_size = Vector2(66, 62)
		button.icon = preload("res://assets/icons/action_menu/skill_placeholder.png")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		skills.append(button)
	capture_button = _button("Capture", grid.handle_radial_capture, actions)
	cancel_button = _button("Cancel", grid.cancel_radial_movement, actions)
	end_button = _button("End turn", grid.handle_radial_end_turn, actions)
	utilities = HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 8)
	add_child(utilities)
	_button("← Lobby", grid.return_to_lobby, utilities)
	zoom_button = _button("Full board", _toggle_zoom, utilities)
	_button("Teams", _toggle_teams, utilities)
	for button in utilities.get_children():
		button.custom_minimum_size.y = 30

func _style(fill: Color, border: Color, right_border := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_right = right_border
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _button(label: String, callback: Callable, parent: Control) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(66, 62)
	button.add_theme_stylebox_override("normal", _style(INK, MUTED))
	button.add_theme_stylebox_override("hover", _style(Color("343127"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("514532"), GOLD))
	button.add_theme_stylebox_override("disabled", _style(Color("161819cc"), Color("49463f")))
	button.add_theme_color_override("font_color", Color("eadbc0"))
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _toggle_zoom() -> void:
	grid.force_full_board_zoom = not grid.force_full_board_zoom

func _select_skill(index: int) -> void:
	# Buttons retain keyboard focus after a click. Release it immediately so
	# focus cannot keep a tooltip alive while the board is being targeted.
	if index >= 0 and index < skills.size():
		skills[index].release_focus()
	skill_tooltip.hide_tooltip()
	grid.select_radial_skill(index)

func _toggle_teams() -> void:
	teams_open = not teams_open

func _process(_delta: float) -> void:
	grid.unit_panel.hide()
	grid.top_capture_hud.hide()
	grid.team_health_hud.visible = teams_open
	grid.get_node("CanvasLayer/EnemyTeamHealthHUD").visible = teams_open
	utilities.position = Vector2(22, 18)
	# Uniformly shrink only on narrow windows; never inherit the board scale.
	var hud_scale := minf(1.0, size.x / 1150.0)
	movement_icon.position = Vector2(24, size.y - 112 * hud_scale) + Vector2(177, 78) * hud_scale
	movement_icon.size = Vector2(30, 26) * hud_scale
	movement_icon.modulate = GOLD if grid.free_movement else Color("69665f")
	movement_icon.tooltip_text = "Free movement available" if grid.free_movement else "Free movement spent"
	movement_icon.visible = is_instance_valid(grid.active_unit)
	actions.scale = Vector2.ONE * hud_scale
	actions.position = Vector2(maxf(300 * hud_scale, (size.x - actions.size.x * hud_scale) * 0.5), size.y - 92 * hud_scale)
	zoom_button.text = "Default zoom" if grid.force_full_board_zoom else "Full board"
	var unit := grid.active_unit
	var valid := is_instance_valid(unit) and not grid.match_ended
	var blocked := not valid or grid.resolving_turn_start or grid.camera_move_pending
	blocked = blocked or (grid.netplay.is_networked() and not grid.netplay.owns_turn())
	blocked = blocked or (grid.active_skill != null and not grid.targeting_skill)
	for i in range(skills.size()):
		var button := skills[i]
		button.disabled = blocked or not grid.can_use_skill(i)
		if valid and i < unit.skills.size():
			var skill: Skill = unit.skills[i]
			button.text = "%d%s" % [i + 1, "\nPassive" if skill.is_passive else ("\n%d turns" % skill.cooldown_remaining if skill.cooldown_remaining > 0 else "")]
			button.tooltip_text = ""
			button.modulate = GOLD if grid.active_skill == skill else Color.WHITE
	move_button.disabled = blocked or (grid.energy <= 0 and not grid.free_movement)
	capture_button.disabled = blocked or not grid.capture_zone.can_unit_capture(unit)
	cancel_button.disabled = blocked or not (grid.targeting_skill or grid.current_action == GridField.Action.MOVE)
	end_button.disabled = blocked
	_update_skill_tooltip()
	queue_redraw()

func _update_skill_tooltip() -> void:
	var unit := grid.active_unit
	# Once a skill is selected, targeting feedback owns the screen. Hide the
	# informational popup even if the cursor is still over the clicked button.
	if not is_instance_valid(unit) or grid.match_ended or grid.targeting_skill or grid.active_skill != null:
		skill_tooltip.hide_tooltip()
		return
	var hovered := -1
	for i in range(skills.size()):
		# Inspect bounds so unavailable/passive skills remain readable too.
		if skills[i].get_global_rect().has_point(get_global_mouse_position()) or skills[i].has_focus():
			hovered = i
			break
	if hovered < 0 or hovered >= unit.skills.size():
		skill_tooltip.hide_tooltip()
		return
	var skill: Skill = unit.skills[hovered]
	skill_tooltip.show_skill(skill, skill.skill_name, Vector2.ZERO)
	# Center over the hovered button, with a 30px gap above its top edge.
	var viewport_size := get_viewport_rect().size
	var panel: PanelContainer = skill_tooltip.panel
	var fit := minf(1.0, minf((viewport_size.x - 32) / panel.size.x, (viewport_size.y - 130) / panel.size.y))
	panel.scale = Vector2.ONE * maxf(0.1, fit)
	var extent := panel.size * panel.scale
	var button_rect := skills[hovered].get_global_rect()
	panel.position = Vector2(
		clampf(button_rect.get_center().x - extent.x * 0.5, 16, maxf(16, viewport_size.x - extent.x - 16)),
		maxf(16, button_rect.position.y - 30 - extent.y)
	)

func _diamond(center: Vector2, radius: float, fill: Color, border: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, border, 1.5, true)

func _face(unit: Unit) -> Texture2D:
	if faces.has(unit):
		return faces[unit]
	var texture := grid.top_capture_hud.get_face_texture(unit)
	if unit.data == grid.berserker_data:
		var crop := AtlasTexture.new()
		crop.atlas = unit.sprite.sprite_frames.get_frame_texture("idle", 0)
		crop.region = Rect2(1120, 455, 330, 330)
		texture = crop
	faces[unit] = texture
	return texture

func _text(at: Vector2, value: String, font_size: int = 12, color: Color = GOLD) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if not is_instance_valid(grid):
		return
	var unit := grid.active_unit
	var hud_scale := minf(1.0, size.x / 1150.0)
	if is_instance_valid(unit):
		draw_set_transform(Vector2(24, size.y - 112 * hud_scale), 0, Vector2.ONE * hud_scale)
		_diamond(Vector2(46, 46), 46, INK, GOLD)
		var face := _face(unit)
		if face:
			draw_texture_rect(face, Rect2(18, 18, 56, 56), false)
		_text(Vector2(96, 30), unit.data.unit_name.to_upper(), 14)
		draw_rect(Rect2(94, 40, 172, 16), INK)
		draw_rect(Rect2(97, 43, 166 * clampf(float(unit.current_health) / maxf(1, unit.data.health), 0, 1), 10), Color("a83c35"))
		draw_rect(Rect2(94, 40, 172, 16), GOLD, false)
		_text(Vector2(96, 74), "%d / %d%s" % [unit.current_health, unit.data.health, "  +%d shield" % unit.temp_health if unit.temp_health > 0 else ""], 11)
		# Turns start with ONE energy, not two. Never imply a missing point.
		_diamond(Vector2(102, 91), 7, GOLD if grid.energy > 0 else INK, GOLD)
		_text(Vector2(116, 96), "%d AP" % grid.energy, 14, GOLD)
		_text(Vector2(215, 96), "Ready" if grid.free_movement else "Spent", 13, GOLD if grid.free_movement else MUTED)
		draw_set_transform(Vector2.ZERO)
	# Small initiative diamonds at the top, with compact capture status beneath.
	var count := mini(5, grid.turn_order.size())
	var start := clampi(grid.turn_index, 0, maxi(0, grid.turn_order.size() - count))
	var origin := Vector2(size.x * 0.5 - (count - 1) * 23, 34)
	for i in range(count):
		var next: Unit = grid.turn_order[start + i]
		var center := origin + Vector2(i * 46, 0)
		var active := next == unit
		_diamond(center, 23 if active else 18, INK, GOLD if active else MUTED)
		var texture := _face(next)
		if texture:
			draw_texture_rect(texture, Rect2(center - Vector2(12, 12), Vector2(24, 24)), false, Color.WHITE if active else Color("999084"))
	var score := grid.capture_zone.team_capture_points
	var status := "ROUND %d   ·   ALLIES %d — %d ENEMIES" % [grid.round_number, score.get(Unit.Side.PLAYER, 0), score.get(Unit.Side.ENEMY, 0)]
	var width := ThemeDB.fallback_font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_text(Vector2((size.x - width) * 0.5, 78), status, 11)
	var capture_text := grid.top_capture_hud.status_label.text
	width = ThemeDB.fallback_font.get_string_size(capture_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	_text(Vector2((size.x - width) * 0.5, 94), capture_text, 10, MUTED)
