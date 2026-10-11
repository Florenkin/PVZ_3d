extends Node3D
## Compose independent lawn and plant entities in the demonstration scene.

signal zombie_respawned(zombie: Zombie)

const ZOMBIE_SCENE := preload("res://scenes/enemies/zombie.tscn")
const CONEHEAD_SCENE := preload("res://scenes/enemies/conehead_zombie.tscn")
const BUCKETHEAD_SCENE := preload("res://scenes/enemies/buckethead_zombie.tscn")
const POLE_ZOMBIE_SCENE := preload("res://scenes/enemies/pole_vaulting_zombie.tscn")
var INK := Color("294936")
var MUTED := Color("6b806a")
var CREAM := Color("f6f8ed")

@export var auto_respawn_enabled: bool = true
@export_range(0.01, 10.0, 0.01) var respawn_delay: float = 1.0

@onready var _plant: Peashooter = $Plants/Peashooter
@onready var _repeater: Repeater = $Plants/Repeater
@onready var _threepeater: Threepeater = $Plants/Threepeater
@onready var _gatling: GatlingPea = $Plants/GatlingPea
@onready var _snowpea: SnowPea = $Plants/SnowPea
@onready var _wallnut: WallNut = $Plants/WallNut
@onready var _lawn: LawnGrid = $LawnGrid
@onready var _dave: CrazyDave = $Characters/CrazyDave
@onready var _house: DaveHouse = $House
@onready var _zombie: Zombie = $Enemies/Zombie
@onready var _cone_zombie: Zombie = $Enemies/ConeheadZombie
@onready var _bucket_zombie: Zombie = $Enemies/BucketheadZombie
@onready var _pole_zombie: PoleVaultingZombie = $Enemies/PoleVaultingZombie
@onready var _projectiles: Node3D = $Projectiles
@onready var _debris: Node3D = $Debris
@onready var _orbit: Node3D = $OrbitRig
var _idle_button: Button
var _view_button: Button
var _zombie_button: Button
var _cone_button: Button
var _bucket_button: Button
var _pole_button: Button
var _view_label: Label
var _hint: Label
var _model_view: bool = false
var _inspect_zombie: bool = false
var _inspect_cone: bool = false
var _inspect_bucket: bool = false
var _inspect_pole: bool = false
var _health_label: Label
var _health_bar: ProgressBar
var _combat_status: Label
var _respawn_timer: Timer
var _cone_respawn_timer: Timer
var _cone_health_label: Label
var _cone_health_bar: ProgressBar
var _cone_status: Label
var _bucket_respawn_timer: Timer
var _bucket_health_label: Label
var _bucket_health_bar: ProgressBar
var _bucket_status: Label
var _pole_respawn_timer: Timer
var _pole_health_label: Label
var _pole_health_bar: ProgressBar
var _pole_status: Label
var _sidebar: PanelContainer
var _sidebar_open: bool = false
var _sidebar_button: Button


func _enter_tree() -> void:
	GameConfiguration.current().apply_scene(self)
	var ui := GameConfiguration.current().section("ui")
	INK = GameConfiguration.current().color(ui.ink_color)
	MUTED = GameConfiguration.current().color(ui.muted_color)
	CREAM = GameConfiguration.current().color(ui.panel_color)


