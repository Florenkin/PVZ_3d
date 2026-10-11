class_name PoleVaultingZombie
extends Zombie
## One pole-assisted ballistic vault, then the shared ground movement and combat.

signal vault_started
signal vault_landed

@export var prepare_time: float = 0.28
@export var pole_length: float = 3.6
@export var pole_radius: float = 0.04
@export var pole_release_fraction: float = 0.45
@export var planted_tip_offset: float = 0.3
@export var vault_lean_degrees: float = 16.042818263663
@export var flight_leg_degrees: float = 34.3774677078494
@export var target_lane_tolerance: float = 0.6

@export var vault_enabled: bool = true
@export_range(0.7, 2.0, 0.1) var vault_trigger_distance: float = 1.3
@export_range(1.4, 2.4, 0.1) var vault_height: float = 1.85
@export_range(0.7, 1.4, 0.1) var landing_clearance: float = 1.1

@onready var _pole: Node3D = $Visuals/Pole
var has_pole: bool = true
var is_vaulting: bool = false
var _preparing: bool = false
var _prepare_elapsed: float = 0.0
var _flight_elapsed: float = 0.0
var _flight_duration: float = 1.0
var _vault_velocity: Vector3 = Vector3.ZERO
var _landing_position: Vector3
var _planted_tip: Vector3
var _pole_rest: Transform3D
var _pole_start: Transform3D
var _arm_rest: Dictionary = {}
var _runner_leg_rest: Dictionary = {}


func _ready() -> void:
	# The scene scale is authored for a 3.6-unit shaft. Keep tips/grip/collider consistent.
	var length_factor := pole_length / 3.6
	for child: MeshInstance3D in _pole.get_children():
		child.position.y *= length_factor
		child.mesh = child.mesh.duplicate(true)
		if child.name == "Shaft":
			(child.mesh as CylinderMesh).height = pole_length
	# Planted poses preserve the configured pole thickness/scale.
	_pole_rest = _pole.transform
	for node: Node3D in [$Visuals/Arms/LeftSleeve, $Visuals/Arms/RightSleeve,
			$Visuals/Arms/LeftHandAssembly, $Visuals/Arms/RightHandAssembly,
			$Visuals/Arms/LeftHandAssembly/LeftForearm, $Visuals/Arms/RightHandAssembly/RightForearm]:
		_arm_rest[node] = node.transform
	for node: Node3D in [$Visuals/Legs/LeftRunnerLeg, $Visuals/Legs/RightRunnerLeg]:
		_runner_leg_rest[node] = node.transform
	super._ready()


func reset_combat() -> void:
	super.reset_combat()
	has_pole = true
	is_vaulting = false
	_preparing = false
	_prepare_elapsed = 0.0
	_flight_elapsed = 0.0
	if is_instance_valid(_pole):
		_pole.transform = _pole_rest
		_pole.show()
	_restore_arms()
	_restore_runner_legs()


func _physics_process(delta: float) -> void:
	if not is_alive():
		super._physics_process(delta)
		return
	if _preparing or is_vaulting:
		_update_slow(delta)
		_update_hit_effect(delta)
		if _preparing:
			_prepare_elapsed += delta
			_pose_planted_pole(smoothstep(0.0, prepare_time, _prepare_elapsed))
			if _prepare_elapsed >= prepare_time:
				_begin_flight()
		else:
			_flight_elapsed += delta
			var progress := clampf(_flight_elapsed / _flight_duration, 0.0, 1.0)
			_visuals.rotation.x = clampf(_recoil_angle - sin(progress * PI) * deg_to_rad(vault_lean_degrees), -MAX_RECOIL_RADIANS, MAX_RECOIL_RADIANS)
			_pose_runner_legs(progress)
			velocity.x = _vault_velocity.x
			velocity.z = _vault_velocity.z
			velocity.y -= _gravity * delta
			move_and_slide()
			_knockback_velocity = Vector3.ZERO
			if has_pole:
				_pose_planted_pole()
				if _flight_elapsed >= _flight_duration * pole_release_fraction:
					_release_pole()
			if is_on_floor() and _flight_elapsed > 0.15:
				is_vaulting = false
				velocity = Vector3.ZERO
				_visuals.rotation.x = _recoil_angle
				_neutral_arms()
				_restore_runner_legs()
				vault_landed.emit()
		return
	super._physics_process(delta)
	if movement_enabled:
		_pose_runner_legs()
	if vault_enabled and has_pole and movement_enabled and is_on_floor():
		var obstacle := _first_plant_ahead()
		if obstacle != null:
			_prepare_vault(obstacle)


func _first_plant_ahead() -> Node3D:
	var forward := -global_basis.z
	var nearest: Node3D
	var nearest_distance := vault_trigger_distance
	for node: Node in get_tree().get_nodes_in_group("vaultable_plants"):
		var plant := node as Node3D
		if plant == null or not plant.is_visible_in_tree() or plant.is_queued_for_deletion():
			continue
		var offset := plant.global_position - global_position
		var distance := offset.dot(forward)
		if distance > 0.0 and distance <= nearest_distance and absf(offset.dot(global_basis.x)) < target_lane_tolerance:
			nearest = plant
			nearest_distance = distance
	return nearest


func _prepare_vault(plant: Node3D) -> void:
	_preparing = true
	_prepare_elapsed = 0.0
	var forward := -global_basis.z
	_landing_position = plant.global_position + forward * landing_clearance
	_landing_position.z = global_position.z
	_planted_tip = plant.global_position - forward * planted_tip_offset
	_pole_start = _pole.global_transform
	velocity = Vector3.ZERO
	_knockback_velocity = Vector3.ZERO
	_pose_planted_pole(0.0)


