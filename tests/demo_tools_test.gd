extends SceneTree
## Actual wheel/right-click input, ray occlusion, combat removal and reset.

var _failed: bool = false
var _app: GameApplication


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if not value:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for frame in frames:
		await physics_frame


func _mouse(button: MouseButton, at: Vector2, control: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = true
	event.ctrl_pressed = control
	root.push_input(event, true)
	await _step(2)
	event = InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.ctrl_pressed = control
	root.push_input(event, true)
	await _step(2)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step(3)


func _aim(dave: CrazyDave, at: Vector3, distance: float = 2.4) -> void:
	dave.global_position = at + Vector3.LEFT * distance
	dave.rotation.y = -PI * 0.5
	dave.waist_mount.rotation = Vector3.ZERO
	dave.camera.rotation = Vector3.ZERO
	dave.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _quiet(demo: StageDemo) -> void:
	demo._dave.set_physics_process(false)
	demo._sun_system._timer.stop()
	for actor: Node in demo.get_node("Plants").get_children() + demo.get_node("Enemies").get_children():
		actor.set_physics_process(false)


func _run() -> void:
	var config := GameConfiguration.current()
	config.emit_warnings = false
	config.use_values_for_tests({"demo_tools": {"shovel_reach": 0}})
	_check(config.section("demo_tools").shovel_reach == 4.8, "Zero reach must fall back to a usable positive value.")
	config.use_values_for_tests(config.default_values())
	AdventureProgress.current().memory_only = true
	_app = load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(_app)
	_app.show_demo()
	var switcher := _app.content as StageSwitcher
	var center := root.get_visible_rect().get_center()
	for number in range(1, 6):
		switcher.switch_stage(number)
		await _step(2)
		var demo := switcher.current_demo as StageDemo
		_quiet(demo)
		var tools := demo._tools
		var name: String = demo._plant_slots[0].name
		var plant := demo.get_node("Plants/" + name) as StagePlant
		var position := plant.global_position
		_aim(demo._dave, position)
		await _step(2)
		_check(tools.selected_tool() == "empty", "Each new showcase must start empty-handed.")
		await _mouse(MOUSE_BUTTON_RIGHT, center)
		_check(plant.is_inside_tree(), "Empty-handed right-click must leave the plant intact.")
		await _mouse(MOUSE_BUTTON_WHEEL_UP, center)
		_check(tools.selected_tool() == "shovel" and tools._hand.visible, "Wheel must equip a visible first-person shovel.")
		_check(tools.target_at_screen(center) == plant, "Crosshair ray must select the nearby plant in each terrain.")
		if number == 1:
			# A solid object between the player and plant must prevent digging.
			var blocker := StaticBody3D.new()
			blocker.collision_layer = 1
			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			blocker.add_child(shape)
			demo.add_child(blocker)
			blocker.global_position = position + Vector3(-1.2, 0.85, 0)
			await _step(2)
			await _mouse(MOUSE_BUTTON_RIGHT, center)
			_check(plant.is_inside_tree(), "Shovel must not remove plants through a wall.")
			blocker.queue_free()
			await _step(2)
			_aim(demo._dave, position, 8.0)
			await _step(2)
			await _mouse(MOUSE_BUTTON_RIGHT, center)
			_check(plant.is_inside_tree(), "First-person digging must respect reach.")
			_aim(demo._dave, position)
			await _key(KEY_TAB)
			await _mouse(MOUSE_BUTTON_WHEEL_DOWN, center)
			await _mouse(MOUSE_BUTTON_RIGHT, center)
			_check(tools.selected_tool() == "shovel" and plant.is_inside_tree(), "Open sidebar must block tool input.")
			await _key(KEY_TAB)
			# Sun keeps its existing left-click behavior while holding the shovel.
			var sun := load("res://scenes/pickups/sun.tscn").instantiate() as SunPickup
			demo.get_node("SunSystem").add_child(sun)
			sun.global_position = position + Vector3(-1.3, 0.94, 0)
			sun.set_physics_process(false)
			sun.collected.connect(demo._sun_system._on_collected)
			var before := demo._sun_system.sun_value
			await _step(2)
			await _mouse(MOUSE_BUTTON_LEFT, center)
			_check(demo._sun_system.sun_value == before + 50 and plant.is_inside_tree(), "Shovel must preserve left-click sun collection.")
			await _key(KEY_ESCAPE)
			var cursor_at := demo._dave.camera.unproject_position(plant.global_position + Vector3.UP * 0.8)
			await _mouse(MOUSE_BUTTON_RIGHT, cursor_at)
		else:
			await _mouse(MOUSE_BUTTON_RIGHT, center)
		_check(not is_instance_valid(plant) and not demo.get_node("Plants").has_node(name), "Right-click must remove the selected plant and collider.")
		await _step(510)
		_check(not demo.get_node("Plants").has_node(name), "Manually removed plants must remain absent past the 8-second respawn delay.")
		await _key(KEY_R)
		_quiet(demo)
		_check(demo.get_node("Plants").has_node(name) and tools.selected_tool() == "empty", "R must restore the roster and reset the held tool.")
		await _key(KEY_M)
		var previous_size: float = demo._orbit.camera.size
		await _mouse(MOUSE_BUTTON_WHEEL_DOWN, center)
		_check(tools.selected_tool() == "shovel" and is_equal_approx(previous_size, demo._orbit.camera.size) and not tools._hand.visible, "Overview wheel must switch tools without zoom or camera-attached models.")
		await _mouse(MOUSE_BUTTON_WHEEL_UP, center, true)
		_check(demo._orbit.camera.size < previous_size and tools.selected_tool() == "shovel", "Ctrl+wheel must zoom without switching tools.")
		plant = demo.get_node("Plants/" + name) as StagePlant
		var at: Vector2 = demo._orbit.camera.unproject_position(plant.global_position + Vector3.UP * 0.8)
		await _mouse(MOUSE_BUTTON_RIGHT, at)
		_check(not is_instance_valid(plant), "Overview cursor right-click must remove its target.")
	var old_tools := (switcher.current_demo as StageDemo)._tools
	await _key(KEY_0)
	_check(not is_instance_valid(old_tools), "Switching to the original demo must release old tool UI and references.")
	var legacy := switcher.current_demo
	legacy._dave.set_physics_process(false)
	legacy._sun_system._timer.stop()
	legacy.auto_respawn_enabled = false
	for enemy: Node in legacy.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
	var shooter := legacy._plant as Peashooter
	_aim(legacy._dave, shooter.global_position)
	await _step(2)
	await _mouse(MOUSE_BUTTON_WHEEL_DOWN, center)
	_check(legacy._tools.selected_tool() == "shovel", "Reverse wheel must equip the shovel in the original demo.")
	var shots := [0]
	shooter.shot_fired.connect(func(_pea: PeaProjectile) -> void: shots[0] += 1)
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	_check(not shooter.visible and not shooter.is_in_group("vaultable_plants"), "Original demo digging must remove the visual and vault target.")
	await _step(180)
	_check(shots[0] == 0 and not shooter.can_process(), "Removed original shooter must stop all future firing.")
	await _key(KEY_R)
	_check(shooter.visible and shooter.is_physics_processing() and shooter.is_in_group("vaultable_plants"), "R must restore the original shooter and combat participation.")
	await _step(2)
	_check(not shooter.get_node("ToolTarget/CollisionShape3D").disabled, "R must restore picking collision.")
	await _mouse(MOUSE_BUTTON_WHEEL_UP, center)
	_aim(legacy._dave, legacy._wallnut.global_position)
	await _step(2)
	await _mouse(MOUSE_BUTTON_RIGHT, center)
	_check(not legacy._wallnut.visible and not legacy._wallnut.is_in_group("vaultable_plants"), "Removing a legacy wall-nut must remove the defense and vault target.")
	for shape: CollisionShape3D in legacy._wallnut.find_children("*", "CollisionShape3D", true, false):
		_check(shape.disabled, "Removed wall-nut must not keep its movement collider.")
	await _key(KEY_R)
	for shape: CollisionShape3D in legacy._wallnut.find_children("*", "CollisionShape3D", true, false):
		_check(not shape.disabled, "R must restore all wall-nut colliders.")
	await _key(KEY_F1)
	_check(_app.current_mode == "menu" and root.find_children("DemoTools", "DemoTools", true, false).is_empty(), "F1 must release all demo tool controllers.")
	_app.start_level(1, true)
	await _step(2)
	_check(not _app.content.has_node("DemoTools"), "Adventure planting controls must remain independent of demo tools.")
	_app.queue_free()
	await _step(3)
	if not _failed:
		print("Demo tools integration: PASSED")
	quit(1 if _failed else 0)
