class_name AdventureBoard
extends Node3D
## Finite adventure waves and player planting, independent of showcase refreshes.

signal retry_requested
signal next_requested(number: int)
signal menu_requested
signal levels_requested
signal level_finished(number: int, victory: bool)

enum State { PLAYING, SELECTING, PAUSED, WON, LOST, CLOSING }
@export_range(1, 50) var level_number: int = 1
var state: State = State.PLAYING
var stage_number: int = 1
var _last_supply_kind: String = ""
var idle_enabled: bool = true
var lawn: StageLawn
var projectiles: Node3D
var sun_value: int = 50
var selected_kind: String = ""
var wave_index: int = 0
var kills: int = 0
var active_rows: Array[int] = []
var settings: Dictionary
var rules_mode: String = "normal"
var supply: Array[String] = []
var cooldowns: Dictionary = {}
var _plants: Node3D
var _enemies: Node3D
var _suns: Node3D
var _effects: Node3D
var _mowers: Dictionary = {}
var _occupied: Dictionary = {}
var _random := RandomNumberGenerator.new()
var _wave_remaining: float = 18.0
var _wave_elapsed: float = 0.0
var _spawn_queue: Array[String] = []
var _spawn_remaining: float = 0.0
var _sun_remaining: float = 5.0
var _sun_count: int = 0
var _flag_warning: float = -1.0
var _first_plant: bool = false
var _spawn_serial: int = 0
var _row_cursor: int = 0
var _camera: Camera3D
var _dave: CrazyDave
var _hand: DaveHand
var _ui_root: Control
var _sun_label: Label
var _wave_label: Label
var _hint_label: Label
var _progress: ProgressBar
var _cards: Dictionary = {}
var _tool_label: Label
var _crosshair: Label
var _overlay: Control
var _cursor: Node3D
var _cursor_mesh: MeshInstance3D
var _ghost: Node3D
var _hint_remaining: float = 0.0
var _supply_remaining: float = 4.0
var _supply_label: Label
var _graves: Dictionary = {}
var _craters: Dictionary = {}
var _crater_models: Dictionary = {}
var world_rules: AdventureWorld


func _enter_tree() -> void:
	settings = GameConfiguration.current().section("adventure")
	stage_number = AdventureLevels.terrain(level_number)
	rules_mode = AdventureLevels.mode(level_number)
	GameConfiguration.current().apply_scene(self)
	lawn = $LawnGrid
	lawn.row_count_override = 6 if StageCatalog.has_pool(stage_number) else 5
	lawn.column_count_override = 9
	lawn.stage_number = stage_number
	lawn.water_rows.assign([2, 3] if StageCatalog.has_pool(stage_number) else [])
	active_rows = AdventureLevels.rows(level_number)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.randomize()
	_plants = $Plants
	_enemies = $Enemies
	projectiles = $Projectiles
	_suns = $SunSystem
	_effects = $Effects
	_dave = $CrazyDave
	_dave.escape_releases_mouse = false
	_dave.click_captures_mouse = false
	_dave.collision_layer = 16
	_dave.collision_mask = 1 | 32
	var dave_settings := GameConfiguration.current().section("dave")
	if dave_settings.derive_bounds_from_lawn:
		var half := Vector2(lawn.column_count, lawn.row_count) * lawn.cell_size * 0.5
		var inset := minf(float(dave_settings.boundary_inset), minf(half.x, half.y) - 0.1)
		half -= Vector2.ONE * inset
		_dave.movement_bounds = Rect2(Vector2(lawn.global_position.x, lawn.global_position.z) - half, half * 2.0)
	_dave.set_spawn(lawn.cell_to_world(2, 0) + Vector3(-0.6, 0, lawn.cell_size * 0.75), -PI * 0.5)
	_dave.waist_mount.rotation.x = -0.25
	_dave.set_first_person_active(true)
	_camera = _dave.camera
	_hand = DaveHand.new()
	_hand.name = "DaveHand"
	_hand.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hand.configure(_dave, can_use_shovel())
	add_child(_hand)
	sun_value = int(settings.initial_sun_tutorial if level_number == 1 else settings.initial_sun)
	_wave_remaining = float(settings.sunflower_tutorial_delay if level_number == 2 else settings.first_wave_delay)
	if stage_number == 3:
		_wave_remaining = float(settings.pool_first_wave_delay)
	elif stage_number == 5:
		_wave_remaining = float(settings.roof_first_wave_delay)
	if AdventureLevels.is_night(level_number):
		_wave_remaining = float(settings.night_first_wave_delay)
	if rules_mode == "whack":
		sun_value = 0
		selected_kind = "hammer"
		_hand.equip("hammer")
	_sun_remaining = _random.randf_range(settings.sun_first_min, settings.sun_first_max)
	_row_cursor = _random.randi_range(0, active_rows.size() - 1)
	$Debris.add_to_group("combat_debris_container")
	_prepare_lawn()
	_prepare_night()
	_build_graves()
	_prepare_supply()
	_build_mowers()
	_build_interface()
	_cursor = Node3D.new()
	_cursor.name = "PlacementPreview"
	add_child(_cursor)
	_cursor_mesh = StageModels.box(_cursor, "Cell", Vector3(lawn.cell_size * 0.92, 0.025, lawn.cell_size * 0.92), Vector3(0, 0.04, 0), Color(0.65, 0.86, 0.39, 0.42))
	_cursor.hide()
	_set_combat_processing(true)
	world_rules = AdventureWorld.new()
	world_rules.name = "WorldRules"
	$Decor.add_child(world_rules)
	world_rules.configure(self)
	_update_interface()


