extends Area2D
class_name UnitClickArea
signal unit_clicked(unit: Unit)

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				unit_clicked.emit(get_parent())
