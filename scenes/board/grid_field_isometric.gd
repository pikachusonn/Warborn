extends GridField
class_name GridFieldIsometric

# Orthographic projection of square ground tiles at 45-degree yaw and a
# low (~21-degree) camera elevation. Ground squares appear foreshortened;
# making their screen bounds square would imply an almost overhead camera.
const VEC_X := TileIsoScene.VEC_X
const VEC_Y := TileIsoScene.VEC_Y
const DET := VEC_X.x * VEC_Y.y - VEC_Y.x * VEC_X.y
const DEFAULT_CAMERA_ZOOM := 1.45
const ACTIVE_FOCUS_WEIGHT := 0.72
const CAMERA_LOWERING := Vector2(0.0, 100.0)

func _ready() -> void:
	y_sort_enabled = true
	# Use the custom angled tile scene
	tile_scene = preload("res://scenes/tile/tile_iso.tscn")

	super._ready()

	# Keep background pure dark / black for demo mode
	if is_instance_valid(cavern_background):
		cavern_background.visible = false
	if is_instance_valid(background_veil):
		background_veil.visible = false
	var dark_fill = get_node_or_null("DarkSpace/Fill")
	if is_instance_valid(dark_fill):
		dark_fill.color = Color(0.015, 0.02, 0.03, 1.0)

	# Reference-inspired screen-space HUD, independent of board zoom.
	var battle_hud := preload("res://scenes/board/tactical_hud.gd").new()
	battle_hud.grid = self
	$CanvasLayer.add_child(battle_hud)

	_update_unit_facing()

func update_radial_menu() -> void:
	super.update_radial_menu()
	# Keep the existing action state machine, but use the bottom action bar.
	radial_menu.hide()

func spawn_character(data: UnitData, pos: Vector2i, side: Unit.Side) -> void:
	super.spawn_character(data, pos, side)
	var team := player_units if side == Unit.Side.PLAYER else enemy_units
	var unit := team.back() as Unit
	# Selection is communicated by the projected ground tile in this view.
	unit.draw_selection_aura = false
	unit.queue_redraw()
	if data == berserker_data:
		return
	var texture := unit.sprite.sprite_frames.get_frame_texture("idle", 0)
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	# Ignore translucent shadows and stray alpha pixels (some sheets extend
	# hundreds of pixels below the actual feet). Use the opaque bottom band,
	# not the full silhouette whose center includes weapons and hats.
	var bottom := -1
	var top := image.get_height()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if bottom < 0:
		return
	var band_height := maxi(2, roundi((bottom - top + 1) * 0.10))
	var left := image.get_width()
	var right := -1
	for y in range(maxi(top, bottom - band_height + 1), bottom + 1):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.5:
				left = mini(left, x)
				right = maxi(right, x)
	# Keep the first-frame anchor fixed during animation to avoid jitter.
	var foot_anchor := Vector2((left + right + 1) * 0.5, bottom + 1)
	unit.sprite.position = -(foot_anchor - texture.get_size() * 0.5) * unit.sprite.scale

func _process(delta: float) -> void:
	super._process(delta)
	_update_unit_facing()

	# Update the active unit's under-foot white diamond outline
	var active_iso_tile: TileIsoScene = null
	if is_instance_valid(active_unit) and tiles.has(active_unit.grid_position):
		active_iso_tile = tiles[active_unit.grid_position] as TileIsoScene

	for tile_pos in tiles:
		var tile_iso := tiles[tile_pos] as TileIsoScene
		if is_instance_valid(tile_iso):
			tile_iso.set_active_tile(
				tile_iso == active_iso_tile,
				active_unit.side if tile_iso == active_iso_tile else -1
			)

func _on_unit_position_changed(unit: Unit) -> void:
	super._on_unit_position_changed(unit)
	_update_unit_facing()

func _on_unit_defeated(unit: Unit) -> void:
	super._on_unit_defeated(unit)
	_update_unit_facing()

