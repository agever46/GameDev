class_name MapBuilder
extends RefCounted
# Builds the (single, fixed) MVP arena procedurally so the project needs
# no imported art or hand-authored .tscn scene graphs.

const MAP_SIZE := Vector2(1200, 700)

const CRIME_SPOT_POSITIONS := [
	Vector2(200, 150),
	Vector2(1000, 150),
	Vector2(200, 550),
	Vector2(1000, 550),
]

const OBSTACLES := [
	{ "center": Vector2(350, 250), "size": Vector2(120, 40) },
	{ "center": Vector2(850, 250), "size": Vector2(120, 40) },
	{ "center": Vector2(350, 450), "size": Vector2(120, 40) },
	{ "center": Vector2(850, 450), "size": Vector2(120, 40) },
	{ "center": Vector2(600, 350), "size": Vector2(80, 80) },
]

const COP_SPAWNS := [
	Vector2(500, 90), Vector2(550, 90), Vector2(600, 90), Vector2(650, 90), Vector2(700, 90),
]

const ROBBER_SPAWNS := [
	Vector2(500, 610), Vector2(550, 610), Vector2(600, 610), Vector2(650, 610), Vector2(700, 610),
]

static func build(world: Node2D) -> Dictionary:
	_make_wall(world, Vector2(600, 20), Vector2(1240, 40))
	_make_wall(world, Vector2(600, 680), Vector2(1240, 40))
	_make_wall(world, Vector2(20, 350), Vector2(40, 700))
	_make_wall(world, Vector2(1180, 350), Vector2(40, 700))

	for obstacle in OBSTACLES:
		_make_wall(world, obstacle["center"], obstacle["size"])

	var crime_spot_nodes: Array[CrimeSpotNode] = []
	for pos in CRIME_SPOT_POSITIONS:
		var spot := CrimeSpotNode.new()
		spot.global_position = pos
		world.add_child(spot)
		crime_spot_nodes.append(spot)

	return {
		"cop_spawns": COP_SPAWNS.duplicate(),
		"robber_spawns": ROBBER_SPAWNS.duplicate(),
		"crime_spot_nodes": crime_spot_nodes,
	}

static func _make_wall(world: Node2D, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.global_position = center

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-size.x / 2.0, -size.y / 2.0),
		Vector2(size.x / 2.0, -size.y / 2.0),
		Vector2(size.x / 2.0, size.y / 2.0),
		Vector2(-size.x / 2.0, size.y / 2.0),
	])
	visual.color = Color(0.35, 0.35, 0.42)
	body.add_child(visual)

	world.add_child(body)