func _ready() -> void:
	for key: String in ["peashooter", "repeater", "threepeater", "gatling_pea", "snow_pea", "wall_nut"]:
		var plant := get_node("Plants/" + _node_name(key)) as Node3D
		plant.global_position = _placement_position(key)
		plant.rotation.y = _placement_yaw(key)
	_dave.set_spawn(_placement_position("crazy_dave"), _placement_yaw("crazy_dave"))
	_dave.configure_exploration(_house.get_exploration_bounds())
	_zombie.set_spawn(_placement_position("zombie"), _placement_yaw("zombie"))
	_cone_zombie.set_spawn(_placement_position("conehead_zombie"), _placement_yaw("conehead_zombie"))
	_bucket_zombie.set_spawn(_placement_position("buckethead_zombie"), _placement_yaw("buckethead_zombie"))
	_pole_zombie.set_spawn(_placement_position("pole_vaulting_zombie"), _placement_yaw("pole_vaulting_zombie"))
	_debris.add_to_group("combat_debris_container")
	_plant.configure_combat(_lawn, _projectiles)
	_repeater.configure_combat(_lawn, _projectiles)
	_threepeater.configure_combat(_lawn, _projectiles)
	_gatling.configure_combat(_lawn, _projectiles)
	_snowpea.configure_combat(_lawn, _projectiles)
	_build_interface()
	_respawn_timer = Timer.new()
	_respawn_timer.name = "ZombieRespawnTimer"
	_respawn_timer.one_shot = true
	_respawn_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_respawn_timer.timeout.connect(_respawn_zombie)
	add_child(_respawn_timer)
	_cone_respawn_timer = Timer.new()
	_cone_respawn_timer.name = "ConeheadRespawnTimer"
	_cone_respawn_timer.one_shot = true
	_cone_respawn_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_cone_respawn_timer.timeout.connect(_respawn_cone_zombie)
	add_child(_cone_respawn_timer)
	_bucket_respawn_timer = Timer.new()
	_bucket_respawn_timer.name = "BucketheadRespawnTimer"
	_bucket_respawn_timer.one_shot = true
	_bucket_respawn_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_bucket_respawn_timer.timeout.connect(_respawn_bucket_zombie)
	add_child(_bucket_respawn_timer)
	_pole_respawn_timer = Timer.new()
	_pole_respawn_timer.name = "PoleZombieRespawnTimer"
	_pole_respawn_timer.one_shot = true
	_pole_respawn_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_pole_respawn_timer.timeout.connect(_respawn_pole_zombie)
	add_child(_pole_respawn_timer)
	_connect_zombie()
	_connect_cone_zombie()
	_connect_bucket_zombie()
	_connect_pole_zombie()
	_on_health_changed(_zombie.health, _zombie.maximum_health)
	_on_cone_health_changed(_cone_zombie.health, _cone_zombie.maximum_health)
	_on_bucket_health_changed(_bucket_zombie.health, _bucket_zombie.maximum_health)
	_on_pole_health_changed(_pole_zombie.health, _pole_zombie.maximum_health)
	_set_model_view(false)
	# A deterministic capture mode for checking the actual rendered scene.
	var arguments := OS.get_cmdline_user_args()
	if "--capture" in arguments or "--capture-model" in arguments or "--capture-zombie" in arguments or "--capture-lawn" in arguments or "--capture-combat" in arguments or "--capture-cone" in arguments or "--capture-debris" in arguments or "--capture-recoil" in arguments or "--capture-threepeater" in arguments or "--capture-threepeater-fire" in arguments or "--capture-gatling" in arguments or "--capture-gatling-fire" in arguments or "--capture-bucket" in arguments or "--capture-bucket-debris" in arguments or "--capture-snowpea" in arguments or "--capture-snowpea-hit" in arguments or "--capture-pole" in arguments or "--capture-pole-vault" in arguments or "--capture-wallnut" in arguments:
		_plant.idle_animation_enabled = false
		_repeater.idle_animation_enabled = false
		_repeater.combat_enabled = false
		_threepeater.idle_animation_enabled = false
		_threepeater.combat_enabled = false
		_gatling.idle_animation_enabled = false
		_gatling.combat_enabled = false
		_snowpea.idle_animation_enabled = false
		_snowpea.combat_enabled = false
		_dave.set_physics_process(false)
		_cone_zombie.movement_enabled = false
		_bucket_zombie.movement_enabled = false
		_pole_zombie.movement_enabled = false
		if "--capture-combat" in arguments:
			_inspect_zombie = true
			_set_model_view(true)
			await _zombie.damaged
			await get_tree().create_timer(0.08).timeout
			_zombie.set_physics_process(false)
			_plant.set_physics_process(false)
			for pea: Node in _projectiles.get_children():
				pea.set_physics_process(false)
		else:
			_plant.combat_enabled = false
			_zombie.movement_enabled = false
		if "--capture-pole" in arguments:
			_inspect_pole = true
			_set_model_view(true)
		elif "--capture-pole-vault" in arguments:
			auto_respawn_enabled = false
			_set_model_view(true)
			_orbit.target = _wallnut.global_position + Vector3(0.1, 1.2, 0)
			_orbit.default_yaw = 0.05
			_orbit.default_pitch = 0.24
			_orbit.default_size = 5.8
			_orbit.reset_view()
			_pole_zombie.movement_enabled = true
			await _pole_zombie.vault_started
			await get_tree().create_timer(0.36).timeout
			_pole_zombie.set_physics_process(false)
			_view_label.text = "撑杆僵尸 · 跃过第 8 格坚果"
		elif "--capture-wallnut" in arguments:
			_set_model_view(true)
			_orbit.target = _wallnut.global_position + Vector3(1.1, 0.95, 0)
			_orbit.default_yaw = 0.05
			_orbit.default_pitch = 0.30
			_orbit.default_size = 4.4
			_orbit.reset_view()
			_view_label.text = "坚果 · 寒冰防线第 8 格"
		elif "--capture-snowpea" in arguments:
			_set_model_view(true)
			_orbit.target = _snowpea.global_position + Vector3(0.1, 0.85, 0)
			_orbit.default_yaw = 0.9
			_orbit.default_pitch = 0.38
			_orbit.default_size = 3.3
			_orbit.reset_view()
			_view_label.text = "寒冰射手模型查看"
		elif "--capture-snowpea-hit" in arguments:
			auto_respawn_enabled = false
			_zombie.set_spawn(_lawn.cell_to_world(4, 5), PI / 2.0)
			_inspect_zombie = true
			_set_model_view(true)
			_snowpea.combat_enabled = true
			await _zombie.damaged
			_snowpea.combat_enabled = false
			await get_tree().create_timer(0.60).timeout
			_view_label.text = "寒冰命中 · 减速 50%"
		elif "--capture-gatling" in arguments or "--capture-gatling-fire" in arguments:
			_set_model_view(true)
			_orbit.target = _gatling.global_position + Vector3(0.15, 0.85, 0)
			_orbit.default_yaw = 0.9
			_orbit.default_pitch = 0.38
			_orbit.default_size = 3.3
			_orbit.reset_view()
			_view_label.text = "机枪射手模型查看"
			if "--capture-gatling-fire" in arguments:
				_gatling.combat_enabled = true
				_orbit.target = _gatling.global_position + Vector3(2.1, 0.8, 0)
				_orbit.default_yaw = 0.20
				_orbit.default_pitch = 0.65
				_orbit.default_size = 7.0
				_orbit.reset_view()
				for index in range(_gatling.burst_size):
					await _gatling.shot_fired
				await get_tree().create_timer(0.05).timeout
				_gatling.set_physics_process(false)
				for pea: Node in _projectiles.get_children():
					pea.set_physics_process(false)
				_view_label.text = "机枪射手 · 一轮四连射"
		elif "--capture-threepeater" in arguments or "--capture-threepeater-fire" in arguments:
			_set_model_view(true)
			_orbit.target = _threepeater.global_position + Vector3(0.1, 0.8, 0)
			_orbit.default_yaw = 0.9
			_orbit.default_pitch = 0.38
			_orbit.default_size = 3.3
			_orbit.reset_view()
			_view_label.text = "三线射手模型查看"
			if "--capture-threepeater-fire" in arguments:
				_orbit.target = _threepeater.global_position + Vector3(2.0, 0.7, 0)
				_orbit.default_yaw = 0.55
				_orbit.default_pitch = 0.75
				_orbit.default_size = 6.8
				_orbit.reset_view()
				_threepeater.combat_enabled = true
				await _threepeater.shot_fired
				await get_tree().create_timer(0.30).timeout
				_threepeater.set_physics_process(false)
				for pea: Node in _projectiles.get_children():
					pea.set_physics_process(false)
				_view_label.text = "三线射手 · 三条路径齐射"
		elif "--capture-model" in arguments:
			_set_model_view(true)
		elif "--capture-recoil" in arguments:
			_set_model_view(true)
			_plant.combat_enabled = true
			_repeater.combat_enabled = true
			await _plant.shot_fired
			await _repeater.shot_fired
			# Freeze this firing pose for the still capture only.
			_plant.set_physics_process(false)
			_repeater.set_physics_process(false)
			for pea: Node in _projectiles.get_children():
				pea.set_physics_process(false)
			_view_label.text = "植物开火后坐力"
		elif "--capture-zombie" in arguments:
			_inspect_zombie = true
			_set_model_view(true)
		elif "--capture-cone" in arguments:
			_inspect_cone = true
			_set_model_view(true)
		elif "--capture-bucket" in arguments:
			_inspect_bucket = true
			_set_model_view(true)
		elif "--capture-bucket-debris" in arguments:
			auto_respawn_enabled = false
			_set_model_view(true)
			_bucket_zombie.set_spawn(_lawn.cell_to_world(0, 5), PI / 2.0)
			_orbit.target = _bucket_zombie.global_position + Vector3(1.0, 0.7, 0)
			_orbit.default_yaw = -0.95
			_orbit.default_pitch = 0.75
			_orbit.default_size = 4.4
			_orbit.reset_view()
			_bucket_zombie.take_damage(_bucket_zombie.maximum_health - 200, Vector3.RIGHT)
			await get_tree().create_timer(1.8).timeout
			_view_label.text = "铁桶脱落 · 物理落地"
		elif "--capture-debris" in arguments:
			auto_respawn_enabled = false
			_set_model_view(true)
			_zombie.set_spawn(_lawn.cell_to_world(2, 5), PI / 2.0)
			_cone_zombie.set_spawn(_lawn.cell_to_world(1, 5), PI / 2.0)
			_orbit.target = Vector3(3.1, 0.45, -1.2)
			_orbit.default_yaw = -0.65
			_orbit.default_pitch = 0.7
			_orbit.default_size = 6.6
			_orbit.reset_view()
			_zombie.take_damage(100, Vector3.RIGHT)
			_cone_zombie.take_damage(370, Vector3.RIGHT)
			await get_tree().create_timer(0.25).timeout
			_zombie.take_damage(100, Vector3.RIGHT)
			_cone_zombie.take_damage(200, Vector3.RIGHT)
			await get_tree().create_timer(1.8).timeout
			_view_label.text = "倒地与脱落部件"
		elif "--capture-lawn" in arguments:
			_set_model_view(true)
			_orbit.target = Vector3(0, 0.1, 0)
			_orbit.default_yaw = 0.10
			_orbit.default_pitch = 0.72
			_orbit.default_size = 15.8
			_orbit.distance = 38.0
			_orbit.reset_view()
			_view_label.text = "草坪总览"
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var filename := "dave_model.png" if _model_view else "dave_view.png"
		if "--capture-zombie" in arguments:
			filename = "zombie_model.png"
		elif "--capture-lawn" in arguments:
			filename = "zombie_lawn.png"
		elif "--capture-combat" in arguments:
			filename = "combat_hit.png"
		elif "--capture-cone" in arguments:
			filename = "conehead_model.png"
		elif "--capture-debris" in arguments:
			filename = "zombie_debris.png"
		elif "--capture-recoil" in arguments:
			filename = "plant_recoil.png"
		elif "--capture-threepeater" in arguments:
			filename = "threepeater_model.png"
		elif "--capture-threepeater-fire" in arguments:
			filename = "threepeater_volley.png"
		elif "--capture-gatling" in arguments:
			filename = "gatling_pea_model.png"
		elif "--capture-gatling-fire" in arguments:
			filename = "gatling_pea_burst.png"
		elif "--capture-bucket" in arguments:
			filename = "buckethead_model.png"
		elif "--capture-bucket-debris" in arguments:
			filename = "buckethead_debris.png"
		elif "--capture-snowpea" in arguments:
			filename = "snow_pea_model.png"
		elif "--capture-snowpea-hit" in arguments:
			filename = "snow_pea_slow.png"
		elif "--capture-pole" in arguments:
			filename = "pole_vaulting_zombie_model.png"
		elif "--capture-pole-vault" in arguments:
			filename = "pole_vault.png"
		elif "--capture-wallnut" in arguments:
			filename = "wall_nut_model.png"
		var capture_path := ProjectSettings.globalize_path("res://artifacts/" + filename)
		DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
		var capture_error := get_viewport().get_texture().get_image().save_png(capture_path)
		if capture_error != OK:
			push_error("Could not save scene capture: %s" % error_string(capture_error))
			get_tree().quit(1)
		else:
			print("Scene capture saved: " + capture_path)
			get_tree().quit()


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = int(round(14 * float(GameConfiguration.current().section("ui").font_scale)))
	root.theme = ui_theme
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.scale = Vector2.ONE * float(GameConfiguration.current().section("ui").scale)
	get_viewport().size_changed.connect(_resize_interface.bind(root))
	_resize_interface(root)

	var heading := VBoxContainer.new()
	heading.position = Vector2(44, 34)
	heading.add_theme_constant_override("separation", 6)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(heading)
	_label(heading, "PVZ  /  3D GARDEN", 13, MUTED)
	_label(heading, "庭院防线", 34, INK)
	_label(heading, "站在植物身后，守住这片草坪。", 14, MUTED)

	var badge := _button(root, "数值信息  Tab")
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -204
	badge.offset_right = -24
	badge.offset_top = 42
	badge.offset_bottom = 84
	badge.pressed.connect(_toggle_sidebar)
	_sidebar_button = badge

	var details_panel := PanelContainer.new()
	_sidebar = details_panel
	details_panel.name = "CombatSidebar"
	details_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	var ui := GameConfiguration.current().section("ui")
	details_panel.offset_left = -float(ui.sidebar_width) - float(ui.sidebar_margin)
	details_panel.offset_right = -float(ui.sidebar_margin)
	details_panel.offset_top = 144
	details_panel.offset_bottom = -108
	details_panel.add_theme_stylebox_override("panel", _panel_style(CREAM, 16, 16, 12))
	details_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(details_panel)
	details_panel.hide()
	var sidebar_content := VBoxContainer.new()
	sidebar_content.add_theme_constant_override("separation", 12)
	details_panel.add_child(sidebar_content)
	var sidebar_heading := HBoxContainer.new()
	sidebar_content.add_child(sidebar_heading)
	var sidebar_title := _label(sidebar_heading, "战斗数值", 17, INK)
	sidebar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_sidebar := _button(sidebar_heading, "收起  Tab")
	close_sidebar.pressed.connect(_toggle_sidebar)
	var scroll := ScrollContainer.new()
	scroll.name = "ValuesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_content.add_child(scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(details)
	_view_label = _label(details, "戴夫腰部视角", 17, INK)
	_health_label = _label(details, "僵尸生命：200 / 200", 13, MUTED)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(GameConfiguration.current().section("ui").health_bar_size[0], GameConfiguration.current().section("ui").health_bar_size[1])
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_theme_stylebox_override("background", _panel_style(Color("dce5d2"), 4, 0, 0))
	_health_bar.add_theme_stylebox_override("fill", _panel_style(Color("79b753"), 4, 0, 0))
	details.add_child(_health_bar)
	_combat_status = _label(details, _attack_status(_plant), 12, MUTED)
	_cone_health_label = _label(details, "路障僵尸：570 / 570", 13, MUTED)
	_cone_health_bar = ProgressBar.new()
	_cone_health_bar.custom_minimum_size = Vector2(GameConfiguration.current().section("ui").health_bar_size[0], GameConfiguration.current().section("ui").health_bar_size[1])
	_cone_health_bar.show_percentage = false
	_cone_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cone_health_bar.add_theme_stylebox_override("background", _panel_style(Color("dce5d2"), 4, 0, 0))
	_cone_health_bar.add_theme_stylebox_override("fill", _panel_style(Color("df923e"), 4, 0, 0))
	details.add_child(_cone_health_bar)
	_cone_status = _label(details, "双发射手    ·    每轮 %d 颗" % _repeater.burst_size, 12, MUTED)
	_bucket_health_label = _label(details, "铁桶僵尸：1370 / 1370", 13, MUTED)
	_bucket_health_bar = ProgressBar.new()
	_bucket_health_bar.custom_minimum_size = Vector2(GameConfiguration.current().section("ui").health_bar_size[0], GameConfiguration.current().section("ui").health_bar_size[1])
	_bucket_health_bar.show_percentage = false
	_bucket_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bucket_health_bar.add_theme_stylebox_override("background", _panel_style(Color("dce5d2"), 4, 0, 0))
	_bucket_health_bar.add_theme_stylebox_override("fill", _panel_style(Color("789598"), 4, 0, 0))
	details.add_child(_bucket_health_bar)
	_bucket_status = _label(details, "机枪射手    ·    每轮 %d 颗" % _gatling.burst_size, 12, MUTED)
	_pole_health_label = _label(details, "撑杆僵尸：500 / 500", 13, MUTED)
	_pole_health_bar = ProgressBar.new()
	_pole_health_bar.custom_minimum_size = Vector2(GameConfiguration.current().section("ui").health_bar_size[0], GameConfiguration.current().section("ui").health_bar_size[1])
	_pole_health_bar.show_percentage = false
	_pole_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pole_health_bar.add_theme_stylebox_override("background", _panel_style(Color("dce5d2"), 4, 0, 0))
	_pole_health_bar.add_theme_stylebox_override("fill", _panel_style(Color("c84c44"), 4, 0, 0))
	details.add_child(_pole_health_bar)
	_pole_status = _label(details, "寒冰防线    ·    撑杆跳跃一次", 12, MUTED)
	_label(details, _threepeater_status(), 12, MUTED)
	_label(details, "寒冰射手    ·    减速 %s%% / %s 秒" % [String.num((1.0 - _snowpea.slow_multiplier) * 100, 1), String.num(_snowpea.slow_duration, 2)], 12, MUTED)

	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.position = Vector2(-942, -86)
	controls.add_theme_constant_override("separation", 10)
	root.add_child(controls)
	_view_button = _button(controls, "查看模型  M")
	_view_button.pressed.connect(_toggle_view)
	_zombie_button = _button(controls, "查看僵尸  Z")
	_zombie_button.pressed.connect(_toggle_zombie_view)
	_cone_button = _button(controls, "路障僵尸  X")
	_cone_button.pressed.connect(_toggle_cone_view)
	_bucket_button = _button(controls, "铁桶僵尸  V")
	_bucket_button.pressed.connect(_toggle_bucket_view)
	_pole_button = _button(controls, "撑杆僵尸  B")
	_pole_button.pressed.connect(_toggle_pole_view)
	_idle_button = _button(controls, "暂停摆动")
	_idle_button.pressed.connect(_toggle_idle)
	var reset := _button(controls, "重新开始  R")
	reset.pressed.connect(_reset_view)

	var hint_panel := PanelContainer.new()
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_panel.offset_left = -255
	hint_panel.offset_right = 255
	hint_panel.offset_top = -44
	hint_panel.offset_bottom = -14
	hint_panel.add_theme_stylebox_override("panel", _panel_style(CREAM, 12, 16, 6))
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_panel)
	var hint := Label.new()
	_hint = hint
	hint.add_theme_color_override("font_color", MUTED)
	hint.add_theme_font_size_override("font_size", int(round(13 * float(GameConfiguration.current().section("ui").font_scale))))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(hint)


