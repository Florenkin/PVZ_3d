class_name Zombie
extends CharacterBody3D
## Living movement is independent of the rigid bodies left behind after hits.

signal health_changed(health: int, maximum: int)
signal damaged(amount: int)
signal defeated
signal part_detached(part: ZombieDebris)

const HIT_MATERIAL: Material = preload("res://assets/materials/zombie_hit_white.tres")
const MAX_RECOIL_RADIANS: float = PI / 6.0

@export var maximum_health: int = 200
@export var walk_speed: float = 0.5
@export var is_ground_zombie: bool = true
@export var movement_enabled: bool = true
@export var knockback_speed: float = 1.4
@export var knockback_deceleration: float = 10.0
@export var maximum_walk_distance: float = 19.9
@export var has_cone: bool = false
@export var has_bucket: bool = false
@export var flash_duration: float = 0.5
@export var recoil_degrees: float = 30.0
@export var recoil_recovery_time: float = 0.5
@export var armor_drop_health: int = 200
@export var hand_drop_health: int = 100
@export var walk_animation_speed: float = 3.0
@export var walk_bob_height: float = 0.012
@export var leg_swing_degrees: float = 4.58366236104659
@export var frost_color: Array = [0.4784313725, 0.7882352941, 0.9333333333, 1.0]
@export var frost_color_strength: float = 0.48
var health: int = 200
var _visuals_rest: Transform3D = Transform3D.IDENTITY
var _arm_geometry: Dictionary = {}
var imported_demo_model_enabled: bool = false
var animated_visual: DemoZombieVisual
var _legacy_meshes: Array[MeshInstance3D] = []
var _animated_corpses: Array[DemoZombieCorpse] = []


func _enter_tree() -> void:
	GameConfiguration.current().apply_entity(self)


@onready var _visuals: Node3D = $Visuals
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _legs: Node3D = $Visuals/Legs
@onready var _head: Node3D = $Visuals/Head
var _spawn_transform: Transform3D
var _materials: Dictionary = {}
var _frost_materials: Dictionary = {}
var _slow_remaining: float = 0.0
var _slow_multiplier: float = 1.0
var _flash_remaining: float = 0.0
var _recoil_angle: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _walk_phase: float = 0.0
var _leg_rest_rotations: Dictionary = {}
var _gravity: float = 9.8
var _cone_dropped: bool = false
var _bucket_dropped: bool = false
var _hand_dropped: bool = false
var _head_dropped: bool = false
var _debris_parent: Node3D
var _spawned_debris: Array[ZombieDebris] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("zombies")
	_rng.randomize()
	_spawn_transform = global_transform
	_visuals_rest = _visuals.transform
	_capture_arm_geometry()
	_gravity = float(GameConfiguration.current().section("physics").gravity)
	if imported_demo_model_enabled:
		_install_imported_demo_visual()
	for mesh: MeshInstance3D in _visuals.find_children("*", "MeshInstance3D", true, false):
		_materials[mesh] = mesh.material_override if mesh.material_override != null else mesh.get_active_material(0)
	for name: String in ["LeftLeg", "RightLeg"]:
		var leg := _legs.get_node(name) as Node3D
		_leg_rest_rotations[leg] = leg.rotation
	reset_combat()


func set_spawn(world_position: Vector3, facing_yaw: float) -> void:
	global_position = world_position
	rotation.y = facing_yaw
	_spawn_transform = global_transform
	reset_combat()


func configure_debris(parent: Node3D) -> void:
	_debris_parent = parent


func is_alive() -> bool:
	return health > 0 and not is_queued_for_deletion()


func _walk_speed_multiplier() -> float:
	return _slow_multiplier


func get_walk_speed() -> float:
	return walk_speed * _walk_speed_multiplier()


func reset_combat() -> void:
	for corpse: DemoZombieCorpse in _animated_corpses:
		if is_instance_valid(corpse):
			corpse.queue_free()
	_animated_corpses.clear()
	for part: ZombieDebris in _spawned_debris:
		if is_instance_valid(part):
			part.queue_free()
	_spawned_debris.clear()
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_knockback_velocity = Vector3.ZERO
	_recoil_angle = 0.0
	_flash_remaining = 0.0
	_slow_remaining = 0.0
	_slow_multiplier = 1.0
	_walk_phase = 0.0
	_cone_dropped = false
	_bucket_dropped = false
	_hand_dropped = false
	_head_dropped = false
	_visuals.transform = _visuals_rest
	_visuals.show()
	_head.show()
	for side: String in ["Left", "Right"]:
		_visuals.get_node("Arms/" + side + "HandAssembly").show()
	var cone := _head.get_node_or_null("Cone") as Node3D
	if cone != null:
		cone.visible = has_cone
	var bucket := _head.get_node_or_null("Bucket") as Node3D
	if bucket != null:
		bucket.visible = has_bucket
	for leg: Node3D in _leg_rest_rotations:
		leg.rotation = _leg_rest_rotations[leg]
	_restore_materials()
	health = maximum_health
	show()
	_collision.set_deferred("disabled", false)
	if animated_visual != null:
		for mesh: MeshInstance3D in _legacy_meshes:
			mesh.hide()
		animated_visual.reset_pose()
	health_changed.emit(health, maximum_health)


