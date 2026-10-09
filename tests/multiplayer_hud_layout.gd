extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1290, 720)
	var grid := load("res://scenes/board/grid_field.tscn").instantiate() as GridField
	root.add_child(grid)
	await process_frame
	var session := root.get_node("Netplay")
	var ally_hud := grid.team_health_hud
	var enemy_hud := grid.get_node("CanvasLayer/EnemyTeamHealthHUD") as TeamHealthHUD
	for mode in [session.Mode.HOST, session.Mode.CLIENT]:
		session.mode = mode
		grid.top_capture_hud._process(0.0)
		ally_hud._process(0.0)
		enemy_hud._process(0.0)
		await process_frame
		assert(grid.top_capture_hud.panel.global_position.y >= 56.0)
		assert(ally_hud.global_position.y >= grid.top_capture_hud.panel.global_position.y + grid.top_capture_hud.panel.size.y + 8.0)
		assert(is_equal_approx(ally_hud.global_position.y, enemy_hud.global_position.y))
		assert(enemy_hud.visible)
		assert(ally_hud.get_team_units() == (grid.enemy_units if mode == session.Mode.CLIENT else grid.player_units))
		assert(enemy_hud.get_team_units() == (grid.player_units if mode == session.Mode.CLIENT else grid.enemy_units))
		for index in enemy_hud.unit_rows.size():
			assert(enemy_hud.unit_rows[index].unit == enemy_hud.get_team_units()[index])
	session.mode = session.Mode.LOCAL
	grid.queue_free()
	print("PASS: multiplayer HUD clears the connection header and shows both teams on host and guest")
	quit()
