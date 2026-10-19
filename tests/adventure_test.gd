extends SceneTree
## Real mouse/keyboard input, transactions, pause, damage, mowers and navigation.

var _failed: bool = false
var _app: GameApplication


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if not value:
		_failed = true
		push_error(message)


func _step(count: int) -> void:
	for frame in count:
		await physics_frame


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _click(at: Vector2) -> void:
	await _mouse(MOUSE_BUTTON_LEFT, at)


func _mouse(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = at
	root.push_input(event, true)
	await _step(2)
	event = InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	root.push_input(event, true)
	await _step(2)


func _aim(board: AdventureBoard, at: Vector3) -> Vector2:
	board._dave.global_position = Vector3(at.x - 2.4, board.lawn.surface_height, at.z)
	board._dave.rotation.y = -PI * 0.5
	board._dave.waist_mount.rotation.x = -atan2(board._dave.camera.global_position.y - at.y, 2.4)
	board._dave.camera.rotation = Vector3.ZERO
	board._dave.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return root.get_visible_rect().get_center()


func _run() -> void:
	var config := GameConfiguration.current()
	config.emit_warnings = false
	var fixture := config.default_values()
	fixture.adventure.sun_first_min = 9
	fixture.adventure.sun_first_max = 2
	fixture.adventure.card_cooldowns.peashooter = -1
	config.use_values_for_tests(fixture)
	_check(config.values.adventure.sun_first_min == 4.25 and config.values.adventure.card_cooldowns.peashooter == 7.5, "Conflicting adventure ranges and invalid card cooldowns must fall back.")
	config.use_values_for_tests(config.default_values())
	var progress := AdventureProgress.current()
	progress.memory_only = true
	progress.completed_level = 0
	_check(progress.unlocked_level() == 50 and progress.can_play(2) and progress.can_play(50) and not progress.can_play(0) and not progress.can_play(51), "A fresh save must allow all fifty valid levels.")
	progress.complete(4)
	_check(progress.completed_level == 0 and progress.has_completed(4) and progress.completed_count() == 1 and not progress.has_completed(1), "An out-of-order victory must record only the actual cleared level.")
	progress.completed_level = 0
	_app = load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(_app)
	await _step(2)
	_check(_app.current_mode == "menu" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Default startup must show a mouse-operable main menu.")
	var buttons := _app._canvas.find_children("AdventureButton", "Button", true, false)
	await _click((buttons[0] as Button).get_global_rect().get_center())
	await process_frame
	await process_frame
	_check(_app.current_mode == "levels", "The adventure menu button must open level selection.")
	for area in range(1, 6):
		_app.show_levels(area)
		await _step(2)
		for number in range((area - 1) * 10 + 1, area * 10 + 1):
			var available := _app._canvas.find_children("Level%dButton" % number, "Button", true, false)[0] as Button
			_check(not available.disabled and available.text.contains("可以挑战"), "All fifty fresh-save menu buttons must be enabled without claiming completion.")
	var last := _app._canvas.find_children("Level50Button", "Button", true, false)[0] as Button
	(last.get_parent().get_parent() as ScrollContainer).ensure_control_visible(last)
	await _step(3)
	await _click(last.get_global_rect().get_center())
	await process_frame
	await process_frame
	_check(_app.current_mode == "adventure" and (_app.content as AdventureBoard).level_number == 50 and progress.completed_count() == 0, "A real fresh-save click must directly enter 5-10 without marking any level cleared.")
	_app.show_levels(1)
	await _step(2)
	var first := _app._canvas.find_children("Level1Button", "Button", true, false)[0] as Button
	await _click(first.get_global_rect().get_center())
	await process_frame
	await process_frame
	_check(_app.current_mode == "adventure", "The unlocked level button must load 1-1.")
	var board := _app.content as AdventureBoard
	_check(board.sun_value == 150 and board.active_rows == [2] and board.wave_index == 0, "1-1 must start with 150 sun and only the central lane.")
	_check(board.lawn.row_count == 5 and board.lawn.column_count == 9, "Adventure keeps the original five-by-nine grid.")
	_check(not board.plant_at("peashooter", Vector2i(0, 0)) and board.sun_value == 150, "Inactive lawn must reject planting without charging sun.")
	_check(not board.plant_at("sunflower", Vector2i(0, 2)), "1-1 must reject plants not yet awarded.")
	await _mouse(MOUSE_BUTTON_RIGHT, root.get_visible_rect().get_center())
	_check(board.state == AdventureBoard.State.SELECTING and paused, "Empty-handed right-click must open the picker and pause the world.")
	await _key(KEY_1)
	var target := _aim(board, board.lawn.cell_to_world(2, 2))
	await _click(target)
	_check(board._occupied.has(Vector2i(2, 2)) and board.sun_value == 50, "A real picker hotkey and first-person crosshair click must plant a pea and charge 100 sun.")
	_check(not board.plant_at("peashooter", Vector2i(2, 2)) and board.sun_value == 50, "Occupied cells must not take a second payment.")
	board.sun_value = 150
	_check(not board.plant_at("peashooter", Vector2i(3, 2)) and board.sun_value == 150, "Cooling cards must reject planting without charging.")
	await _step(451)
	_check(board.plant_at("peashooter", Vector2i(3, 2)) and board.sun_value == 50, "A pea card becomes available after 7.5 seconds.")
	var sun := board.spawn_plant_sun(board.lawn.cell_to_world(2, 5), 25)
	sun.global_position = sun.landing_position
	sun.landed = true
	await _step(2)
	await _click(_aim(board, sun.global_position))
	_check(board.sun_value == 75, "A real mouse click must collect a 25-point sun once.")
	await _key(KEY_ESCAPE)
	_check(board.state == AdventureBoard.State.PAUSED, "Esc must pause gameplay.")
	var wave_time := board._wave_remaining
	var sun_time := board._sun_remaining
	var card_time: float = board.cooldowns.peashooter
	await _step(120)
	_check(is_equal_approx(board._wave_remaining, wave_time) and is_equal_approx(board._sun_remaining, sun_time) and is_equal_approx(board.cooldowns.peashooter, card_time), "Pause must freeze waves, sun and card cooldowns.")
	_check(not board.plant_at("peashooter", Vector2i(4, 2)), "Pause overlay must prevent lawn mutations.")
	await _key(KEY_ESCAPE)
	_check(board.state == AdventureBoard.State.PLAYING, "Esc resumes a paused game.")
	# Mower protection and loss: no respawn or progress for a failed run.
	_app.start_level(1)
	board = _app.content as AdventureBoard
	board._wave_remaining = 999
	var enemy := board.spawn_enemy("zombie", 2)
	enemy.global_position = board.lawn.cell_to_world(2, 0) + Vector3.LEFT * 0.65
	await _step(3)
	_check((board._mowers[2] as AdventureMower).spent and board.kills == 1, "The row mower must trigger once and kill a real zombie.")
	await _step(160)
	enemy = board.spawn_enemy("zombie", 2)
	enemy.global_position = board.lawn.cell_to_world(2, 0) + Vector3.LEFT * 2.15
	await _step(2)
	_check(board.state == AdventureBoard.State.LOST and progress.completed_level == 0, "A breach after mower consumption must lose without unlocking a level.")
	# Cherry fuse, bite damage, visually restored armor, and no demo refresh.
	progress.completed_level = 2
	_app.start_level(3)
	board = _app.content as AdventureBoard
	_check(board.active_rows == [1, 2, 3] and board.sun_value == 50, "1-3 retains three rows and begins with 50 sun.")
	board.sun_value = 150
	_check(board.plant_at("cherry_bomb", Vector2i(5, 2)), "Unlocked cherries cost 150 sun.")
	enemy = board.spawn_enemy("conehead_zombie", 2)
	enemy.global_position = board.lawn.cell_to_world(2, 6)
	enemy.set_physics_process(false)
	_check(enemy.health == 640 and enemy.get_node("Visuals/Head/Cone").visible, "Adventure coneheads must show the cone and retain 270+370 HP.")
	await _step(80)
	_check(board.kills == 1 and not board._occupied.has(Vector2i(5, 2)), "A planted cherry must explode after its fuse and free its cell.")
	await _step(65)
	_check(board.live_enemies().is_empty() and board.live_plants().is_empty(), "Adventure actors must never auto-respawn after death or consumption.")
	board.cooldowns.clear()
	board.sun_value = 100
	board.plant_at("peashooter", Vector2i(2, 2))
	var plant := board._occupied[Vector2i(2, 2)] as AdventurePlant
	plant.set_physics_process(false)
	enemy = board.spawn_enemy("zombie", 2)
	enemy.global_position = plant.global_position + Vector3.RIGHT * 0.7
	await _step(185)
	_check(not board._occupied.has(Vector2i(2, 2)), "Ordinary zombies must eat a 300-HP plant at 100 HP per second.")
	# Rewards are sequential, including shovel after 1-4 and persistent progress.
	progress.completed_level = 0
	for number in range(1, 5):
		_app.start_level(number)
		board = _app.content as AdventureBoard
		board._finish(true)
		_check(progress.completed_level == number, "Victory must award progress in order.")
	_check(progress.unlocked_level() == 50 and progress.recommended_level() == 5, "Sequential wins must update the recommendation while all fifty levels remain open.")
	var save_path := "user://adventure_test_progress.json"
	_check(progress.save_progress(save_path) == OK, "Completed progress must be saveable.")
	progress.completed_level = 3
	_check(progress.save_progress(save_path) == OK, "Saving a later run must safely replace an existing progress file.")
	progress.completed_level = 0
	progress.load_progress(save_path)
	_check(progress.completed_level == 3, "An existing save must contain the updated progress.")
	progress.completed_level = 4
	progress.save_progress(save_path)
	progress.completed_level = 0
	progress.load_progress(save_path)
	_check(progress.completed_level == 4, "Progress must restore after loading the saved file.")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string('{"version":1,"completed_level":99}')
	file.close()
	progress.load_progress(save_path)
	_check(progress.completed_level == 0, "Invalid saved progress must fall back to a new adventure.")
	progress.complete(50)
	progress.complete(27)
	progress.complete(50)
	progress.complete(0)
	progress.complete(51)
	progress.save_progress(save_path)
	progress.completed_level = 0
	progress.load_progress(save_path)
	_check(progress.completed_level == 0 and progress.completed_count() == 2 and progress.has_completed(27) and progress.has_completed(50) and not progress.has_completed(49), "Individual wins must round-trip without duplicates, invalid levels or false preceding victories.")
	_app.show_levels(5)
	await _step(2)
	var cleared := _app._canvas.find_children("Level50Button", "Button", true, false)[0] as Button
	var uncleared := _app._canvas.find_children("Level49Button", "Button", true, false)[0] as Button
	_check(cleared.text.contains("已通关") and uncleared.text.contains("可以挑战"), "Jumping to the boss must not mark 5-9 cleared in the UI.")
	_app.show_main_menu()
	await _step(2)
	var status_labels := _app._canvas.find_children("*", "Label", true, false)
	_check(status_labels.any(func(label: Label) -> bool: return label.text.contains("已通关 2 / 50")) and not status_labels.any(func(label: Label) -> bool: return label.text.contains("冒险五十关已完成")), "A boss-first save must show the actual two victories rather than a completed campaign.")
	file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string('{"version":1,"completed_level":20}')
	file.close()
	progress.load_progress(save_path)
	_check(progress.completed_count() == 20 and progress.has_completed(20) and not progress.has_completed(21) and progress.can_play(50), "An old prefix save must migrate its actual clears while enabling every level.")
	file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string('{"version":1,"completed_level":0,"completed_levels":[50,51]}')
	file.close()
	progress.load_progress(save_path)
	_check(progress.completed_count() == 0 and progress.can_play(50), "Invalid individual completion data must reset records without locking valid levels.")
	_app.start_level(41)
	board = _app.content as AdventureBoard
	_check(board.can_use_shovel() and board._hand.shovel.visible, "Entering a later level directly must provide its shovel without requiring tutorial completion.")
	board.plant_at("sunflower", Vector2i(0, 2))
	_check(board.shovel_at(Vector2i(0, 2)) and board.world_rules.bases.has(Vector2i(0, 2)), "The fresh-save roof shovel must remove the top plant while preserving its pot.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	progress.completed_level = 4
	_app.start_level(4)
	board = _app.content as AdventureBoard
	board.plant_at("wall_nut", Vector2i(0, 2))
	_check(board.shovel_at(Vector2i(0, 2)) and board.sun_value == 0, "The awarded shovel removes a plant without refunding sun.")
	var old_board_id := board.get_instance_id()
	await _key(KEY_F1)
	_check(_app.current_mode == "menu" and not is_instance_id_valid(old_board_id), "F1 must release the outgoing gameplay and return to the main menu.")
	await _step(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	var demo_button := _app._canvas.find_children("DemoButton", "Button", true, false)[0] as Button
	await _click(demo_button.get_global_rect().get_center())
	await process_frame
	await process_frame
	_check(_app.current_mode == "demo" and _app.content is StageSwitcher, "The demo menu entry must retain the existing five-stage showcase.")
	await _key(KEY_4)
	_check((_app.content as StageSwitcher).current_stage == 4, "Numeric switching must still work inside demo mode.")
	await _key(KEY_F1)
	_check(_app.current_mode == "menu" and get_nodes_in_group("stage_plants").is_empty(), "Returning from a demo must remove its old actors.")
	_app.queue_free()
	await process_frame
	print("Adventure integration: ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
