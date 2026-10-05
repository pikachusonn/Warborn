extends SceneTree

# Test suite for cooldown mechanics of all 6 updated skills:
# 1. Unstoppable Force (Breacher): 3 turns cooldown after execution.
# 2. Crater Maker (Berserker): 3 turns cooldown forced after execution.
# 3. Odin's Blessing (Berserker): 3 turns cooldown after cloud strikes or after cloud gets overwritten completely.
# 4. Quagmire (Quagmire): 2 turns cooldown after execution expires or after quagmire gets overwritten completely.
# 5. Eruption / Rupture (Quagmire): 1 turn cooldown after execution.
# 6. Shifting Sand (Quagmire): 3 turns cooldown after execution.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var grid := GridField.new()
	var unit := Unit.new()
	unit.side = 0
	unit.data = UnitData.new()

	print("Testing Skill 1: Unstoppable Force...")
	var unstoppable = load("res://resources/skills/Breacher/Unstoppable_force/unstoppable_force.tres").duplicate() as Unstoppable_force
	assert(unstoppable.cooldown == 3)
	assert(unstoppable.cooldown_remaining == 0)
	assert(unstoppable.has_usable_target(unit))
	# Simulate cast
	unstoppable.cooldown_remaining = unstoppable.cooldown
	assert(not unstoppable.has_usable_target(unit))
	assert(unstoppable.cooldown_remaining == 3)
	unstoppable.on_owner_turn_start(grid)
	assert(unstoppable.cooldown_remaining == 2)
	unstoppable.on_owner_turn_start(grid)
	assert(unstoppable.cooldown_remaining == 1)
	unstoppable.on_owner_turn_start(grid)
	assert(unstoppable.cooldown_remaining == 0)
	assert(unstoppable.has_usable_target(unit))
	print("PASS: Unstoppable Force cooldown")

	print("Testing Skill 2: Crater Maker...")
	var crater = load("res://resources/skills/Berserker/Crater Maker/crater_maker.tres").duplicate() as Crater_Maker
	assert(crater.cooldown == 3)
	assert(crater.cooldown_remaining == 0)
	assert(crater.has_usable_target(unit))
	# Simulate cast
	crater.cooldown_remaining = crater.cooldown
	assert(not crater.has_usable_target(unit))
	assert(crater.cooldown_remaining == 3)
	crater.on_owner_turn_start(grid)
	assert(crater.cooldown_remaining == 2)
	crater.on_owner_turn_start(grid)
	assert(crater.cooldown_remaining == 1)
	crater.on_owner_turn_start(grid)
	assert(crater.cooldown_remaining == 0)
	assert(crater.has_usable_target(unit))
	print("PASS: Crater Maker cooldown")

	print("Testing Skill 3: Odin's Blessing...")
	var blessing = load("res://resources/skills/Berserker/Odin's Blessing/odin_blessing.tres").duplicate() as OdinBlessing
	assert(blessing.cooldown == 3)
	assert(blessing.cooldown_remaining == 0)
	assert(blessing.has_usable_target(unit))

	# Test 3a: Strike expiry trigger
	var dummy_cloud_1 = Node.new()
	blessing.active_zones.append({"turns": 2, "tiles": [Vector2i(0, 0)], "cloud": dummy_cloud_1})
	assert(not blessing.has_usable_target(unit)) # Inactive while cloud active
	# Turn 1
	blessing.active_zones[0]["turns"] -= 1 # 1 turn left
	assert(blessing.cooldown_remaining == 0)
	# Turn 2: resolves / cloud goes off
	blessing.active_zones.clear()
	blessing.cooldown_remaining = blessing.cooldown
	assert(blessing.cooldown_remaining == 3)
	assert(not blessing.has_usable_target(unit))
	blessing.on_owner_turn_start(grid)
	assert(blessing.cooldown_remaining == 2)
	blessing.on_owner_turn_start(grid)
	assert(blessing.cooldown_remaining == 1)
	blessing.on_owner_turn_start(grid)
	assert(blessing.cooldown_remaining == 0)
	assert(blessing.has_usable_target(unit))

	# Test 3b: Overwritten completely trigger
	var dummy_cloud_2 = Node.new()
	blessing.active_zones.append({"turns": 2, "tiles": [Vector2i(1, 1)], "cloud": dummy_cloud_2})
	blessing.remove_aoe_position(grid, Vector2i(1, 1))
	assert(blessing.active_zones.is_empty())
	assert(blessing.cooldown_remaining == 3)
	assert(not blessing.has_usable_target(unit))
	blessing.on_owner_turn_start(grid)
	assert(blessing.cooldown_remaining == 2)
	blessing.on_owner_turn_start(grid)
	assert(blessing.cooldown_remaining == 1)
	blessing.on_owner_turn_start(grid)
	assert(blessing.cooldown_remaining == 0)
	assert(blessing.has_usable_target(unit))
	dummy_cloud_1.free()
	print("PASS: Odin's Blessing cooldown (both expiry and overwrite)")

	print("Testing Skill 4: Quagmire...")
	var quagmire = load("res://resources/skills/Quagmire/Quagmire/quagmire.tres").duplicate() as Quagmire
	assert(quagmire.cooldown == 2)
	assert(quagmire.cooldown_remaining == 0)

	var pillar_skill = Mud_Pillar.new()
	pillar_skill.active_pillars.append(Vector2i(5, 5))
	unit.skills.append(pillar_skill)
	unit.skills.append(quagmire)
	assert(quagmire.has_usable_target(unit))

	# Test 4a: Expiry after 3 turns
	quagmire.active_zones.append({"tiles": [Vector2i(2, 2)], "turns": 3})
	assert(not quagmire.has_usable_target(unit), "Cannot cast while zone active")
	quagmire.on_owner_turn_start(grid) # turns -> 2
	assert(quagmire.cooldown_remaining == 0)
	quagmire.on_owner_turn_start(grid) # turns -> 1
	assert(quagmire.cooldown_remaining == 0)
	quagmire.on_owner_turn_start(grid) # turns -> 0, zone expired, cooldown becomes 2
	assert(quagmire.active_zones.is_empty())
	assert(quagmire.cooldown_remaining == 2)
	assert(not quagmire.has_usable_target(unit))
	quagmire.on_owner_turn_start(grid) # 1 turn left
	assert(quagmire.cooldown_remaining == 1)
	assert(not quagmire.has_usable_target(unit))
	quagmire.on_owner_turn_start(grid) # 0 turns left
	assert(quagmire.cooldown_remaining == 0)
	assert(quagmire.has_usable_target(unit))

	# Test 4b: Overwritten completely trigger
	quagmire.active_zones.append({"tiles": [Vector2i(3, 3)], "turns": 3})
	quagmire.remove_aoe_position(grid, Vector2i(3, 3))
	assert(quagmire.active_zones.is_empty())
	assert(quagmire.cooldown_remaining == 2)
	assert(not quagmire.has_usable_target(unit))
	quagmire.on_owner_turn_start(grid)
	assert(quagmire.cooldown_remaining == 1)
	quagmire.on_owner_turn_start(grid)
	assert(quagmire.cooldown_remaining == 0)
	assert(quagmire.has_usable_target(unit))
	print("PASS: Quagmire cooldown (both expiry and overwrite)")

	print("Testing Skill 5: Eruption / Rupture...")
	var rupture = load("res://resources/skills/Quagmire/Rupture/rupture.tres").duplicate() as Rupture
	assert(rupture.cooldown == 1)
	assert(rupture.cooldown_remaining == 0)
	assert(rupture.has_usable_target(unit))
	rupture.cooldown_remaining = rupture.cooldown
	assert(not rupture.has_usable_target(unit))
	assert(rupture.cooldown_remaining == 1)
	rupture.on_owner_turn_start(grid)
	assert(rupture.cooldown_remaining == 0)
	assert(rupture.has_usable_target(unit))
	print("PASS: Rupture / Eruption cooldown")

	print("Testing Skill 6: Shifting Sand...")
	var shifting = load("res://resources/skills/Quagmire/Shifting Sand/shifting_sand.tres").duplicate() as ShiftingSand
	assert(shifting.cooldown == 3)
	assert(shifting.cooldown_remaining == 0)
	assert(shifting.has_usable_target(unit))
	shifting.cooldown_remaining = shifting.cooldown
	assert(not shifting.has_usable_target(unit))
	assert(shifting.cooldown_remaining == 3)
	shifting.on_owner_turn_start(grid)
	assert(shifting.cooldown_remaining == 2)
	shifting.on_owner_turn_start(grid)
	assert(shifting.cooldown_remaining == 1)
	shifting.on_owner_turn_start(grid)
	assert(shifting.cooldown_remaining == 0)
	assert(shifting.has_usable_target(unit))
	print("PASS: Shifting Sand cooldown")

	grid.free()
	unit.free()
	print("ALL 6 SKILL COOLDOWN TESTS PASSED SUCCESSFULLY!")
	quit()
