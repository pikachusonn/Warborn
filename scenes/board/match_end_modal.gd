extends Control
class_name MatchEndModal

signal rematch_requested

var title_label: Label
var reason_label: Label
var details_label: Label
var button: Button

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.color = Color(0.04, 0.05, 0.08, 0.75)
	add_child(dim)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	add_child(center)

	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	card_style.border_color = Color(0.35, 0.45, 0.6, 0.8)
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left = 48
	card_style.content_margin_right = 48
	card_style.content_margin_top = 36
	card_style.content_margin_bottom = 36
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)

	title_label = Label.new()
	title_label.text = "MATCH FINISHED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(title_label)

	reason_label = Label.new()
	reason_label.text = "Victory by Capture Points"
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 20)
	reason_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	col.add_child(reason_label)

	details_label = Label.new()
	details_label.text = ""
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.7))
	col.add_child(details_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	button = Button.new()
	button.text = "Return to Lobby"
	button.custom_minimum_size = Vector2(200, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_button_pressed)
	col.add_child(button)

func show_match_end(winning_team: int, win_reason: String, local_side: int, player_points: int, enemy_points: int) -> void:
	visible = true
	var won: bool = winning_team == local_side
	var color := Color(0.25, 0.75, 1.0) if won else Color(1.0, 0.35, 0.25)
	if winning_team == -1:
		title_label.text = "DRAW MATCH"
		title_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	elif won:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", color)
	else:
		title_label.text = "DEFEAT"
		title_label.add_theme_color_override("font_color", color)

	var winner_name := "Allies" if winning_team == Unit.Side.PLAYER else "Enemies"
	reason_label.text = "%s victory by %s!" % [winner_name, win_reason]
	details_label.text = "Final Capture Points — Allies: %d · Enemies: %d" % [player_points, enemy_points]

func _on_button_pressed() -> void:
	var netplay = get_node_or_null("/root/Netplay")
	if netplay != null:
		netplay.leave()
	else:
		get_tree().change_scene_to_file("res://network/lobby.tscn")
