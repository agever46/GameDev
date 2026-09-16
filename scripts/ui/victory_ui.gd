class_name VictoryUI
extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var text := "Draw!"
	if GameManager.last_winner == GameManager.Team.COP:
		text = "Cops win!"
	elif GameManager.last_winner == GameManager.Team.ROBBER:
		text = "Robbers win!"

	var title := Label.new()
	title.text = text
	title.position = Vector2(440, 260)
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)

	var score := Label.new()
	score.text = "Cops %d - %d Robbers" % [GameManager.scores[GameManager.Team.COP], GameManager.scores[GameManager.Team.ROBBER]]
	score.position = Vector2(500, 320)
	add_child(score)

	if multiplayer.is_server():
		var btn := Button.new()
		btn.text = "Return to Lobby"
		btn.position = Vector2(560, 400)
		btn.pressed.connect(_on_return_pressed)
		add_child(btn)
	else:
		var wait_label := Label.new()
		wait_label.text = "Waiting for the host to return to lobby..."
		wait_label.position = Vector2(500, 400)
		add_child(wait_label)

func _on_return_pressed() -> void:
	GameManager.return_to_lobby()
