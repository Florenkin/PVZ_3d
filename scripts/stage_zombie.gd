class_name StageZombie
extends Zombie
## Reuses hit flashes, recoil and physical corpses; stage traits are independent.

@export var enemy_kind: String = "zombie"
var stage: Node3D
var hypnotized: bool = false
var body_health: int = 270
var helmet_health: int = 0
var shield_health: int = 0
var settings: Dictionary
var _traits: Node3D
var _label: Label3D
var _freeze_remaining: float = 0.0
var _ability_remaining: float = 8.0
var _age: float = 0.0
var _bite_accumulator: float = 0.0
var _has_tool: bool = true
var _rage_remaining: float = 0.0
var _angry: bool = false
var _underground: bool = false
var _submerged: bool = false
var _airborne: bool = false
var _jump_remaining: float = 0.0
var _jump_start: Vector3
var _jump_end: Vector3
var _thrown_imp: bool = false
var _base_speed: float = 0.5
var _last_ice_column: int = -1
var _summons: Array[StageZombie] = []


func _ready() -> void:
	has_cone = enemy_kind == "conehead_zombie"
	has_bucket = enemy_kind == "buckethead_zombie"
	settings = GameConfiguration.current().section("stages.zombies." + enemy_kind)
	if get_meta("summoned", false) and enemy_kind == "bobsled_team":
		settings.helmet_health = 0
	_traits = StageModels.enemy(self, enemy_kind)
	_base_speed = float(GameConfiguration.current().section("zombies.common").walk_speed) * float(settings.speed_multiplier)
	walk_speed = _base_speed
	maximum_health = int(settings.body_health + settings.helmet_health + settings.shield_health)
	armor_drop_health = int(settings.body_health + settings.shield_health)
	hand_drop_health = int(settings.body_health) / 3
	maximum_walk_distance = 200.0
	super._ready()
	var scale_value := 2.0 if enemy_kind == "gargantuar" else (0.58 if enemy_kind == "imp" else 1.0)
	_collision.shape = _collision.shape.duplicate()
	_collision.scale = Vector3.ONE * scale_value
	_collision.position.y *= scale_value
	if enemy_kind == "zomboss":
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.0, 4.0, 1.7)
		_collision.shape = shape
		_collision.position.y = 2.0
	_label = StageModels.label(self, "", Vector3(0, target_height() + 1.25, 0), Color("eaf0de"))
	_update_label()


func reset_combat() -> void:
	super.reset_combat()
	if settings.is_empty():
		return
	body_health = int(settings.body_health)
	helmet_health = int(settings.helmet_health)
	shield_health = int(settings.shield_health)
	_freeze_remaining = 0.0
	_rage_remaining = 0.0
	_angry = false
	_has_tool = true
	_age = 0.0
	_jump_remaining = 0.0
	_thrown_imp = false
	_last_ice_column = -1
	_ability_remaining = float(settings.ability_interval)
	if enemy_kind == "jack_in_the_box":
		_ability_remaining = randf_range(8.0, 16.0)
	hypnotized = false
	_underground = enemy_kind == "digger_zombie"
	_submerged = enemy_kind == "snorkel_zombie"
	_airborne = enemy_kind == "balloon_zombie"
	if is_instance_valid(_traits):
		_traits.show()
		for child: Node3D in _traits.get_children():
			child.show()
	if enemy_kind == "zomboss":
		_head.hide()
	_update_label()


func target_height() -> float:
	if enemy_kind == "zomboss":
		return 2.2
	if enemy_kind == "gargantuar":
		return 1.9
	if enemy_kind == "imp":
		return 0.62
	return 1.05


func is_flying() -> bool:
	return _airborne


func is_hidden_target() -> bool:
	return _underground or _submerged


func apply_freeze(duration: float) -> void:
	if is_alive() and enemy_kind != "zomboni":
		_freeze_remaining = maxf(_freeze_remaining, duration)


func take_damage(amount: int, incoming_direction: Vector3) -> void:
	receive_hit(amount, incoming_direction)