func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", int(round(font_size * float(GameConfiguration.current().section("ui").font_scale))))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(GameConfiguration.current().section("ui").button_size[0], GameConfiguration.current().section("ui").button_size[1])
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_stylebox_override("normal", _panel_style(CREAM, 12, 16, 10))
	button.add_theme_stylebox_override("hover", _panel_style(Color("ffffff"), 12, 16, 10))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("d9e8cc"), 12, 16, 10))
	parent.add_child(button)
	return button


func _panel_style(color: Color, radius: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _toggle_idle() -> void:
	_plant.idle_animation_enabled = not _plant.idle_animation_enabled
	_repeater.idle_animation_enabled = _plant.idle_animation_enabled
	_threepeater.idle_animation_enabled = _plant.idle_animation_enabled
	_gatling.idle_animation_enabled = _plant.idle_animation_enabled
	_snowpea.idle_animation_enabled = _plant.idle_animation_enabled
	_idle_button.text = "暂停摆动" if _plant.idle_animation_enabled else "继续摆动"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle_sidebar()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _sidebar_open:
			_set_sidebar_open(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			_toggle_view()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			_reset_view()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			_toggle_zombie_view()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_X:
			_toggle_cone_view()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_V:
			_toggle_bucket_view()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B:
			_toggle_pole_view()
			get_viewport().set_input_as_handled()


func _toggle_view() -> void:
	_inspect_zombie = false
	_inspect_cone = false
	_inspect_bucket = false
	_inspect_pole = false
	_set_model_view(not _model_view)


func _set_model_view(enabled: bool) -> void:
	_model_view = enabled
	_orbit.enabled = enabled
	_dave.set_first_person_active(not enabled)
	if enabled:
		_focus_model()
		_orbit.camera.make_current()
	_view_button.text = "戴夫视角  M" if enabled else "查看模型  M"
	_zombie_button.text = "返回游戏  Z" if enabled and _inspect_zombie else "查看僵尸  Z"
	_cone_button.text = "返回游戏  X" if enabled and _inspect_cone else "路障僵尸  X"
	_bucket_button.text = "返回游戏  V" if enabled and _inspect_bucket else "铁桶僵尸  V"
	_pole_button.text = "返回游戏  B" if enabled and _inspect_pole else "撑杆僵尸  B"
	_view_label.text = "戴夫腰部视角"
	if enabled:
		if _inspect_pole:
			_view_label.text = "撑杆僵尸模型查看"
		elif _inspect_bucket:
			_view_label.text = "铁桶僵尸模型查看"
		elif _inspect_cone:
			_view_label.text = "路障僵尸模型查看"
		elif _inspect_zombie:
			_view_label.text = "僵尸模型查看"
		else:
			_view_label.text = "植物与戴夫模型查看"
	_update_input_hint()


func _toggle_sidebar() -> void:
	_set_sidebar_open(not _sidebar_open)


func _set_sidebar_open(open: bool) -> void:
	_sidebar_open = open
	_sidebar.visible = open
	_dave.set_interface_open(open)
	_sidebar_button.text = "收起信息  Tab" if open else "数值信息  Tab"
	_update_input_hint()


func _update_input_hint() -> void:
	if _sidebar_open:
		_hint.text = "Tab / Esc 收起数值    ·    M 切换视角    ·    R 重新开始"
	elif _model_view:
		_hint.text = "左键拖动旋转    ·    滚轮缩放    ·    Tab 数值信息    ·    M 戴夫视角"
	else:
		_hint.text = "WASD 移动    ·    鼠标转向    ·    Tab 数值信息    ·    M 查看模型"


func _reset_view() -> void:
	_respawn_timer.stop()
	_cone_respawn_timer.stop()
	_bucket_respawn_timer.stop()
	_pole_respawn_timer.stop()
	_dave.reset_pose()
	for pea: Node in _projectiles.get_children():
		_projectiles.remove_child(pea)
		pea.queue_free()
	for part: Node in _debris.get_children():
		_debris.remove_child(part)
		part.queue_free()
	_zombie.reset_combat()
	_cone_zombie.reset_combat()
	_bucket_zombie.reset_combat()
	_pole_zombie.reset_combat()
	_plant.reset_combat()
	_repeater.reset_combat()
	_threepeater.reset_combat()
	_gatling.reset_combat()
	_snowpea.reset_combat()
	_wallnut.global_position = _placement_position("wall_nut")
	if _model_view:
		_focus_model()


func _connect_zombie() -> void:
	_zombie.configure_debris(_debris)
	_zombie.health_changed.connect(_on_health_changed)
	_zombie.defeated.connect(_on_zombie_defeated)


func _connect_cone_zombie() -> void:
	_cone_zombie.configure_debris(_debris)
	_cone_zombie.health_changed.connect(_on_cone_health_changed)
	_cone_zombie.defeated.connect(_on_cone_defeated)


func _connect_bucket_zombie() -> void:
	_bucket_zombie.configure_debris(_debris)
	_bucket_zombie.health_changed.connect(_on_bucket_health_changed)
	_bucket_zombie.defeated.connect(_on_bucket_defeated)


func _connect_pole_zombie() -> void:
	_pole_zombie.configure_debris(_debris)
	_pole_zombie.health_changed.connect(_on_pole_health_changed)
	_pole_zombie.defeated.connect(_on_pole_defeated)


func _on_pole_defeated() -> void:
	if auto_respawn_enabled:
		_pole_respawn_timer.start(maxf(respawn_delay, 0.01))


func _on_bucket_defeated() -> void:
	if auto_respawn_enabled:
		_bucket_respawn_timer.start(maxf(respawn_delay, 0.01))


func _on_cone_defeated() -> void:
	if auto_respawn_enabled:
		_cone_respawn_timer.start(maxf(respawn_delay, 0.01))


func _on_zombie_defeated() -> void:
	if auto_respawn_enabled:
		_respawn_timer.start(maxf(respawn_delay, 0.01))


func _respawn_zombie() -> void:
	if not auto_respawn_enabled or _zombie.is_alive():
		return
	_zombie = _replace_enemy(_zombie, ZOMBIE_SCENE, "Zombie")
	_connect_zombie()
	_zombie.set_spawn(_placement_position("zombie"), _placement_yaw("zombie"))
	zombie_respawned.emit(_zombie)


func _respawn_cone_zombie() -> void:
	if not auto_respawn_enabled or _cone_zombie.is_alive():
		return
	_cone_zombie = _replace_enemy(_cone_zombie, CONEHEAD_SCENE, "ConeheadZombie")
	_connect_cone_zombie()
	_cone_zombie.set_spawn(_placement_position("conehead_zombie"), _placement_yaw("conehead_zombie"))
	zombie_respawned.emit(_cone_zombie)


func _respawn_bucket_zombie() -> void:
	if not auto_respawn_enabled or _bucket_zombie.is_alive():
		return
	_bucket_zombie = _replace_enemy(_bucket_zombie, BUCKETHEAD_SCENE, "BucketheadZombie")
	_connect_bucket_zombie()
	_bucket_zombie.set_spawn(_placement_position("buckethead_zombie"), _placement_yaw("buckethead_zombie"))
	zombie_respawned.emit(_bucket_zombie)


func _respawn_pole_zombie() -> void:
	if not auto_respawn_enabled or _pole_zombie.is_alive():
		return
	var previous := _pole_zombie
	_pole_zombie = _replace_enemy(previous, POLE_ZOMBIE_SCENE, "PoleVaultingZombie") as PoleVaultingZombie
	_pole_zombie.vault_enabled = previous.vault_enabled
	_pole_zombie.vault_trigger_distance = previous.vault_trigger_distance
	_pole_zombie.vault_height = previous.vault_height
	_pole_zombie.landing_clearance = previous.landing_clearance
	_connect_pole_zombie()
	_pole_zombie.set_spawn(_placement_position("pole_vaulting_zombie"), _placement_yaw("pole_vaulting_zombie"))
	zombie_respawned.emit(_pole_zombie)


func _replace_enemy(previous: Zombie, scene: PackedScene, node_name: String) -> Zombie:
	var enemies := previous.get_parent()
	var replacement := scene.instantiate() as Zombie
	GameConfiguration.current().apply_entity(replacement)
	# Keep the configured enemy stats, but start with fresh health and hit effects.
	replacement.maximum_health = previous.maximum_health
	replacement.walk_speed = previous.walk_speed
	replacement.is_ground_zombie = previous.is_ground_zombie
	replacement.movement_enabled = previous.movement_enabled
	replacement.knockback_speed = previous.knockback_speed
	replacement.knockback_deceleration = previous.knockback_deceleration
	replacement.maximum_walk_distance = previous.maximum_walk_distance
	enemies.remove_child(previous)
	previous.queue_free()
	replacement.name = node_name
	enemies.add_child(replacement)
	return replacement


func _toggle_zombie_view() -> void:
	if _model_view and _inspect_zombie:
		_set_model_view(false)
	else:
		_inspect_zombie = true
		_inspect_cone = false
		_inspect_bucket = false
		_inspect_pole = false
		_set_model_view(true)


func _toggle_cone_view() -> void:
	if _model_view and _inspect_cone:
		_set_model_view(false)
	else:
		_inspect_cone = true
		_inspect_zombie = false
		_inspect_bucket = false
		_inspect_pole = false
		_set_model_view(true)


func _toggle_bucket_view() -> void:
	if _model_view and _inspect_bucket:
		_set_model_view(false)
	else:
		_inspect_bucket = true
		_inspect_cone = false
		_inspect_zombie = false
		_inspect_pole = false
		_set_model_view(true)


func _toggle_pole_view() -> void:
	if _model_view and _inspect_pole:
		_set_model_view(false)
	else:
		_inspect_pole = true
		_inspect_bucket = false
		_inspect_cone = false
		_inspect_zombie = false
		_set_model_view(true)


func _selected_enemy() -> Zombie:
	return _pole_zombie if _inspect_pole else (_bucket_zombie if _inspect_bucket else (_cone_zombie if _inspect_cone else _zombie))


func _focus_model() -> void:
	var params: Dictionary
	if _inspect_zombie or _inspect_cone or _inspect_bucket or _inspect_pole:
		params = GameConfiguration.current().section("cameras.enemy_view")
		_orbit.target = _selected_enemy().global_position + Vector3(0, _enemy_view_height(), 0)
		_orbit.default_size = params.pole_size if _inspect_pole else params.size
	else:
		params = GameConfiguration.current().section("cameras.plant_view")
		_orbit.target = (_gatling.global_position + _snowpea.global_position) * 0.5 + GameConfiguration.current().vector(params.offset)
		_orbit.default_size = params.size
	_orbit.default_yaw = deg_to_rad(params.yaw_degrees)
	_orbit.default_pitch = deg_to_rad(params.pitch_degrees)
	_orbit.distance = GameConfiguration.current().section("cameras.orbit").distance
	_orbit.reset_view()


func _enemy_view_height() -> float:
	var params := GameConfiguration.current().section("cameras.enemy_view")
	return params.armor_target_height if _inspect_cone or _inspect_bucket else params.target_height


func _process(_delta: float) -> void:
	if _model_view and (_inspect_zombie or _inspect_cone or _inspect_bucket or _inspect_pole):
		_orbit.set_target_position(_selected_enemy().global_position + Vector3(0, _enemy_view_height(), 0))


func _on_health_changed(health: int, maximum: int) -> void:
	_health_label.text = "普通僵尸：%d / %d" % [health, maximum]
	_health_bar.max_value = maximum
	_health_bar.value = health
	if health > 0:
		_combat_status.text = _attack_status(_plant)
	elif auto_respawn_enabled:
		_combat_status.text = "僵尸已击败    ·    %s 秒后刷新" % String.num(respawn_delay, 2)
	else:
		_combat_status.text = "僵尸已击败    ·    R 重新开始"


func _on_cone_health_changed(health: int, maximum: int) -> void:
	_cone_health_label.text = "路障僵尸：%d / %d" % [health, maximum]
	_cone_health_bar.max_value = maximum
	_cone_health_bar.value = health
	if health > 0:
		_cone_status.text = "双发射手    ·    每轮 %d 颗" % _repeater.burst_size
	elif auto_respawn_enabled:
		_cone_status.text = "%s 秒后刷新路障僵尸" % String.num(respawn_delay, 2)
	else:
		_cone_status.text = "路障已击败    ·    R 重新开始"


func _on_bucket_health_changed(health: int, maximum: int) -> void:
	_bucket_health_label.text = "铁桶僵尸：%d / %d" % [health, maximum]
	_bucket_health_bar.max_value = maximum
	_bucket_health_bar.value = health
	if health > 0:
		_bucket_status.text = "机枪射手    ·    每轮 %d 颗" % _gatling.burst_size
	elif auto_respawn_enabled:
		_bucket_status.text = "%s 秒后刷新铁桶僵尸" % String.num(respawn_delay, 2)
	else:
		_bucket_status.text = "铁桶已击败    ·    R 重新开始"


func _on_pole_health_changed(health: int, maximum: int) -> void:
	_pole_health_label.text = "撑杆僵尸：%d / %d" % [health, maximum]
	_pole_health_bar.max_value = maximum
	_pole_health_bar.value = health
	if health > 0:
		_pole_status.text = "寒冰防线    ·    撑杆跳跃一次"
	elif auto_respawn_enabled:
		_pole_status.text = "%s 秒后刷新撑杆僵尸" % String.num(respawn_delay, 2)
	else:
		_pole_status.text = "撑杆已击败    ·    R 重新开始"


func _placement_position(key: String) -> Vector3:
	var placement := GameConfiguration.current().section("placements." + key)
	return _lawn.cell_to_world(int(placement.row) - 1, int(placement.column) - 1)


func _placement_yaw(key: String) -> float:
	return deg_to_rad(GameConfiguration.current().section("placements." + key).yaw_degrees)


func _node_name(key: String) -> String:
	return {"peashooter": "Peashooter", "repeater": "Repeater", "threepeater": "Threepeater", "gatling_pea": "GatlingPea", "snow_pea": "SnowPea", "wall_nut": "WallNut"}[key]


func _attack_status(plant: Peashooter) -> String:
	return "每 %s 秒一发    ·    伤害 %d" % [String.num(plant.shot_interval, 2), plant.pea_damage]


func _threepeater_status() -> String:
	var row := int(GameConfiguration.current().section("placements.threepeater").row)
	var rows: PackedStringArray = []
	for lane: int in range(maxi(1, row - 1), mini(_lawn.row_count, row + 1) + 1):
		rows.append(str(lane))
	return "三线射手    ·    第 %s 行齐射" % " / ".join(rows)


func _resize_interface(layout: Control) -> void:
	layout.size = get_viewport().get_visible_rect().size / layout.scale
