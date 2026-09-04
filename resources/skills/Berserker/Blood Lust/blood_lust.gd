extends Skill
class_name BloodLust

@export_range(0.0, 1.0) var damage_heal_percent: float = 0.3
@export_range(0.0, 1.0) var missing_hp_heal_percent: float = 0.3
@export var execution_damage_bonus: int = 5

func on_skill_resolved(
	_grid_field: GridField,
	owner: Unit,
	used_skill: Skill,
	total_damage: int,
	execution_count: int
) -> void:
	if not used_skill is HelmetSplitter:
		return
	var missing_health := owner.data.health - owner.current_health
	var healing_from_damage := roundi(total_damage * damage_heal_percent)
	var healing_from_missing_health := roundi(missing_health * missing_hp_heal_percent)
	owner.heal(healing_from_damage + healing_from_missing_health)
	if execution_count > 0:
		used_skill.add_damage_bonus(execution_damage_bonus * execution_count)
