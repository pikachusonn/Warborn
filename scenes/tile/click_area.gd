extends Area2D

signal clicked

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hovered := viewport.gui_get_hovered_control()
		if hovered != null and _is_ui_element(hovered):
			return
		clicked.emit()

func _is_ui_element(ctrl: Control) -> bool:
	var c: Node = ctrl
	while c != null and not (c is Window):
		if c is BaseButton or c.name == "Actions" or c.name == "Utilities" or c.name == "BottomHUD" or c.name == "OffscreenHUD":
			return true
		c = c.get_parent()
	return false
