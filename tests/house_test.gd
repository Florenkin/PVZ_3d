extends SceneTree
## Walk the real player controller through an animated, physically cut doorway.

var failed: bool = false
var main: Node3D
var dave: CrazyDave
var house: DaveHouse


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func walk(frames: int, input: Vector2 = Vector2.ZERO) -> void:
	for index in frames:
		await physics_frame
		dave.move_with_input(input, 1.0 / 60.0)


func _run() -> void:
	var config := GameConfiguration.current()
	config.use_values_for_tests(config.default_values())
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	config.apply_entity(main, "main")
	main.auto_respawn_enabled = false
	root.add_child(main)
	dave = main._dave
	house = main._house
	dave.set_physics_process(false)
	for plant: Node in main.get_node("Plants").get_children():
		if plant is Peashooter: plant.combat_enabled = false
	for enemy: Zombie in main.get_node("Enemies").get_children():
		enemy.movement_enabled = false
	await walk(8)
	check(house.get_parent() == main and house.global_position.x < main._dave.global_position.x and house.global_position.x < main._plant.global_position.x, "House must be an independent entity behind player/plants.")
	check(is_equal_approx(house.global_position.x, -12.6) and is_equal_approx(house.global_position.y, main._lawn.surface_height), "House did not follow lawn/configuration placement.")
	check(dave.get_effective_movement_bounds().position.x < house.global_position.x - house.settings.depth + 0.4, "Player bounds do not include the house interior.")
	var world := house.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(house.to_global(Vector3(1, 1, 0)), house.to_global(Vector3(-1, 1, 0)), 1)
	var hit := world.intersect_ray(ray)
	check(hit.get("collider") == house._door and not house.door_is_open, "Closed door must have a matching physical collider.")
	# Face the lawn as normal, then walk backwards into the house using real movement.
	var initial_yaw := dave.rotation.y
	await walk(110, Vector2(0, 1))
	check(house.to_local(dave.global_position).x < -1.0, "Dave could not walk from the lawn through the doorway.")
	check(house.door_is_open and house._door_angle > PI * 0.48, "Door did not automatically open before player contact.")
	check(dave.camera.is_current() and dave.rotation.y == initial_yaw, "Entry changed the player's waist camera or facing.")
	check(absf(dave.global_position.y - house.global_position.y) < 0.04 and dave.is_on_floor(), "Entry dropped player or snagged a floor seam.")
	await walk(170, Vector2(0, 1))
	var local := house.to_local(dave.global_position)
	check(local.x > -house.settings.depth + 0.25 and local.x < -house.settings.depth + 0.65, "Back wall must physically stop the player.")
	await walk(90)
	check(not house.door_is_open and absf(house._door_angle) < 0.01, "Door did not close after the player moved away inside.")
	var stopped := dave.global_position
	await walk(30, Vector2(0, 1))
	check(dave.global_position.distance_to(stopped) < 0.02, "Player walked through the solid back wall.")
	# Exit through the same door; opening must work from the interior too.
	await walk(205, Vector2(0, -1))
	check(dave.global_position.x > house.global_position.x + 2.7, "Dave could not leave the house and return to the lawn.")
	check(absf(dave.global_position.y - main._lawn.surface_height) < 0.04, "Exit snagged the porch/lawn floor seam.")
	await walk(105)
	check(not house.door_is_open and absf(house._door_angle) < 0.01, "Door did not close after exterior departure.")
	# Front sections either side of the doorway remain solid.
	dave.global_position = house.to_global(Vector3(1.0, 0.01, 2.9))
	await walk(100, Vector2(0, 1))
	check(house.to_local(dave.global_position).x > 0.25, "Dave entered through a solid window/front wall.")
	main._reset_view()
	check(dave.global_position.distance_to(main._lawn.cell_to_world(2, 0)) < 0.04 and dave.camera.is_current(), "Restart did not restore the player outside the house.")
	main.queue_free()
	await process_frame
	# Dimension changes and disabled houses use the same startup configuration.
	var custom := config.default_values()
	custom.house.front_gap = 2.4
	custom.house.width = 10.2
	custom.house.depth = 8.2
	custom.house.door_width = 2.1
	config.use_values_for_tests(custom)
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	house = main._house
	check(is_equal_approx(house.global_position.x, -13.2) and house.settings.width == 10.2 and house._door.get_node("CollisionShape3D").shape.size.z > 1.99, "Custom house position/geometry did not apply.")
	main.queue_free()
	await process_frame
	custom.house.enabled = false
	config.use_values_for_tests(custom)
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	check(not main._house.visible and not main._house.get_exploration_bounds().has_area() and main._dave.get_effective_movement_bounds() == main._dave.movement_bounds, "Disabling house left hidden colliders or movement extension.")
	main.queue_free()
	await process_frame
	config.emit_warnings = false
	config.use_values_for_tests({"house": {"door_width": 20}})
	check(config.values.house == config.default_values().house and not config.warnings.is_empty(), "Invalid doorway dimensions did not safely fall back.")
	if not failed:
		print("PASS: independent house behind plants, level floor/porch/lawn, physical closed door, automatic opening from both sides, real player entry/exit, solid front/back walls, waist camera/reset, custom geometry and disabled/invalid configuration.")
	quit(1 if failed else 0)
