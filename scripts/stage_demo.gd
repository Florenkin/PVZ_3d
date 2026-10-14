class_name StageDemo
extends Node3D
## One independent scene per adventure area, with a cumulative fixed roster.

@export_range(1, 5) var stage_number: int = 1
@export var auto_respawn_enabled: bool = true
@export var respawn_delay: float = 1.0
var idle_enabled: bool = true
var lawn: StageLawn
var projectiles: Node3D
var settings: Dictionary
var coins: int = 0
var _plants: Node3D
var _enemies: Node3D
var _effects: Node3D
var _dave: CrazyDave
var _orbit: Node3D
var _sun_system: SunSystem
var _overview: bool = false
var _sidebar_open: bool = false
var _sidebar: PanelContainer
var _stats: Label
var _status: Label
var _reticle: Label
var _pending: Array[Dictionary] = []
var _plant_slots: Array[Dictionary] = []
var _enemy_slots: Array[Dictionary] = []
var _grave_locations: Array[Vector3] = []
var _ice: Dictionary = {}
var _fog: Node3D
var _fog_clear_remaining: float = 0.0
var _ui_elapsed: float = 0.0
var _closing: bool = false
var _summon_serial: int = 0
var _removed_plants: Dictionary = {}
var _tools: DemoTools


func _enter_tree() -> void:
	settings = GameConfiguration.current().section("stages")
	GameConfiguration.current().apply_scene(self)
	lawn = get_node("LawnGrid") as StageLawn
	var plant_keys := StageCatalog.plants_for_stage(stage_number)
	var aquatic_count := 0
	for kind: String in plant_keys:
		if kind in StageCatalog.AQUATIC:
			aquatic_count += 1
	var pool := StageCatalog.has_pool(stage_number)
	var count := plant_keys.size() - aquatic_count if pool else plant_keys.size()
	var rows := maxi(int(settings.minimum_rows), int(ceil(float(count) / float(settings.plant_columns))) + (2 if pool else 0))
	lawn.row_count_override = rows
	lawn.column_count_override = int(settings.board_columns)
	lawn.row_count = rows
	lawn.column_count = int(settings.board_columns)
	lawn.cell_size = float(GameConfiguration.current().section("lawn").cell_size)
	lawn.surface_height = float(GameConfiguration.current().section("lawn").surface_height)
	lawn.stage_number = stage_number
	if pool:
		lawn.water_rows = [rows / 2 - 1, rows / 2]
	var dry_rows: Array[int] = []
	for row in rows:
		if not row in lawn.water_rows:
			dry_rows.append(row)
	var dry_index := 0
	var water_index := 0
	for child: StagePlant in get_node("Plants").get_children():
		var row: int
		var column: int
		var display_only := child.plant_kind in StageCatalog.AQUATIC and not pool
		if child.plant_kind in StageCatalog.AQUATIC and pool:
			row = lawn.water_rows[water_index % 2]
			column = 1 + water_index / 2
			water_index += 1
		else:
			row = dry_rows[dry_index % dry_rows.size()]
			column = 1 + dry_index / dry_rows.size()
			dry_index += 1
		child.stage = self
		child.display_only = display_only
		child.sleeping = child.plant_kind in StageCatalog.MUSHROOMS and not StageCatalog.is_night(stage_number)
		child.position = lawn.cell_to_local(row, column)
		if stage_number == 5 and not display_only and child.plant_kind != "flower_pot":
			child.position.y += 0.38
		_plant_slots.append({"name": String(child.name), "kind": child.plant_kind, "position": child.position, "display_only": display_only})
	var land_index := 0
	var aquatic_index := 0
	for child: StageZombie in get_node("Enemies").get_children():
		var row: int
		var column: int = lawn.column_count - 1
		if child.enemy_kind in StageCatalog.WATER_ENEMIES and pool:
			row = lawn.water_rows[aquatic_index % 2]
			column -= aquatic_index / 2
			aquatic_index += 1
		else:
			row = dry_rows[land_index % dry_rows.size()]
			column -= land_index / dry_rows.size()
			land_index += 1
		child.stage = self
		child.position = lawn.cell_to_local(row, column)
		child.rotation.y = PI * 0.5
		_enemy_slots.append({"name": String(child.name), "kind": child.enemy_kind, "position": child.position})


