extends SceneTree
## Real Snow Pea impacts, ballistic vault, physical pole, death and independent respawn.

var _failed: bool = false
var _main: Node3D
var _lawn: LawnGrid
var _zombie: PoleVaultingZombie
var _parts: Array[ZombieDebris] = []
var _vaults: int = 0
var _landings: int = 0
var _natural: bool = false
var _cycle_hits: int = 0
var _respawns: Array[int] = [0, 0, 0, 0]


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for index in range(frames):
		await physics_frame


func _watch(zombie: PoleVaultingZombie) -> void:
	zombie.part_detached.connect(_on_part)
	zombie.vault_started.connect(func(): _vaults += 1)
	zombie.vault_landed.connect(func(): _landings += 1)
	zombie.damaged.connect(func(amount: int):
		if _natural:
			_check(amount == 20, "Natural pea combat dealt incorrect damage to the pole zombie.")
			_cycle_hits += 1)
	zombie.defeated.connect(func():
		if _natural:
			_check(_cycle_hits == 25, "A 500-HP pole zombie did not die after exactly 25 pea impacts."))


func _on_part(part: ZombieDebris) -> void:
	_parts.append(part)


func _part(kind: StringName) -> ZombieDebris:
	for part: ZombieDebris in _parts:
		if is_instance_valid(part) and part.part_kind == kind:
			return part
	return null


func _on_respawn(zombie: Zombie) -> void:
	var index := 3 if zombie is PoleVaultingZombie else (2 if zombie.has_bucket else (1 if zombie.has_cone else 0))
	_respawns[index] += 1
	if index != 3:
		return
	_zombie = zombie as PoleVaultingZombie
	_watch(_zombie)
	_check(_zombie.health == 500 and _zombie.has_pole and not _zombie.is_vaulting and _zombie._slow_remaining == 0.0, "Respawn failed to restore the pole zombie's type, health, pole or cold status.")
	_check(_zombie.global_position.distance_to(_lawn.cell_to_world(4, 8)) < 0.001, "Pole zombie respawned outside the Snow Pea baseline.")
	_check(_main.get_node("Enemies").get_child_count() == 4 and get_nodes_in_group("zombies").size() == 4, "Independent respawns duplicated enemies.")
	if _natural:
		_check(_cycle_hits == 25, "Respawn lost the final natural damage count.")
		_cycle_hits = 0


