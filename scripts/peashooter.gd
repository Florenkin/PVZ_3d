class_name Peashooter
extends Node3D
## Detect living ground zombies in the same lane, and fire horizontally along +X.

signal shot_fired(projectile: PeaProjectile)

const PEA_SCENE: PackedScene = preload("res://scenes/projectiles/pea.tscn")
const MAX_RECOIL_RADIANS: float = PI / 6.0

@export var idle_animation_enabled: bool = true
@export_range(0.0, 0.08, 0.001) var idle_amplitude: float = 0.018
@export_range(0.1, 4.0, 0.1) var idle_speed: float = 1.5
@export var combat_enabled: bool = true
@export var shot_interval: float = 1.5
@export var pea_damage: int = 20
@export var pea_speed: float = 10.0
@export_range(0.0, 30.0, 0.5) var recoil_degrees: float = 20.0
@export_range(0.05, 1.0, 0.01) var recoil_recovery_time: float = 0.28

@export var maximum_recoil_degrees: float = 30.0
@export var idle_bend_degrees: float = 1.03132403123548
@export var idle_bend_speed: float = 0.7
@export var leaf_sway_degrees: float = 0.859436692696235
@export var leaf_sway_speed: float = 0.65
@export var target_lane_tolerance: float = 0.6


func _enter_tree() -> void:
	GameConfiguration.current().apply_entity(self)


@onready var _head: Node3D = $Head
@onready var _stem: Node3D = $Stem
@onready var _root: Node3D = $Stem/Root
@onready var _leaves: Node3D = $Leaves
@onready var _muzzle_tip: Marker3D = $Head/Muzzle/MuzzleTip
var _time: float = 0.0
var _head_rest_position: Vector3
var _head_rest_rotation: Vector3
var _head_rest_transform: Transform3D
var _stem_rest_transform: Transform3D
var _root_rest_in_plant: Transform3D
var _leaves_rest_rotation: Vector3
var _lawn: LawnGrid
var _projectile_parent: Node3D
var _shot_countdown: float = 1.5
var _recoil_angle: float = 0.0
var _recoil_peak: float = 0.0
var _recoil_remaining: float = 0.0
var _recoil_duration: float = 0.28


func _ready() -> void:
	add_to_group("vaultable_plants")
	_head_rest_position = _head.position
	_head_rest_rotation = _head.rotation
	_head_rest_transform = _head.transform
	_stem_rest_transform = _stem.transform
	_root_rest_in_plant = _stem.transform * _root.transform
	_leaves_rest_rotation = _leaves.rotation
	_shot_countdown = shot_interval


func configure_combat(lawn: LawnGrid, projectiles: Node3D) -> void:
	_lawn = lawn
	_projectile_parent = projectiles
	reset_combat()


func reset_combat() -> void:
	_shot_countdown = shot_interval
	_recoil_angle = 0.0
	_recoil_peak = 0.0
	_recoil_remaining = 0.0
	_time = 0.0
	_apply_visual_pose()


func _physics_process(delta: float) -> void:
	_update_recoil(delta)
	if not combat_enabled or not _has_ground_target():
		_shot_countdown = shot_interval
		return
	_shot_countdown -= delta
	if _shot_countdown <= 0.000001:
		_fire()
		_shot_countdown += maxf(shot_interval, 0.01)


func _has_ground_target() -> bool:
	var forward := _horizontal_forward()
	for node: Node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as Zombie
		if zombie == null or not zombie.is_alive() or not zombie.is_ground_zombie or not zombie.is_on_floor():
			continue
		var offset := zombie.global_position - global_position
		if offset.dot(forward) <= 0.0:
			continue
		if is_instance_valid(_lawn):
			var plant_cell := _lawn.world_to_cell(global_position)
			var zombie_cell := _lawn.world_to_cell(zombie.global_position)
			if plant_cell.x >= 0 and zombie_cell.x >= 0 and plant_cell.y == zombie_cell.y:
				return true
		else:
			var sideways := Vector3(-forward.z, 0, forward.x)
			if absf(offset.dot(sideways)) < target_lane_tolerance:
				return true
	return false


func _horizontal_forward() -> Vector3:
	var forward := global_basis.x
	forward.y = 0.0
	return forward.normalized()


func _fire() -> void:
	var pea := PEA_SCENE.instantiate() as PeaProjectile
	GameConfiguration.current().configure_projectile(pea)
	pea.damage = pea_damage
	pea.speed = pea_speed
	pea.direction = _horizontal_forward()
	var parent: Node = _projectile_parent if is_instance_valid(_projectile_parent) else get_parent()
	parent.add_child(pea)
	pea.global_position = _muzzle_tip.global_position
	# Launch from the current muzzle before the kick; flight direction stays level.
	_trigger_recoil()
	shot_fired.emit(pea)


func _trigger_recoil() -> void:
	var kick := deg_to_rad(clampf(recoil_degrees, 0.0, 30.0))
	_recoil_angle = clampf(_recoil_angle + kick, 0.0, deg_to_rad(maximum_recoil_degrees))
	_recoil_peak = _recoil_angle
	_recoil_duration = maxf(recoil_recovery_time, 0.01)
	_recoil_remaining = _recoil_duration
	_apply_visual_pose()


func _update_recoil(delta: float) -> void:
	_recoil_remaining = maxf(_recoil_remaining - delta, 0.0)
	# Ease out to the rest pose without a spring overshoot past the angle limit.
	var remaining_fraction := _recoil_remaining / _recoil_duration
	_recoil_angle = _recoil_peak * remaining_fraction * remaining_fraction
	_apply_visual_pose()


func _apply_visual_pose() -> void:
	# Head and complete stem share one rotation around the planted root.
	var angle := clampf(sin(_time * idle_bend_speed) * deg_to_rad(idle_bend_degrees) + _recoil_angle, -deg_to_rad(maximum_recoil_degrees), deg_to_rad(maximum_recoil_degrees))
	var bend := Basis(Vector3.BACK, angle)
	var pivot := _root_rest_in_plant.origin
	var upper_plant_pose := Transform3D(bend, pivot - bend * pivot)
	upper_plant_pose.origin.y += sin(_time) * idle_amplitude
	_head.transform = upper_plant_pose * _head_rest_transform
	_stem.transform = upper_plant_pose * _stem_rest_transform
	# The root mesh is a stem child in the editable scene; keep it planted.
	_root.transform = _stem.transform.affine_inverse() * _root_rest_in_plant
	_leaves.rotation = _leaves_rest_rotation + Vector3(0, sin(_time * leaf_sway_speed) * deg_to_rad(leaf_sway_degrees), 0)


func _process(delta: float) -> void:
	if idle_animation_enabled:
		_time += delta * idle_speed
	_apply_visual_pose()
