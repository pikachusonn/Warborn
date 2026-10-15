extends Area2D
class_name UnitClickArea
signal unit_clicked(unit: Unit)

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null and _is_ui_element(hovered):
			return
		unit_clicked.emit(get_parent())

func _is_ui_element(ctrl: Control) -> bool:
	var c: Node = ctrl
	while c != null and not (c is Window):
		if c is BaseButton or c.name == "Actions" or c.name == "Utilities" or c.name == "BottomHUD" or c.name == "OffscreenHUD":
			return true
		c = c.get_parent()
	return false
