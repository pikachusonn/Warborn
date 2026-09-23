extends SceneTree

class TestUnit extends Unit:
	var shake_count := 0
	func update_hp_bar() -> void:
		pass
	func shake() -> void:
		shake_count += 1

func _initialize() -> void:
	var grid := GridField.new()
	var skill := load("res://resources/skills/Berserker/Crater Maker/crater_maker.tres") as Crater_Maker
	for caster_side in [0, 1]:
		var units: Array[Unit] = []
		for index in range(4):
			var unit := TestUnit.new()
			unit.side = caster_side if index < 2 else 1 - caster_side
			unit.current_health = 100
			unit.grid_position = Vector2i(index, 0)
			units.append(unit)
			if unit.side == 0:
				grid.player_units.append(unit)
			else:
				grid.enemy_units.append(unit)
		var impact: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		skill.execute(grid, units[0], impact, Vector2i.ZERO, 3)
		assert(units[0].current_health == 100)
		assert(units[1].current_health == 100)
		assert(units[2].current_health == 100 - skill.damage)
		assert(units[3].current_health == 100)
		assert(units[1].shake_count == 0 and units[2].shake_count == 1)
		grid.player_units.clear()
		grid.enemy_units.clear()
		for unit in units:
			unit.free()
	grid.free()
	print("PASS: Crater Maker hits only opponents in its impact area for either team")
	quit()
