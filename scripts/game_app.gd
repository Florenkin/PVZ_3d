class_name GameApplication
extends Node3D
## The application owns navigation; each mode owns and releases its own gameplay.

var current_mode: String = ""
var content: Node
var _canvas: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--mode=demo":
			show_demo()
			return
		if argument.begins_with("--level="):
			var value := argument.trim_prefix("--level=")
			var number := AdventureLevels.parse_code(value)
			if number > 0:
				start_level(number, true)
				return
	show_main_menu()


func _clear_content() -> void:
	if is_instance_valid(content):
		if content.has_method("begin_close"):
			content.begin_close()
		content.process_mode = Node.PROCESS_MODE_DISABLED
		remove_child(content)
		content.queue_free()
		content = null
	if is_instance_valid(_canvas):
		remove_child(_canvas)
		_canvas.queue_free()
		_canvas = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _menu_root() -> Control:
	content = load("res://scenes/menu_backdrop.tscn").instantiate()
	add_child(content)
	_canvas = CanvasLayer.new()
	_canvas.layer = 40
	add_child(_canvas)
	var root := GameUI.full_rect(_canvas)
	var veil := ColorRect.new()
	veil.color = Color(0.05, 0.10, 0.05, 0.28)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root


func show_main_menu() -> void:
	_clear_content()
	current_mode = "menu"
	var root := _menu_root()
	var compact := get_viewport().get_visible_rect().size.y < 700
	var text_panel := GameUI.panel(root, Color(0.07, 0.14, 0.08, 0.94))
	text_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	text_panel.offset_left = 26
	text_panel.offset_right = 538
	text_panel.offset_top = 24
	text_panel.offset_bottom = -24
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_left = 50
	margin.offset_right = 510
	margin.offset_top = 36 if compact else 50
	margin.offset_bottom = -30 if compact else -45
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10 if compact else 17)
	margin.add_child(column)
	GameUI.label(column, "PVZ  3D", 52 if compact else 64, Color("fff0be"))
	GameUI.label(column, "植物大战僵尸 · 戴夫的庭院", 26)
	GameUI.label(column, "阳光、草坪，与下一场冒险。", 20, GameUI.MUTED)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	var adventure := GameUI.button(column, "冒险模式\n种植你的防线，守住庭院", show_levels.call_deferred, Color("42682f"), Vector2(440, 84 if compact else 96))
	adventure.name = "AdventureButton"
	var demo := GameUI.button(column, "演示模式\n查看五个大关的植物与僵尸", show_demo.call_deferred, Color("7a663b"), Vector2(440, 84 if compact else 96))
	demo.name = "DemoButton"
	var progress_text := "银向日葵奖杯 · 冒险五十关已完成" if AdventureProgress.current().completed_count() == AdventureLevels.LEVEL_COUNT else "全部关卡开放 · 已通关 %d / %d" % [AdventureProgress.current().completed_count(), AdventureLevels.LEVEL_COUNT]
	GameUI.label(column, progress_text, 18, GameUI.GOLD)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	GameUI.button(actions, "退出游戏", func() -> void: get_tree().quit(), Color("3d4b36"), Vector2(150, 44))
	if AdventureProgress.current().highest_completed_level() >= 14:
		var almanac := GameUI.button(actions, "植物与僵尸图鉴", show_almanac.call_deferred, Color("546640"), Vector2(230, 44))
		almanac.name = "AlmanacButton"
	GameUI.label(column, "演示：1–5 切换大关   ·   F1 随时返回主界面", 16, GameUI.MUTED)
	adventure.grab_focus()
	var stamp := GameUI.panel(root, Color(0.09, 0.15, 0.10, 0.88))
	stamp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	stamp.offset_left = -345
	stamp.offset_right = -35
	stamp.offset_top = -122
	stamp.offset_bottom = -35
	var caption := VBoxContainer.new()
	stamp.add_child(caption)
	GameUI.label(caption, "五个大关 · 1-1 ～ 5-10", 22, GameUI.GOLD)
	GameUI.label(caption, "从一条防线开始，逐步建立庭院。", 17)