func _prepare_lawn() -> void:
	for row in lawn.row_count:
		if row in active_rows:
			continue
		for column in 9:
			var tile := lawn.get_tile(row, column)
			(tile.get_node("Turf") as MeshInstance3D).material_override = StageModels.material(Color("866346"))
			(tile.get_node("GrassTufts") as Node3D).hide()
	StageModels.box($Decor, "HouseBoundary", Vector3(0.20, 1.5, 13.0), Vector3(-12.6, 0.6, 0), Color("e1d5b5"))
	for row in lawn.row_count:
		StageModels.box($Decor, "FencePost", Vector3(0.38, 1.85, 0.38), Vector3(-12.6, 0.80, lawn.cell_to_local(row, 0).z), Color("f0e1bd"))
	if rules_mode == "bowling":
		StageModels.box($Decor, "BowlingLine", Vector3(0.09, 0.025, lawn.cell_size * 5.0), lawn.cell_to_local(2, 2) + Vector3(lawn.cell_size * 0.5, 0.05, 0), Color("c65345"))


func _prepare_night() -> void:
	if not AdventureLevels.is_night(level_number):
		return
	var environment := ($WorldEnvironment as WorldEnvironment).environment
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color("111b3b")
	sky.sky_horizon_color = Color("344762")
	sky.ground_horizon_color = Color("344762")
	environment.ambient_light_color = Color("9cb5e0")
	environment.ambient_light_energy = 0.34
	$Sun.light_energy *= 0.28
	$Sun.light_color = Color("94b6e7")
	StageModels.sphere($Decor, "Moon", Vector3.ONE * 2.5, Vector3(17, 16, -16), Color("dfecff"))


func _build_graves() -> void:
	if stage_number != 2 or rules_mode == "vases":
		return
	var count := 9 if rules_mode == "whack" else 5 + mini(4, (level_number - 11) / 2)
	for index in count:
		var cell := Vector2i(5 + index % 2, index) if index < 5 else Vector2i(8, index - 5)
		var grave := Node3D.new()
		grave.name = "Grave_%d_%d" % [cell.y, cell.x]
		grave.position = lawn.cell_to_local(cell.y, cell.x)
		$Decor.add_child(grave)
		StageModels.box(grave, "Stone", Vector3(0.35, 0.95, 0.78), Vector3(0, 0.48, 0), Color("707c86"))
		StageModels.sphere(grave, "Crown", Vector3(0.35, 0.4, 0.78), Vector3(0, 0.96, 0), Color("707c86"))
		StageModels.label(grave, "RIP", Vector3(-0.2, 0.70, 0), Color("d7dce0"))
		var body := StaticBody3D.new()
		body.collision_layer = 256
		body.collision_mask = 16
		body.set_meta("adventure_grave", cell)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.38, 1.1, 0.85)
		shape.shape = box
		shape.position.y = 0.55
		body.add_child(shape)
		grave.add_child(body)
		_graves[cell] = grave
	_dave.collision_mask |= 256


func grave_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_graves.keys())
	return result


func consume_grave(at: Vector3) -> bool:
	var cell := lawn.world_to_cell(at)
	if not _graves.has(cell):
		return false
	(_graves[cell] as Node3D).queue_free()
	_graves.erase(cell)
	return true


func add_crater(at: Vector3) -> void:
	var cell := lawn.world_to_cell(at)
	_craters[cell] = float(settings.crater_lifetime)
	var crater := StageModels.cylinder($Decor, "DoomCrater", lawn.cell_size * 0.38, 0.03, lawn.cell_to_local(cell.y, cell.x) + Vector3.UP * 0.035, Color("2d282c"))
	_crater_models[cell] = crater


func _update_craters(delta: float) -> void:
	for cell: Vector2i in _craters.keys():
		_craters[cell] = maxf(0.0, float(_craters[cell]) - delta)
		if float(_craters[cell]) <= 0.0:
			(_crater_models[cell] as Node3D).queue_free()
			_crater_models.erase(cell)
			_craters.erase(cell)


func _prepare_supply() -> void:
	_supply_remaining = float(settings.conveyor_interval)
	if not uses_supply():
		return
	sun_value = 0
	if rules_mode == "vases":
		return
	var initial: Array = ["bowling_nut", "bowling_nut", "explosive_nut"] if rules_mode == "bowling" else (["peashooter", "repeater", "snow_pea"] if stage_number == 1 else ["fume_shroom", "puff_shroom", "scaredy_shroom"])
	if level_number in [25, 30, 40, 45, 50]:
		initial = {25: ["lily_pad", "peashooter", "peashooter"], 30: ["lily_pad", "threepeater", "threepeater"], 40: ["lily_pad", "cactus", "peashooter"], 45: ["chomper", "chomper", "cherry_bomb"], 50: ["cabbage_pult", "melon_pult", "ice_shroom"]}[level_number]
	supply.assign(initial.slice(0, int(settings.conveyor_capacity)))


func _update_supply(delta: float) -> void:
	if not uses_supply() or rules_mode == "vases" or supply.size() >= int(settings.conveyor_capacity):
		return
	_supply_remaining -= delta
	if _supply_remaining > 0.0:
		return
	_supply_remaining += float(settings.conveyor_interval)
	var weights: Array = [85, 15] if rules_mode == "bowling" else ([20, 20, 15, 20, 10, 5, 10] if stage_number == 1 else [20, 15, 15, 10, 15, 15, 10])
	if AdventureLevels.SUPPLY_WEIGHTS.has(level_number):
		weights = AdventureLevels.SUPPLY_WEIGHTS[level_number].duplicate()
	var choices := available_plants()
	var total := 0
	for index in weights.size():
		# Later conveyor levels taper bases and duplicate stock, as in the source.
		if level_number >= 21:
			var kind: String = choices[index]
			var in_stock := supply.count(kind)
			var placed := 0
			for plant: StagePlant in live_plants():
				if plant.plant_kind == kind:
					placed += 1
			if kind in ["lily_pad", "flower_pot"]:
				var limit := 18 if kind == "lily_pad" else 35
				weights[index] = maxi(1, roundi(lerpf(float(weights[index]), 1.0, clampf(float(placed + in_stock) / limit, 0, 1))))
			if rules_mode == "boss" and kind in ["melon_pult", "kernel_pult", "cabbage_pult"]:
				var empty := 0
				for cell: Vector2i in world_rules.bases:
					if not _occupied.has(cell):
						empty += 1
				weights[index] = maxi(1, int(weights[index]) / (5 if empty <= 2 else (3 if empty <= 5 else 1)))
			if in_stock >= 4:
				weights[index] = 1
			elif in_stock >= 3:
				weights[index] = 5
			elif kind == _last_supply_kind:
				weights[index] = maxi(1, int(weights[index]) / 2)
		if choices[index] == "grave_buster" and _graves.is_empty():
			weights[index] = 0
		elif choices[index] == "lily_pad" and world_rules.bases.size() >= lawn.water_rows.size() * lawn.column_count:
			weights[index] = 0
		elif choices[index] == "flower_pot" and world_rules.bases.size() >= lawn.row_count * lawn.column_count:
			weights[index] = 0
		total += int(weights[index])
	var pick := _random.randi_range(1, total)
	for index in weights.size():
		pick -= weights[index]
		if pick <= 0:
			supply.append(choices[index])
			_last_supply_kind = choices[index]
			return


