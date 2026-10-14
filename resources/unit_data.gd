extends Resource
class_name UnitData

@export var unit_name: String
@export var health := 100
@export var damage := 10
@export var mobility := 1
@export var speed := 1

@export var ally_sprite_frames: SpriteFrames
@export var enemy_sprite_frames: SpriteFrames
@export_range(0.25, 3.0, 0.05) var ally_visual_scale := 1.0
@export_range(0.25, 3.0, 0.05) var enemy_visual_scale := 1.0
@export var ally_visual_offset := Vector2.ZERO
@export var enemy_visual_offset := Vector2.ZERO

@export var skill1_name: String
@export var skill2_name: String
@export var skill3_name: String
@export var skill4_name: String

@export var skills: Array[Skill]
