extends Node
# Owns the ENet connection lifecycle. Game/lobby state itself lives in
# GameManager; this file only sets up the multiplayer_peer and reacts
# to connect/disconnect events.

signal connection_failed(reason: String)

const PORT := 7777
const MAX_PLAYERS := 10

var player_name: String = "Player"

func host_game(desired_name: String) -> bool:
	player_name = desired_name if desired_name != "" else "Player"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		connection_failed.emit("לא ניתן לפתוח שרת (קוד שגיאה %d)" % err)
		return false
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	GameManager.register_player(1, player_name)
	GameManager.state = GameManager.State.LOBBY
	GameManager.state_changed.emit(GameManager.state)
	return true

func join_game(ip: String, desired_name: String) -> bool:
	player_name = desired_name if desired_name != "" else "Player"
	var address := ip.strip_edges()
	if address == "":
		address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		connection_failed.emit("לא ניתן להתחבר לכתובת %s (קוד שגיאה %d)" % [address, err])
		return false
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	return true

func _connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(_id: int) -> void:
	pass # the joining peer registers itself via server_register_player

func _on_peer_disconnected(id: int) -> void:
	GameManager.unregister_player(id)

func _on_connected_to_server() -> void:
	rpc_id(1, "server_register_player", player_name)
	GameManager.state = GameManager.State.LOBBY
	GameManager.state_changed.emit(GameManager.state)

func _on_connection_failed() -> void:
	connection_failed.emit("החיבור לשרת נכשל")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	connection_failed.emit("החיבור לשרת אבד")
	multiplayer.multiplayer_peer = null
	GameManager.reset_to_menu()

@rpc("any_peer", "reliable")
func server_register_player(desired_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	GameManager.register_player(sender, desired_name)
