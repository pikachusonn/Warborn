extends Node2D

signal end_turn_pressed
signal move_pressed
signal action_pressed
signal capture_pressed
signal skill_pressed(index: int)

@export var inner_radius := 52.0
@export var outer_radius := 108.0

const SEGMENT_COUNT := 3
const START_ANGLE := 112.5
const SEGMENT_ANGLE := 45.0
const CURVE_STEPS := 16
const SKILL_ICON = preload("res://assets/icons/action_menu/skill_placeholder.png")

const FILL := Color(0.16, 0.25, 0.4, 0.65)
const BORDER := Color(0.55, 0.75, 1.0, 0.7)
const IDLE_ICON := Color(0.8, 0.9, 1.0, 0.8)
# Segments run from bottom to top: EndTurn, Move, Action, Capture.
const HOVER_COLORS := [
	Color(1.0, 0.4, 0.45),
	Color(0.5, 1.0, 0.65),
	Color(1.0, 0.65, 0.4),
	Color(0.35, 0.85, 1.0),
]

const END_TURN_RED := Color(1.0, 0.4, 0.45)
const CASH_YELLOW := Color(1.0, 0.85, 0.18)
const CASH_FINAL_ORANGE := Color(1.0, 0.32, 0.08)
const ALTERNATE_BLUE_FILL := Color(0.18, 0.32, 0.55, 0.92)
const ALTERNATE_BLUE_BORDER := Color(0.45, 0.78, 1.0)
var pulse_time: float = 0.0

func get_active_unit() -> Unit:
	var grid := get_grid()
	if grid != null and is_instance_valid(grid.active_unit):
		return grid.active_unit
	return null

func get_grid() -> GridField:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is GridField:
			return ancestor as GridField
		ancestor = ancestor.get_parent()
	return null

func get_berserker_skill_status(segment_index: int) -> Dictionary:
	if not skills_mode:
		return {"is_alternating": false, "is_cashout": false, "stacks": 0}
	var unit := get_active_unit()
	if unit == null or unit.skills == null:
		return {"is_alternating": false, "is_cashout": false, "stacks": 0}
	var blood_lust := BloodLust.get_blood_lust(unit)
	if blood_lust == null:
		return {"is_alternating": false, "is_cashout": false, "stacks": 0}
	
	var skill_index := 3 - segment_index
	if skill_index < 0 or skill_index >= unit.skills.size():
		return {"is_alternating": false, "is_cashout": false, "stacks": 0}
	
	var skill: Skill = unit.skills[skill_index]
	var is_alt := false
	var is_cash := false
	if skill is Cleave:
		if blood_lust.last_attack == "chop":
			is_alt = true
		elif blood_lust.last_attack == "cleave":
			is_cash = true
	elif skill is Chop:
		if blood_lust.last_attack == "cleave":
			is_alt = true
		elif blood_lust.last_attack == "chop":
			is_cash = true
	
	return {
		"is_alternating": is_alt,
		"is_cashout": is_cash,
		"stacks": blood_lust.stacks
	}

var hovered_segment := -1
var skills_mode := false
var capture_mode := false
var capture_available := false
var skill_availability: Array[bool] = []
var skill_tooltip: CanvasLayer
var is_sidebar_mode := false
const SKILL_COLOR := Color(1.0, 0.85, 0.3)

func set_skills_mode(value: bool) -> void:
	if skills_mode == value:
		return
	skills_mode = value
	hovered_segment = -1
	update_icon_positions()
	update_icon_colors()
	queue_redraw()

func set_capture_mode(in_zone: bool, can_capture: bool) -> void:
	if capture_mode == in_zone and capture_available == can_capture:
		return
	capture_mode = in_zone
	capture_available = can_capture
	update_icon_positions()
	update_icon_colors()
	queue_redraw()

func set_skill_availability(value: Array[bool]) -> void:
	if skill_availability == value:
		return
	skill_availability = value.duplicate()
	queue_redraw()

func is_segment_available(segment: int) -> bool:
	if skills_mode:
		var index := 3 - segment
		return index >= 0 and index < skill_availability.size() and skill_availability[index]
	if capture_mode and segment == 3:
		return capture_available
	return true

func segment_count() -> int:
	return 4 if (skills_mode or capture_mode) else 3

func arc_start() -> float:
	return 90.0 if (skills_mode or capture_mode) else START_ANGLE

func arc_size() -> float:
	return 180.0 if (skills_mode or capture_mode) else SEGMENT_COUNT * SEGMENT_ANGLE

@onready var icons: Array[TextureButton] = [
	$"../EndTurn",
	$"../Move",
	$"../Action",
	$"../Capture",
]

func _ready() -> void:
	update_icon_positions()
	update_icon_colors()
	skill_tooltip = preload("res://scenes/action_menu/skill_tooltip.gd").new()
	add_child(skill_tooltip)