func receive_hit(amount: int, incoming_direction: Vector3, bypass_shield: bool = false, burn: bool = false) -> void:
	if not is_alive() or amount <= 0:
		return
	if _airborne:
		_airborne = false
		var balloon := _traits.get_node_or_null("Balloon")
		if balloon != null:
			balloon.hide()
	var remaining := amount
	var before := health
	var previous_shield := shield_health
	if not bypass_shield and shield_health > 0:
		var absorbed := mini(remaining, shield_health)
		shield_health -= absorbed
		remaining -= absorbed
	if helmet_health > 0:
		var absorbed := mini(remaining, helmet_health)
		helmet_health -= absorbed
		remaining -= absorbed
	body_health = maxi(0, body_health - remaining)
	if body_health == 0:
		helmet_health = 0
		shield_health = 0
	var after := body_health + helmet_health + shield_health
	if burn:
		_slow_remaining = 0.0
		_slow_multiplier = 1.0
	# Use the shared damage/death pipeline exactly once, after routing the hit.
	super.take_damage(before - after, incoming_direction)
	if previous_shield > 0 and shield_health == 0:
		_hide_shield()
		if enemy_kind == "newspaper_zombie" and is_alive():
			_rage_remaining = 1.0
			_angry = true
	if helmet_health == 0 and enemy_kind in ["football_zombie", "digger_zombie"]:
		_hide_helmet()
	_update_label()


func _hide_shield() -> void:
	for child: Node3D in _traits.get_children():
		if "Door" in child.name or "Shield" in child.name or "Ladder" in child.name:
			child.hide()
	var paper := _visuals.get_node_or_null("Newspaper")
	if paper != null:
		paper.hide()


func _hide_helmet() -> void:
	for prop: Node3D in _traits.get_children():
		if "Helmet" in prop.name or "Grille" in prop.name or enemy_kind == "digger_zombie" and ("Pick" in prop.name or "Lamp" in prop.name):
			prop.hide()


func remove_metal() -> bool:
	if not is_alive():
		return false
	if enemy_kind in ["buckethead_zombie", "football_zombie", "digger_zombie"] and helmet_health > 0:
		helmet_health = 0
		if enemy_kind == "digger_zombie":
			_underground = false
			_has_tool = false
		var bucket := _head.get_node_or_null("Bucket")
		if bucket != null:
			bucket.hide()
		_hide_helmet()
	elif enemy_kind in ["screen_door_zombie", "ladder_zombie"] and shield_health > 0:
		shield_health = 0
		_hide_shield()
	elif enemy_kind in ["jack_in_the_box", "pogo_zombie"] and _has_tool:
		_has_tool = false
		for child: Node3D in _traits.get_children():
			if "Jack" in child.name or "Box" in child.name or "Pogo" in child.name:
				child.hide()
	else:
		return false
	health = body_health + helmet_health + shield_health
	health_changed.emit(health, maximum_health)
	_update_label()
	return true


func hypnotize() -> void:
	if enemy_kind in ["zomboss", "gargantuar", "zomboni", "catapult_zombie", "bungee_zombie"]:
		return
	hypnotized = true
	rotation.y = -PI * 0.5
	_stage_color(Color("b776c7"))
	_update_label()


func _stage_color(color: Color) -> void:
	for item: MeshInstance3D in _visuals.find_children("*", "MeshInstance3D", true, false):
		if item.name.contains("Jacket") or item.name.contains("Sleeve"):
			var new_material := StageModels.material(color)
			_materials[item] = new_material
			item.material_override = new_material


func _update_label() -> void:
	if is_instance_valid(_label):
		_label.text = "%s%s\n%d/%d HP" % [StageCatalog.ENEMY_NAMES.get(enemy_kind, enemy_kind), " · 魅惑" if hypnotized else "", health, maximum_health]
		_label.position.y = target_height() + 1.25


