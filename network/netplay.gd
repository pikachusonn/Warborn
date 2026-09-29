extends Node
## Host-authoritative combat. Clients send intent and render primitive snapshots.
const PORT := 27841
const PROTOCOL := 3
const UPDATE_INTERVAL := 0.05
const CONNECTION_TIMEOUT := 10.0
enum Mode { LOCAL, HOST, CLIENT }
var mode := Mode.LOCAL
var grid: GridField
var running := false
var guest_id := 0
var remote_ready := false
var board_started := false
var connecting := false
var connection_elapsed := 0.0
var status := ""
var overlay: CanvasLayer
var status_label: Label
var revision := 0
var turn_epoch := 0
var command_sequence := 0
var last_sequences: Dictionary = {}
var command_pending := false
var executing_command := false
var dispatching := false
var pointer := Vector2(-100, -100)
var update_clock := 0.0
var last_snapshot: Dictionary = {}
var state_codec: RefCounted
var session_generation := 0
signal status_changed(message: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): fail("Connection failed. Check the address, port, and firewall."))
	multiplayer.server_disconnected.connect(func(): fail("Host disconnected. Match paused."))

func set_status(message: String) -> void:
	status = message
	status_changed.emit(message)
	if is_instance_valid(status_label):
		status_label.text = message

func host(port: int = PORT) -> Error:
	close_session()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, 1, 3)
	if result != OK:
		set_status("Could not host on port %d (error %d)." % [port, result])
		return result
	mode = Mode.HOST
	multiplayer.multiplayer_peer = peer
	var addresses: Array[String] = []
	for address in IP.get_local_addresses():
		if ":" not in address and not address.begins_with("127."):
			addresses.append(address)
	set_status("Waiting for player — %s : %d" % [", ".join(addresses), port])
	return OK

