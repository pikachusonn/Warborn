extends SceneTree

class TestUnit extends Unit:
	var healed := 0
	func heal(amount: int):
		healed += amount
	func update_status_icons():
		pass
	func shake() -> void:
		pass


func _initialize() -> void:
	var grid := GridField.new()
	var archer := TestUnit.new()
	var ally := TestUnit.new()
	archer.side = 0
	ally.side = 0
	archer.current_health = 100
	ally.current_health = 100
	grid.player_units.append(archer)
	grid.player_units.append(ally)
	ally.status_effects[Unit.EFFECTS.ALLY_ARCHER_MARK] = 3
	var skill := load("res://resources/skills/Archer/Rend/rend.tres") as Skill
	assert(skill.get_preview_healing(grid, archer, ally) == 30)
	skill.execute(grid, archer, [], Vector2i.ZERO, 0)
	assert(ally.healed == 30)
	assert(ally.get_status_stacks(Unit.EFFECTS.ALLY_ARCHER_MARK) == 0)
	archer.free()
	ally.free()
	grid.free()
	print("PASS: Rend heals 10 HP per allied mark and preview matches")
	quit()
