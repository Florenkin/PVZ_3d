class_name StagePlant
extends Node3D
## Fixed, cumulative exhibits with autonomous demonstration combat.

signal defeated
signal shot_fired(projectile: StageProjectile)

@export var plant_kind: String = "peashooter"
var stage: Node3D
var display_only: bool = false
var sleeping: bool = false
var health: int = 300
var maximum_health: int = 300
var settings: Dictionary
var _visuals: Node3D
var _label: Label3D
var _timer: float = 1.5
var _age: float = 0.0
var _production_timer: float = 6.0
var _burst: Array[Dictionary] = []
var _recoil: float = 0.0
var _spent: bool = false
var _awakened: bool = false
var _digestion_remaining: float = 0.0

const SHOOTERS: Array[String] = ["peashooter", "snow_pea", "repeater", "puff_shroom", "fume_shroom", "scaredy_shroom", "threepeater", "sea_shroom", "cactus", "split_pea", "starfruit", "cabbage_pult", "kernel_pult", "melon_pult"]
const INSTANTS: Array[String] = ["cherry_bomb", "potato_mine", "squash", "jalapeno", "ice_shroom", "doom_shroom", "blover", "tangle_kelp"]


func _ready() -> void:
	settings = GameConfiguration.current().section("stages.plants." + plant_kind)
	maximum_health = int(settings.maximum_health)
	health = maximum_health
	_timer = 1.5 if plant_kind == "chomper" else float(settings.attack_interval)
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	StageModels.plant(_visuals, plant_kind)
	add_to_group("stage_plants")
	add_to_group("vaultable_plants")
	var body := StaticBody3D.new()
	body.name = "PlantBody"
	body.collision_layer = 32
	body.collision_mask = 16
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.40
	shape.height = 1.45 if plant_kind != "tall_nut" else 2.45
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	body.add_child(collision)
	add_child(body)
	_label = StageModels.label(self, "", Vector3(0, 2.05 if plant_kind != "tall_nut" else 2.8, 0), Color("fff4cf"))
	_update_label()
	if sleeping:
		StageModels.label(self, "Z z z", Vector3(0, 1.5, 0), Color("a9c5ef")).name = "SleepLabel"


func is_alive() -> bool:
	return health > 0 and not _spent and not is_queued_for_deletion()


func wake_up() -> void:
	sleeping = false
	_awakened = true
	var sleep_label := get_node_or_null("SleepLabel")
	if sleep_label != null:
		sleep_label.queue_free()
	_update_label()


func take_damage(amount: int) -> void:
	if not is_alive() or display_only:
		return
	health = maxi(0, health - amount)
	_update_label()
	if health <= 0:
		_consume()


func _consume() -> void:
	if _spent:
		return
	_spent = true
	health = 0
	hide()
	get_node("PlantBody/CollisionShape3D").set_deferred("disabled", true)
	defeated.emit()


func _update_label() -> void:
	if not is_instance_valid(_label):
		return
	var suffix := " · 展示池" if display_only else (" · 睡眠" if sleeping else "")
	_label.text = "%s%s\n%d 阳光  ·  %d/%d HP" % [StageCatalog.plant_name(plant_kind), suffix, int(settings.sun_cost), health, maximum_health]


func _process(delta: float) -> void:
	_age += delta
	_recoil = move_toward(_recoil, 0.0, delta * 1.1)
	if is_alive() and not sleeping and stage.idle_enabled:
		_visuals.rotation.z = sin(_age * 1.4) * 0.025 + _recoil


