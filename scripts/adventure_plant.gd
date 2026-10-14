class_name AdventurePlant
extends StagePlant
## Planted bombs detonate after their fuse, rather than waiting for a demo target.

var _fuse: float = 1.2
var _arm_remaining: float = 15.0
var _grave_remaining: float = 4.0
var _squash_remaining: float = -1.0
var _squash_landing: Vector3


func _ready() -> void:
	super._ready()
	_label.hide()
	_fuse = float(GameConfiguration.current().section("adventure").cherry_fuse)
	if plant_kind in ["ice_shroom", "doom_shroom", "jalapeno", "blover"]:
		_fuse = float(stage.settings.mushroom_fuse)
	_arm_remaining = float(stage.settings.mine_arm_time)
	_grave_remaining = float(stage.settings.grave_eat_time)
	if plant_kind == "potato_mine":
		_visuals.scale = Vector3.ONE * 0.55
	elif plant_kind == "sun_shroom":
		_visuals.scale = Vector3.ONE * 0.65


func _process(delta: float) -> void:
	super._process(delta)
	if plant_kind == "sun_shroom":
		_visuals.scale = Vector3.ONE * (0.65 if _age < 120.0 else 1.0)


func _physics_process(delta: float) -> void:
	if not is_alive() or sleeping:
		return
	if plant_kind == "hypno_shroom":
		# It is consumed by a bite, not by selecting a nearby target.
		return
	if plant_kind == "coffee_bean":
		_timer -= delta
		if _timer <= 0:
			var cell: Vector2i = stage.lawn.world_to_cell(global_position)
			var plant := stage._occupied.get(cell) as AdventurePlant
			if is_instance_valid(plant) and plant.sleeping:
				plant.wake_up()
				stage.effect(plant.global_position, Color("f5d78f"), 0.7)
			_consume()
		return
	if plant_kind == "squash":
		if _squash_remaining < 0:
			var targets := _targets()
			if targets.is_empty():
				return
			_squash_landing = targets[0].global_position
			_squash_remaining = float(stage.settings.squash_windup)
		_squash_remaining -= delta
		_visuals.position.y = sin(clampf(1 - _squash_remaining / float(stage.settings.squash_windup), 0, 1) * PI) * 2.0
		if _squash_remaining <= 0:
			for enemy: StageZombie in stage.hostile_enemies():
				if Vector2(enemy.global_position.x - _squash_landing.x, enemy.global_position.z - _squash_landing.z).length() < stage.lawn.cell_size * 0.8 and not enemy.is_flying():
					enemy.receive_hit(int(settings.damage), Vector3.RIGHT, true, true)
			stage.effect(_squash_landing, Color("b4c367"), 1.3)
			_consume()
		return
	if plant_kind == "grave_buster":
		_grave_remaining -= delta
		if _grave_remaining <= 0.0:
			stage.consume_grave(global_position)
			_consume()
		return
	if plant_kind == "potato_mine":
		_arm_remaining = maxf(0.0, _arm_remaining - delta)
		if _arm_remaining > 0.0:
			return
		_visuals.scale = Vector3.ONE
		for enemy: StageZombie in stage.live_enemies():
			var offset := enemy.global_position - global_position
			if not enemy.hypnotized and not enemy.is_flying() and not enemy.is_hidden_target() and absf(offset.z) < stage.lawn.cell_size * 0.4 and absf(offset.x) < 0.9 and enemy._jump_remaining <= 0.0:
				for victim: StageZombie in stage.live_enemies():
					if victim.hypnotized:
						continue
					var distance := victim.global_position - global_position
					if absf(distance.z) < stage.lawn.cell_size * 0.4 and absf(distance.x) < stage.lawn.cell_size * 0.8:
						victim.receive_hit(int(settings.damage), Vector3.RIGHT, true, true)
				stage.effect(global_position, Color.ORANGE, 1.2)
				_consume()
				return
		return
	if not plant_kind in ["cherry_bomb", "ice_shroom", "doom_shroom", "jalapeno", "blover"]:
		super._physics_process(delta)
		return
	_fuse -= delta
	_visuals.scale = Vector3.ONE * (1.0 + sin(_age * 16.0) * 0.08)
	if _fuse <= 0.0:
		var row: int = stage.lawn.world_to_cell(global_position).y
		if plant_kind in ["ice_shroom", "jalapeno"]:
			stage.world_rules.counter_balls(plant_kind, row)
		if plant_kind == "jalapeno":
			stage.clear_ice(row)
		if plant_kind == "blover":
			stage.clear_fog(float(stage.settings.blover_duration))
		for enemy: StageZombie in stage.live_enemies():
			var offset := enemy.global_position - global_position
			if enemy.hypnotized:
				continue
			if plant_kind == "blover":
				if enemy.is_flying():
					enemy.receive_hit(enemy.maximum_health, Vector3.RIGHT, true, true)
			elif plant_kind == "jalapeno":
				if absf(offset.z) < stage.lawn.cell_size * 0.45:
					enemy.receive_hit(int(settings.damage), Vector3.RIGHT, true, true)
			elif plant_kind == "ice_shroom":
				enemy.receive_hit(int(settings.damage), Vector3.RIGHT, true)
				enemy.apply_freeze(4.0)
				enemy.apply_slow(0.5, 20.0)
			elif (plant_kind == "cherry_bomb" and absf(offset.x) <= stage.lawn.cell_size * 1.5 and absf(offset.z) <= stage.lawn.cell_size * 1.1) or (plant_kind == "doom_shroom" and Vector2(offset.x, offset.z).length() <= stage.lawn.cell_size * 3.0):
				enemy.receive_hit(int(settings.damage), Vector3.RIGHT, true, true)
		if plant_kind == "doom_shroom":
			stage.add_crater(global_position)
			for cell: Vector2i in stage.grave_cells():
				if stage.lawn.cell_to_world(cell.y, cell.x).distance_to(global_position) <= stage.lawn.cell_size * 3.0:
					stage.consume_grave(stage.lawn.cell_to_world(cell.y, cell.x))
		stage.effect(global_position + Vector3.UP * 0.5, Color("a3d5ee") if plant_kind == "ice_shroom" else Color("ffc974"), 3.5 if plant_kind == "doom_shroom" else 2.2)
		_consume()


func _targets() -> Array[StageZombie]:
	var targets := super._targets()
	if plant_kind in ["cabbage_pult", "kernel_pult", "melon_pult"] and stage.rules_mode == "boss":
		var boss: AdventureBoss = stage.world_rules.boss
		if is_instance_valid(boss) and boss.is_alive() and boss.exposed and not boss in targets:
			targets.append(boss)
	if plant_kind == "spikeweed":
		targets = targets.filter(func(enemy: StageZombie) -> bool: return not enemy.is_flying() and enemy._jump_remaining <= 0)
	return targets