func _ready() -> void:
	_plants = $Plants
	_enemies = $Enemies
	projectiles = $Projectiles
	_effects = $Effects
	_dave = $Characters/CrazyDave
	_orbit = $OrbitRig
	_sun_system = $SunSystem
	$Debris.add_to_group("combat_debris_container")
	for enemy: StageZombie in _enemies.get_children():
		enemy.configure_debris($Debris)
	_connect_actors()
	_spawn_bobsled_members()
	_sun_system.settings.medium_value = int(settings.sun_value)
	_sun_system.settings.enabled = bool(_sun_system.settings.enabled) and not StageCatalog.is_night(stage_number)
	_sun_system.configure(lawn)
	_dave.movement_bounds = Rect2(Vector2(-lawn.column_count * lawn.cell_size * 0.5, -lawn.row_count * lawn.cell_size * 0.5), Vector2(lawn.column_count, lawn.row_count) * lawn.cell_size)
	_dave.set_spawn(lawn.cell_to_world(lawn.row_count / 2, 0), -PI * 0.5)
	var house := get_node_or_null("House") as DaveHouse
	if house != null:
		house.position.x = -lawn.column_count * lawn.cell_size * 0.5 - float(house.settings.front_gap)
		_dave.configure_exploration(house.get_exploration_bounds())
	_orbit.default_size = maxf(lawn.row_count, lawn.column_count) * lawn.cell_size * 1.2
	_orbit.maximum_size = _orbit.default_size * 1.8
	_orbit.minimum_size = 6.0
	_orbit.distance = 65.0
	_orbit.default_yaw = 0.24
	_orbit.default_pitch = 0.87
	_orbit.target = Vector3(0, 0.5, 0)
	_orbit.reset_view()
	_apply_theme()
	_decorate_slots()
	_build_interface()
	_tools = DemoTools.new()
	_tools.name = "DemoTools"
	_tools.configure(self, _dave)
	add_child(_tools)
	_orbit.tool_wheel_active = true
	_set_overview(false)
	_sun_system.sun_value_changed.connect(func(_value: int) -> void: _update_interface())
	_update_interface()
	if "--stage-overview" in OS.get_cmdline_user_args():
		_set_overview(true)


func _connect_actors() -> void:
	for index in _plant_slots.size():
		var plant := _plants.get_node(NodePath(_plant_slots[index].name)) as StagePlant
		plant.defeated.connect(_schedule_respawn.bind(true, index))
	for index in _enemy_slots.size():
		var enemy := _enemies.get_node(NodePath(_enemy_slots[index].name)) as StageZombie
		enemy.defeated.connect(_schedule_respawn.bind(false, index))


func _schedule_respawn(is_plant: bool, index: int) -> void:
	if auto_respawn_enabled and not _closing and not (is_plant and _removed_plants.has(index)):
		_pending.append({"plant": is_plant, "index": index, "remaining": float(settings.plant_respawn_delay) if is_plant else respawn_delay})


func _physics_process(delta: float) -> void:
	if _closing:
		return
	for item: Dictionary in _pending:
		item.remaining -= delta
		if item.remaining <= 0.000001:
			_respawn(item.plant, item.index)
	_pending = _pending.filter(func(item: Dictionary) -> bool: return item.remaining > 0.000001)
	if _fog_clear_remaining > 0:
		_fog_clear_remaining = maxf(0, _fog_clear_remaining - delta)
		if is_instance_valid(_fog):
			_fog.visible = _fog_clear_remaining <= 0


