class_name CrazyDave
extends CharacterBody3D
## An independent player character. His front is local -Z.
## Render layer 2 holds the body; the waist camera sees world layer 1.

const MODEL_HEIGHT: float = 1.82

@export var movement_speed: float = 3.0
@export var mouse_sensitivity: float = 0.003
@export var waist_height: float = 0.94
@export var restrict_to_lawn: bool = false
@export var movement_bounds: Rect2 = Rect2(-10.35, -5.55, 20.7, 11.1)

@export var pitch_limit_degrees: float = 60.16056848873644


func _enter_tree() -> void:
	GameConfiguration.current().apply_entity(self)
	var params := GameConfiguration.current().section("dave")
	movement_bounds = Rect2(params.movement_bounds[0], params.movement_bounds[1], params.movement_bounds[2], params.movement_bounds[3])
	if params.derive_bounds_from_lawn:
		var lawn := GameConfiguration.current().section("lawn")
		var half := Vector2(lawn.columns, lawn.rows) * float(lawn.cell_size) * 0.5 - Vector2.ONE * float(params.boundary_inset)
		movement_bounds = Rect2(-half, half * 2.0)
	var camera_params := GameConfiguration.current().section("cameras.first_person")
	var lens := get_node("WaistMount/Camera3D") as Camera3D
	lens.fov = camera_params.fov
	lens.near = camera_params.near
	lens.far = camera_params.far


@onready var waist_mount: Node3D = $WaistMount
@onready var camera: Camera3D = $WaistMount/Camera3D
var first_person_active: bool = true
var interface_open: bool = false
var _spawn_position: Vector3
var _spawn_yaw: float
var _gravity: float = 9.8
var _exploration_bounds: Rect2 = Rect2()


func _ready() -> void:
	add_to_group("dave_player")
	waist_mount.position.y = waist_height
	_spawn_position = global_position
	_spawn_yaw = rotation.y
	_gravity = float(GameConfiguration.current().section("physics").gravity)
	_register_movement_actions()
	_capture_mouse()


func set_spawn(world_position: Vector3, facing_yaw: float) -> void:
	_spawn_position = world_position
	_spawn_yaw = facing_yaw
	reset_pose()


func reset_pose() -> void:
	global_position = _spawn_position
	rotation.y = _spawn_yaw
	waist_mount.rotation.x = 0.0
	velocity = Vector3.ZERO
	if first_person_active:
		_capture_mouse()
	else:
		_release_mouse()


func set_first_person_active(active: bool) -> void:
	first_person_active = active
	if active:
		camera.make_current()
		_capture_mouse()
	else:
		_release_mouse()


func set_interface_open(open: bool) -> void:
	interface_open = open
	if open or not first_person_active:
		_release_mouse()
	else:
		_capture_mouse()


func configure_exploration(bounds: Rect2) -> void:
	# Retain the lawn bounds as the base configuration; extend only for a real
	# walkable area. Solid house walls still enforce physical room boundaries.
	_exploration_bounds = bounds.grow(-float(GameConfiguration.current().section("dave").boundary_inset)) if bounds.has_area() else Rect2()


func get_effective_movement_bounds() -> Rect2:
	return movement_bounds.merge(_exploration_bounds) if _exploration_bounds.has_area() else movement_bounds


func move_with_input(movement: Vector2, delta: float) -> void:
	# Shared by real WASD movement and physics integration checks.
	var direction := global_basis * Vector3(movement.x, 0, movement.y)
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * movement_speed
	velocity.z = direction.z * movement_speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if restrict_to_lawn:
		var bounds := get_effective_movement_bounds()
		var bounded_position := global_position
		bounded_position.x = clampf(bounded_position.x, bounds.position.x, bounds.end.x)
		bounded_position.z = clampf(bounded_position.z, bounds.position.y, bounds.end.y)
		global_position = bounded_position


func _physics_process(delta: float) -> void:
	var movement := Vector2.ZERO
	if first_person_active and not interface_open and get_window().has_focus():
		movement = Input.get_vector("dave_left", "dave_right", "dave_forward", "dave_back")
	move_with_input(movement, delta)


func _unhandled_input(event: InputEvent) -> void:
	if not first_person_active or interface_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		waist_mount.rotation.x = clampf(waist_mount.rotation.x - event.relative.y * mouse_sensitivity, -deg_to_rad(pitch_limit_degrees), deg_to_rad(pitch_limit_degrees))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_release_mouse()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_mouse()


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if interface_open else Input.MOUSE_MODE_CAPTURED


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _register_movement_actions() -> void:
	var actions: Dictionary = {
		"dave_forward": [KEY_W, KEY_UP],
		"dave_back": [KEY_S, KEY_DOWN],
		"dave_left": [KEY_A, KEY_LEFT],
		"dave_right": [KEY_D, KEY_RIGHT],
	}
	for action: String in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
