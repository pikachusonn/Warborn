extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1290, 720)
	var host := load("res://scenes/board/grid_field.tscn").instantiate() as GridField
	var guest := load("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(host)
	root.add_child(guest)
	await process_frame
	var move_pos := Vector2i(4, 4)
	var attack_pos := Vector2i(5, 5)
	host.tiles[move_pos].set_moveable(true)
	host.tiles[attack_pos].set_attackable(true)
	host.tiles[move_pos].set_hovered(true)
	host.target_tiles.assign([host.tiles[move_pos], host.tiles[attack_pos]])
	var state := preload("res://network/combat_state.gd").new(host).capture()
	var session := root.get_node("Netplay")
	session.mode = session.Mode.CLIENT
	guest.update_board_layout()
	preload("res://network/combat_state.gd").new(guest).apply(state)
	assert(guest.target_tiles.size() == 2)
	assert(guest.tiles[move_pos].highlight_color == host.tiles[move_pos].highlight_color)
	assert(guest.tiles[attack_pos].highlight_color == host.tiles[attack_pos].highlight_color)
	assert(not guest.tiles[move_pos].is_hovered, "Private pointer hover must not replicate")
	assert(guest.cavern_background.flip_v and not host.cavern_background.flip_v)
	var artwork_scale := guest.cavern_background.size / GridField.BAKED_BACKGROUND_SIZE
	var flipped_board_top := GridField.BAKED_BACKGROUND_SIZE.y - GridField.BAKED_BOARD_ORIGIN.y - GridField.BAKED_BOARD_SIZE.y
	var painted_board_origin := guest.cavern_background.position + Vector2(GridField.BAKED_BOARD_ORIGIN.x, flipped_board_top) * artwork_scale
	assert(painted_board_origin.distance_to(Vector2.ZERO) < 0.01)
	assert(guest.background_layer.transform == guest.transform)
	session.mode = session.Mode.LOCAL
	host.queue_free()
	guest.queue_free()
	print("PASS: guest targeting colors replicate and background mirrors with the guest board")
	quit()