func _respawn(is_plant: bool, index: int) -> void:
	if is_plant and _removed_plants.has(index):
		return
	var slot: Dictionary = _plant_slots[index] if is_plant else _enemy_slots[index]
	var container := _plants if is_plant else _enemies
	var previous := container.get_node_or_null(NodePath(slot.name))
	if previous != null:
		container.remove_child(previous)
		previous.queue_free()
	if is_plant:
		var plant := StagePlant.new()
		plant.name = slot.name
		plant.plant_kind = slot.kind
		plant.stage = self
		plant.display_only = slot.display_only
		plant.sleeping = plant.plant_kind in StageCatalog.MUSHROOMS and not StageCatalog.is_night(stage_number)
		plant.position = slot.position
		plant.defeated.connect(_schedule_respawn.bind(true, index))
		container.add_child(plant)
	else:
		var enemy := _make_enemy(slot.kind)
		enemy.name = slot.name
		enemy.position = slot.position
		enemy.rotation.y = PI * 0.5
		enemy.defeated.connect(_schedule_respawn.bind(false, index))
		container.add_child(enemy)
		enemy.configure_debris($Debris)
		if enemy.enemy_kind == "bobsled_team":
			_spawn_bobsled_members(enemy)


func _spawn_bobsled_members(leader: StageZombie = null) -> void:
	if leader == null:
		for enemy: StageZombie in _enemies.get_children():
			if enemy.enemy_kind == "bobsled_team" and not enemy.get_meta("summoned", false):
				leader = enemy
				break
	if leader == null:
		return
	for offset in range(1, 4):
		spawn_summoned("bobsled_team", leader.global_position + Vector3.RIGHT * offset * 0.70)


func _make_enemy(kind: String) -> StageZombie:
	var base := kind if kind in ["zombie", "conehead_zombie", "buckethead_zombie", "pole_vaulting_zombie", "newspaper_zombie"] else "zombie"
	var enemy := (load("res://scenes/enemies/" + base + ".tscn") as PackedScene).instantiate() as Zombie
	enemy.set_script(load("res://scripts/stage_zombie.gd"))
	enemy.set("enemy_kind", kind)
	enemy.set("stage", self)
	return enemy as StageZombie


func live_plants() -> Array[StagePlant]:
	var result: Array[StagePlant] = []
	if is_instance_valid(_plants):
		for plant: StagePlant in _plants.get_children():
			if plant.is_alive():
				result.append(plant)
	return result


func live_enemies() -> Array[StageZombie]:
	var result: Array[StageZombie] = []
	if is_instance_valid(_enemies):
		for enemy: StageZombie in _enemies.get_children():
			if enemy.is_alive():
				result.append(enemy)
	return result


func spawn_summoned(kind: String, at: Vector3) -> StageZombie:
	var cell := lawn.world_to_cell(at)
	if cell.x < 0 or cell.y in lawn.water_rows or live_enemies().size() >= 32:
		return null
	var enemy := _make_enemy(kind)
	_summon_serial += 1
	enemy.name = "Summon%d" % _summon_serial
	enemy.set_meta("summoned", true)
	enemy.position = to_local(at)
	enemy.position.y = lawn.surface_at(at)
	enemy.rotation.y = PI * 0.5
	_enemies.add_child(enemy)
	enemy.configure_debris($Debris)
	enemy.defeated.connect(func() -> void: enemy.queue_free())
	return enemy


func reset_stage() -> void:
	_pending.clear()
	_removed_plants.clear()
	_tools.reset_tools()
	for container: Node in [projectiles, $Debris, _effects]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for child: Node in _enemies.get_children():
		if child.get_meta("summoned", false):
			_enemies.remove_child(child)
			child.queue_free()
	for index in _plant_slots.size():
		_respawn(true, index)
	for index in _enemy_slots.size():
		_respawn(false, index)
	_ice.clear()
	_grave_locations.clear()
	_coins_reset()
	_sun_system.reset()
	_dave.reset_pose()
	_fog_clear_remaining = 0.0
	if is_instance_valid(_fog):
		_fog.show()
	_build_graves()
	_update_interface()


func _coins_reset() -> void:
	coins = 0