func _physics_process(delta: float) -> void:
	if not is_alive() or sleeping or display_only or not is_instance_valid(stage):
		return
	if _digestion_remaining > 0.0:
		_digestion_remaining = maxf(0.0, _digestion_remaining - delta)
		return
	for item: Dictionary in _burst:
		item.delay -= delta
		if item.delay <= 0.0 and is_instance_valid(item.target) and item.target.is_alive():
			_spawn_shot(item.target, item.direction, item.get("lane", -1))
	_burst = _burst.filter(func(item: Dictionary) -> bool: return item.delay > 0.0)
	if plant_kind in ["sunflower", "sun_shroom", "marigold"]:
		_production_timer -= delta
		if _production_timer <= 0.0:
			_production_timer += float(settings.attack_interval)
			if plant_kind == "marigold":
				stage.add_coins(50 if randf() < 0.1 else 10, global_position)
			else:
				stage.spawn_plant_sun(global_position, 15 if plant_kind == "sun_shroom" and _age < 120.0 else 25)
		return
	if plant_kind == "coffee_bean":
		_timer -= delta
		if _timer <= 0:
			var nearest: StagePlant
			var distance := INF
			for plant: StagePlant in stage.live_plants():
				var current := global_position.distance_to(plant.global_position)
				if plant.sleeping and not plant.display_only and current < distance:
					nearest = plant
					distance = current
			if nearest != null:
				nearest.wake_up()
				stage.effect(nearest.global_position, Color("f5d78f"), 0.7)
				_consume()
			else:
				_timer = 1.5
		return
	if plant_kind == "grave_buster":
		_timer -= delta
		if _timer <= 0 and stage.consume_grave(global_position):
			_consume()
		return
	if plant_kind in ["wall_nut", "tall_nut", "pumpkin", "torchwood", "lily_pad", "flower_pot", "garlic", "umbrella_leaf", "plantern"]:
		return
	var targets := _targets()
	if plant_kind == "scaredy_shroom":
		for enemy: StageZombie in stage.live_enemies():
			if not enemy.hypnotized and enemy.global_position.distance_to(global_position) < stage.lawn.cell_size * 1.5:
				return
	if targets.is_empty():
		_timer = 1.5 if plant_kind == "chomper" else float(settings.attack_interval)
		return
	_timer -= delta
	if _timer > 0.000001:
		return
	_timer = float(settings.attack_interval)
	if plant_kind == "magnet_shroom":
		for target: StageZombie in targets:
			if target.remove_metal():
				stage.effect(target.global_position + Vector3.UP, Color("e894bc"), 0.8)
				return
	elif plant_kind == "hypno_shroom":
		targets[0].hypnotize()
		_consume()
	elif plant_kind == "chomper":
		var target := targets[0] as StageZombie
		if target.enemy_kind in ["gargantuar", "zomboss", "zomboni", "catapult_zombie"]:
			target.receive_hit(int(settings.damage), Vector3.RIGHT, true)
			_timer = 1.5
		else:
			target.receive_hit(target.maximum_health, Vector3.RIGHT, true, true)
			_digestion_remaining = float(settings.attack_interval)
			_timer = 1.5
			stage.effect(target.global_position, Color("b67cbf"), 0.6)
	elif plant_kind == "spikeweed":
		for target: StageZombie in targets:
			target.receive_hit(int(settings.damage), Vector3.RIGHT, true)
	elif plant_kind in INSTANTS:
		_trigger_instant(targets)
	elif plant_kind in SHOOTERS:
		_fire(targets)


