extends Node2D

const TILEMAP := preload("res://assets/terrain/tilemap_color3.png")
const TILE_SIZE := 64
const BOARD_TILES := 10

func _draw() -> void:
	# The top-left 3x3 block contains the grass corners, edges, and center.
	# Keep its dark pixel outline around the board instead of cropping it away.
	for x in range(BOARD_TILES):
		for y in range(BOARD_TILES):
			var source_x := 0 if x == 0 else 128 if x == BOARD_TILES - 1 else 64
			var source_y := 0 if y == 0 else 128 if y == BOARD_TILES - 1 else 64
			draw_texture_rect_region(
				TILEMAP,
				Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE),
				Rect2(source_x, source_y, TILE_SIZE, TILE_SIZE)
			)
