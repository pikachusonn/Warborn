extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1290, 720)
	var grid := load("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
	await process_frame
	var berserker := grid.player_units[2]
	var crater := berserker.skills[2] as Crater_Maker
	var landing := Vector2i(2, 6)
	grid.active_unit = berserker
	grid.energy = 1
	grid.free_movement = false
	grid.update_board_layout()
	grid.targeting_skill = true
	grid.target_tiles.assign([grid.tiles[landing]])
	await crater.on_tile_clicked(grid, berserker, landing)
	var expected_position := (Vector2(landing) + Vector2.ONE * 0.5) * GridField.TILE_SIZE
	assert(berserker.grid_position == landing)
	assert(berserker.position.distance_to(expected_position) < 0.01)
	grid.queue_free()
	print("PASS: Crater Maker lands on its tile while the camera follows")
	quit()