func _reset_at(position: Vector3) -> void:
	_main.auto_respawn_enabled = false
	for node: Node in _main.get_node("Plants").get_children():
		var plant := node as Peashooter
		if plant != null:
			plant.combat_enabled = false
	_main._reset_view()
	_zombie = _main._pole_zombie
	_zombie.movement_enabled = false
	_zombie.vault_enabled = true
	_zombie.set_spawn(position, PI / 2.0)
	await _step(3)
	_parts.clear()
	_vaults = 0
	_landings = 0


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	GameConfiguration.current().apply_entity(_main)
	_main.auto_respawn_enabled = false
	root.add_child(_main)
	_lawn = _main._lawn
	_zombie = _main._pole_zombie
	for other: Zombie in [_main._zombie, _main._cone_zombie, _main._bucket_zombie]:
		other.movement_enabled = false
	_watch(_zombie)
	_main.zombie_respawned.connect(_on_respawn)
	_check(_lawn.world_to_cell(_zombie.global_position) == Vector2i(8, 4) and _lawn.world_to_cell(_main._snowpea.global_position) == Vector2i(1, 4), "Pole zombie was not placed at the far end of Snow Pea's lane.")
	_check(_zombie.maximum_health == 500 and _zombie.health == 500 and _zombie.walk_speed == 0.5, "Pole zombie defaults differ from 500 HP and 0.5 walking speed.")
	_check((-_zombie.global_basis.z).dot(Vector3.LEFT) > 0.999 and _zombie.has_node("Visuals/Head/Headband/Band") and _zombie.has_node("Visuals/Pole/Shaft"), "The athlete lacks its headband, pole or correct facing.")
	_check(_zombie.get_node("CollisionShape3D").shape.height == _main._zombie.get_node("CollisionShape3D").shape.height, "The pole zombie is not the existing zombie's height.")
	_check(_main._pole_health_bar.value == 500 and _main._pole_health_label.text.contains("500"), "Pole zombie health is absent from the UI.")
	_check(_main.get_node("Plants").get_child_count() == 6 and _lawn.get_node("Tiles").get_child_count() == 45, "Adding the pole zombie changed plants or terrain.")
	var nut := _main._wallnut as WallNut
	_check(_lawn.world_to_cell(nut.global_position) == Vector2i(7, 4) and nut.get_parent() == _main._snowpea.get_parent(), "The independent wall-nut is not in Snow Pea's eighth cell.")
	var shaft_axis := _zombie._pole.global_basis.y.normalized()
	_check(absf(shaft_axis.y) < 0.001 and absf(shaft_axis.dot(-_zombie.global_basis.z)) > 0.999 and _zombie._pole.global_position.y > 1.8, "The carrying pole is not horizontal above the head in the travel direction.")
	var raised := _zombie.get_node("Visuals/Arms/LeftHandAssembly") as Node3D
	var relaxed := _zombie.get_node("Visuals/Arms/RightHandAssembly") as Node3D
	_check(raised.to_global(Vector3(-0.35, 0.967, -0.587)).y > 1.8 and relaxed.to_global(Vector3(0.35, 1.013, -0.587)).y < 0.85, "The carry pose does not have one raised arm and one relaxed arm.")
	_check(_zombie.has_node("Visuals/Legs/LeftRunnerLeg/Shin") and _zombie.get_node("Visuals/Legs/LeftLeg").visible == false, "The runner does not use connected bent-leg geometry.")

	# From the actual ninth-cell spawn, the eighth-cell nut triggers one real vault.
	await _reset_at(_lawn.cell_to_world(4, 8))
	_zombie.movement_enabled = true
	var nut_vault_peak := _zombie.global_position.y
	var overlaps_nut := false
	for index in range(250):
		await _step(1)
		nut_vault_peak = maxf(nut_vault_peak, _zombie.global_position.y)
		if absf(_zombie.global_position.x - nut.global_position.x) < 0.45:
			overlaps_nut = true
			_check(_zombie.global_position.y > 1.4, "The real vaulter clipped the eighth-cell nut instead of clearing it.")
		if _landings > 0:
			break
	_check(_vaults == 1 and _landings == 1 and overlaps_nut and nut_vault_peak > 1.7 and _zombie.global_position.x < nut.global_position.x - 0.95, "The baseline vaulter did not automatically jump and land behind the nut.")
	_check(_part(&"pole") != null and _parts.size() == 1 and not _zombie.has_pole, "The nut vault did not release exactly one physical pole.")
	var released_pole := _part(&"pole")
	await _step(150)
	_check(released_pole.has_landed, "The released carrying pole did not contact the lawn or nut.")
	_check(nut.global_position.distance_to(_lawn.cell_to_world(4, 7)) < 0.001, "Vaulting moved or removed the independent wall-nut.")

	# Without a usable pole, its physical collider blocks the approaching zombie.
	await _reset_at(_lawn.cell_to_world(4, 8))
	_zombie.vault_enabled = false
	_zombie.movement_enabled = true
	await _step(300)
	_check(_vaults == 0 and _zombie.global_position.x > nut.global_position.x + 0.55, "A disabled vaulter walked through the wall-nut collider.")

	# Friendly peas cross the nut's collider and still damage a grounded baseline enemy.
	await _reset_at(_lawn.cell_to_world(4, 8))
	_zombie.vault_enabled = false
	_main._snowpea.combat_enabled = true
	await _step(190)
	_main._snowpea.combat_enabled = false
	_check(_zombie.health == 480 and _zombie._slow_multiplier == 0.5 and nut.is_visible_in_tree(), "The eighth-cell nut blocked the friendly snow pea or lost its model.")

	# The newly populated fifth lane receives real cold damage and walking slowdown.
	await _reset_at(_lawn.cell_to_world(4, 5))
	_main._snowpea.combat_enabled = true
	await _step(150)
	_main._snowpea.combat_enabled = false
	_check(_zombie.health == 480 and _zombie._slow_multiplier == 0.5 and _zombie._slow_remaining > 8.0, "A real Snow Pea did not deal 20 damage and freeze the new enemy.")
	await _step(40)
	_zombie.movement_enabled = true
	_zombie.vault_enabled = false
	var start_x := _zombie.global_position.x
	await _step(60)
	_check(absf(start_x - _zombie.global_position.x - 0.25) < 0.025, "The pole zombie did not walk at 0.25 under cold.")
	_check(_zombie.get_node("Visuals/Pole/Shaft").material_override != _zombie._materials[_zombie.get_node("Visuals/Pole/Shaft")], "The pole was omitted from cold tinting.")

	# A neighboring plant cannot trigger a vault; only the first plant in this lane can.
	await _reset_at(_lawn.cell_to_world(3, 1) + Vector3(1.15, 0, 1.0))
	_zombie.movement_enabled = true
	await _step(40)
	_check(_vaults == 0 and _zombie.has_pole, "The pole zombie vaulted a neighboring lane.")
	var plant_position: Vector3 = _main._snowpea.global_position
	await _reset_at(plant_position + Vector3(1.15, 0, 0))
	_zombie.apply_slow(0.5, 10.0)
	_zombie.movement_enabled = true
	await _step(20)
	_check(_vaults == 1 and _zombie.is_vaulting and not _zombie.is_on_floor(), "The pole zombie did not begin its one ballistic vault.")
	_check(not _main._snowpea._has_ground_target(), "Snow Pea acquired the airborne vaulter as a ground target.")
	for side: String in ["Left", "Right"]:
		var sign_value := -1.0 if side == "Left" else 1.0
		var assembly := _zombie.get_node("Visuals/Arms/" + side + "HandAssembly") as Node3D
		var hand_position := assembly.to_global(Vector3(sign_value * 0.35, 0.99 + sign_value * 0.023, -0.587))
		var grip := _zombie._pole.to_local(hand_position)
		_check(absf(grip.x) < 0.01 and absf(grip.z) < 0.01, "A vaulting hand lost its grip on the pole.")
		_check((assembly.get_node(side + "Forearm").mesh as CapsuleMesh).height * assembly.get_node(side + "Forearm").scale.y < 0.6, "The vault stretched the athlete's forearm beyond reach.")
	var peak_y := _zombie.global_position.y
	for index in range(100):
		await _step(1)
		peak_y = maxf(peak_y, _zombie.global_position.y)
		if _landings > 0:
			break
	_check(_landings == 1 and _zombie.is_on_floor() and not _zombie.is_vaulting and not _zombie.has_pole, "The vaulter did not land and release its pole.")
	_check(peak_y > plant_position.y + 1.70 and absf(_zombie.global_position.x - (plant_position.x - 1.1)) < 0.12 and absf(_zombie.global_position.z - plant_position.z) < 0.001, "The vault did not clear the plant on a level-lane ballistic arc.")
	var pole := _part(&"pole")
	_check(pole != null and not _zombie.get_node("Visuals/Pole").visible and pole.lifetime == 10.0, "The spent pole was not detached once with a 10-second lifetime.")
	if pole != null:
		_check(pole is RigidBody3D and pole.gravity_scale == 1.0 and pole.get_parent() == _main._debris, "The released pole does not have independent physical gravity.")
	var saved_plant_position: Vector3 = _main._plant.global_position
	_main._plant.global_position = plant_position + Vector3(-2.4, 0, 0)
	# Let cold expire, then walk past a second plant without obtaining another pole.
	await _step(600)
	_main._plant.global_position = saved_plant_position
	_check(_vaults == 1 and not _zombie.has_pole, "The same zombie vaulted twice.")
	_check(not is_instance_valid(pole), "The spent pole survived its 10-second lifetime.")

	# R cancels preparation and an active flight immediately, including deferred debris.
	await _reset_at(plant_position + Vector3(1.15, 0, 0))
	_zombie.movement_enabled = true
	await _step(3)
	_check(_zombie._preparing, "Vault preparation was skipped.")
	_main._reset_view()
	_zombie.movement_enabled = false
	await _step(1)
	_check(_zombie.has_pole and not _zombie._preparing and not _zombie.is_vaulting and _main._debris.get_child_count() == 0, "Restart did not cancel planted-pole preparation.")
	await _reset_at(plant_position + Vector3(1.15, 0, 0))
	_zombie.movement_enabled = true
	await _step(42)
	_check(_zombie.is_vaulting, "The active-flight reset fixture did not launch.")
	_main._reset_view()
	_zombie.movement_enabled = false
	await _step(1)
	_check(_zombie.has_pole and not _zombie.is_vaulting and _zombie.velocity.length() < 0.02 and _main._debris.get_child_count() == 0, "Restart left a running vault, momentum or deferred pole.")

	# Shared 100-HP hand loss releases the pole once; lethal midair damage ends the vault.
	await _reset_at(_lawn.cell_to_world(4, 5))
	_zombie.take_damage(399, Vector3.RIGHT)
	_check(_zombie.health == 101 and _zombie.has_pole and _parts.is_empty(), "The pole or hand detached above the shared 100-HP threshold.")
	_zombie.take_damage(1, Vector3.RIGHT)
	_check(not _zombie.has_pole and _parts.size() == 2 and _part(&"pole") != null and (_part(&"left_hand") != null or _part(&"right_hand") != null), "Exactly one pole and one random hand did not drop at 100 HP.")
	_zombie.take_damage(1, Vector3.RIGHT)
	_check(_parts.size() == 2, "The pole detached more than once.")
	await _reset_at(plant_position + Vector3(1.15, 0, 0))
	_zombie.movement_enabled = true
	await _step(37)
	_zombie.apply_slow(0.5, 10.0)
	_main._toggle_pole_view()
	_main.auto_respawn_enabled = true
	_respawns.assign([0, 0, 0, 0])
	var previous := _zombie
	_zombie.take_damage(9999, Vector3.RIGHT)
	_check(not _zombie.is_vaulting and _zombie._slow_remaining == 0.0 and _parts.size() == 4, "Midair death did not cancel the vault and create one pole, hand, head and corpse.")
	_check(absf(_main._pole_respawn_timer.time_left - 1.0) < 0.001 and _main._pole_status.text.contains("刷新"), "Pole zombie death did not begin a 1-second respawn timer.")
	var corpse := _part(&"corpse")
	var head := _part(&"head")
	await _step(58)
	_check(_respawns[3] == 0, "The pole zombie respawned before 1 second.")
	await _step(5)
	_check(_respawns[3] == 1 and not is_instance_valid(previous) and is_instance_valid(corpse) and is_instance_valid(head), "Pole zombie replacement removed old remains or retained the dead instance.")
	_zombie.movement_enabled = false
	_check(_main._orbit.target.distance_to(_zombie.global_position + Vector3(0, 0.78, 0)) < 0.03, "Pole inspection did not follow the replacement.")
	_main._toggle_cone_view()
	_check(not _main._inspect_pole and _main._selected_enemy() == _main._cone_zombie, "Switching from pole to cone inspection kept the wrong target.")
	await _step(240)
	_check(not is_instance_valid(corpse) and is_instance_valid(head), "Pole zombie remains lost their separate 5/10-second lifetimes.")
	await _step(310)
	_check(not is_instance_valid(head) and _main._debris.get_child_count() == 0, "Pole zombie parts survived 10 seconds.")
	_zombie.take_damage(500, Vector3.RIGHT)
	_main._reset_view()
	await _step(80)
	_check(_respawns[3] == 1 and _main._pole_respawn_timer.is_stopped() and _zombie.has_pole and _main._debris.get_child_count() == 0, "Restart failed to cancel pending pole respawn and deferred remains.")
	_main._toggle_pole_view()
	_main._toggle_pole_view()
	_check(_main._dave.camera.is_current(), "Pole model view did not return to Dave's waist camera.")

	# All five plants and four enemy types fight naturally without accumulating entities.
	await _reset_at(_lawn.cell_to_world(4, 8))
	for other: Zombie in [_main._zombie, _main._cone_zombie, _main._bucket_zombie, _zombie]:
		other.movement_enabled = true
	_main.auto_respawn_enabled = true
	_respawns.assign([0, 0, 0, 0])
	_cycle_hits = 0
	_natural = true
	for node: Node in _main.get_node("Plants").get_children():
		var plant := node as Peashooter
		if plant != null:
			plant.combat_enabled = true
	await _step(5400)
	_check(_respawns[0] >= 6 and _respawns[1] >= 3 and _respawns[2] >= 2 and _respawns[3] >= 3 and _vaults >= 1 and _landings >= 1, "Four-lane natural combat did not independently refresh enemies and include a completed nut vault.")
	_check(_main.get_node("Enemies").get_child_count() == 4 and _main._projectiles.get_child_count() < 35 and _main._debris.get_child_count() < 40, "Long combat accumulated enemies, projectiles or expired parts.")
	_natural = false
	_main._reset_view()
	await _step(3)
	_check(_main._debris.get_child_count() == 0 and _main._projectiles.get_child_count() == 0 and _main._pole_respawn_timer.is_stopped(), "Restart failed after sustained four-lane combat.")
	if not _failed:
		print("PASS: overhead single-hand runner pose, independent eighth-cell wall-nut, automatic baseline vault with real obstacle clearance, one physical pole drop and 10s cleanup, friendly pea passage, actual cold damage/slow, hand/head/body death, 1s respawn and reset, plus 90s of five shooters and one nut fighting four enemy types with completed vaults and 25 impacts per pole zombie.")
	quit(1 if _failed else 0)
