extends Resource
class_name UnitData

@export var unit_name: String
@export var health := 100
@export var damage := 10
@export var mobility := 1
@export var speed := 1

@export var texture: Texture2D

@export var skill1_name: String
@export var skill2_name: String
@export var skill3_name: String
@export var skill4_name: String

@export var skills: Array[Skill]
