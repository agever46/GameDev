extends Node
# Authoritative game state. The server (multiplayer.is_server()) is the
# only peer that ever decides outcomes; clients only render what the
# server tells them and locally predict their own movement.

signal state_changed(new_state: int)
signal players_changed
signal scores_changed(cop_score: int, robber_score: int)
signal crime_progress_changed(spot_id: int, progress: float, active_peer: int)
signal crime_completed(spot_id: int)
signal player_caught(peer_id: int)
signal player_respawned(peer_id: int)
signal ability_used(peer_id: int, team: int)
signal timer_updated(seconds_left: float)
signal game_over(winner: int)

enum State { MENU, LOBBY, PLAYING, RESULTS }
enum Team { NONE = -1, COP = 0, ROBBER = 1 }

const MATCH_DURATION := 300.0
const CRIME_HOLD_TIME := 10.0
const CRIME_COOLDOWN := 20.0
const CAPTURE_RANGE := 50.0
const CAPTURE_HOLD_TIME := 0.8
const TOUCH_INTERRUPT_RANGE := 40.0
const RESPAWN_TIME := 15.0
const PLAYER_SPEED := 220.0
const COP_DASH_SPEED_MULT := 2.5
const COP_DASH_DURATION := 0.35
const COP_DASH_COOLDOWN := 6.0
const ROBBER_SMOKE_DURATION := 2.0
const ROBBER_SMOKE_COOLDOWN := 10.0
const WORLD_SYNC_INTERVAL := 1.0 / 15.0

class PlayerInfo:
	var peer_id: int
	var player_name: String
	var team: int = Team.NONE
	var node: PlayerAvatar = null
	var input_dir: Vector2 = Vector2.ZERO
	var wants_interact: bool = false
	var wants_capture: bool = false
	var is_caught: bool = false
	var respawn_timer: float = 0.0
	var dash_cooldown: float = 0.0
	var dash_timer: float = 0.0
	var smoke_cooldown: float = 0.0
	var smoke_timer: float = 0.0
	var capturing_target: int = -1
	var capture_hold: float = 0.0

class CrimeSpotData:
	var position: Vector2
	var radius: float = 60.0
	var progress: float = 0.0
	var cooldown_left: float = 0.0
	var active_peer: int = -1

var state: int = State.MENU
var players: Dictionary = {} # peer_id -> PlayerInfo
var crime_spots: Array[CrimeSpotData] = []
var crime_spot_nodes: Array[CrimeSpotNode] = []
var cop_spawns: Array = []
var robber_spawns: Array = []
var scores := { Team.COP: 0, Team.ROBBER: 0 }
var match_time_left: float = MATCH_DURATION
var last_winner: int = Team.NONE
var world: Node2D = null

var _sync_accum: float = 0.0

func setup_world(w: Node2D) -> void:
	world = w
	var built := MapBuilder.build(world)
	cop_spawns = built["cop_spawns"]
	robber_spawns = built["robber_spawns"]
	crime_spot_nodes = built["crime_spot_nodes"]
	crime_spots.clear()
	for spot_node in crime_spot_nodes:
		var d := CrimeSpotData.new()
		d.position = spot_node.global_position
		d.radius = spot_node.radius
		crime_spots.append(d)

# ---------- Lobby ----------

func register_player(peer_id: int, pname: String) -> void:
	if not multiplayer.is_server():
		return
	if players.has(peer_id):
		return
	if players.size() >= Net.MAX_PLAYERS:
		return
	var info := PlayerInfo.new()
	info.peer_id = peer_id
	info.player_name = pname
	players[peer_id] = info
	_broadcast_lobby_state()

func unregister_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not players.has(peer_id):
		return
	var info: PlayerInfo = players[peer_id]
	if info.node and is_instance_valid(info.node):
		info.node.queue_free()
	players.erase(peer_id)
	rpc("client_remove_player", peer_id)
	if state == State.LOBBY:
		_broadcast_lobby_state()

func _broadcast_lobby_state() -> void:
	var data := []
	for pid in players.keys():
		var info: PlayerInfo = players[pid]
		data.append({ "id": pid, "name": info.player_name, "team": info.team })
	rpc("client_update_lobby", data)

