extends SceneTree
## Lifecycle checks in the real scene, including complete automatic fights.
## godot --headless --path . --fixed-fps 60 --script res://tests/respawn_test.gd

var _failed: bool = false
var _main: Node3D
var _plant: Peashooter
var _lawn: LawnGrid
var _respawn_frames: Array[int] = []
var _death_frames: Array[int] = []
var _spawn_ids: Array[int] = []
var _shots: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for i in range(frames):
		await physics_frame


func _on_defeated() -> void:
	_death_frames.append(Engine.get_physics_frames())


func _on_shot(_pea: PeaProjectile) -> void:
	_shots += 1


func _on_respawn(zombie: Zombie) -> void:
	_respawn_frames.append(Engine.get_physics_frames())
	_spawn_ids.append(zombie.get_instance_id())
	zombie.defeated.connect(_on_defeated)
	_check(zombie.health == 200 and zombie.visible, "Respawn did not create a visible, full-health zombie.")
	_check(zombie.global_position.distance_to(_lawn.cell_to_world(2, 8)) < 0.001, "New zombie did not spawn at the far baseline in the original lane.")
	_check((-zombie.global_basis.z).dot(Vector3.LEFT) > 0.999, "New zombie did not face the plant.")
	_check(is_zero_approx(zombie.get_node("Visuals").rotation.x), "New zombie inherited the previous zombie's recoil.")
	_check(not zombie.get_node("CollisionShape3D").disabled, "New zombie's collision was disabled.")
	for mesh: MeshInstance3D in zombie.get_node("Visuals").find_children("*", "MeshInstance3D", true, false):
		_check(mesh.material_override != Zombie.HIT_MATERIAL, "New zombie inherited the death flash.")
	_check(_main.get_node("Enemies").get_child_count() == 4, "Respawn left a duplicate enemy in the scene.")
	_check(_main._health_bar.value == 200, "Respawn did not update the health bar.")
	_check(_main._combat_status.text.contains("伤害 20"), "Respawn did not restore the combat status.")
	if not _death_frames.is_empty():
		var elapsed := float(_respawn_frames[-1] - _death_frames[-1]) / Engine.physics_ticks_per_second
		_check(absf(elapsed - 1.0) <= 0.035, "Respawn did not occur 1 second after health reached zero: %.3f seconds." % elapsed)


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	GameConfiguration.current().apply_entity(_main)
	root.add_child(_main)
	_main._pole_zombie.movement_enabled = false
	_main._pole_zombie.is_ground_zombie = false
	_main._pole_zombie.set_spawn(_main._lawn.cell_to_world(4, 8) + Vector3(3, 0, 0), PI / 2.0)
	_plant = _main.get_node("Plants/Peashooter") as Peashooter
	_lawn = _main.get_node("LawnGrid") as LawnGrid
	# This suite checks the normal-zombie slot independently of the conehead slot.
	_main._repeater.combat_enabled = false
	_main._threepeater.combat_enabled = false
	_main._gatling.combat_enabled = false
	_main._snowpea.combat_enabled = false
	_main._bucket_zombie.is_ground_zombie = false
	_main._bucket_zombie.movement_enabled = false
	_main._bucket_zombie.set_spawn(_lawn.cell_to_world(0, 8) + Vector3(3, 0, 0), PI / 2.0)
	_main._cone_zombie.movement_enabled = false
	_main.zombie_respawned.connect(_on_respawn)
	_plant.shot_fired.connect(_on_shot)
	var zombie: Zombie = _main._zombie
	zombie.defeated.connect(_on_defeated)
	_plant.combat_enabled = false
	zombie.movement_enabled = false
	await _step(3)

	# The timer starts on death, while the final 0.5-second flash is preserved.
	var old_id := zombie.get_instance_id()
	zombie.take_damage(200, Vector3.RIGHT)
	var corpse: ZombieDebris = zombie._spawned_debris[-1]
	_check(_main._combat_status.text.contains("秒后刷新"), "Death did not announce the pending respawn.")
	_check(absf(_main._respawn_timer.time_left - 1.0) < 0.001, "Death did not start a 1-second respawn timer.")
	await _step(29)
	_check(corpse.visible and _respawn_frames.is_empty(), "Respawn interrupted the physical corpse's final hit effect.")
	await _step(7)
	_check(not zombie.visible and corpse.visible and _respawn_frames.is_empty(), "The physical corpse did not remain while waiting for respawn.")
	await _step(22)
	_check(_respawn_frames.is_empty(), "The replacement spawned before the 1-second delay.")
	await _step(5)
	_check(_respawn_frames.size() == 1, "Expected exactly one replacement after 1 second.")
	_check(not is_instance_valid(zombie), "The old zombie instance was not freed.")
	zombie = _main._zombie
	_check(zombie.get_instance_id() != old_id, "Respawn reused the dead instance instead of creating a new zombie.")
	_check(get_nodes_in_group("zombies").size() == 4, "A freed zombie remained in the detection group.")
	_check(is_instance_valid(corpse) and corpse.visible, "Respawn prematurely removed the old physical corpse.")

	# Movement, target detection and actual projectile damage resume automatically.
	zombie.movement_enabled = true
	var start_x := zombie.global_position.x
	_plant.combat_enabled = true
	await _step(60)
	_check(absf(start_x - zombie.global_position.x - 0.5) < 0.025, "Replacement did not walk at 0.5 units/second.")
	await _step(150)
	_check(_shots >= 2 and zombie.health < 200, "The plant did not fire at and damage the replacement.")
	_check(_main.get_node("Characters/CrazyDave").camera.is_current(), "Respawn changed Dave's waist camera.")

	# Model inspection follows the new instance, including subsequent respawns.
	_plant.combat_enabled = false
	_main._toggle_zombie_view()
	zombie.take_damage(200, Vector3.RIGHT)
	await _step(65)
	_check(_respawn_frames.size() == 2, "Subsequent death did not schedule another replacement.")
	zombie = _main._zombie
	_check(_main._orbit.target.distance_to(zombie.global_position + Vector3(0, 0.78, 0)) < 0.02, "Inspection camera did not follow the replacement.")
	_main._set_model_view(false)

	# Restart during the delay cancels it; an old timeout must not add an enemy.
	zombie.take_damage(200, Vector3.RIGHT)
	await _step(30)
	_main._reset_view()
	_check(_main._respawn_timer.is_stopped(), "Restart did not cancel the pending respawn timer.")
	await _step(90)
	_check(_respawn_frames.size() == 2 and is_instance_valid(zombie) and zombie.health == 200, "A pending respawn survived restart.")
	_check(_main.get_node("Enemies").get_child_count() == 4, "Restart created duplicate zombies.")

	# Full automatic combat must keep cycling without manual death or restart.
	_main._reset_view()
	_plant.combat_enabled = true
	var expected_respawns := _respawn_frames.size() + 2
	await _step(2400)
	_check(_respawn_frames.size() >= expected_respawns, "Automatic combat did not complete two death/respawn cycles.")
	_check(_main.get_node("Enemies").get_child_count() == 4, "Repeated automatic fights accumulated old enemies.")
	for i in range(1, _spawn_ids.size()):
		_check(_spawn_ids[i] != _spawn_ids[i - 1], "Consecutive respawns did not create distinct instances.")
	_check(_main.get_node("Characters/CrazyDave").camera.is_current(), "Repeated fights changed the player camera.")
	if not _failed:
		print("PASS: death-to-respawn delay 1s, final hit effect, fresh full-health baseline instance, old enemy cleanup, resumed movement/fire/damage, repeated respawns, inspection follow, restart cancellation and two complete automatic fight cycles.")
	quit(1 if _failed else 0)
