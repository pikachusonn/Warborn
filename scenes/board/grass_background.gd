extends Node2D

const MAP_TEXTURE := preload("res://assets/terrain/map_10x10_uniform_borders_v3_rocky.png")
const TILE_SIZE := 64
const BOARD_TILES := 10

func _draw() -> void:
	var board_size := Vector2(TILE_SIZE * BOARD_TILES, TILE_SIZE * BOARD_TILES)
	draw_texture_rect(MAP_TEXTURE, Rect2(Vector2.ZERO, board_size), false)
