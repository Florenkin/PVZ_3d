class_name PeaProjectile
extends Area3D
## Horizontal projectile: the swept center ray also catches fast crossings.

@export var damage: int = 20
@export var speed: float = 10.0
@export var maximum_distance: float = 30.0
@export_range(0.0, 1.0, 0.05) var slow_multiplier: float = 1.0
@export var slow_duration: float = 0.0
var direction: Vector3 = Vector3.RIGHT
var _distance_travelled: float = 0.0
var _spent: bool = false
var _lane_lawn: LawnGrid
var _target_row: int = -1
var _launch_position: Vector3
var _lane_offset: Vector3
var _spread_distance: float = 3.6
var _forward_distance: float = 0.0


func _enter_tree() -> void:
	GameConfiguration.current().configure_projectile(self)


func _ready() -> void:
	direction.y = 0.0
	direction = direction.normalized()
	body_entered.connect(_on_body_entered)
	add_to_group("pea_projectiles")


func configure_lane(lawn: LawnGrid, row: int, lane_center: Vector3, spread_distance: float) -> void:
	_lane_lawn = lawn
	_target_row = row
	_launch_position = global_position
	var sideways := Vector3(-direction.z, 0, direction.x)
	_lane_offset = sideways * (lane_center - _launch_position).dot(sideways)
	_spread_distance = maxf(spread_distance, 0.01)
	_forward_distance = 0.0


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var motion := direction * speed * delta
	var next_position := global_position + motion
	if _target_row >= 0:
		_forward_distance += speed * delta
		var spread := smoothstep(0.0, 1.0, clampf(_forward_distance / _spread_distance, 0.0, 1.0))
		next_position = _launch_position + direction * _forward_distance + _lane_offset * spread
		motion = next_position - global_position
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position, collision_mask)
	query.hit_from_inside = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	while not result.is_empty():
		var zombie := result.get("collider") as Zombie
		if _can_hit(zombie):
			global_position = result["position"]
			_hit(zombie)
			return
		# An off-lane zombie must not block a swept ray aimed at another lane.
		var excluded := query.exclude
		excluded.append(result["rid"])
		query.exclude = excluded
		result = get_world_3d().direct_space_state.intersect_ray(query)
	global_position = next_position
	_distance_travelled += motion.length()
	if _distance_travelled >= maximum_distance:
		_spent = true
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	var zombie := body as Zombie
	if _can_hit(zombie):
		_hit(zombie)


func _can_hit(zombie: Zombie) -> bool:
	if zombie == null or not zombie.is_alive():
		return false
	if _target_row < 0:
		return true
	if not is_instance_valid(_lane_lawn):
		return false
	var cell := _lane_lawn.world_to_cell(zombie.global_position)
	return cell.x >= 0 and cell.y == _target_row


func _hit(zombie: Zombie) -> void:
	if _spent:
		return
	_spent = true
	if slow_duration > 0.0:
		zombie.apply_slow(slow_multiplier, slow_duration)
	zombie.take_damage(damage, direction)
	hide()
	set_deferred("monitoring", false)
	queue_free()
