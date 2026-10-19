extends SceneTree
## First-person input, real world pause, handheld plants, previews and stowing.

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if not value:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for frame in frames:
		await physics_frame
	await process_frame


func _mouse(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = true
	root.push_input(event, true)
	await _step(2)
	event = InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	root.push_input(event, true)
	await _step(2)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await _step(2)
	event = InputEventKey.new()
	event.keycode = code
	root.push_input(event, true)


func _aim(board: AdventureBoard, at: Vector3) -> Vector2:
	board._dave.global_position = Vector3(at.x - 2.4, board.lawn.surface_height, at.z)
	board._dave.rotation.y = -PI * 0.5
	board._dave.waist_mount.rotation.x = -atan2(board._camera.global_position.y - at.y, 2.4)
	board._camera.rotation = Vector3.ZERO
	board._dave.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var center := root.get_visible_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion, true)
	return center


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	var progress := AdventureProgress.current()
	progress.memory_only = true
	progress.completed_level = 4
	var app := load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	await _step(2)
	app.start_level(4)
	var board := app.content as AdventureBoard
	await _step(2)
	var center := root.get_visible_rect().get_center()
	_check(root.get_camera_3d() == board._dave.camera and board._camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Adventure must use Dave's first-person perspective camera.")
	_check(board._hand.shovel.get_parent() == board._hand.back and board._hand.shovel.visible, "An unlocked, unused shovel must start on Dave's back.")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Adventure must capture the mouse for first-person aiming.")
	board.sun_value = 500
	board.plant_at("sunflower", Vector2i(0, 2))
	board.plant_at("cherry_bomb", Vector2i(6, 2))
	var flower := board._occupied[Vector2i(0, 2)] as AdventurePlant
	var cherry := board._occupied[Vector2i(6, 2)] as AdventurePlant
	var enemy := board.spawn_enemy("zombie", 1)
	var sun := board.spawn_plant_sun(board.lawn.cell_to_world(2, 5), 25)
	var shot := StageProjectile.new()
	shot.stage = board
	shot.position = Vector3(0, 2, -4.8)
	board.projectiles.add_child(shot)
	var debris := RigidBody3D.new()
	debris.position = Vector3(0, 4, 4.8)
	debris.linear_velocity = Vector3(1, 0, 0)
	board.get_node("Debris").add_child(debris)
	var mower := board._mowers[4] as AdventureMower
	mower.trigger()
	board.effect(Vector3(0, 2, 0), Color.ORANGE, 2.0)
	await _step(3)
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	_check(board.state == AdventureBoard.State.SELECTING and paused and board._dave.interface_open, "Empty-handed right-click must pause the world and release Dave for the picker.")
	var times := [board._wave_remaining, board._sun_remaining, board.cooldowns.duplicate(), flower._production_timer, cherry._fuse, sun._age_on_lawn]
	var poses := [enemy.global_transform, sun.global_transform, shot.global_transform, debris.global_transform, mower.global_transform, flower._visuals.transform, board._dave.global_transform, board._effects.get_child(0).scale]
	await _step(90)
	_check(times == [board._wave_remaining, board._sun_remaining, board.cooldowns, flower._production_timer, cherry._fuse, sun._age_on_lawn], "Selection must freeze waves, sun, cooldowns, production and cherry fuse.")
	_check(poses == [enemy.global_transform, sun.global_transform, shot.global_transform, debris.global_transform, mower.global_transform, flower._visuals.transform, board._dave.global_transform, board._effects.get_child(0).scale], "Selection must freeze enemies, falling sun, projectiles, rigid debris, mowers, animation, Dave and effect tweens.")
	_check(not board.plant_at("peashooter", Vector2i(2, 2)) and not board.shovel_at(Vector2i(0, 2)), "The picker must block planting and shoveling transactions.")
	_check((board._cards.sunflower as Button).disabled and (board._cards.cherry_bomb as Button).disabled, "Cooling plants must be disabled in the picker.")
	await _key(KEY_3)
	_check(board.state == AdventureBoard.State.SELECTING and paused, "An unavailable numeric shortcut must leave selection paused.")
	var card := board._cards.peashooter as AdventureSeedCard
	await _mouse(MOUSE_BUTTON_LEFT, card.get_global_rect().get_center())
	_check(board.state == AdventureBoard.State.PLAYING and not paused and board.selected_kind == "peashooter", "Clicking an available seed must resume the world with the plant selected.")
	_check(is_instance_valid(board._hand.held_plant) and board._hand.held_plant.scale == Vector3.ONE * 0.32 and board._hand.held_plant.get_parent() == board._hand.hand, "The selected plant must be a small visual in Dave's right hand.")
	_check(board._hand.held_plant.find_children("*", "CollisionObject3D", true, false).is_empty(), "Handheld plants must have no combat or picking collisions.")
	_check(board._hand.shovel.get_parent() == board._hand.back, "Holding a plant must leave the shovel on the back.")
	var cell := Vector2i(2, 2)
	_aim(board, board.lawn.cell_to_world(cell.y, cell.x))
	# Free-cursor aiming is also exercised by the headless backend.
	Input.warp_mouse(center)
	await _step(2)
	if DisplayServer.get_name() == "headless":
		# This backend cannot capture/warp a hardware cursor; use the same preview ray.
		board._update_placement_preview(center)
	_check(board._cursor.visible and board._cursor.position.is_equal_approx(board.lawn.cell_to_local(cell.y, cell.x)), "Aiming at a lawn cell must display the plant preview at that cell.")
	for mesh: MeshInstance3D in board._ghost.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.material_override as StandardMaterial3D
		_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and is_equal_approx(material.albedo_color.a, 0.45), "Every preview mesh must use a translucent material supported by Compatibility.")
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	blocker.add_child(shape)
	board.add_child(blocker)
	blocker.global_position = board._camera.global_position.lerp(board.lawn.cell_to_world(cell.y, cell.x), 0.5)
	await _step(2)
	_check(board.cell_at_screen(center) == Vector2i(-1, -1) and not board._cursor.visible, "Solid objects must block lawn picking and previews.")
	await _mouse(MOUSE_BUTTON_LEFT, center)
	_check(not board._occupied.has(cell), "A blocked click must not plant through scenery.")
	blocker.queue_free()
	await _step(2)
	var before := board.sun_value
	await _mouse(MOUSE_BUTTON_LEFT, center)
	_check(board._occupied.has(cell) and board.sun_value == before - 100 and board.selected_kind.is_empty() and not is_instance_valid(board._hand.held_plant), "A left click must plant, pay once and return the right hand to empty.")
	await _mouse(MOUSE_BUTTON_WHEEL_DOWN, center)
	_check(board.selected_kind == "shovel" and board._hand.shovel.get_parent() == board._hand.hand, "The wheel must move the same shovel from the back into the right hand.")
	await _mouse(MOUSE_BUTTON_LEFT, center)
	_check(not board._occupied.has(cell) and board.sun_value == before - 100 and board.selected_kind == "shovel", "Left-click shoveling must remove the target without refunding or unequipping the shovel.")
	await _mouse(MOUSE_BUTTON_WHEEL_UP, center)
	_check(board.selected_kind.is_empty() and board._hand.shovel.get_parent() == board._hand.back, "Switching to empty must return the shovel to Dave's back.")
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	_check(board.state == AdventureBoard.State.PLAYING and not paused and board.selected_kind.is_empty(), "Right-click cancellation over the modal must resume without a plant.")
	board.sun_value = 0
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	_check((board._cards.wall_nut as Button).disabled, "Insufficient sun must disable otherwise available plants.")
	await _key(KEY_4)
	_check(board.state == AdventureBoard.State.SELECTING and paused, "An unaffordable shortcut must leave the picker open.")
	await _key(KEY_ESCAPE)
	_check(board.state == AdventureBoard.State.PLAYING and not paused, "Esc in the picker must cancel and resume, without opening another pause screen.")
	await _key(KEY_S)
	_check(board.selected_kind.is_empty(), "S must remain a movement key and never equip the shovel.")
	await _key(KEY_ESCAPE)
	_check(board.state == AdventureBoard.State.PAUSED and paused and board._dave.interface_open, "Esc in gameplay must pause and release the mouse.")
	await _key(KEY_ESCAPE)
	_check(board.state == AdventureBoard.State.PLAYING and not paused and not board._dave.interface_open, "Esc must resume first-person control.")
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	var old_id := board.get_instance_id()
	await _key(KEY_R)
	board = app.content as AdventureBoard
	_check(not is_instance_id_valid(old_id) and not paused and board.state == AdventureBoard.State.PLAYING and board.selected_kind.is_empty(), "Retry from the picker must release the old paused world and start empty-handed.")
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	await _key(KEY_F1)
	_check(app.current_mode == "menu" and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "F1 from the picker must release pause and return to the menu.")
	progress.completed_level = 0
	app.start_level(1)
	board = app.content as AdventureBoard
	await _step(2)
	await _mouse(MOUSE_BUTTON_WHEEL_UP, center)
	_check(board.selected_kind.is_empty() and not board._hand.shovel.visible, "A new adventure must retain the existing 1-4 shovel unlock requirement.")
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	await _key(KEY_1)
	_aim(board, board.lawn.cell_to_world(0, 2))
	Input.warp_mouse(center)
	await _step(2)
	_check(not board._cursor.visible, "Inactive lanes must not display a placement preview.")
	await _mouse(MOUSE_BUTTON_LEFT, center)
	_check(board._occupied.is_empty() and board.sun_value == 150, "Inactive lanes must reject a first-person click without payment.")
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	_check(board.selected_kind.is_empty() and board.state == AdventureBoard.State.PLAYING, "Right-clicking a held plant must cancel it before reopening the picker.")
	var config := GameConfiguration.current()
	var fixture := config.default_values()
	fixture.lawn.rows = 8
	fixture.lawn.columns = 13
	fixture.dave.boundary_inset = 0.4
	config.use_values_for_tests(fixture)
	app.start_level(1)
	board = app.content as AdventureBoard
	var half := Vector2(9, 5) * board.lawn.cell_size * 0.5 - Vector2.ONE * 0.4
	_check(board._dave.movement_bounds == Rect2(-half, half * 2.0), "Automatic adventure movement bounds must use its fixed lawn and the configured inset, regardless of demo lawn size.")
	fixture.dave.derive_bounds_from_lawn = false
	fixture.dave.movement_bounds = [-3, -2, 6, 4]
	config.use_values_for_tests(fixture)
	app.start_level(1)
	board = app.content as AdventureBoard
	_check(board._dave.movement_bounds == Rect2(-3, -2, 6, 4), "Adventure must preserve configured manual movement bounds.")
	app.queue_free()
	await _step(2)
	_check(not paused, "Removing the board must never leave the application paused.")
	print("Adventure hand integration: ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