func remove_demo_plant(plant: Node3D) -> bool:
	if _closing or not plant is StagePlant or plant.get_parent() != _plants or not plant.is_alive():
		return false
	var index := -1
	for item in _plant_slots.size():
		if _plant_slots[item].name == String(plant.name):
			index = item
			break
	if index < 0:
		return false
	_removed_plants[index] = true
	_pending = _pending.filter(func(item: Dictionary) -> bool: return not (item.plant and item.index == index))
	plant.process_mode = Node.PROCESS_MODE_DISABLED
	plant.hide()
	_plants.remove_child(plant)
	plant.queue_free()
	_update_interface()
	return true


func begin_close() -> void:
	_closing = true
	_pending.clear()
	set_process(false)
	set_physics_process(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:
				_set_overview(not _overview)
				get_viewport().set_input_as_handled()
			KEY_R:
				reset_stage()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				_set_sidebar(not _sidebar_open)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _sidebar_open:
					_set_sidebar(false)
					get_viewport().set_input_as_handled()
			KEY_P:
				idle_enabled = not idle_enabled


func _set_overview(enabled: bool) -> void:
	_overview = enabled
	_orbit.enabled = enabled and not _sidebar_open
	_dave.set_first_person_active(not enabled)
	_dave.set_interface_open(_sidebar_open)
	if enabled:
		_orbit.camera.make_current()
	if is_instance_valid(_reticle):
		_reticle.visible = not enabled and not _sidebar_open


func _set_sidebar(open: bool) -> void:
	_sidebar_open = open
	_sidebar.visible = open
	_dave.set_interface_open(open)
	_orbit.enabled = _overview and not open
	_reticle.visible = not _overview and not open
	_update_interface()


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "StageUI"
	add_child(canvas)
	var summary := VBoxContainer.new()
	summary.position = Vector2(18, 62)
	canvas.add_child(summary)
	var title := Label.new()
	title.text = "%d · %s" % [stage_number, StageCatalog.STAGE_NAMES[stage_number - 1]]
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("fff3cc"))
	title.add_theme_color_override("font_shadow_color", Color("263b30"))
	title.add_theme_constant_override("shadow_outline_size", 5)
	summary.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_shadow_color", Color("263b30"))
	_status.add_theme_constant_override("shadow_outline_size", 4)
	summary.add_child(_status)
	var hint := Label.new()
	hint.text = "1–5 切换大关  ·  0 原演示  ·  WASD 移动  ·  M 全景  ·  Tab 数值  ·  R 重置  ·  P 摆动\n滚轮切换道具  ·  铲子右键铲除  ·  左键收集阳光  ·  Esc 释放鼠标  ·  全景：拖动旋转 / Ctrl＋滚轮缩放"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(18, -58)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_shadow_color", Color("263b30"))
	hint.add_theme_constant_override("shadow_outline_size", 4)
	canvas.add_child(hint)
	_reticle = Label.new()
	_reticle.text = "+"
	_reticle.add_theme_font_size_override("font_size", 25)
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_reticle)
	_sidebar = PanelContainer.new()
	_sidebar.name = "RosterSidebar"
	_sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_sidebar.offset_left = -370
	_sidebar.offset_right = -10
	_sidebar.offset_top = 65
	_sidebar.offset_bottom = -65
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.20, 0.17, 0.96)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_sidebar.add_theme_stylebox_override("panel", style)
	canvas.add_child(_sidebar)
	var scroll := ScrollContainer.new()
	_sidebar.add_child(scroll)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 16)
	scroll.add_child(_stats)
	_sidebar.hide()


func _process(delta: float) -> void:
	_ui_elapsed += delta
	if _ui_elapsed >= 0.25:
		_ui_elapsed = 0.0
		_update_interface()
		_refresh_plantern_light()


func _refresh_plantern_light() -> void:
	if not is_instance_valid(_fog):
		return
	for cloud: Node3D in _fog.get_children():
		cloud.visible = true
		for plant: StagePlant in live_plants():
			if plant.plant_kind == "plantern" and absf(plant.global_position.x - cloud.global_position.x) <= lawn.cell_size * 2.5 and absf(plant.global_position.z - cloud.global_position.z) <= lawn.cell_size * 2.5:
				cloud.hide()
				break


