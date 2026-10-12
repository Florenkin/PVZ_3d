extends SceneTree
## Real physics cadence, stable landing, mouse collection, occlusion and restart.
## godot --headless --path . --fixed-fps 60 --script res://tests/sun_test.gd

var failed: bool = false
var main: Node3D
var system: SunSystem
var spawn_frames: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func step(frames: int) -> void:
	for index in frames:
		await physics_frame


func suns() -> Array[SunPickup]:
	var result: Array[SunPickup] = []
	for child: Node in system.get_children():
		if child is SunPickup:
			result.append(child)
	return result


func mouse_click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	root.push_input(event, true)
	await step(2)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	root.push_input(event, true)
	await step(2)


func _run() -> void:
	var config := GameConfiguration.current()
	config.emit_warnings = false
	config.use_values_for_tests({"sun": {"spawn_interval": 0, "medium_value": 1.5, "initial_value": -1, "fall_speed": 0, "lifetime": -2}})
	check(config.values.sun.spawn_interval == 10.0 and config.values.sun.medium_value == 50 and config.values.sun.initial_value == 0 and config.values.sun.fall_speed == 1.4 and config.values.sun.lifetime == 20.0, "Invalid sun settings did not fall back to playable defaults.")
	config.use_values_for_tests(config.default_values())
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	main._dave.set_physics_process(false)
	for plant: Node in main.get_node("Plants").get_children():
		if plant is Peashooter:
			plant.combat_enabled = false
	for zombie: Zombie in main.get_node("Enemies").get_children():
		zombie.movement_enabled = false
	system = main._sun_system
	system.sun_spawned.connect(func(_sun: SunPickup) -> void: spawn_frames.append(Engine.get_physics_frames()))
	var start_frame := Engine.get_physics_frames()
	check(system.sun_value == 0 and main._sun_label.text == "0", "New game should show zero sun in the HUD.")
	await step(598)
	check(suns().is_empty(), "Sky sun spawned before the first 10 seconds.")
	await step(5)
	check(suns().size() == 1 and spawn_frames.size() == 1, "Exactly one medium sun should spawn at 10 seconds.")
	if suns().is_empty():
		quit(1)
		return
	check(absf(float(spawn_frames[0] - start_frame) / 60.0 - 10.0) < 0.04, "First sun timer was not 10 seconds.")
	var sun := suns()[0]
	var start_position := sun.global_position
	check(sun.value == 50 and not sun.landed, "Sky sun must start in the air and be worth 50.")
	check(main._lawn.world_to_cell(sun.landing_position) != Vector2i(-1, -1), "Sun landing point is outside the lawn.")
	for plant: Node3D in get_nodes_in_group("vaultable_plants"):
		check(main._lawn.world_to_cell(plant.global_position) != main._lawn.world_to_cell(sun.landing_position), "Sun would land inside a plant.")
	await step(60)
	check(absf(start_position.y - sun.global_position.y - 1.4) < 0.03 and is_equal_approx(start_position.x, sun.global_position.x) and is_equal_approx(start_position.z, sun.global_position.z), "Falling sun must descend at 1.4 units/s without drifting.")
	await step(245)
	check(sun.landed and sun.global_position.distance_to(sun.landing_position) < 0.001, "Sun did not settle on its lawn landing point.")
	var rest_position := sun.global_position
	await step(120)
	check(sun.global_position.distance_to(rest_position) < 0.001 and sun.rotation == Vector3.ZERO, "Landed sun rolled, bounced or drifted.")
	await step(180)
	check(spawn_frames.size() == 2 and absf(float(spawn_frames[1] - spawn_frames[0]) / 60.0 - 10.0) < 0.04, "Subsequent sky drops must remain 10 seconds apart.")
	system._timer.stop()

	# Aim in the normal captured-mouse camera, then use the real input pipeline.
	sun.global_position = main._dave.camera.global_position - main._dave.camera.global_basis.z * 2.0
	sun.set_physics_process(false)
	await step(2)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Dummy headless display servers cannot capture a mouse; still exercise the
	# same camera ray and real input dispatch at the center of the viewport.
	var click_position := Vector2(5, 5) if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else root.get_visible_rect().get_center()
	await mouse_click(click_position)
	check(system.sun_value == 50 and main._sun_label.text == "50", "Captured-mouse aiming did not award exactly 50 sun.")
	check(not is_instance_valid(sun), "Collected sun was not removed.")

	# Cursor selection in inspection mode must precede orbit dragging.
	main._set_model_view(true)
	var second := suns()[0]
	second.set_physics_process(false)
	second.global_position = main._orbit.camera.global_position - main._orbit.camera.global_basis.z * 2.0
	await step(2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await mouse_click(main._orbit.camera.unproject_position(second.global_position))
	check(system.sun_value == 100 and main._sun_label.text == "100", "Visible cursor did not collect the second 50-point sun.")
	check(not main._orbit._dragging, "Collecting a sun incorrectly started camera dragging.")
	# A real HUD button consumes clicks even when a sun sits behind it.
	var ui_sun := system.spawn_sun()
	ui_sun.set_physics_process(false)
	var button_position := Vector2(1180, 62)
	ui_sun.global_position = main._orbit.camera.project_position(button_position, 2.0)
	await step(2)
	await mouse_click(button_position)
	check(system.sun_value == 100 and is_instance_valid(ui_sun) and main._sidebar_open, "HUD button clicks passed through and collected a sun.")
	main._set_sidebar_open(false)
	ui_sun.queue_free()
	await step(2)

	# Esc/free-cursor collection in Dave's camera must not recapture the mouse.
	main._set_model_view(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cursor_sun := system.spawn_sun()
	cursor_sun.set_physics_process(false)
	cursor_sun.global_position = main._dave.camera.global_position - main._dave.camera.global_basis.z * 2.0
	await step(2)
	await mouse_click(main._dave.camera.unproject_position(cursor_sun.global_position))
	check(system.sun_value == 150 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Free-cursor collection failed or relocked Dave's mouse.")
	main._set_model_view(true)
	var duplicate := system.spawn_sun()
	duplicate.collect()
	duplicate.collect()
	check(system.sun_value == 200, "Repeated collection credited one sun more than once.")
	await step(2)

	# Solid geometry should prevent collecting a sun through a wall.
	var hidden_sun := system.spawn_sun()
	hidden_sun.set_physics_process(false)
	hidden_sun.global_position = main._orbit.camera.global_position - main._orbit.camera.global_basis.z * 4.0
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var blocker_shape := CollisionShape3D.new()
	blocker_shape.shape = BoxShape3D.new()
	blocker.add_child(blocker_shape)
	main.add_child(blocker)
	blocker.global_position = main._orbit.camera.global_position - main._orbit.camera.global_basis.z * 2.0
	await step(2)
	check(not system.collect_at_screen(main._orbit.camera.unproject_position(hidden_sun.global_position)) and system.sun_value == 200, "Sun was collected through solid geometry.")
	blocker.queue_free()
	await step(2)

	# Expiring an uncollected sun does not add resource value.
	hidden_sun.landing_position = hidden_sun.global_position
	hidden_sun.landed = true
	hidden_sun.lifetime = 0.1
	hidden_sun.set_physics_process(true)
	await step(10)
	check(not is_instance_valid(hidden_sun) and system.sun_value == 200, "Uncollected expiration credited sun or failed to clean it up.")

	# R resets the count, all live pickups, and the entire spawn interval.
	system.spawn_sun()
	main._reset_view()
	check(suns().is_empty() and system.sun_value == 0 and main._sun_label.text == "0", "Restart must clear pickups and reset the HUD balance.")
	check(absf(system._timer.time_left - 10.0) < 0.01, "Restart did not restore a full 10-second timer.")
	await step(598)
	check(suns().is_empty(), "An old timeout spawned a sun early after restart.")
	await step(5)
	check(suns().size() == 1, "Sky drops did not resume once after restart.")

	# Custom settings and the disabled switch share the validated snapshot.
	main.queue_free()
	await step(2)
	config.use_values_for_tests({"sun": {"initial_value": 125, "medium_value": 75, "spawn_interval": 0.5}})
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	system = main._sun_system
	check(system.sun_value == 125 and main._sun_label.text == "125", "Custom initial sun did not reach the HUD.")
	await step(33)
	check(suns().size() == 1 and suns()[0].value == 75, "Custom interval/value was not applied to spawned suns.")
	suns()[0].collect()
	check(system.sun_value == 200, "Configured pickup value was not credited.")
	system.settings.enabled = false
	system.reset()
	await step(40)
	check(system._timer.is_stopped() and suns().is_empty(), "Disabled sky sun still spawned pickups.")
	main.queue_free()
	await step(2)
	if not failed:
		print("Sun test passed: 10-second cadence, stable landing, 50-point collection, mouse modes, occlusion, expiry, restart and configuration.")
	quit(1 if failed else 0)