func join(address: String, port: int = PORT) -> Error:
	close_session()
	if address.strip_edges().is_empty():
		set_status("Enter the host's IP address first.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(), port, 3)
	if result != OK:
		set_status("Could not connect (error %d)." % result)
		return result
	mode = Mode.CLIENT
	multiplayer.multiplayer_peer = peer
	connecting = true
	connection_elapsed = 0.0
	set_status("Connecting to %s : %d…" % [address, port])
	return OK

func local_play() -> void:
	close_session()
	get_tree().change_scene_to_file("res://scenes/board/grid_field.tscn")

func close_session() -> void:
	session_generation += 1
	revision = 0
	turn_epoch = 0
	command_sequence = 0
	last_sequences.clear()
	command_pending = false
	executing_command = false
	dispatching = false
	pointer = Vector2(-100, -100)
	last_snapshot.clear()
	state_codec = null
	running = false
	connecting = false
	grid = null
	guest_id = 0
	remote_ready = false
	board_started = false
	get_tree().paused = false
	var previous := multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if previous:
		previous.close()
	mode = Mode.LOCAL
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	status_label = null

func leave() -> void:
	close_session()
	get_tree().change_scene_to_file("res://network/lobby.tscn")

func fail(message: String) -> void:
	connecting = false
	running = false
	if is_instance_valid(grid):
		get_tree().paused = true
	else:
		close_session()
	set_status(message)

func _process(delta: float) -> void:
	if connecting:
		connection_elapsed += delta
		if connection_elapsed >= CONNECTION_TIMEOUT:
			fail("Connection timed out. Check the host's address, port, and firewall.")
	if not running or not board_started or not is_instance_valid(grid):
		return
	update_clock += delta
	if update_clock >= UPDATE_INTERVAL:
		update_clock = 0.0
		if mode == Mode.HOST:
			send_snapshot()
		elif owns_turn() and not command_pending:
			_pointer_update.rpc_id(1, revision, turn_epoch, grid.to_local(grid.get_global_mouse_position()))
	if is_instance_valid(status_label) and is_instance_valid(grid.active_unit):
		status_label.text = "%s · %s · %s" % ["Host" if mode == Mode.HOST else "Guest", grid.active_unit.data.unit_name, "Resolving…" if executing_command or grid.resolving_turn_start else ("Your turn" if owns_turn() else "Opponent's turn")]

func _peer_connected(id: int) -> void:
	if mode == Mode.HOST and guest_id == 0:
		guest_id = id

func _peer_disconnected(id: int) -> void:
	if mode == Mode.HOST and id == guest_id:
		fail("Player disconnected. Match paused. Return to the lobby to start again.")

func _connected() -> void:
	_hello.rpc_id(1, PROTOCOL)

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(protocol: int) -> void:
	if mode != Mode.HOST or multiplayer.get_remote_sender_id() != guest_id or running:
		return
	if protocol != PROTOCOL:
		_reject_version.rpc_id(guest_id)
		set_status("The joining player's game version does not match.")
		return
	_begin_match.rpc()

@rpc("authority", "call_remote", "reliable", 0)
func _reject_version() -> void:
	fail("Game versions do not match. Both players need the same build.")

@rpc("authority", "call_local", "reliable", 0)
func _begin_match() -> void:
	running = true
	connecting = false
	get_tree().change_scene_to_file("res://scenes/board/grid_field.tscn")

func attach_board(board: GridField) -> void:
	grid = board
	state_codec = preload("res://network/combat_state.gd").new(grid)
	_make_overlay()
	if mode == Mode.CLIENT:
		_board_ready.rpc_id(1)
	elif remote_ready:
		_start_boards.rpc()

@rpc("any_peer", "call_remote", "reliable", 0)
func _board_ready() -> void:
	if mode != Mode.HOST or multiplayer.get_remote_sender_id() != guest_id or remote_ready:
		return
	remote_ready = true
	if is_instance_valid(grid):
		_start_boards.rpc()

@rpc("authority", "call_local", "reliable", 0)
func _start_boards() -> void:
	if not running or board_started or not is_instance_valid(grid):
		return
	board_started = true
	if mode == Mode.HOST:
		grid.start_combat()
	else:
		grid.initialize_turn_order()

func is_networked() -> bool:
	return mode != Mode.LOCAL

func is_client() -> bool:
	return mode == Mode.CLIENT

func can_input() -> bool:
	if mode == Mode.LOCAL:
		return true
	return owns_turn() and not command_pending and not executing_command and not grid.resolving_turn_start and not grid.presenting_skill

func owns_turn() -> bool:
	if not running or not board_started or not is_instance_valid(grid) or not is_instance_valid(grid.active_unit):
		return false
	return grid.active_unit.side == (Unit.Side.PLAYER if mode == Mode.HOST else Unit.Side.ENEMY)

func intercept(action: String, argument: int = -1, tile := Vector2i(-1, -1)) -> bool:
	if not is_networked() or dispatching:
		return false
	if can_input():
		submit(action, argument, tile, grid.to_local(grid.get_global_mouse_position()))
	return true

func submit(action: String, argument: int, tile: Vector2i, cursor: Vector2) -> void:
	if not can_input():
		return
	command_sequence += 1
	if mode == Mode.HOST:
		_accept_command(1, command_sequence, revision, turn_epoch, action, argument, tile, cursor)
	else:
		command_pending = true
		_request_command.rpc_id(1, command_sequence, revision, turn_epoch, action, argument, tile, cursor)

@rpc("any_peer", "call_remote", "reliable", 0)
func _request_command(sequence: int, expected_revision: int, epoch: int, action: String, argument: int, tile: Vector2i, cursor: Vector2) -> void:
	if mode == Mode.HOST:
		_accept_command(multiplayer.get_remote_sender_id(), sequence, expected_revision, epoch, action, argument, tile, cursor)

func _accept_command(sender: int, sequence: int, expected_revision: int, epoch: int, action: String, argument: int, tile: Vector2i, cursor: Vector2) -> void:
	if mode != Mode.HOST or not running or not board_started or not is_instance_valid(grid) or sender not in [1, guest_id]:
		return
	if sequence <= last_sequences.get(sender, 0):
		_reply(sender, sequence)
		return
	last_sequences[sender] = sequence
	var owner_id: int = 1 if is_instance_valid(grid.active_unit) and grid.active_unit.side == Unit.Side.PLAYER else guest_id
	if sender != owner_id or expected_revision != revision or epoch != turn_epoch or executing_command or not cursor.is_finite() or cursor.length() > 100000:
		_reply(sender, sequence)
		return
	if not grid.network_command_allowed(action, argument):
		_reply(sender, sequence)
		return
	# The committed cursor wins over unreliable preview packets, even at an edge.
	pointer = cursor
	dispatching = true
	grid.refresh_target_preview()
	dispatching = false
	if action == "tile" and (not grid.tiles.has(tile) or (grid.tiles[tile] not in grid.target_tiles and (grid.active_skill == null or not grid.active_skill.instant_cast()))):
		_reply(sender, sequence)
		return
	executing_command = true
	revision += 1
	var generation := session_generation
	dispatching = true
	# Start the handler synchronously, then release dispatch bypass while it awaits.
	grid.execute_network_command(action, argument, tile)
	dispatching = false
	while is_instance_valid(grid) and (grid.network_handler_busy or grid.resolving_turn_start or grid.presenting_skill):
		await get_tree().process_frame
		if generation != session_generation or not running:
			return
	executing_command = false
	send_snapshot()
	_reply(sender, sequence)

func _reply(sender: int, sequence: int) -> void:
	if sender == guest_id and guest_id != 0:
		# State precedes acknowledgment on the same reliable channel.
		send_snapshot()
		_command_reply.rpc_id(sender, sequence)

@rpc("authority", "call_remote", "reliable", 0)
func _command_reply(sequence: int) -> void:
	if sequence == command_sequence:
		command_pending = false

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _pointer_update(expected_revision: int, epoch: int, cursor: Vector2) -> void:
	if mode != Mode.HOST or not running or executing_command or multiplayer.get_remote_sender_id() != guest_id:
		return
	if expected_revision != revision or epoch != turn_epoch or not cursor.is_finite() or cursor.length() > 100000:
		return
	if is_instance_valid(grid.active_unit) and grid.active_unit.side == Unit.Side.ENEMY:
		pointer = cursor

func send_snapshot() -> void:
	if mode != Mode.HOST or not running or not remote_ready or state_codec == null:
		return
	var state: Dictionary = state_codec.capture()
	state["revision"] = revision
	state["epoch"] = turn_epoch
	state["busy"] = executing_command
	var changes: Dictionary = {}
	for key in state:
		if not last_snapshot.has(key) or last_snapshot[key] != state[key]:
			changes[key] = state[key]
	if not changes.is_empty():
		_snapshot.rpc_id(guest_id, changes)
		last_snapshot = state.duplicate(true)

@rpc("authority", "call_remote", "reliable", 0)
func _snapshot(changes: Dictionary) -> void:
	if mode != Mode.CLIENT or not running or state_codec == null:
		return
	last_snapshot.merge(changes, true)
	revision = last_snapshot.revision
	turn_epoch = last_snapshot.epoch
	executing_command = last_snapshot.busy
	state_codec.apply(last_snapshot)

func _make_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 16)
	row.add_theme_constant_override("separation", 24)
	overlay.add_child(row)
	var back := Button.new()
	back.text = "Leave match"
	back.pressed.connect(leave)
	row.add_child(back)
	status_label = Label.new()
	status_label.text = "Waiting for both boards…"
	row.add_child(status_label)