@rpc("authority", "reliable", "call_local")
func client_update_lobby(data: Array) -> void:
	var incoming_ids := []
	for entry in data:
		incoming_ids.append(entry["id"])
		if not players.has(entry["id"]):
			var info := PlayerInfo.new()
			info.peer_id = entry["id"]
			players[entry["id"]] = info
		players[entry["id"]].player_name = entry["name"]
		players[entry["id"]].team = entry["team"]
	for pid in players.keys().duplicate():
		if pid not in incoming_ids:
			players.erase(pid)
	players_changed.emit()

@rpc("authority", "reliable", "call_local")
func client_remove_player(peer_id: int) -> void:
	if players.has(peer_id):
		if players[peer_id].node and is_instance_valid(players[peer_id].node):
			players[peer_id].node.queue_free()
		players.erase(peer_id)
	players_changed.emit()

func reset_to_menu() -> void:
	players.clear()
	scores[Team.COP] = 0
	scores[Team.ROBBER] = 0
	if world:
		for c in world.get_children():
			if c is PlayerAvatar:
				c.queue_free()
	state = State.MENU
	state_changed.emit(state)

# ---------- Match start / end ----------

func start_game() -> void:
	if not multiplayer.is_server():
		return
	if players.size() < 2:
		return
	var ids := players.keys()
	ids.shuffle()
	var half := ceili(ids.size() / 2.0)
	for i in ids.size():
		var info: PlayerInfo = players[ids[i]]
		info.team = Team.COP if i < half else Team.ROBBER
		info.is_caught = false
		info.respawn_timer = 0.0
		info.dash_cooldown = 0.0
		info.dash_timer = 0.0
		info.smoke_cooldown = 0.0
		info.smoke_timer = 0.0
		info.input_dir = Vector2.ZERO
	match_time_left = MATCH_DURATION
	var team_data := {}
	for pid in players.keys():
		team_data[pid] = players[pid].team
	rpc("client_start_game", team_data, match_time_left)

@rpc("authority", "reliable", "call_local")
func client_start_game(team_data: Dictionary, time_left: float) -> void:
	for pid in team_data.keys():
		if players.has(pid):
			players[pid].team = team_data[pid]
	match_time_left = time_left
	scores[Team.COP] = 0
	scores[Team.ROBBER] = 0
	last_winner = Team.NONE
	_reset_crime_spots()
	state = State.PLAYING
	_spawn_all_players()
	state_changed.emit(state)

func return_to_lobby() -> void:
	if not multiplayer.is_server():
		return
	rpc("client_return_to_lobby")

@rpc("authority", "reliable", "call_local")
func client_return_to_lobby() -> void:
	for pid in players.keys():
		players[pid].team = Team.NONE
		if players[pid].node and is_instance_valid(players[pid].node):
			players[pid].node.queue_free()
		players[pid].node = null
	state = State.LOBBY
	state_changed.emit(state)

func _end_game() -> void:
	state = State.RESULTS
	var winner: int
	if scores[Team.COP] > scores[Team.ROBBER]:
		winner = Team.COP
	elif scores[Team.ROBBER] > scores[Team.COP]:
		winner = Team.ROBBER
	else:
		winner = Team.NONE
	rpc("client_game_over", winner, scores[Team.COP], scores[Team.ROBBER])

@rpc("authority", "reliable", "call_local")
func client_game_over(winner: int, cop_score: int, robber_score: int) -> void:
	state = State.RESULTS
	scores[Team.COP] = cop_score
	scores[Team.ROBBER] = robber_score
	last_winner = winner
	game_over.emit(winner)
	state_changed.emit(state)

# ---------- Spawning ----------

func _spawn_all_players() -> void:
	for pid in players.keys():
		_spawn_player_node(pid)

func _spawn_player_node(pid: int) -> void:
	var info: PlayerInfo = players[pid]
	if info.node and is_instance_valid(info.node):
		info.node.queue_free()
	var avatar := PlayerAvatar.new()
	avatar.peer_id = pid
	avatar.team = info.team
	avatar.display_name = info.player_name
	if multiplayer.is_server():
		avatar.mode = PlayerAvatar.Mode.SERVER_AUTH
	elif pid == multiplayer.get_unique_id():
		avatar.mode = PlayerAvatar.Mode.LOCAL_PREDICTED
	else:
		avatar.mode = PlayerAvatar.Mode.REMOTE_INTERP
	world.add_child(avatar)
	avatar.global_position = _get_spawn_point(info.team)
	info.node = avatar

