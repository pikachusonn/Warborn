extends SceneTree
## Two real ENet processes exercise commands and authoritative outcomes.
const PORT := 27952
var session: Node
var grid: GridField
var client := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(35.0).timeout.connect(func():
		push_error("Combat test timed out")
		quit(1))
	root.size = Vector2i(1100, 800) if "client" in OS.get_cmdline_user_args() else Vector2i(1600, 900)
	session = root.get_node("Netplay")
	client = "client" in OS.get_cmdline_user_args()
	if client:
		await create_timer(1.0).timeout
		assert(session.join("127.0.0.1", PORT) == OK)
	else:
		assert(session.host(PORT) == OK)
	while not session.board_started:
		await process_frame
	grid = session.grid
	while not is_instance_valid(grid.active_unit):
		await process_frame
	if client:
		await run_client()
	else:
		await run_host()
	print("PASS: stage 2 %s combat" % ["client" if client else "host"])
	quit()

func command(action: String, argument := -1, tile := Vector2i(-1, -1)) -> void:
	assert(session.can_input(), "Only the initiative owner can submit")
	var revision: int = session.revision
	var cursor := (Vector2(tile) + Vector2(0.5, 0.5)) * GridField.TILE_SIZE
	session.submit(action, argument, tile, cursor)
	await process_frame
	while session.command_pending or session.executing_command or grid.resolving_turn_start:
		await process_frame
	assert(session.revision > revision, "Expected command accepted: " + action)

func rejected(action: String, argument := -1, tile := Vector2i(-1, -1)) -> void:
	var revision: int = session.revision
	session.submit(action, argument, tile, Vector2.ZERO)
	await process_frame
	while session.command_pending:
		await process_frame
	assert(session.revision == revision, "Invalid command must not mutate state")

func run_host() -> void:
	assert(grid.active_unit == grid.player_units[0])
	# Fixture: place the two Breachers within range; all actions still use ENet flow.
	grid.enemy_units[0].grid_position = Vector2i(6, 6)
	grid.enemy_units[0].position = Vector2(6.5, 6.5) * GridField.TILE_SIZE
	session.send_snapshot()
	await rejected("skill", 99)
	await rejected("tile", -1, Vector2i(-1, -1))
	var before: int = session.revision
	session._accept_command(session.guest_id, 1, before, session.turn_epoch, "end", -1, Vector2i.ZERO, Vector2.ZERO)
	assert(session.revision == before, "Host rejects wrong-side RPC")
	# Reserve sequence 1 on the client as a forged packet in this test.
	await command("skills")
	await command("cancel")
	await command("move")
	await rejected("tile", -1, Vector2i(0, 0))
	await command("tile", -1, Vector2i(6, 7))
	assert(grid.energy == 1 and not grid.free_movement)
	assert(grid.player_units[0].grid_position == Vector2i(6, 7))
	before = session.revision
	session._accept_command(1, session.command_sequence, before, session.turn_epoch, "end", -1, Vector2i.ZERO, Vector2.ZERO)
	assert(session.revision == before, "Duplicate sequence cannot execute twice")
	session._accept_command(1, session.command_sequence + 100, before - 1, session.turn_epoch, "end", -1, Vector2i.ZERO, Vector2.ZERO)
	assert(session.revision == before, "Stale revision must be rejected")
	session.command_sequence += 100
	await command("skill", 0)
	await command("tile", -1, Vector2i(6, 6))
	assert(grid.enemy_units[0].current_health == grid.enemy_units[0].data.health - grid.player_units[0].skills[0].damage)
	assert(grid.active_unit == grid.enemy_units[0], "Paid attack after free move advances turn")
	while grid.active_unit != grid.player_units[2]:
		await process_frame
	assert(grid.player_units[0].has_status(Unit.EFFECTS.STUNNED))
	assert(grid.player_units[0].current_health == grid.player_units[0].data.health - grid.enemy_units[0].skills[1].damage)
	assert(grid.enemy_units[0].grid_position == Vector2i(5, 6))
	await rejected("skill", 2) # Blood Lust is passive.
	await command("skill", 3)
	await command("tile", -1, grid.active_unit.grid_position)
	assert(not grid.active_aoe_effects.is_empty())
	await command("end")
	while not session.can_input():
		await process_frame
	assert(grid.active_unit == grid.player_units[1])
	await command("skill", 3)
	await command("tile", -1, Vector2i(3, 9))
	assert(grid.player_units[1].skills[3].cooldown_remaining == 2)
	assert(grid.bouncing_pads.has(Vector2i(3, 9)))
	await command("move")
	await command("tile", -1, Vector2i(5, 9))
	assert(grid.active_unit == grid.player_units[3])
	await command("end")
	while grid.active_unit != grid.enemy_units[3]:
		await process_frame
	assert(grid.enemy_units[1].grid_position == Vector2i(5, 1))
	assert(grid.enemy_units[1].skills[1].cooldown_remaining == 1)
	assert(grid.player_units[1].has_status(Unit.EFFECTS.ENEMY_ARCHER_MARK))
	while session.running:
		await process_frame
	assert(paused, "Client departure pauses the host")
	session.close_session()