func _install_imported_demo_visual() -> void:
	for mesh: MeshInstance3D in _visuals.find_children("*", "MeshInstance3D", true, false):
		_legacy_meshes.append(mesh)
		mesh.hide()
	animated_visual = DemoZombieVisual.new()
	animated_visual.name = "ImportedAnimatedZombie"
	animated_visual.scale = Vector3.ONE * DemoZombieVisual.MODEL_HEIGHT
	animated_visual.rotation.y = PI
	_visuals.add_child(animated_visual)
	damaged.connect(func(_amount: int) -> void:
		if is_alive():
			animated_visual.notify_hit()
	)


func _animate_demo_model(delta: float, state: StringName) -> void:
	if animated_visual == null:
		return
	var rate := get_walk_speed() / 0.5 if state == &"Walk" else _walk_speed_multiplier()
	animated_visual.animate(delta, state, rate)


func apply_slow(multiplier: float, duration: float) -> void:
	if not is_alive() or duration <= 0.0 or multiplier >= 1.0:
		return
	var strength := clampf(multiplier, 0.0, 1.0)
	_slow_multiplier = minf(_slow_multiplier, strength) if _slow_remaining > 0.0 else strength
	_slow_remaining = maxf(_slow_remaining, duration)
	if _frost_materials.is_empty():
		for mesh: MeshInstance3D in _materials:
			var original := _materials[mesh] as StandardMaterial3D
			if original != null:
				var frosted := original.duplicate() as StandardMaterial3D
				var tint := GameConfiguration.current().color(frost_color)
				tint.a = original.albedo_color.a
				frosted.albedo_color = original.albedo_color.lerp(tint, frost_color_strength)
				_frost_materials[mesh] = frosted
	# The existing white hit flash takes priority over the longer frost tint.
	if _flash_remaining <= 0.0:
		_restore_materials()


func take_damage(amount: int, incoming_direction: Vector3) -> void:
	if not is_alive() or amount <= 0:
		return
	health = maxi(health - amount, 0)
	var backward := incoming_direction
	backward.y = 0.0
	if backward.is_zero_approx():
		backward = global_basis.z
	backward = backward.normalized()
	# Copies use their original palette, even if consecutive hits overlap a flash.
	_restore_materials()
	if has_cone and not _cone_dropped and health <= armor_drop_health:
		_drop_cone(backward)
	if has_bucket and not _bucket_dropped and health <= armor_drop_health:
		_drop_bucket(backward)
	if not _hand_dropped and health <= hand_drop_health:
		_drop_hand(backward)
	_flash_remaining = flash_duration
	_recoil_angle = deg_to_rad(recoil_degrees)
	_visuals.rotation.x = _recoil_angle
	_knockback_velocity = backward * knockback_speed
	if health <= 0:
		_die(backward)
	if flash_duration > 0.0:
		for mesh: MeshInstance3D in _materials:
			mesh.material_override = HIT_MATERIAL
	health_changed.emit(health, maximum_health)
	damaged.emit(amount)
	if not is_alive():
		_collision.set_deferred("disabled", true)
		defeated.emit()


func _drop_cone(backward: Vector3) -> void:
	_cone_dropped = true
	var cone := _head.get_node_or_null("Cone") as Node3D
	if cone == null:
		return
	var hull := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for x: float in [-0.28, 0.28]:
		for z: float in [-0.28, 0.28]:
			points.append(Vector3(x, -0.32, z))
			points.append(Vector3(x, -0.25, z))
	for i in range(12):
		var angle := TAU * i / 12.0
		points.append(Vector3(cos(angle) * 0.035, 0.36, sin(angle) * 0.035))
	hull.points = points
	var part := _make_part(cone, &"cone", Vector3(0, 0.32, 0), hull)
	_launch_part(part, "cone", backward)
	_publish_part(part)