func whack_at_screen(at: Vector2) -> bool:
	if state != State.PLAYING or rules_mode != "whack" or selected_kind != "hammer":
		return false
	_hand.swing()
	var start := _camera.project_ray_origin(at)
	var query := PhysicsRayQueryParameters3D.create(start, start + _camera.project_ray_normal(at) * _camera.far, 1 | 4 | 32 | 256)
	query.exclude = [_dave.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var enemy := hit.get("collider") as StageZombie
	if enemy == null or not enemy.is_alive():
		return false
	enemy.receive_hit(int(settings.whack_damage), Vector3.RIGHT)
	return true


func _build_mowers() -> void:
	for row in active_rows:
		var mower := AdventureMower.new()
		mower.name = "Mower%d" % row
		mower.stage = self
		mower.row = row
		mower.speed = float(settings.mower_speed)
		mower.position = lawn.cell_to_local(row, 0) + Vector3.LEFT * 1.55
		$Mowers.add_child(mower)
		_mowers[row] = mower


func plant_at(kind: String, cell: Vector2i) -> bool:
	if state != State.PLAYING:
		return false
	var reason := placement_error(kind, cell)
	if not reason.is_empty():
		_notice(reason)
		return false
	if rules_mode == "bowling":
		var nut := AdventureBowlingNut.new()
		nut.stage = self
		nut.explosive = kind == "explosive_nut"
		nut.position = lawn.cell_to_local(cell.y, cell.x)
		projectiles.add_child(nut)
	else:
		_create_plant(kind, cell)
	if uses_supply():
		supply.erase(kind)
	else:
		sun_value -= seed_cost(kind)
		cooldowns[kind] = float(settings.card_cooldowns[kind])
	_first_plant = true
	select_plant("")
	_update_interface()
	return true


func _create_plant(kind: String, cell: Vector2i) -> AdventurePlant:
	var plant := AdventurePlant.new()
	plant.name = "Plant_%d_%d_%s" % [cell.y, cell.x, kind]
	plant.plant_kind = kind
	plant.stage = self
	plant.sleeping = kind in StageCatalog.MUSHROOMS and not AdventureLevels.is_night(level_number)
	plant.position = lawn.cell_to_local(cell.y, cell.x)
	if world_rules.layer(kind) not in ["base", "shell"] and world_rules.bases.has(cell):
		plant.position.y += 0.22
	world_rules.register_plant(cell, plant)
	plant.defeated.connect(_remove_plant.bind(cell, plant))
	_plants.add_child(plant)
	return plant


func available_plants() -> Array[String]:
	return AdventureLevels.plants(level_number)


func uses_supply() -> bool:
	return rules_mode in ["bowling", "conveyor", "mini", "vases", "bungee", "boss"]


func seed_cost(kind: String) -> int:
	return 0 if uses_supply() else int(GameConfiguration.current().section("stages.plants." + kind).get("sun_cost", 0))


func seed_ready(kind: String) -> bool:
	return supply.has(kind) if uses_supply() else float(cooldowns.get(kind, 0.0)) <= 0.0 and sun_value >= seed_cost(kind)


func placement_error(kind: String, cell: Vector2i) -> String:
	if not kind in available_plants():
		return "这张植物卡牌尚未解锁。"
	if not lawn.is_valid_cell(cell.y, cell.x) or not cell.y in active_rows:
		return "只能在绿色草坪上种植。"
	if rules_mode == "bowling" and cell.x > 2:
		return "在左侧三列投出坚果。"
	if _craters.has(cell):
		return "毁灭菇的弹坑尚未恢复。"
	if kind == "grave_buster" and not _graves.has(cell):
		return "墓碑吞噬者只能种在墓碑上。"
	if kind != "grave_buster" and _graves.has(cell):
		return "墓碑占据了这个格子。"
	var terrain_error := world_rules.planting_error(kind, cell)
	if not terrain_error.is_empty():
		return terrain_error
	if uses_supply():
		return "传送带还没有这张卡牌。" if not supply.has(kind) else ""
	if float(cooldowns.get(kind, 0.0)) > 0.0:
		return "卡牌还在冷却，请稍等。"
	if sun_value < seed_cost(kind):
		return "阳光不足：需要 %d 点阳光。" % seed_cost(kind)
	return ""


func _remove_plant(cell: Vector2i, plant: AdventurePlant) -> void:
	world_rules.remove_plant(cell, plant)
	plant.queue_free()


func can_use_shovel() -> bool:
	return level_number >= 5 or AdventureProgress.current().has_completed(4)


func shovel_at(cell: Vector2i) -> bool:
	if state != State.PLAYING or not can_use_shovel():
		return false
	var plant := world_rules.shovel_target(cell)
	if not is_instance_valid(plant):
		return false
	plant._consume()
	_hand.swing()
	return true


func select_plant(kind: String) -> void:
	if not state in [State.PLAYING, State.SELECTING]:
		return
	if kind == "shovel" and not can_use_shovel():
		_notice("通关 1-4 后获得铲子。")
		return
	if kind == "hammer" and rules_mode != "whack":
		return
	if not kind.is_empty() and not kind in ["shovel", "hammer"] and not kind in available_plants():
		return
	if not kind.is_empty() and not kind in ["shovel", "hammer"] and not seed_ready(kind):
		_notice("传送带库存、阳光或冷却暂不满足使用条件。")
		return
	selected_kind = kind
	if state == State.SELECTING:
		state = State.PLAYING
		_clear_overlay()
		_set_combat_processing(true)
	_hand.equip(selected_kind)
	if is_instance_valid(_ghost):
		_cursor.remove_child(_ghost)
		_ghost.queue_free()
		_ghost = null
	if not selected_kind.is_empty() and not selected_kind in ["shovel", "hammer"]:
		_ghost = Node3D.new()
		_cursor.add_child(_ghost)
		StageModels.plant(_ghost, selected_kind)
		for mesh: MeshInstance3D in _ghost.find_children("*", "MeshInstance3D", true, false):
			# Explicit alpha materials also render correctly in Compatibility.
			var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 0.45
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.hide()
	_update_interface()


func open_plant_picker() -> void:
	if state != State.PLAYING or not selected_kind.is_empty():
		return
	state = State.SELECTING
	_set_combat_processing(false)
	var column := _overlay_column("选择右手的植物", "世界时间已暂停 · 选择后继续游戏，左键使用")
	var choices := available_plants()
	var scroll := ScrollContainer.new()
	var rows := ceili(choices.size() / 6.0)
	scroll.custom_minimum_size = Vector2(740, minf(rows * 130 - 12, minf(375, get_viewport().get_visible_rect().size.y - 280)))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var cards := GridContainer.new()
	cards.columns = 6
	cards.add_theme_constant_override("separation", 12)
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 12)
	scroll.add_child(cards)
	_cards.clear()
	for index in choices.size():
		var kind: String = choices[index]
		var card := AdventureSeedCard.new()
		card.plant_kind = kind
		card.number = index + 1
		card.cost = seed_cost(kind)
		card.pressed.connect(select_plant.bind(kind))
		cards.add_child(card)
		_cards[kind] = card
	GameUI.label(column, "1–9 选择前九张 · 其余点击选择 · " + ("放下才消耗库存" if uses_supply() else "阳光不足或冷却中不可选"), 16, GameUI.MUTED)
	GameUI.button(column, "返回空手 [右键 / Esc]", select_plant.bind(""), Color("596044"))
	_update_interface()