func show_levels(area: int = 0) -> void:
	_clear_content()
	current_mode = "levels"
	var root := _menu_root()
	if area == 0:
		area = AdventureLevels.area(AdventureProgress.current().recommended_level())
	var panel := GameUI.panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 32
	panel.offset_right = -32
	panel.offset_top = 20
	panel.offset_bottom = -20
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	GameUI.label(column, "冒险模式  /  " + StageCatalog.STAGE_NAMES[area - 1], 32, GameUI.GOLD)
	GameUI.label(column, "全部 50 关已开放，可任意选关。通关记录会自动保存。", 19, GameUI.MUTED)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for world in range(1, 6):
		var tab := GameUI.button(tabs, "%d · %s" % [world, StageCatalog.STAGE_NAMES[world - 1]], show_levels.bind(world).call_deferred, Color("536c3c"), Vector2(160, 44))
		tab.add_theme_font_size_override("font_size", 17)
		tab.name = "Area%dButton" % world
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for number in range((area - 1) * 10 + 1, area * 10 + 1):
		var reward := AdventureLevels.reward_name(number)
		var status := "已通关 · 可以重玩" if AdventureProgress.current().has_completed(number) else "可以挑战"
		var button := GameUI.button(grid, "%s   %s\n%d 条路径 · %d 波僵尸\n奖励：%s · %s" % [AdventureLevels.code(number), AdventureLevels.TITLES[number - 1], AdventureLevels.rows(number).size(), AdventureLevels.WAVE_COUNTS[number - 1], reward, status], start_level.bind(number).call_deferred, GameUI.GREEN, Vector2(390, 115))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		button.name = "Level%dButton" % number
		button.disabled = not AdventureProgress.current().can_play(number)
	GameUI.button(column, "返回主界面", show_main_menu.call_deferred, Color("465b38"), Vector2(180, 48))


func show_almanac() -> void:
	if AdventureProgress.current().highest_completed_level() < 14:
		return
	_clear_content()
	current_mode = "almanac"
	var root := _menu_root()
	var panel := GameUI.panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 32
	panel.offset_right = -32
	panel.offset_top = 20
	panel.offset_bottom = -20
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	GameUI.label(column, "植物与僵尸图鉴", 32, GameUI.GOLD)
	GameUI.label(column, "显示最高通关关卡范围内的植物与僵尸，数值使用本次启动配置。", 18)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 10)
	scroll.add_child(entries)
	GameUI.label(entries, "植物", 25, GameUI.GOLD)
	for kind: String in AdventureLevels.unlocked_plants(AdventureProgress.current().highest_completed_level() + 1):
		var stats := GameConfiguration.current().section("stages.plants." + kind)
		GameUI.label(entries, "%s · %d 阳光 · %d HP · 卡牌冷却 %.1f 秒" % [StageCatalog.plant_name(kind), stats.sun_cost, stats.maximum_health, GameConfiguration.current().section("adventure").card_cooldowns[kind]], 19)
	GameUI.label(entries, "僵尸", 25, GameUI.GOLD)
	var encountered: Array[String] = []
	for number in range(1, mini(AdventureLevels.LEVEL_COUNT, AdventureProgress.current().highest_completed_level() + 1) + 1):
		for kind: String in AdventureLevels.ENEMIES[number - 1]:
			if not kind in encountered:
				encountered.append(kind)
	if "dancing_zombie" in encountered:
		encountered.append("backup_dancer")
	if AdventureProgress.current().highest_completed_level() >= 20:
		encountered.append("ducky_tube_zombie")
	if AdventureProgress.current().highest_completed_level() >= 48:
		encountered.append("imp")
	if AdventureProgress.current().highest_completed_level() >= 49:
		for kind: String in AdventureLevels.BOSS_SUMMONS:
			if not kind in encountered:
				encountered.append(kind)
	if AdventureProgress.current().highest_completed_level() >= 2:
		encountered.append("flag_zombie")
	for kind: String in encountered:
		var stats := GameConfiguration.current().section("stages.zombies." + kind)
		GameUI.label(entries, "%s · 本体 %d + 头甲 %d + 盾牌 %d HP" % [StageCatalog.ENEMY_NAMES[kind], stats.body_health, stats.helmet_health, stats.shield_health], 19)
	GameUI.button(column, "返回主界面 [Esc]", show_main_menu.call_deferred, Color("465b38"))


func show_demo() -> void:
	_clear_content()
	current_mode = "demo"
	content = load("res://scenes/adventure.tscn").instantiate()
	add_child(content)
	_canvas = CanvasLayer.new()
	_canvas.layer = 40
	add_child(_canvas)
	var root := GameUI.full_rect(_canvas)
	var button := GameUI.button(root, "主界面 [F1]", show_main_menu.call_deferred, Color("435735"), Vector2(160, 42))
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -185
	button.offset_right = -18
	button.offset_top = 12
	button.offset_bottom = 54
	button.focus_mode = Control.FOCUS_NONE


func start_level(number: int, preview: bool = false) -> void:
	if number < 1 or number > AdventureLevels.LEVEL_COUNT or not preview and not AdventureProgress.current().can_play(number):
		return
	_clear_content()
	current_mode = "adventure"
	var board := load("res://scenes/adventure/level_%d.tscn" % number).instantiate() as AdventureBoard
	content = board
	board.retry_requested.connect(start_level.bind(number, preview).call_deferred)
	board.next_requested.connect(start_level.call_deferred)
	board.menu_requested.connect(show_main_menu.call_deferred)
	board.levels_requested.connect(show_levels.call_deferred)
	add_child(board)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			show_main_menu.call_deferred()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and current_mode in ["levels", "almanac"]:
			show_main_menu.call_deferred()
			get_viewport().set_input_as_handled()
