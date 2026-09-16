class_name GameHUD
extends Control

var _timer_label: Label
var _score_label: Label
var _team_label: Label
var _prompt_label: Label
var _ability_label: Label

var _ability_cd_left: float = 0.0
var _ability_cd_total: float = 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_timer_label = Label.new()
	_timer_label.position = Vector2(560, 20)
	_timer_label.add_theme_font_size_override("font_size", 32)
	add_child(_timer_label)

	_score_label = Label.new()
	_score_label.position = Vector2(20, 20)
	_score_label.add_theme_font_size_override("font_size", 22)
	add_child(_score_label)

	_team_label = Label.new()
	_team_label.position = Vector2(20, 60)
	add_child(_team_label)

	_prompt_label = Label.new()
	_prompt_label.position = Vector2(440, 650)
	_prompt_label.size = Vector2(400, 30)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt_label)

	_ability_label = Label.new()
	_ability_label.position = Vector2(1040, 650)
	add_child(_ability_label)

	GameManager.timer_updated.connect(_on_timer)
	GameManager.scores_changed.connect(_on_scores)
	GameManager.crime_progress_changed.connect(_on_crime_progress)
	GameManager.player_caught.connect(_on_player_caught)
	GameManager.player_respawned.connect(_on_player_respawned)
	GameManager.ability_used.connect(_on_ability_used)

	_on_scores(GameManager.scores[GameManager.Team.COP], GameManager.scores[GameManager.Team.ROBBER])
	_on_timer(GameManager.match_time_left)

	var my_id := multiplayer.get_unique_id()
	if GameManager.players.has(my_id):
		var team = GameManager.players[my_id].team
		if team == GameManager.Team.COP:
			_team_label.text = "Your team: Cops"
			_ability_cd_total = GameManager.COP_DASH_COOLDOWN
		else:
			_team_label.text = "Your team: Robbers"
			_ability_cd_total = GameManager.ROBBER_SMOKE_COOLDOWN

func _process(delta: float) -> void:
	if _ability_cd_left > 0.0:
		_ability_cd_left = maxf(0.0, _ability_cd_left - delta)
		_ability_label.text = "Ability (Space): %.1f" % _ability_cd_left
	else:
		_ability_label.text = "Ability (Space): Ready"

	var my_id := multiplayer.get_unique_id()
	if GameManager.players.has(my_id):
		var info = GameManager.players[my_id]
		if info.is_caught:
			_prompt_label.text = "You were caught! Waiting to respawn..."
		elif info.team == GameManager.Team.ROBBER:
			_prompt_label.text = "Hold E at a crime spot and stand still to commit a crime"
		else:
			_prompt_label.text = "Hold F near a robber to capture them"

func _on_timer(seconds_left: float) -> void:
	var s := maxi(0, int(ceil(seconds_left)))
	_timer_label.text = "%02d:%02d" % [s / 60, s % 60]

func _on_scores(cop_score: int, robber_score: int) -> void:
	_score_label.text = "Cops %d - %d Robbers" % [cop_score, robber_score]

func _on_crime_progress(_spot_id: int, progress: float, active_peer: int) -> void:
	if active_peer == multiplayer.get_unique_id() and progress > 0.0:
		_prompt_label.text = "Committing crime... %d%%" % int(progress * 100)

func _on_player_caught(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_prompt_label.text = "You were caught! Waiting to respawn..."

func _on_player_respawned(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_prompt_label.text = "You're back in the game!"

func _on_ability_used(peer_id: int, _team: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_ability_cd_left = _ability_cd_total