func cycle_tool() -> void:
	if state != State.PLAYING:
		return
	if rules_mode == "whack":
		select_plant("hammer" if selected_kind.is_empty() else ("shovel" if selected_kind == "hammer" else ""))
	else:
		select_plant("shovel" if selected_kind.is_empty() else "")


func live_plants() -> Array[StagePlant]:
	var result: Array[StagePlant] = []
	for plant: StagePlant in _plants.get_children():
		if plant.is_alive():
			result.append(plant)
	return result


func live_enemies() -> Array[StageZombie]:
	var result: Array[StageZombie] = []
	for enemy: StageZombie in _enemies.get_children():
		if enemy.is_alive():
			result.append(enemy)
	return result


func spawn_enemy(kind: String, row: int) -> StageZombie:
	if not row in active_rows or state != State.PLAYING:
		return null
	var sled_member := kind == "bobsled_member"
	if sled_member:
		kind = "bobsled_team"
	var water_form := ""
	if not lawn.water_rows.is_empty():
		var legal: Array[int] = []
		for candidate in active_rows:
			if (candidate in lawn.water_rows) == (kind in StageCatalog.WATER_ENEMIES):
				legal.append(candidate)
		if kind in ["zombie", "conehead_zombie", "buckethead_zombie", "flag_zombie"] and row in lawn.water_rows:
			water_form = kind
		elif not row in legal:
			row = legal[_random.randi_range(0, legal.size() - 1)]
	if kind == "bobsled_team" and not sled_member and world_rules.ice.is_empty():
		kind = "zomboni"
	elif kind == "bobsled_team" and not sled_member:
		var tracks: Array = world_rules.ice.keys()
		row = (tracks[_random.randi_range(0, tracks.size() - 1)] as Vector2i).y
	var base := kind if kind in ["conehead_zombie", "buckethead_zombie", "pole_vaulting_zombie", "newspaper_zombie"] else "zombie"
	var enemy := (load("res://scenes/enemies/" + base + ".tscn") as PackedScene).instantiate()
	enemy.set_script(load("res://scripts/adventure_boss.gd" if kind == "zomboss" else "res://scripts/adventure_zombie.gd"))
	_spawn_serial += 1
	enemy.name = "Zombie%d" % _spawn_serial
	enemy.set("enemy_kind", "ducky_tube_zombie" if not water_form.is_empty() else kind)
	enemy.set("stage", self)
	if sled_member:
		enemy.set_meta("summoned", true)
	enemy.position = lawn.cell_to_local(row, 8) + Vector3.RIGHT * lawn.cell_size
	enemy.rotation.y = PI * 0.5
	_enemies.add_child(enemy)
	var actor := enemy as StageZombie
	actor.configure_debris($Debris)
	actor._label.hide()
	actor.defeated.connect(_enemy_defeated.bind(actor))
	if not water_form.is_empty():
		(actor as AdventureZombie).configure_water_armor(water_form)
	if rules_mode == "mini":
		(actor as AdventureZombie).configure_mini()
	if kind == "bobsled_team" and not sled_member:
		for member in 3:
			var summon := spawn_summoned("bobsled_member", actor.global_position + Vector3.RIGHT * (member + 1) * 0.8)
			if summon != null:
				summon.set_meta("sled_member", true)
	return actor


func _enemy_defeated(enemy: StageZombie) -> void:
	if enemy.enemy_kind == "zomboss":
		world_rules.boss = null
		for projectile: Node in projectiles.get_children():
			if projectile is AdventureBossBall:
				projectile.queue_free()
	if not enemy.get_meta("escaped", false):
		kills += 1
	if rules_mode == "whack":
		spawn_plant_sun(enemy.global_position, int(settings.whack_sun_value))
	enemy.queue_free()


func hostile_enemies() -> Array[StageZombie]:
	return live_enemies().filter(func(enemy: StageZombie) -> bool: return not enemy.hypnotized)


