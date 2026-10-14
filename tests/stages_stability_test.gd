extends SceneTree
## Ninety seconds of actual automatic combat per stage, then reset and switch.

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	seed(20261013)
	var switcher := load("res://scenes/adventure.tscn").instantiate() as StageSwitcher
	root.add_child(switcher)
	for number in range(1, 6):
		switcher.switch_stage(number)
		var demo := switcher.current_demo as StageDemo
		for frame in 5400:
			await physics_frame
			if frame % 600 == 0:
				_check(demo.live_enemies().size() <= 32, "Summons must remain bounded in prolonged combat.")
				_check(demo.projectiles.get_child_count() < 150, "Expired projectiles must be cleaned up.")
				for enemy: StageZombie in demo.live_enemies():
					_check(enemy.health == enemy.body_health + enemy.helmet_health + enemy.shield_health and enemy.health <= enemy.maximum_health, "Independent damage layers must keep a valid total.")
		demo.reset_stage()
		_check(demo._pending.is_empty() and demo.projectiles.get_child_count() == 0 and demo.get_node("Debris").get_child_count() == 0, "Reset after prolonged combat must clear pending refreshes, shots and corpses.")
		_check(demo.live_plants().size() == [9, 17, 25, 33, 40][number - 1], "Reset must restore every cumulative plant.")
		print("Stage %d: 90-second simulation and reset completed." % number)
	switcher.queue_free()
	await process_frame
	print("Stages stability: ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
