class_name DemoTools
extends Node3D
## Shared handheld tools for the five showcases and the original demo.

const TOOL_IDS: Array[String] = ["empty", "shovel"]
const TOOL_NAMES: Array[String] = ["空手", "铲子"]
const TARGET_LAYER: int = 128
var selected_index: int = 0
var reach: float = 4.8
var target: Node3D
var _demo: Node3D
var _dave: CrazyDave
var _hand: Node3D
var _hand_visual: DaveHand
var _panel: PanelContainer
var _title: Label
var _hint: Label
var _feedback: String = ""
var _feedback_remaining: float = 0.0


func configure(demo: Node3D, dave: CrazyDave) -> void:
	_demo = demo
	_dave = dave


func _ready() -> void:
	reach = float(GameConfiguration.current().section("demo_tools").shovel_reach)
	_build_hand()
	_build_interface()
	for plant: Node3D in _demo.get_node("Plants").get_children():
		register_plant(plant)
	_refresh_interface()


func register_plant(plant: Node3D) -> void:
	# Stage plants already expose a collider; legacy shooters need a picking area.
	if plant is StagePlant or plant.has_node("ToolTarget"):
		return
	var area := Area3D.new()
	area.name = "ToolTarget"
	area.collision_layer = TARGET_LAYER
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.55
	shape.shape = capsule
	shape.position.y = 0.78
	area.add_child(shape)
	plant.add_child(area)


func selected_tool() -> String:
	return TOOL_IDS[selected_index]


func cycle_tool(direction: int) -> void:
	selected_index = posmod(selected_index + direction, TOOL_IDS.size())
	target = null
	_feedback_remaining = 0.0
	_hand_visual.equip("shovel" if selected_tool() == "shovel" else "")
	_refresh_interface()


func reset_tools() -> void:
	selected_index = 0
	target = null
	_hand_visual.equip("")
	_feedback_remaining = 0.0
	_refresh_interface()


func _unhandled_input(event: InputEvent) -> void:
	if _dave.interface_open or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not event.ctrl_pressed:
		cycle_tool(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT and selected_tool() == "shovel":
		var at: Vector2 = get_viewport().get_visible_rect().get_center() if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else event.position
		use_shovel(at)
		get_viewport().set_input_as_handled()


func target_at_screen(at: Vector2) -> Node3D:
	if _dave.interface_open:
		return null
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var start := camera.project_ray_origin(at)
	var length := minf(camera.far, reach) if _dave.first_person_active else camera.far
	var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(at) * length, 1 | 4 | 32 | TARGET_LAYER)
	query.collide_with_areas = true
	query.hit_from_inside = true
	query.exclude = [_dave.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var actor := hit.get("collider") as Node
	while actor != null and actor.get_parent() != _demo.get_node("Plants"):
		actor = actor.get_parent()
	if not actor is Node3D or not actor.is_visible_in_tree() or actor.is_queued_for_deletion():
		return null
	if actor is StagePlant and not actor.is_alive():
		return null
	return actor as Node3D


func use_shovel(at: Vector2) -> bool:
	if selected_tool() != "shovel" or _dave.interface_open:
		return false
	var plant := target_at_screen(at)
	_hand_visual.swing()
	if plant == null:
		_feedback = "瞄准植物；戴夫视角需靠近。"
		_feedback_remaining = 1.8
		_refresh_interface()
		return false
	var plant_name := StageCatalog.plant_name(plant.plant_kind) if plant is StagePlant else _legacy_name(plant)
	if not _demo.remove_demo_plant(plant):
		return false
	target = null
	_feedback = "已铲除%s · R 恢复" % plant_name
	_feedback_remaining = 2.0
	_refresh_interface()
	return true


func _legacy_name(plant: Node) -> String:
	return StageCatalog.plant_name(plant.scene_file_path.get_file().get_basename())


func _physics_process(_delta: float) -> void:
	target = null
	if selected_tool() == "shovel" and not _dave.interface_open and get_viewport().gui_get_hovered_control() == null:
		var at := get_viewport().get_visible_rect().get_center() if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else get_viewport().get_mouse_position()
		target = target_at_screen(at)


func _process(delta: float) -> void:
	_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	_panel.visible = not _dave.interface_open
	_refresh_interface()


func _refresh_interface() -> void:
	if not is_instance_valid(_title):
		return
	_title.text = "手持：%s  %d / %d" % [TOOL_NAMES[selected_index], selected_index + 1, TOOL_IDS.size()]
	if _feedback_remaining > 0:
		_hint.text = _feedback
	elif selected_tool() == "empty":
		_hint.text = "滚轮切换道具"
	elif is_instance_valid(target):
		_hint.text = "右键铲除：" + (StageCatalog.plant_name(target.plant_kind) if target is StagePlant else _legacy_name(target))
	else:
		_hint.text = "滚轮切换 · 右键铲除植物"
	_hint.modulate = GameUI.GOLD if is_instance_valid(target) else Color.WHITE


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ToolUI"
	canvas.layer = 22
	add_child(canvas)
	var root := GameUI.full_rect(canvas)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	_panel = GameUI.panel(root, Color(0.08, 0.15, 0.09, 0.94))
	_panel.name = "ToolPanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -330
	_panel.offset_right = -18
	_panel.offset_top = 68 if _demo is StageDemo else 118
	_panel.offset_bottom = _panel.offset_top + 92
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_title = GameUI.label(column, "", 23, GameUI.GOLD)
	_hint = GameUI.label(column, "", 17)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_hand() -> void:
	_hand_visual = DaveHand.new()
	_hand_visual.name = "DaveHand"
	_hand_visual.configure(_dave, true)
	add_child(_hand_visual)
	_hand = _hand_visual.hand
