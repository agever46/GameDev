extends Node

var world: Node2D
var ui_layer: CanvasLayer
var current_ui: Control

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().title = "Cops & Robbers"

	world = Node2D.new()
	world.name = "World"
	add_child(world)
	GameManager.setup_world(world)

	var camera := Camera2D.new()
	camera.position = Vector2(600, 350)
	world.add_child(camera)
	camera.make_current()

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 10
	add_child(ui_layer)

	GameManager.state_changed.connect(_on_state_changed)
	_show_ui(MainMenuUI.new())

	_handle_cmdline_args()

func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.MENU:
			_show_ui(MainMenuUI.new())
		GameManager.State.LOBBY:
			_show_ui(LobbyUI.new())
		GameManager.State.PLAYING:
			_show_ui(GameHUD.new())
		GameManager.State.RESULTS:
			_show_ui(VictoryUI.new())

func _show_ui(ui: Control) -> void:
	if current_ui and is_instance_valid(current_ui):
		current_ui.queue_free()
	current_ui = ui
	ui_layer.add_child(ui)

func _handle_cmdline_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--dedicated-server":
			call_deferred("_auto_host")
		elif a.begins_with("--autojoin="):
			call_deferred("_auto_join", a.substr(11))

func _auto_host() -> void:
	Net.host_game("Server")

func _auto_join(ip: String) -> void:
	Net.join_game(ip, "Bot")
