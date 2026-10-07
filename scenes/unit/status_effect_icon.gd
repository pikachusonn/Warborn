extends TextureRect
class_name status_effect_icon

@export var status_name: String
@export var description: String
@export var status_id: String

var tooltip: StatusTooltip
var owner_unit: Unit
@onready var stack_label: Label = get_node_or_null("StackLabel")

func setup(
	tooltip_instance: StatusTooltip,
	unit: Unit
):
	tooltip = tooltip_instance
	owner_unit = unit
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_stack_count(count: int) -> void:
	if stack_label == null:
		stack_label = get_node_or_null("StackLabel")
	if stack_label:
		stack_label.text = str(count)

func _on_mouse_entered() -> void:
	if tooltip == null:
		return

	var stack := owner_unit.get_status_stacks(status_id)
	tooltip.show_status(
		status_name,
		stack,
		description
	)

func _on_mouse_exited() -> void:
	if tooltip:
		tooltip.hide_status()
