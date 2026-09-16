class_name LobbyUI
extends Control

var _list_label: Label
var _start_btn: Button

func _ready() -> void:
	size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title := Label.new()
	title.text = "לובי - ממתינים לשחקנים"
	title.position = Vector2(40, 30)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	_list_label = Label.new()
	_list_label.position = Vector2(40, 90)
	_list_label.size = Vector2(500, 480)
	add_child(_list_label)

	_start_btn = Button.new()
	_start_btn.text = "התחל משחק"
	_start_btn.position = Vector2(40, 600)
	_start_btn.pressed.connect(_on_start_pressed)
	_start_btn.visible = multiplayer.is_server()
	add_child(_start_btn)

	if not multiplayer.is_server():
		var hint := Label.new()
		hint.text = "ממתין למארח שיתחיל את המשחק..."
		hint.position = Vector2(40, 600)
		add_child(hint)

	GameManager.players_changed.connect(_refresh)
	_refresh()

func _on_start_pressed() -> void:
	GameManager.start_game()

func _refresh() -> void:
	var text := "שחקנים מחוברים (%d/10):\n" % GameManager.players.size()
	for pid in GameManager.players.keys():
		var info = GameManager.players[pid]
		var tag := " (את/ה)" if pid == multiplayer.get_unique_id() else ""
		text += "- %s%s\n" % [info.player_name, tag]
	_list_label.text = text