func _update_interface() -> void:
	if not is_instance_valid(_status):
		return
	_status.text = "累计基础植物 %d 种  ·  大关僵尸 %d 种  ·  %d×%d 格\n阳光 %d  ·  金币 %d  ·  %s" % [_plant_slots.size(), _enemy_slots.size(), lawn.row_count, lawn.column_count, _sun_system.sun_value, coins, "夜间无天降阳光" if StageCatalog.is_night(stage_number) else "白天蘑菇睡眠，咖啡豆可唤醒"]
	if not _sidebar_open:
		return
	var text := "植物 · 阳光费用 / 实时生命\n\n"
	for plant: StagePlant in _plants.get_children():
		text += "%s  %d☀  %d/%d\n" % [StageCatalog.plant_name(plant.plant_kind), int(plant.settings.sun_cost), plant.health, plant.maximum_health]
	text += "\n僵尸 · 本体 / 头甲 / 盾牌\n\n"
	for enemy: StageZombie in _enemies.get_children():
		text += "%s\n%d / %d / %d\n" % [StageCatalog.ENEMY_NAMES.get(enemy.enemy_kind, enemy.enemy_kind), enemy.body_health, enemy.helmet_health, enemy.shield_health]
	_stats.text = text


func _apply_theme() -> void:
	var world := $WorldEnvironment as WorldEnvironment
	var sky := world.environment.sky.sky_material as ProceduralSkyMaterial
	if StageCatalog.is_night(stage_number):
		$Sun.light_energy = 0.35
		$Sun.light_color = Color("b5c8e5")
		world.environment.ambient_light_energy = 0.55
		world.environment.ambient_light_color = Color("93a8c6")
		sky.sky_top_color = Color("132d46")
		sky.sky_horizon_color = Color("50627e")
		for i in 12:
			StageModels.sphere($Decor, "Star", Vector3.ONE * 0.13, Vector3(-15 + i * 3.0, 15 + (i % 3), -lawn.row_count * lawn.cell_size), Color("eef2d7"))
	if stage_number == 5:
		StageModels.box($Decor, "RoofFascia", Vector3(lawn.column_count * lawn.cell_size + 0.3, 0.65, lawn.row_count * lawn.cell_size + 0.3), Vector3(0, -0.37, 0), Color("c9ac7c"))
		for z: float in [-1, 1]:
			StageModels.box($Decor, "Gutter", Vector3(lawn.column_count * lawn.cell_size + 0.8, 0.16, 0.25), Vector3(0, 0.03, z * lawn.row_count * lawn.cell_size * 0.5), Color("8b6a4d"))
	if stage_number == 4:
		_fog = Node3D.new()
		_fog.name = "Fog"
		$Decor.add_child(_fog)
		var fog_color := Color(0.77, 0.86, 0.87, float(settings.fog_opacity))
		var fog_material := ShaderMaterial.new()
		fog_material.shader = preload("res://assets/materials/stage_fog.gdshader")
		fog_material.set_shader_parameter("fog_color", fog_color)
		for row in lawn.row_count:
			for column in range(lawn.column_count - 4, lawn.column_count):
				var cloud := StageModels.sphere(_fog, "FogCloud", Vector3(lawn.cell_size * 1.7, 2.2, lawn.cell_size * 1.7), lawn.cell_to_local(row, column) + Vector3.UP * 1.2, fog_color)
				cloud.material_override = fog_material


func _decorate_slots() -> void:
	for plant: StagePlant in _plants.get_children():
		if plant.display_only:
			StageModels.cylinder($Decor, "AquaticExhibit", 0.92, 0.13, plant.position - Vector3.UP * 0.05, Color("64b6c4"))
		elif stage_number == 5 and plant.plant_kind != "flower_pot":
			StageModels.cylinder($Decor, "PlantPot", 0.38, 0.38, plant.position - Vector3.UP * 0.20, Color("b7744f"), 0.50)
	_build_graves()


