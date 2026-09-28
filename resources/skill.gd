extends Resource
class_name Skill

@export var skill_name: String
@export_multiline var description: String
@export_range(0, 1) var action_cost: int = 1
@export var damage: int
@export var cutscene_texture: Texture2D
@export var cutscene_video: VideoStream
@export var is_projectile: bool
@export var is_mobile: bool = false
@export var is_passive: bool = false
@export var cooldown: int = 0
var cooldown_remaining: int = 0

func get_action_cost() -> int:
	return 0 if is_passive else action_cost

func get_tooltip_damage() -> int:
	return damage

func has_usable_target(_unit: Unit) -> bool:
	return true

func begin(grid_field: GridField, unit: Unit):
	pass
	
func on_tile_clicked(
	grid_field: GridField, unit: Unit, pos: Vector2i
) -> void:
	pass
	
func update_preview(
	grid: GridField,
	unit: Unit
) -> void:
	pass

func cancel(grid: GridField, unit: Unit) -> void:
	grid.clean_up_skill()

func get_target_tiles(grid_field: GridField,unit: Unit, direction: Vector2i, distance: int = 1) -> Array[Vector2i]:
	return []

func execute(grid: GridField, unit: Unit, target_positions: Array[Vector2i], direction: Vector2i, distance: int):
	pass

func show_preview(grid: GridField, unit: Unit, direction: Vector2i):
	pass

func instant_cast() -> bool:
	return false

func get_preview_damage(_grid: GridField, unit: Unit, target: Unit) -> int:
	return damage if target.side != unit.side else 0

func get_preview_healing(_grid: GridField, _unit: Unit, _target: Unit) -> int:
	return 0

func on_owner_turn_start(grid: GridField):
	pass
	
func on_skill_resolved(_grid_field: GridField, _owner: Unit, _used_skill: Skill, _total_damage: int, _execution_count: int) -> void:
	pass