func update_icon_positions() -> void:
	var r := (inner_radius + outer_radius) / 2.0
	if skills_mode:
		for icon in icons:
			if is_instance_valid(icon):
				icon.visible = false
		return
	var count := segment_count()
	var seg_angle := arc_size() / float(count)
	var active_count := 4 if capture_mode else 3
	for index in range(active_count):
		if index < icons.size() and is_instance_valid(icons[index]):
			var btn := icons[index]
			var angle := arc_start() + (index + 0.5) * seg_angle
			var center := Vector2.from_angle(deg_to_rad(angle)) * r
			btn.pivot_offset = btn.size / 2.0
			btn.position = center - btn.pivot_offset
			btn.visible = true
	if not capture_mode and icons.size() > 3 and is_instance_valid(icons[3]):
		icons[3].visible = false

func _input(event: InputEvent) -> void:
	if not get_node("/root/Netplay").can_input():
		return
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var segment := get_segment_at(get_local_mouse_position())
		if segment < 0:
			return
		# Consume the click before the grid or a unit underneath receives it.
		get_viewport().set_input_as_handled()
		if event.pressed:
			if skills_mode:
				if is_segment_available(segment):
					skill_pressed.emit(3 - segment)
			elif capture_mode:
				if segment == 0:
					end_turn_pressed.emit()
				elif segment == 1:
					move_pressed.emit()
				elif segment == 2:
					action_pressed.emit()
				elif segment == 3 and capture_available:
					capture_pressed.emit()
			elif segment == 0:
				end_turn_pressed.emit()
			elif segment == 1:
				move_pressed.emit()
			else:
				action_pressed.emit()
	
func _process(delta: float) -> void:
	update_hover_from_point(get_local_mouse_position())
	if skills_mode and is_visible_in_tree():
		pulse_time += delta
		queue_redraw()

func update_hover_from_point(point: Vector2) -> void:
	var next_segment := get_segment_at(point)
	update_skill_tooltip(next_segment)
	# Inspection remains local, but an observer must not get actionable hover tint.
	if not get_node("/root/Netplay").can_input():
		next_segment = -1

	if next_segment != hovered_segment:
		hovered_segment = next_segment
		update_icon_colors()
		queue_redraw()

func show_sidebar_tooltip(skill: Skill, display_name: String) -> void:
	is_sidebar_mode = true
	if is_instance_valid(skill_tooltip):
		skill_tooltip.show_skill_sidebar(skill, display_name)

func hide_sidebar_tooltip() -> void:
	is_sidebar_mode = false
	if is_instance_valid(skill_tooltip):
		skill_tooltip.hide_tooltip()

func update_skill_tooltip(segment: int) -> void:
	if GridField.is_mobile():
		if not is_sidebar_mode:
			skill_tooltip.hide_tooltip()
		return

	var grid := get_grid()
	if not is_visible_in_tree() or segment < 0 or grid == null:
		skill_tooltip.hide_tooltip()
		return
	if not is_instance_valid(grid.active_unit) or grid.targeting_skill or grid.resolving_turn_start:
		skill_tooltip.hide_tooltip()
		return

	var character_position := grid.active_unit.get_global_transform_with_canvas().origin
	var menu_radius := 108.0 * get_global_transform_with_canvas().get_scale().x

	if skills_mode:
		var index := 3 - segment
		if index >= grid.active_unit.skills.size():
			skill_tooltip.hide_tooltip()
			return
		var names := [grid.active_unit.data.skill1_name, grid.active_unit.data.skill2_name, grid.active_unit.data.skill3_name, grid.active_unit.data.skill4_name]
		skill_tooltip.show_skill(grid.active_unit.skills[index], names[index], character_position - Vector2(menu_radius, 0))
	elif capture_mode and segment == 3:
		skill_tooltip.show_capture(character_position - Vector2(menu_radius, 0), capture_available)
	else:
		skill_tooltip.hide_tooltip()


func get_segment_at(point: Vector2) -> int:
	var radius := point.length()
	if radius < inner_radius or radius > outer_radius:
		return -1

	var angle := fposmod(rad_to_deg(point.angle()), 360.0)
	var relative_angle := angle - arc_start()
	var total_angle := arc_size()

	if relative_angle < 0.0 or relative_angle >= total_angle:
		return -1

	return int(relative_angle / (total_angle / segment_count()))


func update_icon_colors() -> void:
	for index in range(icons.size()):
		if not is_instance_valid(icons[index]):
			continue
		var is_avail := is_segment_available(index) if (capture_mode and index == 3) else true
		if not is_avail:
			icons[index].self_modulate = Color(1, 1, 1, 0.3)
		elif index == hovered_segment:
			icons[index].self_modulate = HOVER_COLORS[index]
		else:
			icons[index].self_modulate = IDLE_ICON

