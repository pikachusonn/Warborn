extends Control
class_name StatusTooltip

@onready var name_label: Label = $PanelContainer/VBoxContainer/Label
@onready var description_label: Label = $PanelContainer/VBoxContainer/Description

func _ready() -> void:
	hide()

func show_status(
	status_name: String,
	stack: int,
	description: String
) -> void:
	name_label.text = status_name + " (" + str(stack) + ")"
	description_label.text = description
	show()

func hide_status() -> void:
	hide()
