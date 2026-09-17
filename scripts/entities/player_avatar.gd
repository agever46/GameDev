class_name PlayerAvatar
extends CharacterBody2D

const RADIUS := 16.0

enum Mode { SERVER_AUTH, LOCAL_PREDICTED, REMOTE_INTERP }

var peer_id: int = -1
var team: int = -1
var display_name: String = ""
var mode: int = Mode.SERVER_AUTH
var render_target: Vector2

var _label: Label

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	_label = Label.new()
	_label.text = display_name
	_label.position = Vector2(-40, -RADIUS - 22)
	_label.size = Vector2(80, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

	render_target = global_position

func _process(delta: float) -> void:
	if mode == Mode.REMOTE_INTERP:
		global_position = global_position.lerp(render_target, clampf(delta * 12.0, 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	var col: Color = Color(0.2, 0.45, 0.95) if team == 0 else Color(0.85, 0.2, 0.2)
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.6), false, 2.0)

func set_caught_visual(caught: bool) -> void:
	visible = not caught
