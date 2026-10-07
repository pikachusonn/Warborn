extends Skill
class_name BloodLust

var stacks: int = 0
const MAX_STACKS: int = 5
var last_attack: String = "" # "cleave", "chop", or ""

static func get_blood_lust(unit: Unit) -> BloodLust:
	if unit == null or unit.skills == null:
		return null
	for skill in unit.skills:
		if skill is BloodLust:
			return skill
	return null

func get_tier_percent(s: int) -> float:
	match s:
		1: return 0.05
		2: return 0.10
		3: return 0.20
		4: return 0.25
		5: return 0.30
		_: return 0.0

func is_enhanced(attack_name: String) -> bool:
	return last_attack == attack_name

func get_preview_data(attack_name: String) -> Dictionary:
	var enhanced := is_enhanced(attack_name)
	if enhanced:
		return {
			"is_enhanced": true,
			"stacks": stacks,
			"tier_percent": get_tier_percent(stacks)
		}
	else:
		var projected_stacks = stacks
		if last_attack != "" and last_attack != attack_name:
			projected_stacks = mini(stacks + 1, MAX_STACKS)
		return {
			"is_enhanced": false,
			"stacks": projected_stacks,
			"tier_percent": 0.0
		}

func record_execution(attack_name: String, unit: Unit = null) -> Dictionary:
	var enhanced := is_enhanced(attack_name)
	if enhanced:
		var consumed := stacks
		var tier := get_tier_percent(consumed)
		stacks = 0
		last_attack = ""
		if unit != null:
			unit.remove_status(Unit.EFFECTS.BLOOD_LUST)
		return {
			"is_enhanced": true,
			"stacks_consumed": consumed,
			"tier_percent": tier
		}
	else:
		if last_attack != "" and last_attack != attack_name:
			stacks = mini(stacks + 1, MAX_STACKS)
		last_attack = attack_name
		if unit != null:
			if stacks > 0:
				unit.status_effects[Unit.EFFECTS.BLOOD_LUST] = stacks
				unit.update_status_icons()
			else:
				unit.remove_status(Unit.EFFECTS.BLOOD_LUST)
		return {
			"is_enhanced": false,
			"stacks": stacks,
			"tier_percent": 0.0
		}
