class_name ZombieDebris
extends RigidBody3D
## Detached geometry keeps moving under gravity, ground contact and friction.

signal landed

const HIT_MATERIAL: Material = preload("res://assets/materials/zombie_hit_white.tres")

var part_kind: StringName
var owner_zombie_id: int = 0
var lifetime: float = 10.0
var age: float = 0.0
var has_landed: bool = false
var initial_flash_duration: float = 0.5
var _flash_remaining: float = 0.0
var _materials: Dictionary = {}
var attached_part: ZombieDebris
var attachment_anchor: Vector3


func _init() -> void:
	collision_layer = 16
	# Peas and living enemies use separate layers; remains collide with terrain and each other.
	collision_mask = 17
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.12
	angular_damp = 0.8
	var surface := PhysicsMaterial.new()
	surface.friction = 0.75
	surface.bounce = 0.16
	physics_material_override = surface


func attach_to(parent: Node3D, world_transform: Transform3D) -> void:
	# Deferred attachment lets collision shapes enter outside physics-query callbacks.
	if is_queued_for_deletion():
		return
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		queue_free()
		return
	transform = parent.global_transform.affine_inverse() * world_transform
	parent.add_child(self)


func _ready() -> void:
	add_to_group("zombie_debris")
	if is_instance_valid(attached_part) and attached_part.is_inside_tree():
		var joint := PinJoint3D.new()
		joint.name = "ElbowJoint"
		joint.position = attachment_anchor
		joint.node_a = get_path()
		joint.node_b = attached_part.get_path()
		add_child(joint)
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		_materials[mesh] = mesh.material_override
	_flash_remaining = initial_flash_duration
	if _flash_remaining > 0.0:
		for mesh: MeshInstance3D in _materials:
			mesh.material_override = HIT_MATERIAL


func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime - 0.000001:
		queue_free()
		return
	if not has_landed and get_contact_count() > 0:
		has_landed = true
		landed.emit()
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(_flash_remaining - delta, 0.0)
		if _flash_remaining <= 0.0:
			for mesh: MeshInstance3D in _materials:
				mesh.material_override = _materials[mesh]
