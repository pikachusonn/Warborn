extends SceneTree

class TestUnit extends Unit:
	func update_hp_bar() -> void:
		pass
	func shake() -> void:
		pass

class TestTile extends TileScene:
	func _ready() -> void:
		pass
	func clear_aoe() -> void:
		pass


func _initialize() -> void:
	for caster_is_player in [true, false]:
		var grid := GridField.new()
		for x in range(10):
			for y in range(10):
				var tile := TestTile.new()
				tile.position = Vector2(x * 64, y * 64)
				grid.tiles[Vector2i(x, y)] = tile
				grid.add_child(tile)
		var caster := _add_unit(grid, Vector2i(4, 7), caster_is_player)
		var ally_ahead := _add_unit(grid, Vector2i(4, 5), caster_is_player)
		var enemy_ahead := _add_unit(grid, Vector2i(4, 4), not caster_is_player)
		var ally_side := _add_unit(grid, Vector2i(3, 6), caster_is_player)
		var blocking_ally := _add_unit(grid, Vector2i(2, 6), caster_is_player)
		var skill := load("res://resources/skills/Breacher/Unstoppable_force/unstoppable_force.tres") as Unstoppable_force
		var targets := skill.get_target_tiles(grid, caster, Vector2i.UP, 3)
		var hazard_position := Vector2i(5, 5)
		var blocker := Node2D.new()
		grid.add_child(blocker)
		grid.add_movement_blocker(hazard_position, blocker)
		skill.execute(grid, caster, targets, Vector2i.UP, 3)
		assert(ally_ahead.current_health == 100)
		assert(ally_side.current_health == 100)
		assert(enemy_ahead.current_health == 100 - skill.damage)
		assert(ally_ahead.grid_position != Vector2i(4, 5))
		assert(ally_side.grid_position == Vector2i(3, 6))
		assert(blocking_ally.grid_position == Vector2i(2, 6))
		assert(not grid.movement_blockers.has(hazard_position))
		var occupied := {}
		for unit in grid.player_units + grid.enemy_units:
			assert(not occupied.has(unit.grid_position))
			occupied[unit.grid_position] = true
		caster.grid_position = Vector2i(0, 9)
		skill.execute(grid, caster, [], Vector2i.RIGHT, 9)
		assert(caster.grid_position == Vector2i(3, 9))
		grid.free()
	print("PASS: Unstoppable Force limits charge to 3 tiles, prevents overlaps, and clears ground blockers")
	quit()


func _add_unit(grid: GridField, position: Vector2i, is_player: bool) -> TestUnit:
	var unit := TestUnit.new()
	unit.grid_position = position
	unit.current_health = 100
	unit.side = 0 if is_player else 1
	grid.add_child(unit)
	if is_player:
		grid.player_units.append(unit)
	else:
		grid.enemy_units.append(unit)
	return unit
