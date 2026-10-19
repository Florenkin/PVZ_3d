extends SceneTree
## Render the actual reading and enraged models for visual review.


func _initialize() -> void:
	call_deferred("run")


func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://artifacts/" + filename)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Newspaper capture failed: " + error_string(result))
		quit(1)
	else:
		print("Saved " + path)


func run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	main._dave.set_physics_process(false)
	main.auto_respawn_enabled = false
	for plant: Node in main.get_node("Plants").get_children():
		if plant is Peashooter:
			plant.combat_enabled = false
			plant.idle_animation_enabled = false
	for zombie: Zombie in main.get_node("Enemies").get_children():
		zombie.movement_enabled = false
		if zombie != main._newspaper_zombie:
			zombie.hide()
	main.get_node("Plants").hide()
	main._sun_system._timer.stop()
	main._toggle_newspaper_view()
	main._orbit.default_yaw = -1.32
	main._orbit.default_pitch = 0.16
	main._orbit.default_size = 2.7
	main._orbit.target = main._newspaper_zombie.global_position + Vector3(0, 0.95, 0)
	main._orbit.reset_view()
	main.get_node("Interface").hide()
	await capture("newspaper_reading.png")
	main._newspaper_zombie.take_damage(150, Vector3.RIGHT)
	for index in 70:
		await physics_frame
	for part: Node in main._debris.get_children():
		main._debris.remove_child(part)
		part.queue_free()
	await capture("newspaper_enraged.png")
	main.get_node("Plants").show()
	main._reset_view()
	main._sun_system._timer.stop()
	main._toggle_view()
	main._set_model_view(true)
	main._orbit.default_yaw = 0.30
	main._orbit.default_pitch = 0.70
	main._orbit.default_size = 24.0
	main._orbit.distance = 38.0
	main._orbit.target = Vector3(-4.5, 0.1, 0)
	main._orbit.reset_view()
	main.get_node("Interface").show()
	await capture("newspaper_garden.png")
	main.queue_free()
	await process_frame
	quit()