func _physics_process(delta: float) -> void:
	if not is_instance_valid(stage) or not is_alive():
		super._physics_process(delta)
		return
	_age += delta
	_update_slow(delta)
	_update_hit_effect(delta)
	if _freeze_remaining > 0.0 or _rage_remaining > 0.0:
		_freeze_remaining = maxf(0.0, _freeze_remaining - delta)
		_rage_remaining = maxf(0.0, _rage_remaining - delta)
		return
	if _jump_remaining > 0.0:
		_jump_remaining = maxf(0.0, _jump_remaining - delta)
		var progress := 1.0 - _jump_remaining / 0.8
		global_position = _jump_start.lerp(_jump_end, progress) + Vector3.UP * sin(progress * PI) * 1.8
		return
	if enemy_kind == "zomboss":
		_update_ability(delta)
		return
	if enemy_kind == "bungee_zombie":
		_update_bungee(delta)
		return
	if _underground:
		global_position.x -= get_walk_speed() * delta
		global_position.y = stage.lawn.surface_at(global_position) - 0.55
		if global_position.x <= stage.lawn.cell_to_world(0, 0).x:
			_underground = false
			rotation.y = -PI * 0.5
			_freeze_remaining = 1.0
			_base_speed = 0.35
		return
	if _airborne:
		global_position.x -= get_walk_speed() * delta
		global_position.y = stage.lawn.surface_at(global_position) + 1.7
		if global_position.x < stage.lawn.cell_to_world(0, 0).x - stage.lawn.cell_size:
			receive_hit(maximum_health, Vector3.RIGHT, true, true)
		return
	var obstacle := _nearest_plant()
	if _submerged:
		if obstacle != null:
			_submerged = false
		else:
			global_position.x -= get_walk_speed() * delta
			global_position.y = stage.lawn.surface_at(global_position) - 0.42
			return
	if obstacle != null and not hypnotized:
		if _try_jump(obstacle):
			return
		_attack_plant(obstacle, delta)
		if obstacle.plant_kind != "spikeweed":
			_update_ability(delta)
			return
	if hypnotized:
		for other: StageZombie in stage.live_enemies():
			if other != self and not other.hypnotized and absf(other.global_position.z - global_position.z) < 0.7 and absf(other.global_position.x - global_position.x) < 1.0:
				_bite_accumulator += 100.0 * delta
				var damage := int(_bite_accumulator)
				_bite_accumulator -= damage
				other.receive_hit(damage, Vector3.RIGHT)
				return
	walk_speed = _base_speed * (3.3 if _angry else 1.0)
	# Advance movement separately: status timers have already advanced once.
	_step_movement(delta)
	_update_ability(delta)
	if enemy_kind == "pogo_zombie" and _has_tool:
		_visuals.position.y = _visuals_rest.origin.y + absf(sin(_age * 5.0)) * 0.32
	if enemy_kind == "yeti_zombie" and _age >= 15.0:
		rotation.y = -PI * 0.5
		_base_speed = 1.2
	var left: float = stage.lawn.cell_to_world(0, 0).x - stage.lawn.cell_size
	var right: float = stage.lawn.cell_to_world(0, stage.lawn.column_count - 1).x + stage.lawn.cell_size * 4.0
	if global_position.x < left or global_position.x > right:
		receive_hit(maximum_health, Vector3.RIGHT, true, true)


func _nearest_plant() -> StagePlant:
	var result: StagePlant
	var nearest := 1.1
	var direction := -global_basis.z
	for plant: StagePlant in stage.live_plants():
		if plant.display_only or absf(plant.global_position.z - global_position.z) > stage.lawn.cell_size * 0.40:
			continue
		var forward := (plant.global_position - global_position).dot(direction)
		if forward >= -0.2 and forward < nearest:
			result = plant
			nearest = forward
	return result


func _try_jump(plant: StagePlant) -> bool:
	if not enemy_kind in ["pole_vaulting_zombie", "dolphin_rider", "pogo_zombie"] or not _has_tool:
		return false
	if plant.plant_kind == "tall_nut":
		return false
	_jump_start = global_position
	_jump_end = plant.global_position + Vector3.LEFT * 1.25
	_jump_end.z = global_position.z
	_jump_remaining = 0.8
	if enemy_kind != "pogo_zombie":
		_has_tool = false
		_base_speed = 0.5
		var pole := _visuals.get_node_or_null("Pole")
		if pole != null:
			pole.hide()
		var dolphin := _traits.get_node_or_null("Dolphin")
		if dolphin != null:
			dolphin.hide()
	return true