func spawn_summoned(kind: String, at: Vector3) -> StageZombie:
	var cell := lawn.world_to_cell(at)
	# Sled members start just beyond the right edge, in their leader's valid lane.
	if kind == "bobsled_member":
		cell.y = clampi(roundi((at.z - lawn.global_position.z) / lawn.cell_size + (lawn.row_count - 1) * 0.5), 0, lawn.row_count - 1)
	if (cell.x < 0 and kind != "bobsled_member") or not cell.y in active_rows or cell.y in lawn.water_rows or live_enemies().size() >= 64:
		return null
	var enemy := spawn_enemy(kind, cell.y)
	if enemy != null:
		enemy.global_position = Vector3(at.x, lawn.surface_at(at), at.z)
		enemy.set_meta("summoned", true)
	return enemy


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	for kind: String in cooldowns:
		cooldowns[kind] = maxf(0.0, float(cooldowns[kind]) - delta)
	_update_sun(delta)
	_update_supply(delta)
	_update_craters(delta)
	world_rules.update(delta)
	_update_waves(delta)
	_check_breaches()
	var finished := not is_instance_valid(world_rules.boss) if rules_mode == "boss" else wave_index == AdventureLevels.WAVE_COUNTS[level_number - 1]
	if state == State.PLAYING and rules_mode != "vases" and finished and _spawn_queue.is_empty() and hostile_enemies().is_empty():
		_finish(true)


func _update_sun(delta: float) -> void:
	if AdventureLevels.is_night(level_number) or uses_supply():
		return
	if level_number == 1 and not _first_plant:
		return
	_sun_remaining -= delta
	if _sun_remaining > 0:
		return
	_sun_count += 1
	_sun_remaining = minf(float(settings.sun_max_interval), float(settings.sun_base_interval) + _sun_count * float(settings.sun_interval_growth)) + _random.randf_range(0, settings.sun_interval_jitter)
	var row: int = active_rows[_random.randi_range(0, active_rows.size() - 1)]
	var column := _random.randi_range(0, 8)
	var at := lawn.cell_to_world(row, column)
	var sun := _spawn_sun(at + Vector3.UP * float(settings.sun_radius) * 1.08, int(settings.sun_value), 7.0)
	sun.radius = float(settings.sun_radius)


func _update_waves(delta: float) -> void:
	if rules_mode in ["vases", "boss"] or state != State.PLAYING:
		return
	if level_number == 1 and not _first_plant:
		return
	_spawn_remaining -= delta
	if not _spawn_queue.is_empty() and _spawn_remaining <= 0:
		var row: int = active_rows[_row_cursor % active_rows.size()]
		var enemy := spawn_enemy(_spawn_queue.pop_front(), row)
		if rules_mode == "whack":
			var graves := grave_cells()
			var cell := graves[_random.randi_range(0, graves.size() - 1)] if not graves.is_empty() else Vector2i(_random.randi_range(5, 8), row)
			enemy.global_position = lawn.cell_to_world(cell.y, cell.x)
			(enemy as AdventureZombie).emergence_remaining = 0.6
			enemy._base_speed *= 2.0
		_row_cursor += 1
		_spawn_remaining = 0.8
	if wave_index >= AdventureLevels.WAVE_COUNTS[level_number - 1]:
		return
	_wave_remaining -= delta
	_wave_elapsed += delta
	if _flag_warning >= 0:
		_flag_warning -= delta
		if _flag_warning <= 0:
			_flag_warning = -1.0
			_dispatch_wave()
		return
	var cleared := wave_index > 0 and _spawn_queue.is_empty() and hostile_enemies().is_empty() and _wave_elapsed >= float(settings.minimum_wave_gap)
	if _wave_remaining <= 0 or cleared:
		if level_number > 1 and wave_index == AdventureLevels.WAVE_COUNTS[level_number - 1] - 1:
			_flag_warning = float(settings.flag_warning_duration)
			_notice("一大波僵尸即将来袭！", float(settings.flag_warning_duration))
		else:
			_dispatch_wave()


func _dispatch_wave() -> void:
	_spawn_queue.append_array(AdventureLevels.wave(level_number, wave_index, _random))
	wave_index += 1
	_wave_elapsed = 0.0
	_wave_remaining = float(settings.wave_interval) + _random.randf_range(0, settings.wave_interval_range)
	_spawn_remaining = 0.0
	if stage_number == 2 and rules_mode != "whack" and wave_index == AdventureLevels.WAVE_COUNTS[level_number - 1]:
		for cell: Vector2i in grave_cells():
			var enemy := spawn_enemy("conehead_zombie" if level_number > 11 and _random.randf() < 0.35 else "zombie", cell.y)
			enemy.global_position = lawn.cell_to_world(cell.y, cell.x)
			(enemy as AdventureZombie).emergence_remaining = 0.6
		_notice("最后一波！剩余墓碑里冒出了僵尸。", 5.0)
	if not lawn.water_rows.is_empty() and wave_index == AdventureLevels.WAVE_COUNTS[level_number - 1]:
		for row in lawn.water_rows:
			for column in [6, 8]:
				var enemy := spawn_enemy("zombie", row)
				enemy.global_position = lawn.cell_to_world(row, column)
				(enemy as AdventureZombie).emergence_remaining = 0.6
		_notice("最后一波！水池里冒出了僵尸。", 5.0)
	if level_number in [43, 44, 46, 48] and wave_index == AdventureLevels.WAVE_COUNTS[level_number - 1]:
		for row in [0, 2, 4]:
			spawn_enemy("bungee_zombie", row)


func _check_breaches() -> void:
	var boundary := lawn.cell_to_world(2, 0).x
	for enemy: StageZombie in live_enemies():
		if enemy.hypnotized:
			continue
		if enemy._underground or (-enemy.global_basis.z).x > 0.1 or enemy.enemy_kind in ["bungee_zombie", "zomboss"]:
			continue
		if enemy.global_position.x > boundary - 0.50:
			continue
		var row := clampi(int(round((enemy.global_position.z - lawn.global_position.z) / lawn.cell_size + (lawn.row_count - 1) * 0.5)), 0, lawn.row_count - 1)
		var mower := _mowers.get(row) as AdventureMower
		if mower != null and not mower.spent and not enemy.is_flying():
			mower.trigger()
			_notice("割草机启动！这条路径只剩最后一次保护。")
		if enemy.global_position.x < boundary - 2.1:
			_finish(false)
			return


