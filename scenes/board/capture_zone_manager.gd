extends Node2D
class_name CaptureZoneManager

signal capture_state_changed

enum CaptureState {
	NEUTRAL,
	CAPTURING
}

const NEUTRAL_FILL := Color.TRANSPARENT
const NEUTRAL_BORDER := Color(0.72, 0.78, 0.86, 0.8)

const PLAYER_FILL := Color(0.15, 0.55, 1.0, 0.28)
const PLAYER_BORDER := Color(0.25, 0.75, 1.0, 0.9)

const ENEMY_FILL := Color(1.0, 0.2, 0.25, 0.28)
const ENEMY_BORDER := Color(1.0, 0.35, 0.25, 0.9)

const ZONE_RECT := Rect2(0.0, 256.0, 640.0, 128.0)

var state: CaptureState = CaptureState.NEUTRAL
var capturing_unit: Unit = null
var capturing_team: int = Unit.Side.PLAYER
var capture_turns_completed: int = 0
var team_capture_points := {
	Unit.Side.PLAYER: 0,
	Unit.Side.ENEMY: 0
}

var grid_field: GridField
var fill_layer: Node2D
var border_layer: Node2D
var pulse_time: float = 0.0

func _ready() -> void:
	fill_layer = Node2D.new()
	fill_layer.name = "CaptureFillLayer"
	fill_layer.z_index = 1
	fill_layer.draw.connect(_draw_fill)
	add_child(fill_layer)

	border_layer = Node2D.new()
	border_layer.name = "CaptureBorderLayer"
	border_layer.z_index = 4
	border_layer.draw.connect(_draw_border)
	add_child(border_layer)

func _draw_fill() -> void:
	if not is_instance_valid(fill_layer):
		return
	var fill_color := get_current_fill_color()
	fill_layer.draw_rect(ZONE_RECT, fill_color, true)

func _draw_border() -> void:
	if not is_instance_valid(border_layer):
		return
	var border_color := get_current_border_color()
	var base_alpha := 0.75
	if state == CaptureState.CAPTURING:
		base_alpha = 0.65 + 0.25 * sin(pulse_time * 4.5)

	# Wide soft outer glow (18px)
	border_layer.draw_rect(ZONE_RECT, Color(border_color.r, border_color.g, border_color.b, base_alpha * 0.08), false, 18.0)
	# Mid atmospheric glow (10px)
	border_layer.draw_rect(ZONE_RECT, Color(border_color.r, border_color.g, border_color.b, base_alpha * 0.18), false, 10.0)
	# Soft inner glow (5px)
	border_layer.draw_rect(ZONE_RECT, Color(border_color.r, border_color.g, border_color.b, base_alpha * 0.30), false, 5.0)
	# Thinned, low-opacity main border line (1.5px, 0.6 alpha)
	border_layer.draw_rect(ZONE_RECT, Color(border_color.r, border_color.g, border_color.b, base_alpha * 0.60), false, 1.5)

func _process(delta: float) -> void:
	if state == CaptureState.CAPTURING:
		pulse_time += delta
		border_layer.queue_redraw()

func setup(board: GridField) -> void:
	grid_field = board
	reset_match()

func reset_match() -> void:
	state = CaptureState.NEUTRAL
	capturing_unit = null
	capture_turns_completed = 0
	team_capture_points = {
		Unit.Side.PLAYER: 0,
		Unit.Side.ENEMY: 0
	}
	pulse_time = 0.0
	update_zone_visuals()

func is_inside_capture_zone(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GridField.WIDTH and (pos.y == 4 or pos.y == 5)

func can_unit_capture(unit: Unit) -> bool:
	if grid_field == null or not is_instance_valid(unit):
		return false
	return (
		state == CaptureState.NEUTRAL
		and not unit.is_defeated()
		and is_inside_capture_zone(unit.grid_position)
		and not unit.has_completed_capture
		and grid_field.energy >= 1
		and not grid_field.match_ended
	)

func start_capture(unit: Unit) -> void:
	if not can_unit_capture(unit):
		return
	capturing_unit = unit
	capturing_team = unit.side
	capture_turns_completed = 1
	state = CaptureState.CAPTURING
	pulse_time = 0.0

	grid_field.energy -= 1
	grid_field.unit_panel.update_energy(grid_field.energy)
	update_zone_visuals()
	capture_state_changed.emit()

	# Energy was spent; update radial menu or end turn if no actions left
	grid_field.clean_up_skill()

func on_unit_turn_start(unit: Unit) -> void:
	if state != CaptureState.CAPTURING or unit != capturing_unit:
		return

	if not is_capture_still_valid():
		cancel_capture()
		return

	capture_turns_completed += 1
	update_zone_visuals()
	capture_state_changed.emit()

	if capture_turns_completed >= 3:
		complete_capture()

func is_capture_still_valid() -> bool:
	return (
		is_instance_valid(capturing_unit)
		and not capturing_unit.is_defeated()
		and is_inside_capture_zone(capturing_unit.grid_position)
	)

func on_unit_position_changed(unit: Unit) -> void:
	if unit == capturing_unit:
		if not is_inside_capture_zone(unit.grid_position):
			cancel_capture()

func on_unit_defeated(unit: Unit) -> void:
	if unit == capturing_unit:
		cancel_capture()
	if grid_field != null:
		grid_field.check_elimination_victory()

func cancel_capture() -> void:
	capturing_unit = null
	capture_turns_completed = 0
	state = CaptureState.NEUTRAL
	pulse_time = 0.0
	update_zone_visuals()
	capture_state_changed.emit()

func reset_capture_zone() -> void:
	capturing_unit = null
	capture_turns_completed = 0
	state = CaptureState.NEUTRAL
	pulse_time = 0.0
	update_zone_visuals()
	capture_state_changed.emit()

func complete_capture() -> void:
	team_capture_points[capturing_team] += 1
	if is_instance_valid(capturing_unit):
		capturing_unit.has_completed_capture = true

	var scoring_team := capturing_team
	reset_capture_zone()

	if team_capture_points[scoring_team] >= 2 and grid_field != null:
		grid_field.end_match(scoring_team, "Capture")

func get_current_fill_color() -> Color:
	if state == CaptureState.CAPTURING:
		return PLAYER_FILL if capturing_team == Unit.Side.PLAYER else ENEMY_FILL
	return NEUTRAL_FILL

func get_current_border_color() -> Color:
	if state == CaptureState.CAPTURING:
		return PLAYER_BORDER if capturing_team == Unit.Side.PLAYER else ENEMY_BORDER
	return NEUTRAL_BORDER

func update_zone_visuals() -> void:
	if is_instance_valid(fill_layer):
		fill_layer.queue_redraw()
	if is_instance_valid(border_layer):
		border_layer.queue_redraw()