func _attack_plant(plant: StagePlant, delta: float) -> void:
	if plant.plant_kind == "spikeweed" and not enemy_kind in ["gargantuar", "zomboni", "catapult_zombie"]:
		return
	if plant.plant_kind == "garlic" and not enemy_kind in ["gargantuar", "zomboni", "catapult_zombie"]:
		plant.take_damage(25)
		stage.move_to_adjacent_lane(self)
		return
	if enemy_kind in ["zomboni", "catapult_zombie"]:
		if plant.plant_kind == "spikeweed":
			receive_hit(1800, Vector3.RIGHT, true, true)
		plant.take_damage(plant.maximum_health)
		return
	if enemy_kind == "gargantuar":
		_bite_accumulator += delta
		if _bite_accumulator >= 1.5:
			_bite_accumulator = 0.0
			plant.take_damage(plant.maximum_health)
			stage.effect(plant.global_position, Color("bd996b"), 0.9)
		return
	if enemy_kind == "ladder_zombie" and shield_health > 0 and plant.plant_kind in ["wall_nut", "tall_nut", "pumpkin"]:
		stage.effect(plant.global_position, Color("dec596"), 1.1)
		shield_health = 0
		_hide_shield()
		health = body_health + helmet_health
		global_position.x = plant.global_position.x - 1.25
		_update_label()
		return
	_bite_accumulator += float(settings.bite_damage_per_second) * delta * (0.5 if _slow_remaining > 0 else 1.0)
	var damage := int(_bite_accumulator)
	_bite_accumulator -= damage
	plant.take_damage(damage)


func _update_ability(delta: float) -> void:
	if enemy_kind == "gargantuar" and not _thrown_imp and body_health < int(settings.body_health) / 2:
		_thrown_imp = true
		stage.spawn_summoned("imp", global_position + Vector3.LEFT * stage.lawn.cell_size * 3.0)
	_ability_remaining -= delta
	if _ability_remaining > 0.0:
		return
	_ability_remaining = float(settings.ability_interval)
	match enemy_kind:
		"dancing_zombie":
			_summons = _summons.filter(func(enemy: Variant) -> bool: return is_instance_valid(enemy) and enemy.is_alive())
			if _summons.is_empty():
				for offset: Vector3 in [Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0), Vector3(0, 0, 2.4), Vector3(0, 0, -2.4)]:
					var summon: StageZombie = stage.spawn_summoned("backup_dancer", global_position + offset)
					if summon != null:
						_summons.append(summon)
		"jack_in_the_box":
			if _has_tool:
				for plant: StagePlant in stage.live_plants():
					if plant.global_position.distance_to(global_position) < stage.lawn.cell_size * 1.5:
						plant.take_damage(plant.maximum_health)
				stage.effect(global_position, Color("f8bd7d"), 2.0)
				receive_hit(maximum_health, Vector3.RIGHT, true, true)
		"catapult_zombie", "zomboss":
			var victim: StagePlant = stage.first_plant_in_lane(global_position.z)
			if victim != null and not stage.is_umbrella_protected(victim.global_position):
				victim.take_damage(75)
				stage.effect(victim.global_position + Vector3.UP, Color("da9757") if enemy_kind == "catapult_zombie" else Color("85cadd"), 0.7)
		"zomboni":
			var cell: Vector2i = stage.lawn.world_to_cell(global_position)
			if cell.x >= 0 and cell.x != _last_ice_column:
				_last_ice_column = cell.x
				stage.add_ice(cell)
			_ability_remaining = 0.3


func _update_bungee(delta: float) -> void:
	_ability_remaining -= delta
	var target: StagePlant = stage.first_plant_in_lane(_spawn_transform.origin.z)
	if target == null:
		return
	var phase := fmod(_age, 8.0)
	global_position.x = target.global_position.x
	global_position.z = target.global_position.z
	global_position.y = target.global_position.y + (4.0 - phase * 2.0 if phase < 2.0 else (0.0 if phase < 4.0 else (phase - 4.0)))
	if phase >= 2.0 and phase < 4.0 and _has_tool:
		_has_tool = false
		if stage.is_umbrella_protected(target.global_position):
			stage.effect(global_position, Color("a9d988"), 1.0)
		else:
			target.take_damage(target.maximum_health)
	if phase > 6.0:
		_has_tool = true
