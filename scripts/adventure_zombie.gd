class_name AdventureZombie
extends StageZombie
## Adventure faction combat, four dancing slots and whack-a-zombie emergence.

var _dancer_slots: Dictionary = {}
var emergence_remaining: float = 0.0
var bungee_target: Vector2i = Vector2i(-1, -1)


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	if emergence_remaining > 0.0:
		emergence_remaining = maxf(0.0, emergence_remaining - delta)
		_visuals.position.y = _visuals_rest.origin.y - emergence_remaining * 1.5
		_update_slow(delta)
		_update_hit_effect(delta)
		return
	# Both sides stop and bite when a hypnotized zombie meets a hostile one.
	for other: StageZombie in stage.live_enemies():
		if other == self or other.hypnotized == hypnotized:
			continue
		if absf(other.global_position.z - global_position.z) > 0.7 or absf(other.global_position.x - global_position.x) > 0.95:
			continue
		_update_slow(delta)
		_update_hit_effect(delta)
		if _freeze_remaining > 0.0 or _rage_remaining > 0.0:
			_freeze_remaining = maxf(0.0, _freeze_remaining - delta)
			_rage_remaining = maxf(0.0, _rage_remaining - delta)
			return
		_bite_accumulator += float(settings.bite_damage_per_second) * delta * (0.5 if _slow_remaining > 0.0 else 1.0)
		var damage := int(_bite_accumulator)
		_bite_accumulator -= damage
		other.receive_hit(damage, Vector3.RIGHT if hypnotized else Vector3.LEFT)
		return
	super._physics_process(delta)


func _attack_plant(plant: StagePlant, delta: float) -> void:
	if plant.plant_kind == "hypno_shroom" and not plant.sleeping:
		hypnotize()
		plant._consume()
		return
	super._attack_plant(plant, delta)


func _nearest_plant() -> StagePlant:
	var result: StagePlant
	var nearest := 1.1
	var best_layer := -1
	for plant: StagePlant in stage.live_plants():
		if plant.plant_kind == "coffee_bean" or absf(plant.global_position.z - global_position.z) > stage.lawn.cell_size * 0.4:
			continue
		var distance := (plant.global_position - global_position).dot(-global_basis.z)
		var priority: int = {"base": 0, "plant": 1, "shell": 2}.get(stage.world_rules.layer(plant.plant_kind), 0)
		if distance >= -0.2 and (distance < nearest - 0.01 or (absf(distance - nearest) <= 0.01 and priority > best_layer)):
			nearest = distance
			best_layer = priority
			result = plant
	return result


func configure_water_armor(form: String) -> void:
	var armor: Dictionary = GameConfiguration.current().section("stages.zombies." + form)
	helmet_health = int(armor.helmet_health)
	maximum_health = body_health + helmet_health
	health = maximum_health
	armor_drop_health = body_health
	_base_speed = float(GameConfiguration.current().section("zombies.common").walk_speed) * float(armor.speed_multiplier)
	has_cone = form == "conehead_zombie"
	has_bucket = form == "buckethead_zombie"
	var cone := _head.get_node_or_null("Cone") as Node3D
	var bucket := _head.get_node_or_null("Bucket") as Node3D
	if cone != null:
		cone.visible = has_cone
	if bucket != null:
		bucket.visible = has_bucket


func configure_mini() -> void:
	set_meta("mini", true)
	var factor := float(stage.settings.mini_health_multiplier)
	body_health = maxi(1, roundi(body_health * factor))
	helmet_health = roundi(helmet_health * factor)
	shield_health = roundi(shield_health * factor)
	maximum_health = body_health + helmet_health + shield_health
	health = maximum_health
	_visuals.scale *= float(stage.settings.mini_scale)
	_collision.scale *= float(stage.settings.mini_scale)
	_collision.position *= float(stage.settings.mini_scale)
	_base_speed *= float(stage.settings.mini_speed_multiplier)


func target_height() -> float:
	return super.target_height() * (float(stage.settings.mini_scale) if get_meta("mini", false) else 1.0)


func _update_bungee(_delta: float) -> void:
	if bungee_target.x < 0:
		var victim: StagePlant = stage.first_plant_in_lane(global_position.z)
		bungee_target = stage.lawn.world_to_cell(victim.global_position) if victim != null else Vector2i(3, stage.lawn.world_to_cell(global_position).y)
	var at: Vector3 = stage.lawn.cell_to_world(bungee_target.y, bungee_target.x)
	global_position = at + Vector3.UP * (maxf(0, 4 - _age * 2) if _age < 4 else (_age - 4) * 2)
	if _age >= 2 and _has_tool:
		_has_tool = false
		if stage.is_umbrella_protected(at):
			stage.effect(at, Color("a9d988"), 1.0)
		elif stage.rules_mode == "bungee":
			var payload: StageZombie = stage.spawn_summoned("ladder_zombie" if stage._random.randf() < 0.25 else "conehead_zombie", at + Vector3.RIGHT * 0.6)
			if payload != null:
				stage._notice("蹦极空投了僵尸！", 2)
		else:
			stage.world_rules.clear_cell(bungee_target)
	if _age >= 6:
		set_meta("escaped", true)
		receive_hit(maximum_health, Vector3.UP, true, true)


func hypnotize() -> void:
	super.hypnotize()
	for summon: Variant in _dancer_slots.values():
		if is_instance_valid(summon) and summon.is_alive():
			summon.hypnotize()


func _update_ability(delta: float) -> void:
	if enemy_kind != "dancing_zombie":
		super._update_ability(delta)
		return
	_ability_remaining -= delta
	if _ability_remaining > 0.0:
		return
	_ability_remaining = float(settings.ability_interval)
	var offsets: Array[Vector3] = [Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0), Vector3(0, 0, stage.lawn.cell_size), Vector3(0, 0, -stage.lawn.cell_size)]
	for index in offsets.size():
		var previous: Variant = _dancer_slots.get(index)
		if is_instance_valid(previous) and previous.is_alive():
			continue
		var summon: StageZombie = stage.spawn_summoned("backup_dancer", global_position + offsets[index])
		if summon != null:
			_dancer_slots[index] = summon
			if hypnotized:
				summon.hypnotize()