func _get_spawn_point(team: int) -> Vector2:
	var arr: Array = cop_spawns if team == Team.COP else robber_spawns
	if arr.is_empty():
		return Vector2.ZERO
	return arr[randi() % arr.size()]

# ---------- Per-frame simulation ----------

func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		_client_tick(delta)

func _server_tick(delta: float) -> void:
	var host_id := multiplayer.get_unique_id()
	if players.has(host_id) and not players[host_id].is_caught:
		players[host_id].input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_poll_action_inputs_for(host_id)

	match_time_left -= delta
	if match_time_left <= 0.0:
		match_time_left = 0.0
		for pid in players.keys():
			_simulate_player(pid, delta)
		_end_game()
		return

	for pid in players.keys():
		_simulate_player(pid, delta)
	_simulate_crime_spots(delta)

	_sync_accum += delta
	if _sync_accum >= WORLD_SYNC_INTERVAL:
		_sync_accum = 0.0
		_broadcast_world_state()

func _client_tick(delta: float) -> void:
	var my_id := multiplayer.get_unique_id()
	if not players.has(my_id):
		return
	var info: PlayerInfo = players[my_id]
	_poll_action_inputs()
	if info.is_caught or info.node == null:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	rpc_id(1, "server_receive_input", dir)

	if info.dash_timer > 0.0:
		info.dash_timer = maxf(0.0, info.dash_timer - delta)
	if info.smoke_timer > 0.0:
		info.smoke_timer = maxf(0.0, info.smoke_timer - delta)

	var speed := PLAYER_SPEED
	if info.team == Team.COP and info.dash_timer > 0.0:
		speed *= COP_DASH_SPEED_MULT
	var move_dir := dir if dir.length() <= 1.0 else dir.normalized()
	info.node.velocity = move_dir * speed
	info.node.move_and_slide()

func _simulate_player(pid: int, delta: float) -> void:
	var info: PlayerInfo = players[pid]
	if info.is_caught:
		info.respawn_timer -= delta
		if info.respawn_timer <= 0.0:
			_respawn_player(pid)
		return

	if info.dash_cooldown > 0.0:
		info.dash_cooldown = maxf(0.0, info.dash_cooldown - delta)
	if info.smoke_cooldown > 0.0:
		info.smoke_cooldown = maxf(0.0, info.smoke_cooldown - delta)
	if info.dash_timer > 0.0:
		info.dash_timer = maxf(0.0, info.dash_timer - delta)
	if info.smoke_timer > 0.0:
		info.smoke_timer = maxf(0.0, info.smoke_timer - delta)

	var node := info.node
	if node == null:
		return

	var dir := info.input_dir
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := PLAYER_SPEED
	if info.team == Team.COP and info.dash_timer > 0.0:
		speed *= COP_DASH_SPEED_MULT
	node.velocity = dir * speed
	node.move_and_slide()

	if info.team == Team.ROBBER:
		_simulate_robber_crime(pid, info, delta)
	else:
		_simulate_cop_capture(pid, info, delta)

func _simulate_robber_crime(pid: int, info: PlayerInfo, delta: float) -> void:
	if not info.wants_interact or info.input_dir.length() > 0.05:
		_cancel_crime_progress(pid)
		return
	var spot := _find_spot_under(info.node.global_position)
	if spot == null or spot.cooldown_left > 0.0 or (spot.active_peer != -1 and spot.active_peer != pid):
		_cancel_crime_progress(pid)
		return
	for opid in players.keys():
		var oinfo: PlayerInfo = players[opid]
		if oinfo.team == Team.COP and not oinfo.is_caught and oinfo.node:
			if oinfo.node.global_position.distance_to(info.node.global_position) <= TOUCH_INTERRUPT_RANGE:
				_cancel_crime_progress(pid)
				return
	spot.active_peer = pid
	spot.progress = minf(CRIME_HOLD_TIME, spot.progress + delta)
	if spot.progress >= CRIME_HOLD_TIME:
		_complete_crime(spot)

