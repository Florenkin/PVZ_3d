class_name SunSystem
extends Node3D
## The sun timer, lawn placement and resource balance have one reset lifecycle.

signal sun_value_changed(total: int)
signal sun_spawned(sun: SunPickup)

const SUN_SCENE := preload("res://scenes/pickups/sun.tscn")

var sun_value: int = 0
var settings: Dictionary
var _lawn: LawnGrid
var _timer: Timer
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	settings = GameConfiguration.current().section("sun")
	_random.randomize()
	_timer = Timer.new()
	_timer.name = "SkySunTimer"
	_timer.wait_time = settings.spawn_interval
	_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_timer.timeout.connect(spawn_sun)
	add_child(_timer)
	sun_value = int(settings.initial_value)


func configure(lawn: LawnGrid) -> void:
	_lawn = lawn
	reset()


func reset() -> void:
	_timer.stop()
	for sun: Node in get_children():
		if sun is SunPickup:
			remove_child(sun)
			sun.queue_free()
	sun_value = int(settings.initial_value)
	sun_value_changed.emit(sun_value)
	if _lawn != null and settings.enabled:
		_timer.start()


func spawn_sun() -> SunPickup:
	if _lawn == null or not settings.enabled:
		return null
	var cells: Array[Vector2i] = []
	var occupied: Array[Vector2i] = []
	for plant: Node3D in get_tree().get_nodes_in_group("vaultable_plants"):
		occupied.append(_lawn.world_to_cell(plant.global_position))
	for row in _lawn.row_count:
		for column in _lawn.column_count:
			var cell := Vector2i(column, row)
			if not cell in occupied:
				cells.append(cell)
	if cells.is_empty():
		return null
	var cell := cells[_random.randi_range(0, cells.size() - 1)]
	var landing := _lawn.cell_to_world(cell.y, cell.x)
	var tile_width := float(GameConfiguration.current().section("lawn").tile_width)
	var sun_radius := minf(float(settings.radius), tile_width * 0.4)
	var margin := maxf(0.0, tile_width * 0.5 - sun_radius * 1.08)
	landing.x += _random.randf_range(-margin, margin)
	landing.z += _random.randf_range(-margin, margin)
	landing.y += sun_radius * 1.08
	var sun := SUN_SCENE.instantiate() as SunPickup
	sun.value = int(settings.medium_value)
	sun.radius = sun_radius
	sun.fall_speed = settings.fall_speed
	sun.lifetime = settings.lifetime
	sun.landing_position = landing
	# Establish the spawn transform before ready builds the camera-facing model.
	sun.position = to_local(landing + Vector3.UP * float(settings.spawn_height))
	sun.collected.connect(_on_collected)
	add_child(sun)
	sun_spawned.emit(sun)
	return sun


func _on_collected(value: int) -> void:
	sun_value += value
	sun_value_changed.emit(sun_value)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var screen_position: Vector2 = get_viewport().get_visible_rect().get_center() if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else event.position
		if collect_at_screen(screen_position):
			get_viewport().set_input_as_handled()


func collect_at_screen(screen_position: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var start := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	# Walls, plants and zombies occlude pickups; suns never block movement or peas.
	var query := PhysicsRayQueryParameters3D.create(start, start + direction * camera.far, 1 | 2 | 4 | 32 | SunPickup.PICKUP_LAYER)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var excluded: Array[RID] = []
	for player: CollisionObject3D in get_tree().get_nodes_in_group("dave_player"):
		excluded.append(player.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var sun := hit.get("collider") as SunPickup
	if sun == null or sun.is_queued_for_deletion():
		return false
	sun.collect()
	return true