func _build_graves() -> void:
	if stage_number != 2:
		return
	for row in range(0, lawn.row_count, 2):
		var position := lawn.cell_to_world(row, int(settings.plant_columns) + 2)
		_grave_locations.append(position)
		var grave := StageModels.box(_effects, "Grave", Vector3(0.75, 0.88, 0.24), to_local(position) + Vector3.UP * 0.44, Color("838d7b"))
		grave.set_meta("grave", true)
		StageModels.label(grave, "RIP", Vector3(0, 0.13, -0.15), Color("ecebdd"))


func consume_grave(from: Vector3) -> bool:
	if _grave_locations.is_empty():
		return false
	var closest := _grave_locations[0]
	for position: Vector3 in _grave_locations:
		if from.distance_squared_to(position) < from.distance_squared_to(closest):
			closest = position
	_grave_locations.erase(closest)
	for item: Node3D in _effects.get_children():
		if item.get_meta("grave", false) and item.global_position.distance_to(closest + Vector3.UP * 0.44) < 0.2:
			item.queue_free()
	effect(closest, Color("a9bb81"), 0.8)
	return true


func spawn_plant_sun(at: Vector3, value: int) -> SunPickup:
	var sun := SunSystem.SUN_SCENE.instantiate() as SunPickup
	sun.value = value
	sun.radius = 0.32
	sun.fall_speed = float(_sun_system.settings.fall_speed)
	sun.lifetime = float(_sun_system.settings.lifetime)
	sun.landing_position = at + Vector3(0.55, 0.4, 0.30)
	sun.position = _sun_system.to_local(sun.landing_position + Vector3.UP * 0.75)
	sun.collected.connect(_sun_system._on_collected)
	_sun_system.add_child(sun)
	return sun


func add_coins(value: int, at: Vector3) -> void:
	coins += value
	var text := StageModels.label(_effects, "+%d 金币" % value, to_local(at) + Vector3.UP * 1.6, Color("f8d778"))
	var tween := text.create_tween()
	tween.tween_property(text, "position:y", text.position.y + 1.3, 1.3)
	tween.tween_callback(text.queue_free)


func effect(at: Vector3, color: Color, radius: float) -> void:
	var flash := StageModels.sphere(_effects, "CombatEffect", Vector3.ONE * 0.2, to_local(at), Color(color, 0.45))
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * radius * 2.0, 0.24)
	tween.parallel().tween_property(flash, "transparency", 1.0, 0.40)
	tween.tween_callback(flash.queue_free)


func clear_fog(duration: float) -> void:
	_fog_clear_remaining = maxf(_fog_clear_remaining, duration)
	if is_instance_valid(_fog):
		_fog.hide()


func first_plant_in_lane(z: float) -> StagePlant:
	var result: StagePlant
	for plant: StagePlant in live_plants():
		if not plant.display_only and absf(plant.global_position.z - z) < lawn.cell_size * 0.45:
			if result == null or plant.global_position.x < result.global_position.x:
				result = plant
	return result


func is_umbrella_protected(at: Vector3) -> bool:
	for plant: StagePlant in live_plants():
		if plant.plant_kind == "umbrella_leaf" and absf(plant.global_position.x - at.x) <= lawn.cell_size and absf(plant.global_position.z - at.z) <= lawn.cell_size:
			return true
	return false


func move_to_adjacent_lane(enemy: StageZombie) -> void:
	var cell := lawn.world_to_cell(enemy.global_position)
	var choices: Array[int] = []
	for row in [cell.y - 1, cell.y + 1]:
		if row >= 0 and row < lawn.row_count and not row in lawn.water_rows:
			choices.append(row)
	if not choices.is_empty():
		enemy.global_position.z = lawn.cell_to_world(choices.pick_random(), 0).z


func add_ice(cell: Vector2i) -> void:
	if _ice.has(cell):
		return
	_ice[cell] = StageModels.box(_effects, "Ice", Vector3(lawn.cell_size * 0.95, 0.03, lawn.cell_size * 0.95), lawn.cell_to_local(cell.y, cell.x) + Vector3.UP * 0.035, Color("a3d3de"))


func clear_ice(row: int) -> void:
	for cell: Vector2i in _ice.keys():
		if cell.y == row:
			if is_instance_valid(_ice[cell]):
				_ice[cell].queue_free()
			_ice.erase(cell)
