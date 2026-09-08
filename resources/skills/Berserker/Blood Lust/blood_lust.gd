extends Skill
class_name BloodLust

@export_range(0.0, 1.0) var damage_heal_percent: float = 0.3
@export_range(0.0, 1.0) var missing_hp_heal_percent: float = 0.2
@export_range(0.0, 1.0) var low_health_heal_percent: float = 0.35
@export_range(0.0, 1.0) var low_health_threshold: float = 0.4
@export var execution_damage_bonus: int = 5

func on_skill_resolved(
	_grid_field: GridField,
	owner: Unit,
	used_skill: Skill,
	total_damage: int,
	execution_count: int
) -> void:
	if not used_skill is Helmet_Splitter:
		return
	var max_health: int = owner.data.health
	var missing_health: int = max_health - owner.current_health
	var health_percent: float = (float(owner.current_health) / float(max_health))
	var current_missing_hp_heal_percent := (
		low_health_heal_percent
		if health_percent <= low_health_threshold
		else missing_hp_heal_percent
	)
	var healing_from_damage := roundi(total_damage * damage_heal_percent)

	var healing_from_missing_health := roundi(missing_health * current_missing_hp_heal_percent)
	owner.heal(healing_from_damage + healing_from_missing_health)
	owner.shake()
	if execution_count > 0:
		used_skill.add_damage_bonus(execution_damage_bonus * execution_count)