func _draw() -> void:
	for index in range(segment_count()):
		draw_segment(index)
	if skills_mode:
		var icon_size := SKILL_ICON.get_size()
		icon_size *= 42.0 / maxf(icon_size.x, icon_size.y)
		for index in range(segment_count()):
			var angle := deg_to_rad(arc_start() + (index + 0.5) * arc_size() / segment_count())
			var center := Vector2.from_angle(angle) * (inner_radius + outer_radius) / 2.0
			var bz_status := get_berserker_skill_status(index)
			var is_special: bool = bz_status["is_cashout"] or bz_status["is_alternating"]
			var tint := Color(1, 1, 1, 0.28) if not is_segment_available(index) else (Color.WHITE if (index == hovered_segment or is_special) else Color(1, 1, 1, 0.8))
			draw_texture_rect(SKILL_ICON, Rect2(center - icon_size / 2.0, icon_size), false, tint)


func draw_segment(index: int) -> void:
	var segment_angle := arc_size() / float(segment_count())
	var start := deg_to_rad(arc_start() + index * segment_angle)
	var end := start + deg_to_rad(segment_angle)
	var points := PackedVector2Array()

	# Follow the outer curve.
	for step in range(CURVE_STEPS + 1):
		var angle := lerpf(start, end, float(step) / CURVE_STEPS)
		points.append(Vector2.from_angle(angle) * outer_radius)

	# Return along the inner curve to form a ring segment.
	for step in range(CURVE_STEPS, -1, -1):
		var angle := lerpf(start, end, float(step) / CURVE_STEPS)
		points.append(Vector2.from_angle(angle) * inner_radius)

	var outline := points.duplicate()
	outline.append(points[0])

	if not is_segment_available(index):
		var fill := Color(0.12, 0.15, 0.19, 0.42)
		var border := Color(0.35, 0.39, 0.44, 0.4)
		draw_colored_polygon(points, fill)
		draw_polyline(outline, Color(border, 0.06), 10.0, true)
		draw_polyline(outline, Color(border, 0.12), 6.0, true)
		draw_polyline(outline, border, 2.0, true)
		return

	var bz_status := get_berserker_skill_status(index)
	var is_hovered := (index == hovered_segment)

	if bz_status["is_alternating"]:
		# 1. Alternating skill: higher opacity for current blue + breathing glowing border like capture zone
		var pulse_alpha := 0.65 + 0.25 * sin(pulse_time * 4.5)
		var fill := ALTERNATE_BLUE_FILL
		if is_hovered:
			fill = Color(0.25, 0.45, 0.72, 0.96)
		draw_colored_polygon(points, fill)

		var glow_color := ALTERNATE_BLUE_BORDER
		if is_hovered:
			glow_color = Color(0.75, 0.92, 1.0)
		draw_polyline(outline, Color(glow_color, pulse_alpha * 0.18), 14.0, true)
		draw_polyline(outline, Color(glow_color, pulse_alpha * 0.38), 7.0, true)
		draw_polyline(outline, Color(glow_color, pulse_alpha * 0.95), 2.5, true)

	elif bz_status["is_cashout"]:
		# 2. Cash-out skill: yellow to red/orange background, opacity, vibrancy, and glow scale with stacks
		var stacks: int = bz_status["stacks"]
		var stack_ratio := clampf(float(stacks) / 5.0, 0.0, 1.0)
		var cash_color: Color = CASH_YELLOW.lerp(CASH_FINAL_ORANGE, stack_ratio)
		var fill_alpha := lerpf(0.55, 0.90, stack_ratio)
		var fill := Color(cash_color, fill_alpha)
		if is_hovered:
			fill = Color(cash_color.lerp(Color.WHITE, 0.25), minf(fill_alpha + 0.1, 1.0))
		draw_colored_polygon(points, fill)

		var cash_pulse := 0.70 + 0.30 * sin(pulse_time * (4.5 + stack_ratio * 3.0))
		var glow_alpha := cash_pulse * (0.85 + 0.15 * stack_ratio)
		var wide_width := 10.0 + 8.0 * stack_ratio
		var mid_width := 5.0 + 5.0 * stack_ratio
		var sharp_width := 2.0 + 1.5 * stack_ratio
		draw_polyline(outline, Color(cash_color, glow_alpha * (0.15 + 0.20 * stack_ratio)), wide_width, true)
		draw_polyline(outline, Color(cash_color, glow_alpha * (0.35 + 0.25 * stack_ratio)), mid_width, true)
		draw_polyline(outline, Color(cash_color.lerp(Color.WHITE, 0.2), glow_alpha), sharp_width, true)

	else:
		var fill := FILL
		var border := BORDER
		if is_hovered:
			var tint: Color = SKILL_COLOR if skills_mode else HOVER_COLORS[index]
			fill = Color(tint, 0.75)
			border = Color(tint, 1.0)
		draw_colored_polygon(points, fill)
		draw_polyline(outline, Color(border, 0.06), 10.0, true)
		draw_polyline(outline, Color(border, 0.12), 6.0, true)
		draw_polyline(outline, border, 2.0, true)