func _drop_bucket(backward: Vector3) -> void:
	_bucket_dropped = true
	var bucket := _head.get_node_or_null("Bucket") as Node3D
	if bucket == null:
		return
	var shape := CylinderShape3D.new()
	shape.radius = 0.355
	shape.height = 0.46
	var part := _make_part(bucket, &"bucket", Vector3(0, 0.17, 0), shape)
	_launch_part(part, "bucket", backward)
	_publish_part(part)


func _drop_hand(backward: Vector3) -> void:
	_hand_dropped = true
	if animated_visual != null:
		return
	var side := "Left" if _rng.randi_range(0, 1) == 0 else "Right"
	var sign_value := -1.0 if side == "Left" else 1.0
	var source := _visuals.get_node("Arms/" + side + "HandAssembly") as Node3D
	var shape := CapsuleShape3D.new()
	shape.radius = 0.085
	shape.height = 0.58
	var center: Vector3 = _arm_geometry[side].center
	var part := _make_part(source, StringName(side.to_lower() + "_hand"), center, shape)
	part.get_node("CollisionShape3D").rotation.x = PI / 2.0
	_launch_part(part, "hand", backward, sign_value)
	_publish_part(part)


func _die(backward: Vector3) -> void:
	if animated_visual != null:
		_die_animated()
		return
	_head_dropped = true
	_slow_remaining = 0.0
	_slow_multiplier = 1.0
	_restore_materials()
	# Death chooses a fresh forward/backward fall, independent of hit recoil.
	_recoil_angle = 0.0
	_visuals.rotation.x = 0.0
	var head_shape := SphereShape3D.new()
	head_shape.radius = 0.31
	var head := _make_part(_head, &"head", Vector3.ZERO, head_shape)
	_launch_part(head, "head", backward)
	_publish_part(head)
	# Keep the remaining forearm attached through a physical elbow joint, so it
	# bends on impact instead of propping a forward-falling corpse upright.
	var attached_arm: ZombieDebris
	var attached_source: Node3D
	var hand_center := Vector3.ZERO
	var elbow := Vector3.ZERO
	for side: String in ["Left", "Right"]:
		var source := _visuals.get_node("Arms/" + side + "HandAssembly") as Node3D
		if source.visible:
			attached_source = source
			var sign_value := -1.0 if side == "Left" else 1.0
			hand_center = _arm_geometry[side].center
			elbow = _arm_geometry[side].elbow
			var arm_shape := CapsuleShape3D.new()
			arm_shape.radius = 0.085
			arm_shape.height = 0.58
			attached_arm = _make_part(source, &"corpse_arm", hand_center, arm_shape)
			attached_arm.get_node("CollisionShape3D").rotation.x = PI / 2.0
			GameConfiguration.current().configure_debris(attached_arm, "corpse_arm")
	var torso_shape := BoxShape3D.new()
	torso_shape.size = Vector3(0.60, 0.68, 0.42)
	var torso: Node3D = _visuals.get_node("Torso")
	GameConfiguration.current().scale_shape(torso_shape, torso.scale * (torso.get_meta("config_bounds_ratio", Vector3.ONE) as Vector3))
	var center := Vector3(0, 0.68, 0)
	var corpse := _make_part(_visuals, &"corpse", center, torso_shape)
	var corpse_params := GameConfiguration.current().section("physics.parts.corpse")
	var overall_scale := _visuals.global_basis.get_scale()
	corpse.get_node("CollisionShape3D").position = (torso.transform * Vector3(0, 0.97, 0.01) - center) * overall_scale
	var legs_shape := BoxShape3D.new()
	legs_shape.size = Vector3(0.46, 0.68, 0.40)
	GameConfiguration.current().scale_shape(legs_shape, overall_scale * _legs.scale * (_legs.get_meta("config_bounds_ratio", Vector3.ONE) as Vector3))
	_add_shape(corpse, legs_shape, (_legs.transform * Vector3(0, 0.34, -0.04) - center) * overall_scale)
	var fall_sign := -1.0 if _rng.randi_range(0, 1) == 0 else 1.0
	corpse.set_meta("fall_direction", fall_sign)
	var launch: Transform3D = corpse.get_meta("launch_transform")
	launch.basis = launch.basis * Basis(Vector3.RIGHT, fall_sign * deg_to_rad(corpse_params.initial_tilt_degrees))
	launch.origin += Vector3.UP * float(corpse_params.lift_height)
	corpse.set_meta("launch_transform", launch)
	corpse.angular_velocity = global_basis.x * fall_sign * float(corpse_params.spin_x_min)
	corpse.linear_velocity = global_basis.z * fall_sign * float(corpse_params.backward_speed) + Vector3.UP * float(corpse_params.upward_speed)
	if attached_arm != null:
		var arm_source := attached_source
		var arm_center := _visuals.to_local(arm_source.to_global(hand_center))
		attached_arm.set_meta("launch_transform", launch.translated_local((arm_center - center) * overall_scale))
		attached_arm.linear_velocity = corpse.linear_velocity
		attached_arm.angular_velocity = corpse.angular_velocity
		corpse.attached_part = attached_arm
		corpse.attachment_anchor = (_visuals.to_local(arm_source.to_global(elbow)) - center) * overall_scale
		_publish_part(attached_arm, false)
	_publish_part(corpse)
	hide()


