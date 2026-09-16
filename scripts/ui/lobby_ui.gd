class_name LobbyUI
extends Control

var _list_label: Label
var _start_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "Lobby - Waiting for Players"
	title.position = Vector2(40, 30)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	_list_label = Label.new()
	_list_label.position = Vector2(40, 90)
	_list_label.size = Vector2(500, 480)
	add_child(_list_label)

	_start_btn = Button.new()
	_start_btn.text = "Start Game"
	_start_btn.position = Vector2(40, 600)
	_start_btn.pressed.connect(_on_start_pressed)
	_start_btn.visible = multiplayer.is_server()
	add_child(_start_btn)

	if not multiplayer.is_server():
		var hint := Label.new()
		hint.text = "Waiting for the host to start the game..."
		hint.position = Vector2(40, 600)
		add_child(hint)

	GameManager.players_changed.connect(_refresh)
	_refresh()

func _on_start_pressed() -> void:
	GameManager.start_game()

func _refresh() -> void:
	var text := "Connected players (%d/10):\n" % GameManager.players.size()
	for pid in GameManager.players.keys():
		var info = GameManager.players[pid]
		var tag := " (you)" if pid == multiplayer.get_unique_id() else ""
		text += "- %s%s\n" % [info.player_name, tag]
	_list_label.text = text