func _update_unit_facing() -> void:
	# Units dynamically face toward the side of the map with the higher concentration of living enemies.
	# Recalculates on every frame and on position changes so movement naturally updates orientation.
	var living_players: Array[Unit] = []
	var living_enemies: Array[Unit] = []
	for u: Unit in player_units:
		if is_instance_valid(u) and not u.is_defeated():
			living_players.append(u)
	for u: Unit in enemy_units:
		if is_instance_valid(u) and not u.is_defeated():
			living_enemies.append(u)

	var all_living: Array[Unit] = []
	all_living.append_array(living_players)
	all_living.append_array(living_enemies)

	for unit: Unit in all_living:
		if not is_instance_valid(unit) or not is_instance_valid(unit.sprite):
			continue
		var opponents := living_enemies if unit.side == Unit.Side.PLAYER else living_players
		if opponents.is_empty():
			continue

		var unit_x := unit.position.x if unit.position != Vector2.ZERO else get_tile_local_position(unit.grid_position).x
		var unit_pos := unit.position if unit.position != Vector2.ZERO else get_tile_local_position(unit.grid_position)

		var enemies_left := 0
		var enemies_right := 0
		var min_dist_left := INF
		var min_dist_right := INF
		var inline_tie_left := 0
		var inline_tie_right := 0

		for opp: Unit in opponents:
			if not is_instance_valid(opp):
				continue
			var opp_x := opp.position.x if opp.position != Vector2.ZERO else get_tile_local_position(opp.grid_position).x
			var opp_pos := opp.position if opp.position != Vector2.ZERO else get_tile_local_position(opp.grid_position)
			var dx := opp_x - unit_x
			var dist := unit_pos.distance_to(opp_pos)

			if dx < -1.0:
				enemies_left += 1
				min_dist_left = minf(min_dist_left, dist)
			elif dx > 1.0:
				enemies_right += 1
				min_dist_right = minf(min_dist_right, dist)
			else:
				# Vertically inline on screen; check logical grid X
				if opp.grid_position.x < unit.grid_position.x:
					inline_tie_left += 1
				elif opp.grid_position.x > unit.grid_position.x:
					inline_tie_right += 1

		var face_left := unit.sprite.flip_h
		if enemies_left > enemies_right:
			face_left = true
		elif enemies_right > enemies_left:
			face_left = false
		elif enemies_left > 0 or enemies_right > 0:
			# Equal count on left and right: face toward the closer enemy
			if min_dist_left < min_dist_right:
				face_left = true
			elif min_dist_right < min_dist_left:
				face_left = false
		elif inline_tie_left != inline_tie_right:
			face_left = inline_tie_left > inline_tie_right

		unit.sprite.flip_h = face_left

		# Maintain mirrored visual offset when horizontal facing flips
		if unit.data != null:
			if unit.data == berserker_data:
				var configured_offset := unit.data.ally_visual_offset if unit.side == Unit.Side.PLAYER else unit.data.enemy_visual_offset
				unit.sprite.position.x = -absf(configured_offset.x) if face_left else absf(configured_offset.x)
			else:
				if not unit.has_meta("base_sprite_offset_x"):
					unit.set_meta("base_sprite_offset_x", unit.sprite.position.x)
				var base_x: float = unit.get_meta("base_sprite_offset_x")
				unit.sprite.position.x = -base_x if face_left else base_x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return_to_lobby()

func return_to_lobby() -> void:
	netplay.close_session()
	get_tree().change_scene_to_file("res://network/lobby.tscn")

func get_tile_local_position(pos: Vector2i) -> Vector2:
	if tiles.has(pos):
		return tiles[pos].position
	return pos.x * VEC_X + pos.y * VEC_Y

func local_to_grid_coordinates(local_pos: Vector2) -> Vector2:
	return Vector2(
		(VEC_Y.y * local_pos.x - VEC_Y.x * local_pos.y) / DET,
		(-VEC_X.y * local_pos.x + VEC_X.x * local_pos.y) / DET
	)

func local_to_grid(local_pos: Vector2) -> Vector2i:
	var grid_coordinates := local_to_grid_coordinates(local_pos)
	return Vector2i(roundi(grid_coordinates.x), roundi(grid_coordinates.y))

