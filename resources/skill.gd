extends Resource
class_name Skill

@export var skill_name: String
@export var damage: int
@export var cutscene_texture: Texture2D
@export var cutscene_video: VideoStream

func get_target_tiles(unit: Unit, direction: Vector2i, distance: int = 1) -> Array[Vector2i]:
	return []

func execute(grid: GridField, unit: Unit, target_positions: Array[Vector2i], direction: Vector2i, distance: int):
	pass
