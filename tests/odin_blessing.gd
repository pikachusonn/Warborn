extends SceneTree

class TestGrid extends GridField:
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass


class TestUnit extends Unit:
	var shake_count := 0
	func update_hp_bar() -> void:
		pass
	func shake() -> void:
		shake_count += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var grid := TestGrid.new()
	var canvas := load("res://scenes/canvas_layer.tscn").instantiate() as CanvasLayer
	canvas.name = "CanvasLayer"
	grid.add_child(canvas)
	root.add_child(grid)
	var scene := load("res://scenes/tile/tile.tscn") as PackedScene
	for x in range(6):
		for y in range(6):
			var tile := scene.instantiate() as TileScene
			root.add_child(tile)
			grid.tiles[Vector2i(x, y)] = tile
	var caster := TestUnit.new()
	caster.data = UnitData.new()
	caster.current_health = 100
	caster.grid_position = Vector2i(2, 2)
	var enemy := TestUnit.new()
	enemy.side = 1
	enemy.current_health = 100
	enemy.grid_position = Vector2i(1, 2)
	grid.player_units.append(caster)
	grid.enemy_units.append(enemy)
	var ally := TestUnit.new()
	ally.current_health = 100
	ally.grid_position = Vector2i(2, 1)
	grid.player_units.append(ally)
	var blessing := load("res://resources/skills/Berserker/Odin's Blessing/odin_blessing.tres").duplicate() as OdinBlessing
	blessing.execute(grid, caster, blessing.get_impact_tiles(grid, Vector2i(2, 2)), Vector2i(2, 2), 0)
	assert(enemy.current_health == 100)
	assert(grid.aoe_tile_owners.size() == 9)
	assert(blessing.active_zones[0]["cloud"].tiles.size() == 9)
	var cloud = blessing.active_zones[0]["cloud"]
	assert(cloud.countdown.text == "2")
	assert(not cloud.countdown.visible)
	# Cloud visibility changes must not remove gameplay coverage.
	grid.active_unit = caster
	grid.hovered_unit = enemy
	cloud.update_cleared_tiles(grid)
	assert(caster.grid_position in cloud.cleared_tiles)
	assert(enemy.grid_position in cloud.cleared_tiles)
	assert(ally.grid_position not in cloud.cleared_tiles)
	grid.hovered_unit = null
	grid.targeting_skill = true
	grid.target_tiles.append(grid.tiles[ally.grid_position])
	grid.impact_preview_tiles.append(grid.tiles[enemy.grid_position])
	cloud.update_cleared_tiles(grid)
	assert(cloud.cleared_tiles.size() == 3)
	assert(cloud.tiles.size() == 9 and grid.aoe_tile_owners.size() == 9)
	grid.targeting_skill = false
	grid.current_action = GridField.Action.MOVE
	cloud.update_cleared_tiles(grid)
	assert(cloud.cleared_tiles.size() == 1)
	grid.active_unit = null
	grid.current_action = GridField.Action.NONE
	grid.target_tiles.clear()
	grid.impact_preview_tiles.clear()
	cloud.update_cleared_tiles(grid)
	assert(cloud.cleared_tiles.is_empty())
	grid.suppress_aoe_hover(blessing.get_aoe_zone_tiles(Vector2i(2, 2)))
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(not is_instance_valid(grid.aoe_hover_glow) or grid.aoe_hover_glow.positions.is_empty())
	assert(is_equal_approx(cloud.material.get_shader_parameter("opacity"), 0.18))
	grid.update_aoe_hover(Vector2i(1, 2))
	assert(not grid.suppressed_aoe_hover_tiles.is_empty())
	grid.update_aoe_hover(Vector2i(0, 0))
	assert(grid.suppressed_aoe_hover_tiles.is_empty())
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(grid.aoe_hover_glow.positions.size() == 9)
	assert(is_equal_approx(cloud.material.get_shader_parameter("opacity"), 1.0))
	assert(cloud.countdown.visible)
	assert(is_equal_approx(grid.tiles[Vector2i(2, 2)].aoe_overlay.color.a, 0.55))
	grid.targeting_skill = true
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(grid.aoe_hover_glow.positions.is_empty())
	assert(not cloud.countdown.visible)
	assert(is_equal_approx(cloud.material.get_shader_parameter("opacity"), 0.18))
	assert(is_equal_approx(grid.tiles[Vector2i(2, 2)].aoe_overlay.color.a, 0.35))
	grid.targeting_skill = false
	grid.update_aoe_hover(Vector2i(1, 2))
	assert(not cloud.countdown.visible)
	assert(grid.aoe_hover_glow.positions.is_empty())
	grid.update_aoe_hover(Vector2i.ZERO)
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(cloud.countdown.visible)
	grid.current_action = GridField.Action.MOVE
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(grid.aoe_hover_glow.positions.is_empty())
	assert(not cloud.countdown.visible)
	assert(is_equal_approx(cloud.material.get_shader_parameter("opacity"), 0.18))
	grid.current_action = GridField.Action.NONE
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(not cloud.countdown.visible)
	grid.update_aoe_hover(Vector2i(1, 2))
	assert(grid.aoe_hover_glow.positions.is_empty())
	assert(is_equal_approx(cloud.material.get_shader_parameter("opacity"), 0.18))
	grid.update_aoe_hover(Vector2i.ZERO)
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(cloud.countdown.visible)
	grid.clear_hover()
	assert(not cloud.countdown.visible)
	assert(is_equal_approx(cloud.material.get_shader_parameter("opacity"), 0.18))
	await blessing.on_owner_turn_start(grid)
	assert(cloud.countdown.text == "1")
	assert(enemy.current_health == 100 and caster.temp_health == 0)
	assert(blessing.active_zones.size() == 1)
	var red_phase_checked := [false]
	create_timer(0.7).timeout.connect(func():
		assert(cloud.countdown.text == "0")
		assert(cloud.countdown.visible)
		assert(enemy.current_health == 100 and caster.temp_health == 0)
		assert(grid.tiles[Vector2i(2, 2)].modulate.is_equal_approx(Color(1.0, 0.2, 0.2)))
		red_phase_checked[0] = true
	)
	await blessing.on_owner_turn_start(grid)
	assert(red_phase_checked[0])
	assert(grid.tiles[Vector2i(2, 2)].modulate == Color.WHITE)
	assert(enemy.current_health == 80)
	assert(caster.temp_health == 50)
	assert(caster.shake_count == 1)
	assert(ally.current_health == 100 and ally.temp_health == 0)
	assert(grid.aoe_tile_owners.is_empty())
	assert(blessing.active_zones.is_empty())
	await blessing.on_owner_turn_start(grid)
	assert(enemy.current_health == 80)
	# Quagmire overwrites six tiles, including the caster: no shield there.
	caster.temp_health = 0
	blessing.execute(grid, caster, blessing.get_impact_tiles(grid, Vector2i(2, 2)), Vector2i(2, 2), 0)
	var mud := Quagmire.new()
	mud.owner = caster
	mud.create_quagmire_zone(grid, mud.get_zone_tiles(Vector2i(3, 2)))
	assert(blessing.active_zones[0]["cloud"].tiles.size() == 3)
	assert(not grid.tiles[Vector2i(2, 2)].aoe_overlay.visible)
	await blessing.on_owner_turn_start(grid)
	assert(enemy.current_health == 80)
	await blessing.on_owner_turn_start(grid)
	assert(enemy.current_health == 60)
	assert(caster.temp_health == 0)
	assert(caster.shake_count == 1)
	assert(grid.aoe_tile_owners.size() == 9)
	# Blessing can overwrite Quagmire and be recast without losing ownership.
	for iteration in range(2):
		blessing.execute(grid, caster, blessing.get_impact_tiles(grid, Vector2i(3, 2)), Vector2i(3, 2), 0)
	assert(mud.active_zones.is_empty())
	assert(blessing.active_zones.size() == 1)
	assert(grid.aoe_tile_owners.size() == 9)
	for tile in grid.tiles.values():
		tile.free()
	grid.free()
	caster.free()
	enemy.free()
	ally.free()
	print("PASS: Odin delayed damage, shield, expiry, cloud coverage, hover and cross-skill overlaps")
	quit()
