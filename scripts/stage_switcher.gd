class_name StageSwitcher
extends Node
## All pending actor refreshes are owned by the outgoing scene.

signal stage_changed(number: int)
var current_stage: int = -1
var current_demo: Node3D
var _switch_pending: bool = false
var _bar: HBoxContainer


func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	_bar = HBoxContainer.new()
	_bar.position = Vector2(14, 12)
	_bar.add_theme_constant_override("separation", 8)
	canvas.add_child(_bar)
	for index in 5:
		var button := Button.new()
		button.text = "%d  %s" % [index + 1, StageCatalog.STAGE_NAMES[index]]
		button.custom_minimum_size = Vector2(132, 36)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(switch_stage.bind(index + 1))
		_bar.add_child(button)
	var number := int(GameConfiguration.current().section("stages").start_stage)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			var value := argument.trim_prefix("--stage=")
			if value.is_valid_int() and int(value) >= 0 and int(value) <= 5:
				number = int(value)
	switch_stage(number)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var number := -1
		if event.keycode >= KEY_0 and event.keycode <= KEY_5:
			number = event.keycode - KEY_0
		else:
			number = [KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5].find(event.keycode)
		if number >= 0:
			get_viewport().set_input_as_handled()
			if not _switch_pending:
				_switch_pending = true
				switch_stage.call_deferred(number)


func switch_stage(number: int) -> void:
	_switch_pending = false
	if number < 0 or number > 5 or number == current_stage:
		return
	var path := "res://scenes/main.tscn" if number == 0 else StageCatalog.STAGE_PATHS[number - 1]
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("无法加载大关场景：" + path)
		return
	if is_instance_valid(current_demo):
		if current_demo.has_method("begin_close"):
			current_demo.begin_close()
		remove_child(current_demo)
		current_demo.queue_free()
	current_stage = number
	current_demo = packed.instantiate() as Node3D
	add_child(current_demo)
	_bar.visible = number != 0
	for index in 5:
		(_bar.get_child(index) as Button).disabled = index + 1 == number
	stage_changed.emit(number)