func spawn_plant_sun(at: Vector3, value: int) -> SunPickup:
	return _spawn_sun(at + Vector3(0.45, 0.42, 0.15), value, 0.8)


func _spawn_sun(landing: Vector3, value: int, height: float) -> SunPickup:
	var sun := SunSystem.SUN_SCENE.instantiate() as SunPickup
	sun.value = value
	sun.radius = float(settings.sun_radius)
	sun.fall_speed = float(GameConfiguration.current().section("sun").fall_speed)
	sun.lifetime = float(GameConfiguration.current().section("sun").lifetime)
	sun.landing_position = landing
	sun.position = landing + Vector3.UP * height
	sun.collected.connect(_collect_sun)
	_suns.add_child(sun)
	return sun


func _collect_sun(value: int) -> void:
	if state == State.PLAYING:
		sun_value += value
		_update_interface()


func effect(at: Vector3, color: Color, radius: float) -> void:
	var flash := StageModels.sphere(_effects, "Explosion", Vector3.ONE * 0.2, at, Color(color, 0.5))
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * radius * 2.0, 0.25)
	tween.parallel().tween_property(flash, "transparency", 1.0, 0.5)
	tween.tween_callback(flash.queue_free)


func first_plant_in_lane(z: float) -> StagePlant:
	var result: StagePlant
	for plant: StagePlant in live_plants():
		if world_rules.layer(plant.plant_kind) in ["base", "coffee", "shell"]:
			continue
		if absf(plant.global_position.z - z) < lawn.cell_size * 0.45 and (result == null or plant.global_position.x < result.global_position.x):
			result = plant
	return result


func is_umbrella_protected(at: Vector3) -> bool:
	for plant: StagePlant in live_plants():
		if plant.plant_kind == "umbrella_leaf" and absf(plant.global_position.x - at.x) <= lawn.cell_size * 1.05 and absf(plant.global_position.z - at.z) <= lawn.cell_size * 1.05:
			return true
	return false


func move_to_adjacent_lane(enemy: StageZombie) -> void:
	var row := lawn.world_to_cell(enemy.global_position).y
	var choices: Array[int] = []
	for candidate in [row - 1, row + 1]:
		if candidate in active_rows and not candidate in lawn.water_rows:
			choices.append(candidate)
	if not choices.is_empty():
		enemy.global_position.z = lawn.cell_to_world(choices[_random.randi_range(0, choices.size() - 1)], 0).z


func clear_fog(duration: float) -> void:
	world_rules.clear_fog(duration)


func add_ice(cell: Vector2i) -> void:
	world_rules.add_ice(cell)


func clear_ice(row: int) -> void:
	world_rules.clear_ice(row)


func add_coins(value: int, at: Vector3) -> void:
	world_rules.coins += value
	var label := StageModels.label(_effects, "+%d 金币" % value, at + Vector3.UP * 1.6, GameUI.GOLD)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.3, 1.3)
	tween.tween_callback(label.queue_free)


