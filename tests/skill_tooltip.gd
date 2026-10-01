extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 900)
	var tooltip := preload("res://scenes/action_menu/skill_tooltip.gd").new()
	root.add_child(tooltip)
	for path in ["Breacher/Breacher", "Archer/Archer", "Berserker/Berserker", "Quagmire/Quagmire"]:
		var data = load("res://resources/units/%s.tres" % path)
		for skill in data.skills:
			assert(not skill.description.is_empty(), skill.resource_path)
			tooltip.show_skill(skill, "Fallback name", Vector2(1900, 880))
			await process_frame
			tooltip.show_skill(skill, "Fallback name", Vector2(1900, 880))
			assert(tooltip.panel.visible)
			assert(tooltip.panel.position.x >= 0 and tooltip.panel.position.y >= 0)
			assert(tooltip.panel.get_global_rect().end.x <= root.get_visible_rect().size.x)
			assert(tooltip.panel.get_global_rect().end.y <= root.get_visible_rect().size.y)
			assert(tooltip.description_label.size.y >= tooltip.description_label.get_minimum_size().y)
			assert(tooltip.bolt_material.get_shader_parameter("inactive") == (skill.get_action_cost() == 0))
	var kit := load("res://resources/skills/Archer/Hunter's kit/hunter_kit.tres").duplicate() as Hunter_kit
	assert(kit.get_action_cost() == 1)
	kit.deployed = true
	assert(kit.get_action_cost() == 0)
	tooltip.show_skill_sidebar(kit, "Hunter's Kit")
	assert(tooltip.panel.visible)
	assert(tooltip.panel.position.x > 0 and tooltip.panel.position.y >= 0)
	tooltip.show_capture_sidebar(true)
	assert(tooltip.panel.visible)
	tooltip.hide_tooltip()
	assert(not tooltip.panel.visible)
	tooltip.free()
	print("PASS: Skill tooltip descriptions, action costs, layout and viewport bounds")
	quit()
