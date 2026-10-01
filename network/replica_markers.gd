extends Node2D
## Basic pillars, pads, and shields for the stage 2 playable checkpoint.
var markers: Array = []

func _ready() -> void:
	z_index = 500

func set_markers(value: Array) -> void:
	if markers != value:
		markers = value.duplicate(true)
		queue_redraw()

func _draw() -> void:
	for marker in markers:
		if marker.kind == "polygon":
			var transform: Transform2D = marker.transform
			if marker.upright:
				transform = transform * Transform2D(PI, Vector2.ZERO)
			draw_set_transform_matrix(transform)
			draw_colored_polygon(marker.points, marker.color)
		else:
			draw_set_transform_matrix(Transform2D.IDENTITY)
			if marker.points.size() >= 2:
				draw_polyline(marker.points, marker.color, marker.width, true)