func _targets() -> Array[StageZombie]:
	var result: Array[StageZombie] = []
	var cell: Vector2i = stage.lawn.world_to_cell(global_position)
	for enemy: StageZombie in stage.live_enemies():
		if enemy.hypnotized:
			continue
		var offset := enemy.global_position - global_position
		var distance := Vector2(offset.x, offset.z).length()
		var enemy_cell: Vector2i = stage.lawn.world_to_cell(enemy.global_position)
		var same_lane: bool = absf(offset.z) < stage.lawn.cell_size * 0.45
		var within: bool = distance <= float(settings.range_cells) * stage.lawn.cell_size
		if not within:
			continue
		if enemy.is_hidden_target() and plant_kind != "tangle_kelp":
			continue
		if enemy.is_flying() and not plant_kind in ["cactus", "blover", "ice_shroom", "cherry_bomb", "jalapeno", "doom_shroom"]:
			continue
		if plant_kind in ["ice_shroom", "blover", "magnet_shroom", "starfruit"]:
			result.append(enemy)
		elif plant_kind == "threepeater" and enemy_cell.y >= 0 and absi(enemy_cell.y - cell.y) <= 1 and offset.x > 0:
			result.append(enemy)
		elif plant_kind == "split_pea" and same_lane:
			result.append(enemy)
		elif plant_kind in ["cherry_bomb", "doom_shroom"] and distance < stage.lawn.cell_size * (1.5 if plant_kind == "cherry_bomb" else 3.0):
			result.append(enemy)
		elif same_lane and offset.x > -0.15:
			if plant_kind != "potato_mine" or _age >= 15.0:
				result.append(enemy)
	result.sort_custom(func(a: StageZombie, b: StageZombie) -> bool: return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	return result


func _fire(targets: Array[StageZombie]) -> void:
	_recoil = 0.17
	if plant_kind == "starfruit":
		for direction: Vector3 in [Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(1, 0, -1), Vector3(1, 0, 1)]:
			_spawn_shot(targets[0], direction)
		return
	if plant_kind == "threepeater":
		var row: int = stage.lawn.world_to_cell(global_position).y
		for offset in [-1, 0, 1]:
			if row + offset >= 0 and row + offset < stage.lawn.row_count:
				_spawn_shot(targets[0], Vector3.RIGHT, row + offset)
		return
	if plant_kind == "split_pea":
		var front: StageZombie
		var back: StageZombie
		for target: StageZombie in targets:
			if target.global_position.x > global_position.x and front == null:
				front = target
			elif target.global_position.x < global_position.x and back == null:
				back = target
		if front != null:
			_spawn_shot(front, Vector3.RIGHT)
		if back != null:
			_spawn_shot(back, Vector3.LEFT)
			_burst.append({"delay": 0.18, "target": back, "direction": Vector3.LEFT})
		return
	_spawn_shot(targets[0], Vector3.RIGHT)
	if plant_kind == "repeater":
		_burst.append({"delay": 0.18, "target": targets[0], "direction": Vector3.RIGHT})


func _spawn_shot(target: StageZombie, direction: Vector3, lane: int = -1) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		return
	var shot := StageProjectile.new()
	shot.stage = stage
	shot.target = target
	shot.damage = int(settings.damage)
	shot.maximum_distance = float(settings.range_cells) * stage.lawn.cell_size
	shot.speed = float(GameConfiguration.current().section("plants.common").pea_speed)
	shot.direction = direction
	shot.lobbed = plant_kind in ["cabbage_pult", "kernel_pult", "melon_pult"]
	shot.piercing = plant_kind == "fume_shroom"
	shot.anti_air = plant_kind == "cactus"
	shot.cold = plant_kind == "snow_pea"
	shot.torch_compatible = plant_kind in ["peashooter", "repeater", "threepeater", "snow_pea", "split_pea"]
	shot.backward = direction.x < 0.0
	shot.splash = plant_kind == "melon_pult"
	shot.color = Color("95cfe6") if shot.cold else Color("83c751")
	if plant_kind in ["puff_shroom", "fume_shroom", "sea_shroom", "scaredy_shroom"]:
		shot.color = Color("cda5d9")
	if plant_kind == "kernel_pult":
		shot.butter = randf() < 0.25
		shot.damage = 40 if shot.butter else 20
		shot.color = Color("ffe7a0") if shot.butter else Color("edc550")
	var origin := global_position + Vector3(0.5 * signf(direction.x), 0.6 if plant_kind in StageCatalog.MUSHROOMS else 1.05, 0)
	if target.get_meta("mini", false):
		origin.y = global_position.y + 0.45
	if lane >= 0:
		shot.target_lane_z = stage.lawn.cell_to_world(lane, 0).z
	stage.projectiles.add_child(shot)
	shot.global_position = origin
	shot.set_start(origin)
	shot_fired.emit(shot)


func _trigger_instant(targets: Array[StageZombie]) -> void:
	if plant_kind == "tangle_kelp":
		targets[0].receive_hit(targets[0].maximum_health, Vector3.RIGHT, true, true)
	elif plant_kind == "blover":
		for enemy: StageZombie in stage.live_enemies():
			if enemy.is_flying():
				enemy.receive_hit(enemy.maximum_health, Vector3.RIGHT, true, true)
		stage.clear_fog(25.0)
	elif plant_kind == "ice_shroom":
		for enemy: StageZombie in stage.live_enemies():
			enemy.receive_hit(int(settings.damage), Vector3.RIGHT, true)
			enemy.apply_freeze(4.0)
			enemy.apply_slow(0.5, 20.0)
	else:
		var center := global_position if plant_kind in ["cherry_bomb", "doom_shroom", "potato_mine"] else targets[0].global_position
		var radius: float = stage.lawn.cell_size * (3.0 if plant_kind == "doom_shroom" else (1.5 if plant_kind == "cherry_bomb" else 0.8))
		for enemy: StageZombie in stage.live_enemies():
			var same_lane: bool = absf(enemy.global_position.z - global_position.z) < stage.lawn.cell_size * 0.45
			if (plant_kind == "jalapeno" and same_lane) or (plant_kind != "jalapeno" and enemy.global_position.distance_to(center) <= radius):
				enemy.receive_hit(int(settings.damage), Vector3.RIGHT, true, true)
		if plant_kind == "jalapeno":
			stage.clear_ice(stage.lawn.world_to_cell(global_position).y)
	stage.effect(global_position + Vector3.UP * 0.5, Color("9acfe9") if plant_kind == "ice_shroom" else Color("ffba61"), 2.0)
	_consume()