func _begin_flight() -> void:
	_preparing = false
	is_vaulting = true
	_flight_elapsed = 0.0
	# Gravity determines the flight time; cold affects walking, not a launched arc.
	var launch_speed := sqrt(2.0 * _gravity * vault_height)
	_flight_duration = 2.0 * launch_speed / _gravity
	_vault_velocity = (_landing_position - global_position) / _flight_duration
	_vault_velocity.y = 0.0
	velocity.y = launch_speed
	vault_started.emit()


func _pose_planted_pole(blend: float = 1.0) -> void:
	# Keep the tip planted on the turf while the athlete moves around it.
	var grip_world := _visuals.to_global(Vector3(0, 1.0, -0.6))
	var shaft_direction := (grip_world - _planted_tip).normalized()
	var shaft_scale := _pole_rest.basis.get_scale() * _visuals.scale
	var actual_length := pole_length * shaft_scale.y
	var planted := Transform3D(Basis(Quaternion(Vector3.UP, shaft_direction)).scaled_local(shaft_scale), _planted_tip + shaft_direction * actual_length * 0.5)
	_pole.global_transform = _pole_start.interpolate_with(planted, blend)
	var grip_distance := grip_world.distance_to(_planted_tip)
	for side: String in ["Left", "Right"]:
		var offset := -0.08 if side == "Left" else 0.12
		var grip_height := clampf((grip_distance + offset) / shaft_scale.y, 0.4, pole_length - 0.14)
		var hand := ($Visuals/Arms as Node3D).to_local(_pole.to_global(Vector3(0, grip_height - pole_length * 0.5, 0)))
		var sign_value := -1.0 if side == "Left" else 1.0
		var original_hand: Vector3 = _arm_geometry[side].hand
		var assembly := _visuals.get_node("Arms/" + side + "HandAssembly") as Node3D
		var carry_pose: Transform3D = _arm_rest[assembly]
		var wrist := carry_pose.basis.get_rotation_quaternion().slerp(Quaternion.IDENTITY, blend)
		_pose_arm(side, (carry_pose * original_hand).lerp(hand, blend), wrist)


func _pose_arm(side: String, hand: Vector3, wrist: Quaternion = Quaternion.IDENTITY) -> void:
	var sign_value := -1.0 if side == "Left" else 1.0
	var shoulder: Vector3 = _arm_geometry[side].shoulder
	var elbow := shoulder.lerp(hand, 0.48) + Vector3(sign_value * 0.10, -0.07, 0.07)
	var assembly := _visuals.get_node("Arms/" + side + "HandAssembly") as Node3D
	var original_hand: Vector3 = _arm_geometry[side].hand
	var wrist_basis := Basis(wrist)
	assembly.transform = Transform3D(wrist_basis, hand - wrist_basis * original_hand)
	_pose_segment(_visuals.get_node("Arms/" + side + "Sleeve"), shoulder, elbow)
	_pose_segment(assembly.get_node(side + "Forearm"), assembly.transform.affine_inverse() * elbow, original_hand)


func _pose_segment(mesh: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var segment := end - start
	mesh.position = (start + end) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, segment.normalized())
	mesh.scale.y = segment.length() / (mesh.mesh as CapsuleMesh).height


func _restore_arms() -> void:
	for node: Node3D in _arm_rest:
		node.transform = _arm_rest[node]


func _neutral_arms() -> void:
	# The shared hand/corpse colliders use these original forearm coordinates.
	for side: String in ["Left", "Right"]:
		var sign_value := -1.0 if side == "Left" else 1.0
		var elbow: Vector3 = _arm_geometry[side].elbow
		var assembly := _visuals.get_node("Arms/" + side + "HandAssembly") as Node3D
		assembly.transform = Transform3D.IDENTITY
		_pose_segment(_visuals.get_node("Arms/" + side + "Sleeve"), _arm_geometry[side].shoulder, elbow)
		_pose_segment(assembly.get_node(side + "Forearm"), elbow, _arm_geometry[side].forearm_end)


func _restore_runner_legs() -> void:
	for leg: Node3D in _runner_leg_rest:
		leg.transform = _runner_leg_rest[leg]


func _pose_runner_legs(flight_progress: float = -1.0) -> void:
	for leg: Node3D in _runner_leg_rest:
		leg.transform = _runner_leg_rest[leg]
		var sign_value := -1.0 if leg.name == "LeftRunnerLeg" else 1.0
		leg.rotation.x += sin(flight_progress * PI) * sign_value * deg_to_rad(flight_leg_degrees) if flight_progress >= 0.0 else sin(_walk_phase) * sign_value * deg_to_rad(leg_swing_degrees)


func _release_pole() -> void:
	if not has_pole:
		return
	has_pole = false
	_neutral_arms()
	var shape := CapsuleShape3D.new()
	shape.radius = pole_radius
	shape.height = pole_length
	var pole := _make_part(_pole, &"pole", Vector3.ZERO, shape)
	pole.initial_flash_duration = _flash_remaining
	pole.collision_mask |= 32
	_launch_part(pole, "pole", global_basis.z)
	_publish_part(pole)


func _drop_hand(backward: Vector3) -> void:
	# A lost hand ends the grip; all detached parts keep the shared physics rules.
	_release_pole()
	if _preparing:
		_preparing = false
	super._drop_hand(backward)


func _die(backward: Vector3) -> void:
	_release_pole()
	_preparing = false
	is_vaulting = false
	_neutral_arms()
	_restore_runner_legs()
	super._die(backward)