func _simulate_cop_capture(pid: int, info: PlayerInfo, delta: float) -> void:
	if not info.wants_capture:
		info.capturing_target = -1
		info.capture_hold = 0.0
		return
	var target_id := _find_nearest_robber(info.node.global_position)
	if target_id == -1:
		info.capturing_target = -1
		info.capture_hold = 0.0
		return
	if info.capturing_target != target_id:
		info.capturing_target = target_id
		info.capture_hold = 0.0
	info.capture_hold += delta
	if info.capture_hold >= CAPTURE_HOLD_TIME:
		_catch_robber(target_id, pid)
		info.capturing_target = -1
		info.capture_hold = 0.0

func _simulate_crime_spots(delta: float) -> void:
	for spot in crime_spots:
		if spot.cooldown_left > 0.0:
			spot.cooldown_left = maxf(0.0, spot.cooldown_left - delta)

func _find_spot_under(pos: Vector2) -> CrimeSpotData:
	for spot in crime_spots:
		if spot.position.distance_to(pos) <= spot.radius:
			return spot
	return null

func _find_nearest_robber(pos: Vector2) -> int:
	var best_id := -1
	var best_dist := CAPTURE_RANGE
	for pid in players.keys():
		var info: PlayerInfo = players[pid]
		if info.team == Team.ROBBER and not info.is_caught and info.smoke_timer <= 0.0 and info.node:
			var d := info.node.global_position.distance_to(pos)
			if d <= best_dist:
				best_dist = d
				best_id = pid
	return best_id

func _cancel_crime_progress(pid: int) -> void:
	for spot in crime_spots:
		if spot.active_peer == pid:
			spot.active_peer = -1
			spot.progress = 0.0

func _reset_crime_spots() -> void:
	for spot in crime_spots:
		spot.progress = 0.0
		spot.cooldown_left = 0.0
		spot.active_peer = -1

func _complete_crime(spot: CrimeSpotData) -> void:
	spot.progress = 0.0
	spot.active_peer = -1
	spot.cooldown_left = CRIME_COOLDOWN
	scores[Team.ROBBER] += 1
	var spot_id := crime_spots.find(spot)
	rpc("client_crime_completed", spot_id, scores[Team.COP], scores[Team.ROBBER])

@rpc("authority", "reliable", "call_local")
func client_crime_completed(spot_id: int, cop_score: int, robber_score: int) -> void:
	scores[Team.COP] = cop_score
	scores[Team.ROBBER] = robber_score
	crime_completed.emit(spot_id)
	scores_changed.emit(cop_score, robber_score)

func _catch_robber(robber_id: int, _cop_id: int) -> void:
	var info: PlayerInfo = players[robber_id]
	info.is_caught = true
	info.respawn_timer = RESPAWN_TIME
	info.wants_interact = false
	_cancel_crime_progress(robber_id)
	scores[Team.COP] += 1
	if info.node:
		info.node.set_caught_visual(true)
	rpc("client_player_caught", robber_id, scores[Team.COP], scores[Team.ROBBER])

@rpc("authority", "reliable", "call_local")
func client_player_caught(robber_id: int, cop_score: int, robber_score: int) -> void:
	if players.has(robber_id):
		players[robber_id].is_caught = true
		if players[robber_id].node:
			players[robber_id].node.set_caught_visual(true)
	scores[Team.COP] = cop_score
	scores[Team.ROBBER] = robber_score
	player_caught.emit(robber_id)
	scores_changed.emit(cop_score, robber_score)

func _respawn_player(pid: int) -> void:
	var info: PlayerInfo = players[pid]
	info.is_caught = false
	info.respawn_timer = 0.0
	info.input_dir = Vector2.ZERO
	var spawn := _get_spawn_point(info.team)
	if info.node:
		info.node.global_position = spawn
		info.node.set_caught_visual(false)
	rpc("client_player_respawned", pid, spawn)

@rpc("authority", "reliable", "call_local")
func client_player_respawned(pid: int, pos: Vector2) -> void:
	if players.has(pid):
		players[pid].is_caught = false
		if players[pid].node:
			players[pid].node.global_position = pos
			players[pid].node.set_caught_visual(false)
	player_respawned.emit(pid)

