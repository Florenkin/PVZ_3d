extends SceneTree
## Render the real sun model and HUD with both game cameras.

var main: Node3D


func _initialize() -> void:
	call_deferred("_run")


func place_sun(row: int, column: int, height: float = 0.0) -> SunPickup:
	var sun: SunPickup = main._sun_system.spawn_sun()
	sun.landing_position = main._lawn.cell_to_world(row, column) + Vector3.UP * sun.radius * 1.08
	sun.global_position = sun.landing_position + Vector3.UP * height
	sun.landed = is_zero_approx(height)
	sun.set_physics_process(false)
	return sun


func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://artifacts/" + filename)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Sun capture failed: " + error_string(error))
		quit(1)
	else:
		print("Sun capture saved: " + path)


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	main._dave.set_physics_process(false)
	for plant: Node in main.get_node("Plants").get_children():
		if plant is Peashooter:
			plant.combat_enabled = false
			plant.idle_animation_enabled = false
	for zombie: Zombie in main.get_node("Enemies").get_children():
		zombie.movement_enabled = false
	main._sun_system._timer.stop()
	var collected: SunPickup = main._sun_system.spawn_sun()
	collected.collect()
	var near_sun := place_sun(3, 2)
	place_sun(1, 5)
	place_sun(2, 6, 3.0)
	await capture("sun_dave.png")
	main._set_model_view(true)
	main._orbit.target = Vector3(0, 1.0, 0)
	main._orbit.default_yaw = 0.10
	main._orbit.default_pitch = 0.72
	main._orbit.default_size = 15.8
	main._orbit.distance = 38.0
	main._orbit.reset_view()
	await capture("sun_lawn.png")
	main._orbit.target = near_sun.global_position
	main._orbit.default_yaw = 0.45
	main._orbit.default_pitch = 0.25
	main._orbit.default_size = 3.0
	main._orbit.distance = 7.0
	main._orbit.reset_view()
	await capture("sun_closeup.png")
	main.queue_free()
	await process_frame
	quit()
