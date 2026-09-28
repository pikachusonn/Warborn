extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 900)
	var grid := preload("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	var spawn_bursts := 0
	for child in grid.get_children():
		if child is AnimatedSprite2D:
			spawn_bursts += 1
	assert(spawn_bursts == grid.player_units.size() + grid.enemy_units.size())
	var victim := grid.enemy_units[0]
	victim.take_damage(victim.data.health + victim.temp_health)
	assert(victim.is_defeated())
	var bursts_after_death := 0
	for child in grid.get_children():
		if child is AnimatedSprite2D:
			bursts_after_death += 1
	assert(bursts_after_death == spawn_bursts + 1)
	await create_timer(1.3).timeout
	for child in grid.get_children():
		assert(not child is AnimatedSprite2D)
	print("PASS: Dust bursts play on spawn and death, then clean up")
	quit()