# ---------- Abilities ----------

func _poll_action_inputs() -> void:
	if Input.is_action_just_pressed("interact"):
		rpc_id(1, "server_set_interacting", true)
	if Input.is_action_just_released("interact"):
		rpc_id(1, "server_set_interacting", false)
	if Input.is_action_just_pressed("capture"):
		rpc_id(1, "server_set_capturing", true)
	if Input.is_action_just_released("capture"):
		rpc_id(1, "server_set_capturing", false)
	if Input.is_action_just_pressed("ability"):
		rpc_id(1, "server_use_ability")

func _poll_action_inputs_for(pid: int) -> void:
	var info: PlayerInfo = players[pid]
	if Input.is_action_just_pressed("interact"):
		info.wants_interact = true
	if Input.is_action_just_released("interact"):
		info.wants_interact = false
	if Input.is_action_just_pressed("capture"):
		info.wants_capture = true
	if Input.is_action_just_released("capture"):
		info.wants_capture = false
	if Input.is_action_just_pressed("ability"):
		_trigger_ability(pid, info)

func _trigger_ability(pid: int, info: PlayerInfo) -> void:
	if info.is_caught or state != State.PLAYING:
		return
	if info.team == Team.COP:
		if info.dash_cooldown > 0.0:
			return
		info.dash_timer = COP_DASH_DURATION
		info.dash_cooldown = COP_DASH_COOLDOWN
	else:
		if info.smoke_cooldown > 0.0:
			return
		info.smoke_timer = ROBBER_SMOKE_DURATION
		info.smoke_cooldown = ROBBER_SMOKE_COOLDOWN
	rpc("client_ability_used", pid, info.team)

@rpc("authority", "reliable", "call_local")
func client_ability_used(peer_id: int, team: int) -> void:
	ability_used.emit(peer_id, team)

# ---------- Server-bound RPCs from clients ----------

@rpc("any_peer", "unreliable_ordered")
func server_receive_input(dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender) and not players[sender].is_caught:
		if dir.length() > 1.001:
			dir = dir.normalized()
		players[sender].input_dir = dir

@rpc("any_peer", "unreliable_ordered")
func server_set_interacting(pressed: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender):
		players[sender].wants_interact = pressed

@rpc("any_peer", "unreliable_ordered")
func server_set_capturing(pressed: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender):
		players[sender].wants_capture = pressed
		if not pressed:
			players[sender].capturing_target = -1
			players[sender].capture_hold = 0.0

@rpc("any_peer", "reliable")
func server_use_ability() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender):
		_trigger_ability(sender, players[sender])

# ---------- World state broadcast ----------

func _broadcast_world_state() -> void:
	var pos_data := {}
	for pid in players.keys():
		var info: PlayerInfo = players[pid]
		if info.node and not info.is_caught:
			pos_data[pid] = info.node.global_position
	var spot_data := []
	for spot in crime_spots:
		spot_data.append({
			"progress": spot.progress / CRIME_HOLD_TIME,
			"cooldown": spot.cooldown_left,
			"active": spot.active_peer,
		})
	rpc("client_world_snapshot", pos_data, spot_data, match_time_left)

@rpc("authority", "unreliable", "call_local")
func client_world_snapshot(pos_data: Dictionary, spot_data: Array, time_left: float) -> void:
	match_time_left = time_left
	timer_updated.emit(time_left)
	var my_id := multiplayer.get_unique_id()
	for pid in pos_data.keys():
		if not players.has(pid) or players[pid].node == null:
			continue
		var node: PlayerAvatar = players[pid].node
		var server_pos: Vector2 = pos_data[pid]
		if pid == my_id:
			if node.global_position.distance_to(server_pos) > 40.0:
				node.global_position = server_pos
		else:
			node.render_target = server_pos
	for i in spot_data.size():
		if i < crime_spot_nodes.size():
			var d = spot_data[i]
			crime_spot_nodes[i].set_visual_state(d["progress"], d["cooldown"])
			crime_progress_changed.emit(i, d["progress"], d["active"])
