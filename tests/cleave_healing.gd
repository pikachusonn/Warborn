extends Node

class TestUnit extends Unit:
	var shown_damage := 0
	var shown_healing := 0
	func update_hp_bar() -> void:
		pass
	func update_status_icons() -> void:
		pass
	func shake() -> void:
		pass
	func clear_health_preview() -> void:
		shown_damage = 0
		shown_healing = 0
	func show_health_preview(damage_amount: int, healing_amount: int) -> void:
		shown_damage = damage_amount
		shown_healing = healing_amount

func _ready() -> void:
	var berserker := load("res://resources/units/Berserker/Berserker.tres") as UnitData
	assert(berserker.skills[0] is Cleave, "Berserker must load Cleave, not Helmet Splitter")
	assert(berserker.skills[1] is Chop)
	assert(berserker.skills[3] is BloodLust)
	var grid := GridField.new()
	var caster := TestUnit.new()
	caster.data = UnitData.new()
	caster.current_health = 40
	caster.grid_position = Vector2i(2, 2)
	var passive := BloodLust.new()
	caster.skills.append(passive)
	var enemy := TestUnit.new()
	enemy.data = UnitData.new()
	enemy.side = 1
	enemy.current_health = 100
	enemy.grid_position = Vector2i(2, 1)
	grid.player_units.append(caster)
	grid.enemy_units.append(enemy)
	var tile := TileScene.new()
	tile.grid_position = enemy.grid_position
	grid.target_tiles.append(tile)
	grid.active_unit = caster
	grid.active_skill = load("res://resources/skills/Berserker/Cleave/cleave.tres").duplicate() as Cleave
	grid.active_skill.damage = 25
	grid.targeting_skill = true
	grid.update_health_previews()
	assert(caster.shown_healing == 10, "First Cleave heals base amount and grants its stack only after healing")
	assert(enemy.shown_healing == 0 and enemy.shown_damage == 25)
	var positions: Array[Vector2i] = [enemy.grid_position]
	grid.active_skill.execute(grid, caster, positions, Vector2i.UP, 1)
	assert(caster.current_health == 50 and enemy.current_health == 75)
	assert(passive.stacks == 1, "First Cleave grants one stack")
	enemy.temp_health = 10
	grid.update_health_previews()
	assert(caster.shown_healing == 23, "Enhanced healing uses HP damage after shields")
	assert(enemy.shown_healing == 0)
	grid.active_skill.execute(grid, caster, positions, Vector2i.UP, 1)
	assert(caster.current_health == 73 and enemy.current_health == 60)
	assert(passive.stacks == 0)
	caster.heal(1000)
	assert(caster.current_health == caster.data.health)
	var chop := berserker.skills[1].duplicate() as Chop
	chop.damage = 20
	chop.execute(grid, caster, positions, Vector2i.UP, 1)
	assert(passive.stacks == 1 and enemy.current_health == 40)
	caster.current_health = 40
	grid.update_health_previews()
	assert(caster.shown_healing == 15 and enemy.shown_healing == 0)
	grid.active_skill.execute(grid, caster, positions, Vector2i.UP, 1)
	assert(passive.stacks == 2 and caster.current_health == 55)
	grid.active_skill.damage = 20
	var expected_heals := [0, 25, 31, 39, 47, 55]
	for stacks in range(1, 6):
		passive.stacks = stacks
		passive.last_attack = "cleave"
		caster.current_health = 1
		enemy.current_health = 100
		enemy.temp_health = 0
		var expected_healing: int = expected_heals[stacks]
		grid.update_health_previews()
		assert(caster.shown_healing == expected_healing)
		grid.active_skill.execute(grid, caster, positions, Vector2i.UP, 1)
		assert(caster.current_health == 1 + expected_healing)
	var expected_base_heals := [10, 15, 20, 25, 30, 35]
	for stacks in range(1, 6):
		passive.stacks = stacks
		passive.last_attack = "chop"
		caster.current_health = 40
		enemy.current_health = 100
		var expected_base_healing: int = expected_base_heals[stacks]
		grid.update_health_previews()
		assert(caster.shown_healing == expected_base_healing)
		grid.active_skill.execute(grid, caster, positions, Vector2i.UP, 1)
		assert(caster.current_health == 40 + expected_base_healing)
	tile.free()
	caster.free()
	enemy.free()
	grid.free()
	print("PASS: Cleave caster healing and health previews")
	get_tree().quit()
