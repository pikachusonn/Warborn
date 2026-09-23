extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var grid := GridField.new()
	var tile_scene := load("res://scenes/tile/tile.tscn") as PackedScene
	for x in range(6):
		for y in range(6):
			var tile := tile_scene.instantiate() as TileScene
			root.add_child(tile)
			grid.tiles[Vector2i(x, y)] = tile
	var unit := Unit.new()
	var first := Quagmire.new()
	first.owner = unit
	var second := Quagmire.new()
	second.owner = unit
	first.create_quagmire_zone(grid, first.get_zone_tiles(Vector2i(2, 2)))
	assert(grid.aoe_tile_owners.size() == 9)
	assert(grid.tiles[Vector2i(1, 1)].quagmire_overlay.texture == first.TILE_TEXTURES[0])
	assert(grid.tiles[Vector2i(3, 3)].quagmire_overlay.texture == first.TILE_TEXTURES[8])
	second.create_quagmire_zone(grid, second.get_zone_tiles(Vector2i(3, 2)))
	assert(first.active_zones[0]["tiles"].size() == 3)
	assert(second.active_zones[0]["tiles"].size() == 9)
	assert(grid.aoe_tile_owners.size() == 12)
	grid.update_aoe_hover(Vector2i(1, 2))
	assert(grid.aoe_hover_glow.positions.size() == 3)
	assert(Vector2i(2, 2) not in grid.aoe_hover_glow.positions)
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(grid.aoe_hover_glow.positions.size() == 9)
	grid.clear_hover()
	assert(grid.aoe_hover_glow.positions.is_empty())
	grid.update_aoe_hover(Vector2i(1, 2))
	first.on_owner_turn_start(grid)
	first.on_owner_turn_start(grid)
	first.on_owner_turn_start(grid)
	assert(not grid.tiles[Vector2i(1, 2)].quagmire_overlay.visible)
	assert(grid.tiles[Vector2i(2, 2)].quagmire_overlay.visible)
	assert(grid.aoe_tile_owners.size() == 9)
	grid.update_aoe_hover(Vector2i(1, 2))
	assert(grid.aoe_hover_glow.positions.is_empty())
	# Full recast used to unregister the newly assigned tiles during cleanup.
	second.create_quagmire_zone(grid, second.get_zone_tiles(Vector2i(3, 2)))
	assert(second.active_zones.size() == 1)
	assert(grid.aoe_tile_owners.size() == 9)
	for pos in second.get_zone_tiles(Vector2i(3, 2)):
		assert(grid.aoe_tile_owners.get(pos) == second)
	# Partial recast keeps the old zone's remaining tiles and duration.
	second.on_owner_turn_start(grid)
	second.create_quagmire_zone(grid, second.get_zone_tiles(Vector2i(4, 2)))
	assert(second.active_zones.size() == 2)
	assert(second.active_zones[0]["tiles"].size() == 3)
	grid.update_aoe_hover(Vector2i(2, 2))
	assert(grid.aoe_hover_glow.positions.size() == 3)
	grid.update_aoe_hover(Vector2i(3, 2))
	assert(grid.aoe_hover_glow.positions.size() == 9)
	grid.update_aoe_hover(Vector2i(0, 5))
	assert(grid.aoe_hover_glow.positions.is_empty())
	second.on_owner_turn_start(grid)
	second.on_owner_turn_start(grid)
	assert(grid.aoe_tile_owners.size() == 9)
	assert(grid.tiles[Vector2i(3, 2)].quagmire_overlay.visible)
	second.on_owner_turn_start(grid)
	assert(grid.aoe_tile_owners.is_empty())
	assert(grid.active_aoe_effects.is_empty())
	first.create_quagmire_zone(grid, first.get_zone_tiles(Vector2i.ZERO))
	assert(grid.aoe_tile_owners.size() == 4)
	assert(grid.tiles[Vector2i.ZERO].quagmire_overlay.texture == first.TILE_TEXTURES[4])
	for tile in grid.tiles.values():
		tile.free()
	grid.free()
	unit.free()
	print("PASS: Quagmire textures, overlaps, recasts, expiry, board edges and zone hover")
	quit()
