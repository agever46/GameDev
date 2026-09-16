class_name MainMenuUI
extends Control

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := VBoxContainer.new()
	panel.position = Vector2(340, 100)
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)

	var title := Label.new()
	title.text = "Cops & Robbers"
	title.add_theme_font_size_override("font_size", 40)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Standalone multiplayer: Cops vs Robbers"
	panel.add_child(subtitle)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Player name"
	_name_edit.text = "Player%d" % (randi() % 1000)
	panel.add_child(_name_edit)

	var host_btn := Button.new()
	host_btn.text = "Host New Game"
	host_btn.pressed.connect(_on_host_pressed)
	panel.add_child(host_btn)

	var join_label := Label.new()
	join_label.text = "Or join an existing game:"
	panel.add_child(join_label)

	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "Server IP to join"
	_ip_edit.text = "127.0.0.1"
	panel.add_child(_ip_edit)

	var join_btn := Button.new()
	join_btn.text = "Join Game"
	join_btn.pressed.connect(_on_join_pressed)
	panel.add_child(join_btn)

	_status_label = Label.new()
	_status_label.modulate = Color(1, 0.5, 0.5)
	panel.add_child(_status_label)

	Net.connection_failed.connect(_on_connection_failed)

func _on_host_pressed() -> void:
	Net.host_game(_name_edit.text)

func _on_join_pressed() -> void:
	Net.join_game(_ip_edit.text, _name_edit.text)

func _on_connection_failed(reason: String) -> void:
	_status_label.text = reason
