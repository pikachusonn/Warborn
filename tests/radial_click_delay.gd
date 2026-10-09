extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := load("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
	await process_frame
	assert(is_instance_valid(grid.active_unit))
	grid.open_radial_skills()
	assert(grid.radial_skills_open)
	assert(grid.is_radial_click_blocked())
	while grid.is_radial_click_blocked():
		await process_frame
	assert(not grid.is_radial_click_blocked())
	grid.cancel_radial_movement()
	assert(not grid.radial_skills_open)
	assert(grid.is_radial_click_blocked())
	grid.queue_free()
	print("PASS: radial state transitions briefly block follow-up clicks")
	quit()