func _die_animated() -> void:
	_slow_remaining = 0.0
	_slow_multiplier = 1.0
	_restore_materials()
	_recoil_angle = 0.0
	_visuals.rotation.x = 0.0
	var parent := _debris_parent
	if not is_instance_valid(parent):
		parent = get_tree().get_first_node_in_group("combat_debris_container") as Node3D
	if parent == null:
		parent = get_parent() as Node3D
	var corpse := DemoZombieCorpse.new()
	corpse.name = "AnimatedZombieCorpse"
	corpse.lifetime = float(GameConfiguration.current().section("physics.parts.corpse").lifetime)
	parent.add_child(corpse)
	corpse.global_transform = _visuals.global_transform
	var animation_lawn := get_meta("demo_animation_lawn") as StageLawn if has_meta("demo_animation_lawn") else null
	if is_instance_valid(animation_lawn):
		var p := global_position
		var dx := (animation_lawn.surface_at(p + Vector3.RIGHT * .1) - animation_lawn.surface_at(p - Vector3.RIGHT * .1)) / .2
		var dz := (animation_lawn.surface_at(p + Vector3.BACK * .1) - animation_lawn.surface_at(p - Vector3.BACK * .1)) / .2
		var normal := Vector3(-dx, 1, -dz).normalized()
		corpse.global_basis = Basis(Quaternion(Vector3.UP, normal)) * corpse.global_basis
	_animated_corpses.append(corpse)
	hide()


func _make_part(source: Node3D, kind: StringName, center: Vector3, shape: Shape3D) -> ZombieDebris:
	var part := ZombieDebris.new()
	part.name = String(kind).to_pascal_case()
	part.part_kind = kind
	part.owner_zombie_id = get_instance_id()
	GameConfiguration.current().configure_debris(part, _physics_kind(kind))
	part.initial_flash_duration = flash_duration
	var model := source.duplicate() as Node3D
	model.name = "Model"
	var source_scale := source.global_basis.get_scale()
	model.transform = Transform3D(Basis.from_scale(source_scale), -center * source_scale)
	var shape_ratio: Vector3 = Vector3.ONE if kind == &"corpse" else source.get_meta("config_bounds_ratio", Vector3.ONE)
	GameConfiguration.current().scale_shape(shape, source_scale * shape_ratio)
	model.show()
	# Detached parts keep their own original palette, independent of living debuffs.
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var copy := model.get_node(source.get_path_to(mesh)) as MeshInstance3D
		copy.material_override = _materials.get(mesh, mesh.material_override)
	part.add_child(model)
	_add_shape(part, shape, Vector3.ZERO)
	var launch := source.global_transform.translated_local(center)
	launch.basis = launch.basis.orthonormalized()
	part.set_meta("launch_transform", launch)
	source.hide()
	_spawned_debris.append(part)
	return part


func _physics_kind(kind: StringName) -> String:
	return "hand" if String(kind).ends_with("_hand") else String(kind)


func _capture_arm_geometry() -> void:
	# Preserve authored collision/animation anchors, transformed by configured limbs.
	var models: Dictionary = GameConfiguration.current().default_values().models
	var model_key := GameConfiguration.current().entity_key(self)
	var defaults: Dictionary = models.get(model_key, models.zombie).parts
	for side: String in ["Left", "Right"]:
		var sign_value := -1.0 if side == "Left" else 1.0
		var path := "Visuals/Arms/" + side + "HandAssembly/" + side + "Forearm"
		var forearm := get_node(path) as Node3D
		var spec: Dictionary = defaults[path]
		var authored := Transform3D(Basis.from_euler(GameConfiguration.current().vector(spec.rotation_degrees) * PI / 180.0).scaled_local(GameConfiguration.current().vector(spec.scale)), GameConfiguration.current().vector(spec.position))
		var adjusted := forearm.transform * authored.affine_inverse()
		var sleeve_path := "Visuals/Arms/" + side + "Sleeve"
		var sleeve := get_node(sleeve_path) as Node3D
		spec = defaults[sleeve_path]
		authored = Transform3D(Basis.from_euler(GameConfiguration.current().vector(spec.rotation_degrees) * PI / 180.0).scaled_local(GameConfiguration.current().vector(spec.scale)), GameConfiguration.current().vector(spec.position))
		_arm_geometry[side] = {
			"center": adjusted * Vector3(sign_value * 0.35, 0.97 + sign_value * 0.023, -0.50),
			"elbow": adjusted * Vector3(sign_value * 0.35, 0.94 + sign_value * 0.023, -0.23),
			"hand": adjusted * Vector3(sign_value * 0.35, 0.99 + sign_value * 0.023, -0.587),
			"forearm_end": adjusted * Vector3(sign_value * 0.35, 0.99 + sign_value * 0.023, -0.55),
			"shoulder": sleeve.transform * authored.affine_inverse() * Vector3(sign_value * 0.28, 1.16, -0.18)
		}


