extends Skill
class_name Retreating_shot

enum Stage {
	MOVE,
	SHOT
}
var stage := Stage.MOVE
@export var piercing_shot: Piercing_shot

func begin(grid_field: GridField, unit: Unit) -> void:
	stage = Stage.MOVE
	grid_field.clear_move_range()
	grid_field.calculate_move_range(unit, true)
	
func on_tile_clicked(grid_field: GridField, unit: Unit, pos: Vector2i) -> void:
	match stage:
		Stage.MOVE:
			handle_move_stage(grid_field, unit, pos)
		Stage.SHOT:
			handle_shot_stage(grid_field, unit, pos)
			
func handle_move_stage(grid_field: GridField, unit: Unit, pos: Vector2i):
	if not grid_field.tiles.has(pos):
		return	
	var tile = grid_field.tiles[pos]
	if tile not in grid_field.target_tiles:
		return
	# Move
	unit.grid_position = pos
	unit.global_position = (grid_field.tiles[pos].global_position + Vector2(32, 32))
	#Clear preview
	grid_field.clear_move_range()
	stage = Stage.SHOT
	piercing_shot.begin(grid_field, unit)
	
func update_preview(grid_field: GridField, unit: Unit) -> void:
	if stage == Stage.SHOT:
		piercing_shot.update_preview(grid_field, unit)

func handle_shot_stage(grid_field: GridField, unit: Unit, pos: Vector2i):
	piercing_shot.on_tile_clicked(grid_field, unit, pos)
	
func cancel(grid_field: GridField, unit: Unit) -> void:
	grid_field.clear_move_range()
	if piercing_shot:
		piercing_shot.cancel(grid_field, unit)
	stage = Stage.MOVE
