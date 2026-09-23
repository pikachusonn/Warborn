extends Node2D

const CLOUD = preload("res://assets/odin_blessing/cloud.png")
const FLOAT_HEIGHT := 20.0
var tiles: Array[Vector2i] = []
var cleared_tiles: Array[Vector2i] = []
var origin := Vector2i.ZERO
var elapsed := 0.0
var countdown: Label
var is_hovered := false
var is_striking := false

func _init() -> void:
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cloud_material := ShaderMaterial.new()
	cloud_material.shader = preload("res://assets/odin_blessing/cloud.gdshader")
	material = cloud_material

func setup(center: Vector2i, positions: Array[Vector2i]) -> void:
	origin = center - Vector2i.ONE
	countdown = Label.new()
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown.size = Vector2(96, 80)
	countdown.visible = false
	countdown.add_theme_font_size_override("font_size", 48)
	countdown.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	countdown.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.18, 0.9))
	countdown.add_theme_constant_override("outline_size", 6)
	add_child(countdown)
	set_tiles(positions)
	_process(0.0)

func set_tiles(positions: Array[Vector2i]) -> void:
	tiles.assign(positions)
	if is_instance_valid(countdown) and not tiles.is_empty():
		var midpoint := Vector2.ZERO
		for tile in tiles:
			midpoint += (Vector2(tile) + Vector2(0.5, 0.5)) * GridField.TILE_SIZE
		countdown.position = midpoint / tiles.size() - countdown.size / 2.0
	queue_redraw()

func set_rounds_left(rounds: int) -> void:
	countdown.text = str(maxi(rounds, 0))
	is_striking = rounds <= 0
	countdown.visible = is_hovered or is_striking

func set_hovered(value: bool) -> void:
	is_hovered = value
	countdown.visible = is_hovered or is_striking
	material.set_shader_parameter("opacity", 1.0 if value else 0.18)
	material.set_shader_parameter("hovered", value)

func _process(delta: float) -> void:
	elapsed += delta
	# Height, gentle bobbing and sideways drift separate the cloud from the floor.
	position = Vector2(sin(elapsed * 0.65) * 3.0, -FLOAT_HEIGHT + sin(elapsed * 1.1) * 4.0)
	material.set_shader_parameter("cloud_offset", position)
	var grid := get_parent() as GridField
	if grid != null:
		update_cleared_tiles(grid)

func update_cleared_tiles(grid: GridField) -> void:
	var next_cleared: Array[Vector2i] = []
	for unit in grid.player_units + grid.enemy_units:
		if not is_instance_valid(unit) or unit.grid_position not in tiles:
			continue
		var tile = grid.tiles.get(unit.grid_position)
		var in_attack_range: bool = grid.targeting_skill and (
			tile in grid.target_tiles or tile in grid.impact_preview_tiles
		)
		if unit == grid.hovered_unit or unit == grid.active_unit or in_attack_range:
			if unit.grid_position not in next_cleared:
				next_cleared.append(unit.grid_position)
	if cleared_tiles != next_cleared:
		cleared_tiles.assign(next_cleared)
		var cutout_origins := PackedVector2Array()
		cutout_origins.resize(GridField.WIDTH * GridField.HEIGHT)
		for index in cleared_tiles.size():
			cutout_origins[index] = Vector2(cleared_tiles[index]) * GridField.TILE_SIZE
		material.set_shader_parameter("cutout_origins", cutout_origins)
		material.set_shader_parameter("cutout_count", cleared_tiles.size())

func _draw() -> void:
	var cell := Vector2(GridField.TILE_SIZE, GridField.TILE_SIZE)
	var source_cell := Vector2(1086.0, 1062.0) / 3.0
	for tile in tiles:
		var source := Rect2(Vector2(84, 92) + Vector2(tile - origin) * source_cell, source_cell)
		draw_texture_rect_region(CLOUD, Rect2(Vector2(tile) * cell, cell), source)