func cell_at_screen(position: Vector2) -> Vector2i:
	var start := _camera.project_ray_origin(position)
	var direction := _camera.project_ray_normal(position)
	if stage_number == 5:
		var roof_query := PhysicsRayQueryParameters3D.create(start, start + direction * _camera.far, 1 | 4 | 256 | 512)
		roof_query.exclude = [_dave.get_rid()]
		var roof_hit := get_world_3d().direct_space_state.intersect_ray(roof_query)
		if roof_hit.is_empty() or roof_hit.collider is StageZombie:
			return Vector2i(-1, -1)
		return lawn.world_to_cell(roof_hit.position)
	if direction.y >= -0.001:
		return Vector2i(-1, -1)
	var point: Variant = Plane(Vector3.UP, lawn.global_position.y + lawn.surface_height).intersects_ray(start, direction)
	if not point is Vector3 or start.distance_to(point) > _camera.far:
		return Vector2i(-1, -1)
	# Plants still reveal their occupied cell; solid scenery and zombies block it.
	var query := PhysicsRayQueryParameters3D.create(start, point, 1 | 4 | 256 | 512)
	query.exclude = [_dave.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and start.distance_to(hit.position) < start.distance_to(point) - 0.08:
		if (hit.collider as Node).has_meta("adventure_grave"):
			return hit.collider.get_meta("adventure_grave") as Vector2i
		if (hit.collider as Node).has_meta("adventure_vase"):
			return hit.collider.get_meta("adventure_vase") as Vector2i
		return Vector2i(-1, -1)
	return lawn.world_to_cell(point)


func aim_position(cursor_position: Vector2) -> Vector2:
	return get_viewport().get_visible_rect().get_center() if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else cursor_position


func collect_at_screen(position: Vector2) -> bool:
	if state != State.PLAYING:
		return false
	var start := _camera.project_ray_origin(position)
	var query := PhysicsRayQueryParameters3D.create(start, start + _camera.project_ray_normal(position) * _camera.far, 1 | 4 | 32 | 256 | 512 | SunPickup.PICKUP_LAYER)
	query.collide_with_areas = true
	query.exclude = [_dave.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var sun := hit.get("collider") as SunPickup
	if sun == null:
		return false
	sun.collect()
	return true


func _input(event: InputEvent) -> void:
	# The modal consumes mouse input, so cancellation is handled before GUI input.
	if state == State.SELECTING:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			select_plant("")
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			select_plant("")
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if state == State.SELECTING:
				select_plant("")
			else:
				set_paused(state != State.PAUSED)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			retry_requested.emit()
			get_viewport().set_input_as_handled()
		elif state == State.SELECTING:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				var index: int = event.keycode - KEY_1
				var choices := available_plants()
				if index < choices.size():
					select_plant(choices[index])
				get_viewport().set_input_as_handled()
	if state != State.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if selected_kind.is_empty():
				open_plant_picker()
			else:
				select_plant("")
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			cycle_tool()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var at := aim_position(event.position)
			if not collect_at_screen(at):
				var cell := cell_at_screen(at)
				if selected_kind == "hammer":
					whack_at_screen(at)
				elif rules_mode == "vases" and selected_kind in ["", "shovel"] and world_rules.vases.has(cell_at_screen(at)):
					world_rules.break_vase(cell_at_screen(at))
				elif selected_kind == "shovel":
					_hand.swing()
					shovel_at(cell)
				elif not selected_kind.is_empty():
					plant_at(selected_kind, cell)
			_dave.set_interface_open(false)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _hint_remaining > 0 and state == State.PLAYING:
		_hint_remaining = maxf(0, _hint_remaining - delta)
		if _hint_remaining == 0:
			_hint_label.text = AdventureLevels.HINTS[level_number - 1]
	_update_interface()
	_update_placement_preview(aim_position(get_viewport().get_mouse_position()))


func _update_placement_preview(at: Vector2) -> void:
	if not is_instance_valid(_cursor):
		return
	if state != State.PLAYING or selected_kind.is_empty() or selected_kind == "hammer":
		_cursor.hide()
		return
	var cell := cell_at_screen(at)
	_cursor.visible = lawn.is_valid_cell(cell.y, cell.x) and cell.y in active_rows
	if _cursor.visible:
		_cursor.position = lawn.cell_to_local(cell.y, cell.x)
		if is_instance_valid(_ghost):
			_ghost.position.y = 0.22 if world_rules.bases.has(cell) and world_rules.layer(selected_kind) not in ["base", "shell"] else 0.0
		var valid := is_instance_valid(world_rules.shovel_target(cell)) if selected_kind == "shovel" else placement_error(selected_kind, cell).is_empty()
		_cursor_mesh.material_override = StageModels.material(Color(0.66, 0.86, 0.40, 0.42) if valid else Color(0.90, 0.34, 0.25, 0.45))


func _notice(value: String, duration: float = 3.0) -> void:
	_hint_label.text = value
	_hint_remaining = duration


func _set_combat_processing(enabled: bool) -> void:
	for container: Node in [$Plants, $Enemies, $Projectiles, $SunSystem, $Mowers, $Debris, $Effects, $Decor]:
		container.process_mode = Node.PROCESS_MODE_PAUSABLE
	_dave.process_mode = Node.PROCESS_MODE_PAUSABLE
	_dave.set_interface_open(not enabled)
	# SceneTree pause also freezes rigid bodies and bound tweens, not just timers.
	get_tree().paused = not enabled
	if not enabled:
		_cursor.hide()


func set_paused(paused: bool) -> void:
	if is_instance_valid(world_rules) and world_rules.waiting_group:
		return
	if not state in [State.PLAYING, State.PAUSED]:
		return
	state = State.PAUSED if paused else State.PLAYING
	_set_combat_processing(not paused)
	if paused:
		_show_overlay("游戏已暂停", "你的防线会等你回来。", false)
	else:
		_clear_overlay()
	_update_interface()


func _finish(victory: bool) -> void:
	if state != State.PLAYING:
		return
	state = State.WON if victory else State.LOST
	_set_combat_processing(false)
	if victory:
		AdventureProgress.current().complete(level_number)
		var continuation := "下一关：" + AdventureLevels.code(level_number + 1) if level_number < AdventureLevels.LEVEL_COUNT else "僵王已击败！可返回选关挑战其他关卡。"
		if AdventureProgress.current().completed_count() == AdventureLevels.LEVEL_COUNT:
			continuation = "冒险五十关全部完成！可返回选关重玩。"
		var detail := "获得奖励：%s\n%s" % [AdventureLevels.reward_name(level_number), continuation]
		if AdventureLevels.REWARDS[level_number - 1] == "note":
			detail += "\n僵尸便条：我们会在最后一关发起总攻！"
		elif level_number == 14:
			detail += "\n主界面已开放植物与僵尸图鉴。"
		_show_overlay("%s 关卡完成！" % AdventureLevels.code(level_number), detail, true)
	else:
		_show_overlay("僵尸进入了你的房子", "调整植物布局，再守一次庭院吧。", false)
	level_finished.emit(level_number, victory)


func begin_close() -> void:
	state = State.CLOSING
	_spawn_queue.clear()
	_set_combat_processing(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "AdventureHUD"
	add_child(canvas)
	_ui_root = GameUI.full_rect(canvas)
	var top := HBoxContainer.new()
	top.position = Vector2(18, 16)
	top.add_theme_constant_override("separation", 10)
	_ui_root.add_child(top)
	var sun_panel := GameUI.panel(top)
	sun_panel.custom_minimum_size = Vector2(140, 118)
	var sun_text := VBoxContainer.new()
	sun_panel.add_child(sun_text)
	GameUI.label(sun_text, "罐子植物卡" if rules_mode == "vases" else ("免费供应" if uses_supply() else "☀ 阳光"), 19, GameUI.GOLD)
	_sun_label = GameUI.label(sun_text, "50", 36)
	var tool_panel := GameUI.panel(top)
	var tool_text := VBoxContainer.new()
	tool_panel.add_child(tool_text)
	_tool_label = GameUI.label(tool_text, "右手：空手", 23, GameUI.GOLD)
	GameUI.label(tool_text, "滚轮：空手 / 木锤 / 铲子" if rules_mode == "whack" else "滚轮切换空手 / 铲子", 17)
	GameUI.label(tool_text, "空手右键选植物 · 左键使用", 17)
	var right := VBoxContainer.new()
	_ui_root.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -300
	right.offset_right = -18
	right.offset_top = 16
	var actions := HBoxContainer.new()
	right.add_child(actions)
	GameUI.button(actions, "暂停", set_paused.bind(true), Color("48583b"), Vector2(120, 42))
	GameUI.button(actions, "主界面", func() -> void: menu_requested.emit(), Color("48583b"), Vector2(120, 42))
	var wave_panel := GameUI.panel(right)
	var wave_text := VBoxContainer.new()
	wave_panel.add_child(wave_text)
	GameUI.label(wave_text, "冒险  %s · %s" % [AdventureLevels.code(level_number), AdventureLevels.TITLES[level_number - 1]], 17)
	_wave_label = GameUI.label(wave_text, "准备防线", 16, GameUI.GOLD)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(240, 12)
	_progress.add_theme_stylebox_override("background", GameUI.style(Color("263b28"), Color("263b28"), 4))
	_progress.add_theme_stylebox_override("fill", GameUI.style(Color("8cab50"), Color("8cab50"), 4))
	wave_text.add_child(_progress)
	GameUI.label(right, "铲子：通关 1-4 后解锁" if not can_use_shovel() else "铲子可用 · 不退还阳光", 17, GameUI.MUTED)
	if uses_supply():
		var belt := GameUI.panel(_ui_root)
		belt.position = Vector2(18, 145)
		belt.custom_minimum_size = Vector2(minf(650, get_viewport().get_visible_rect().size.x - 350), 76)
		var belt_text := VBoxContainer.new()
		belt.add_child(belt_text)
		GameUI.label(belt_text, ("砸罐所得" if rules_mode == "vases" else "传送带库存") + " · 空手右键选择 · 成功使用才消耗", 17, GameUI.GOLD)
		_supply_label = GameUI.label(belt_text, "", 15)
		_supply_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crosshair = GameUI.label(_ui_root, "+", 24)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -10
	_crosshair.offset_right = 10
	_crosshair.offset_top = -17
	_crosshair.offset_bottom = 17
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var footer := GameUI.panel(_ui_root, Color(0.08, 0.15, 0.09, 0.94))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 18
	footer.offset_right = -18
	footer.offset_top = -104
	footer.offset_bottom = -14
	var bottom := VBoxContainer.new()
	footer.add_child(bottom)
	_hint_label = GameUI.label(bottom, AdventureLevels.HINTS[level_number - 1], 20)
	GameUI.label(bottom, "WASD 移动 · 鼠标瞄准 · 空手右键选植物（暂停）· 左键种植 / 铲除 / 收阳光 · Esc 暂停 · R 重试 · F1 主界面", 15, Color("e9f0d5"))


func _update_interface() -> void:
	if not is_instance_valid(_sun_label):
		return
	_sun_label.text = "%d 张" % supply.size() if uses_supply() else str(sun_value)
	if is_instance_valid(_supply_label):
		var names: Array[String] = []
		for kind: String in available_plants():
			var count := supply.count(kind)
			if count > 0:
				names.append("%s×%d" % [StageCatalog.plant_name(kind), count])
		_supply_label.text = "  ".join(names) if not names.is_empty() else ("砸开罐子，获得植物卡。" if rules_mode == "vases" else "等待下一张卡牌…")
	for kind: String in _cards:
		var card := _cards[kind] as AdventureSeedCard
		if not is_instance_valid(card):
			continue
		card.remaining = float(cooldowns.get(kind, 0))
		card.selected = selected_kind == kind
		card.supply_count = supply.count(kind) if uses_supply() else -1
		card.disabled = state != State.SELECTING or not seed_ready(kind)
		card.queue_redraw()
	_tool_label.text = "右手：" + ("空手" if selected_kind.is_empty() else ("铲子" if selected_kind == "shovel" else StageCatalog.plant_name(selected_kind)))
	_crosshair.visible = state == State.PLAYING and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_wave_label.text = "第 %d / %d 波  ·  敌人 %d" % [wave_index, AdventureLevels.WAVE_COUNTS[level_number - 1], hostile_enemies().size()]
	if wave_index == 0:
		_wave_label.text = "种下第一株豌豆后开始" if level_number == 1 and not _first_plant else "准备防线 · %d 秒" % int(ceil(_wave_remaining))
	if is_instance_valid(world_rules) and rules_mode == "vases":
		_wave_label.text = "第 %d / 3 组 · 剩 %d 罐 · 敌人 %d" % [world_rules.vase_group, world_rules.vases.size(), hostile_enemies().size()]
		_progress.value = world_rules.vase_group / 3.0 * 100
	elif is_instance_valid(world_rules) and rules_mode == "boss":
		var boss := world_rules.boss
		_wave_label.text = "僵王 %d HP · %s" % [boss.health, "伸头中" if boss.exposed else "等待伸头"] if is_instance_valid(boss) else "清除剩余僵尸"
		_progress.value = (1 - float(boss.health) / boss.maximum_health) * 100 if is_instance_valid(boss) else 100
	_progress.value = float(wave_index) / AdventureLevels.WAVE_COUNTS[level_number - 1] * 100.0


func _clear_overlay() -> void:
	_cards.clear()
	if is_instance_valid(_overlay):
		_overlay.hide()
		_overlay.queue_free()
		_overlay = null


func _overlay_column(title: String, detail: String) -> VBoxContainer:
	_clear_overlay()
	_overlay = GameUI.full_rect(_ui_root)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.08, 0.04, 0.76)
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := GameUI.panel(center)
	panel.custom_minimum_size = Vector2(530, 360)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	GameUI.label(column, title, 32, GameUI.GOLD)
	GameUI.label(column, detail, 19)
	return column


func _show_overlay(title: String, detail: String, victory: bool) -> void:
	var column := _overlay_column(title, detail)
	if state == State.PAUSED:
		GameUI.button(column, "继续游戏", set_paused.bind(false))
	elif victory and level_number < AdventureLevels.LEVEL_COUNT:
		GameUI.button(column, "继续 " + AdventureLevels.code(level_number + 1), func() -> void: next_requested.emit(level_number + 1))
	GameUI.button(column, "重新挑战", func() -> void: retry_requested.emit(), Color("596044"))
	var row := HBoxContainer.new()
	column.add_child(row)
	GameUI.button(row, "返回选关", func() -> void: levels_requested.emit(), Color("47563b"), Vector2(235, 44))
	GameUI.button(row, "返回主界面", func() -> void: menu_requested.emit(), Color("47563b"), Vector2(235, 44))