func run_client() -> void:
	assert(not session.can_input())
	var initial: Unit = grid.active_unit
	grid.handle_unit_clicked(grid.enemy_units[2])
	assert(grid.active_unit == initial)
	# Sequence 1 is consumed by the host's deliberately forged ownership test.
	session.command_sequence = 1
	while not session.can_input():
		await process_frame
	assert(grid.active_unit == grid.enemy_units[0])
	assert(grid.player_units[0].grid_position == Vector2i(6, 7))
	assert(grid.enemy_units[0].current_health == grid.enemy_units[0].data.health - grid.player_units[0].skills[0].damage)
	# The client viewport differs and is rotated: submitted coordinates stay canonical.
	var screen_center := grid.get_tile_center(Vector2i(6, 7))
	assert(grid.to_local(screen_center).is_equal_approx(Vector2(6.5, 7.5) * GridField.TILE_SIZE))
	await command("skill", 1)
	await command("tile", -1, Vector2i(6, 7))
	assert(grid.energy == 0 and grid.free_movement)
	assert(grid.player_units[0].has_status(Unit.EFFECTS.STUNNED))
	await command("move")
	await command("tile", -1, Vector2i(5, 6))
	assert(grid.active_unit != grid.enemy_units[0])
	while not session.can_input():
		await process_frame
	assert(grid.active_unit == grid.enemy_units[2])
	assert(not session.last_snapshot.world.zones.is_empty(), "Persistent zone state must replicate")
	assert(not session.state_codec.replica_clouds.is_empty(), "Odin cloud must exist on the guest")
	var cloud = session.state_codec.replica_clouds.values()[0]
	var cloud_tile: Vector2i = session.last_snapshot.world.zones[0].tiles[0]
	assert(not cloud.is_hovered)
	grid.update_aoe_hover(cloud_tile)
	assert(cloud.is_hovered, "Guest cloud hover must be calculated locally")
	grid.update_aoe_hover(Vector2i(9, 9))
	assert(not cloud.is_hovered)
	assert(grid.active_unit.current_health == grid.active_unit.data.health)
	await command("end")
	while not session.can_input():
		await process_frame
	assert(grid.active_unit == grid.enemy_units[1])
	assert(Vector2i(3, 9) in session.last_snapshot.world.pads)
	assert(grid.player_units[1].skills[3].cooldown_remaining == 2)
	await command("skill", 1)
	assert(grid.targeting_skill, "Retreating Shot must accept its movement-stage click")
	await command("tile", -1, Vector2i(5, 1))
	assert(grid.enemy_units[1].grid_position == Vector2i(5, 1))
	assert(grid.enemy_units[1].skills[1].cooldown_remaining == 1)
	await command("tile", -1, Vector2i(5, 2))
	assert(grid.player_units[1].has_status(Unit.EFFECTS.ENEMY_ARCHER_MARK))
	assert(grid.player_units[1].current_health < grid.player_units[1].data.health)
	await command("end")
	await create_timer(0.15).timeout
	session.leave()
	await process_frame
	await process_frame
