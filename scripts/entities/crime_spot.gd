class_name CrimeSpotNode
extends Area2D

var radius: float = 60.0
var progress: float = 0.0 # 0..1
var cooldown_left: float = 0.0

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	monitoring = true
	monitorable = true

func set_visual_state(p: float, cooldown: float) -> void:
	progress = p
	cooldown_left = cooldown
	queue_redraw()

func _draw() -> void:
	var base_col := Color(0.9, 0.75, 0.1, 0.3) if cooldown_left <= 0.0 else Color(0.5, 0.5, 0.5, 0.25)
	draw_circle(Vector2.ZERO, radius, base_col)
	draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 0.25), false, 2.0)
	if progress > 0.0:
		draw_arc(Vector2.ZERO, radius - 8, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, Color(0.15, 0.9, 0.25, 0.9), 6.0)
