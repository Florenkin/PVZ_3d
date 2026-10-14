extends Node3D
## Drag to inspect the model. Keep the view above the ground.

@export var default_yaw: float = 0.10
@export var default_pitch: float = 0.72
@export var default_size: float = 15.8
@export var target: Vector3 = Vector3(0.0, 0.1, 0.0)
@export var distance: float = 38.0
@export var minimum_size: float = 5.0
@export var maximum_size: float = 30.0
@export var enabled: bool = true

var yaw_sensitivity: float = 0.008
var pitch_sensitivity: float = 0.005
var minimum_pitch_degrees: float = 6.87549354156988
var maximum_pitch_degrees: float = 65.8901464400447
var zoom_in_factor: float = 0.91
var zoom_out_factor: float = 1.09
var tool_wheel_active: bool = false


func _enter_tree() -> void:
	for field: String in GameConfiguration.current().section("cameras.orbit"):
		set(field, GameConfiguration.current().section("cameras.orbit")[field])


@onready var camera: Camera3D = $Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	reset_view()


func reset_view() -> void:
	_yaw = default_yaw
	_pitch = default_pitch
	camera.size = default_size
	_update_camera()


func set_target_position(new_target: Vector3) -> void:
	target = new_target
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		_dragging = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and (not tool_wheel_active or event.ctrl_pressed):
			camera.size = clampf(camera.size * zoom_in_factor, minimum_size, maximum_size)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and (not tool_wheel_active or event.ctrl_pressed):
			camera.size = clampf(camera.size * zoom_out_factor, minimum_size, maximum_size)
	elif event is InputEventMouseMotion and _dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_yaw -= event.relative.x * yaw_sensitivity
			_pitch = clampf(_pitch + event.relative.y * pitch_sensitivity, deg_to_rad(minimum_pitch_degrees), deg_to_rad(maximum_pitch_degrees))
			_update_camera()
		else:
			_dragging = false
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_view()


func _update_camera() -> void:
	var direction := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	camera.position = target + direction * distance
	camera.look_at(target)