func _launch_part(part: ZombieDebris, kind: String, backward: Vector3, side: float = 0.0) -> void:
	var params := GameConfiguration.current().section("physics.parts." + kind)
	var sideways := side * float(params.side_speed) if kind == "hand" else _rng.randf_range(-params.side_speed, params.side_speed)
	part.linear_velocity = backward * float(params.backward_speed) + Vector3.UP * float(params.upward_speed) + global_basis.x * sideways
	part.angular_velocity = global_basis.x * _rng.randf_range(params.spin_x_min, params.spin_x_max) + Vector3.UP * float(params.spin_y) + global_basis.z * float(params.spin_z) * (side if kind == "hand" else 1.0)


func _add_shape(body: ZombieDebris, shape: Shape3D, offset: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.shape = shape
	collider.position = offset
	body.add_child(collider)


func _publish_part(part: ZombieDebris, detached: bool = true) -> void:
	var parent := _debris_parent
	if not is_instance_valid(parent):
		parent = get_tree().get_first_node_in_group("combat_debris_container") as Node3D
	if parent == null:
		parent = get_parent() as Node3D
	part.call_deferred("attach_to", parent, part.get_meta("launch_transform"))
	if detached:
		part_detached.emit(part)


func _physics_process(delta: float) -> void:
	_update_slow(delta)
	_update_hit_effect(delta)
	_step_movement(delta)


func _step_movement(delta: float) -> void:
	if not is_alive():
		velocity = Vector3.ZERO
		return
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var walking := movement_enabled and global_position.distance_to(_spawn_transform.origin) < maximum_walk_distance
	var horizontal_velocity := forward * get_walk_speed() if walking else Vector3.ZERO
	horizontal_velocity += _knockback_velocity
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, knockback_deceleration * delta)
	if animated_visual != null:
		var biting := false
		for index in get_slide_collision_count():
			var contact := get_slide_collision(index).get_collider() as Node
			while contact != null and contact != get_parent():
				if contact.is_in_group("vaultable_plants"):
					biting = true
					break
				contact = contact.get_parent()
		_animate_demo_model(delta, &"Eat" if biting else (&"Walk" if walking else &"Idle"))
		return
	if walking:
		_walk_phase += delta * walk_animation_speed * _walk_speed_multiplier()
		_visuals.position.y = _visuals_rest.origin.y + absf(sin(_walk_phase)) * walk_bob_height
		for leg: Node3D in _leg_rest_rotations:
			var sign_value := 1.0 if leg.name == "LeftLeg" else -1.0
			leg.rotation.x = _leg_rest_rotations[leg].x + sin(_walk_phase) * deg_to_rad(leg_swing_degrees) * sign_value


func _update_slow(delta: float) -> void:
	if _slow_remaining <= 0.0:
		return
	_slow_remaining = maxf(_slow_remaining - delta, 0.0)
	if _slow_remaining <= 0.000001:
		_slow_remaining = 0.0
		_slow_multiplier = 1.0
		if _flash_remaining <= 0.0:
			_restore_materials()


func _update_hit_effect(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(_flash_remaining - delta, 0.0)
		if _flash_remaining <= 0.0:
			_restore_materials()
	_recoil_angle = move_toward(_recoil_angle, 0.0, deg_to_rad(recoil_degrees) * delta / recoil_recovery_time)
	_visuals.rotation.x = clampf(_recoil_angle, 0.0, deg_to_rad(recoil_degrees))


func _restore_materials() -> void:
	for mesh: MeshInstance3D in _materials:
		mesh.material_override = _frost_materials.get(mesh, _materials[mesh]) if _slow_remaining > 0.0 else _materials[mesh]