func get_direction_to_mouse(position: Vector2, diagonal = false) -> Vector2i:
	# Aim in logical grid space. Screen-space X/Y does not represent the board's
	# axes after projection and caused directional skills to select wrong tiles.
	var origin := local_to_grid_coordinates(to_local(position))
	var target := local_to_grid_coordinates(to_local(get_target_mouse_position()))
	var delta := target - origin
	if not diagonal:
		if absf(delta.x) > absf(delta.y):
			return Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
		return Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP
	var angle := delta.angle()
	if angle >= -PI / 8.0 and angle < PI / 8.0:
		return Vector2i.RIGHT
	if angle >= PI / 8.0 and angle < 3.0 * PI / 8.0:
		return Vector2i(1, 1)
	if angle >= 3.0 * PI / 8.0 and angle < 5.0 * PI / 8.0:
		return Vector2i.DOWN
	if angle >= 5.0 * PI / 8.0 and angle < 7.0 * PI / 8.0:
		return Vector2i(-1, 1)
	if angle >= 7.0 * PI / 8.0 or angle < -7.0 * PI / 8.0:
		return Vector2i.LEFT
	if angle >= -7.0 * PI / 8.0 and angle < -5.0 * PI / 8.0:
		return Vector2i(-1, -1)
	if angle >= -5.0 * PI / 8.0 and angle < -3.0 * PI / 8.0:
		return Vector2i.UP
	return Vector2i(1, -1)

func get_skill_distance(unit: Unit) -> int:
	var origin := Vector2(unit.grid_position)
	var target := local_to_grid_coordinates(to_local(get_target_mouse_position()))
	var delta := target - origin
	return clampi(roundi(maxf(absf(delta.x), absf(delta.y))), 1, 3)

func get_board_center_position() -> Vector2:
	var center_grid := Vector2(float(WIDTH - 1) * 0.5, float(HEIGHT - 1) * 0.5)
	return center_grid.x * VEC_X + center_grid.y * VEC_Y

func get_capture_zone_polygon() -> PackedVector2Array:
	# Capture covers every tile in rows 4 and 5. Build the visual from the
	# projected outer corners of those tiles so it shares the grid's exact axes.
	var top_left_center := 4.0 * VEC_Y
	var top_right_center := float(WIDTH - 1) * VEC_X + 4.0 * VEC_Y
	var bottom_right_center := float(WIDTH - 1) * VEC_X + 5.0 * VEC_Y
	var bottom_left_center := 5.0 * VEC_Y
	return PackedVector2Array([
		top_left_center - (VEC_X + VEC_Y) * 0.5,
		top_right_center + (VEC_X - VEC_Y) * 0.5,
		bottom_right_center + (VEC_X + VEC_Y) * 0.5,
		bottom_left_center + (-VEC_X + VEC_Y) * 0.5
	])

func get_camera_target_position() -> Vector2:
	var board_center := get_board_center_position()
	if force_full_board_zoom or not is_instance_valid(active_unit):
		return board_center
	var action_focus := camera_lead_position if camera_lead_unit == active_unit else active_unit.position
	# Keep the acting unit prominent without letting a unit near the foreground
	# push the far half of the battlefield above the viewport.
	return board_center.lerp(action_focus, ACTIVE_FOCUS_WEIGHT) - CAMERA_LOWERING

func get_camera_board_scale(viewport_size: Vector2) -> float:
	var span_x := float(WIDTH) * VEC_X.x + float(HEIGHT) * absf(VEC_Y.x)
	var span_y := float(WIDTH) * VEC_X.y + float(HEIGHT) * VEC_Y.y
	var target_scale_x := viewport_size.x * 0.90 / span_x
	var target_scale_y := viewport_size.y * 0.88 / span_y
	var fit_scale := minf(target_scale_x, target_scale_y)
	if force_full_board_zoom:
		return fit_scale
	# A relative zoom keeps default view visibly closer at every window size.
	return fit_scale * DEFAULT_CAMERA_ZOOM

func is_full_board_camera_active() -> bool:
	# In this presentation mode, long-range units should not automatically pull
	# the camera out. The HUD button remains the explicit full-board toggle.
	return force_full_board_zoom

func update_board_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var board_scale := get_camera_board_scale(viewport_size)
	scale = Vector2.ONE * board_scale
	rotation = 0.0
	var focus := get_camera_target_position()
	position = viewport_size / 2.0 - focus * board_scale
	camera_focus_position = focus
	if is_instance_valid(active_unit):
		camera_has_focused_unit = true
	if is_instance_valid(radial_menu_layer):
		radial_menu_layer.transform = transform
	for child in get_children():
		if child is Unit:
			child.rotation = 0.0
	if is_instance_valid(radial_menu):
		radial_menu.rotation = 0.0
	if offscreen_hud:
		offscreen_hud.refresh_indicators()
