class_name StageProjectile
extends Node3D
## Swept hits, lobbed trajectories, piercing spores and anti-air are stage-local.

var stage: Node3D
var target: StageZombie
var damage: int = 20
var direction := Vector3.RIGHT
var speed: float = 10.0
var lobbed: bool = false
var piercing: bool = false
var anti_air: bool = false
var cold: bool = false
var butter: bool = false
var splash: bool = false
var burning: bool = false
var torch_compatible: bool = false
var backward: bool = false
var color := Color("80ce50")
var _age: float = 0.0
var _start: Vector3
var _hit_ids: Array[int] = []
var _torch_ids: Array[int] = []
var _spent: bool = false
var _lob_duration: float = 1.2
var maximum_distance: float = 32.0
var target_lane_z: float = INF


func _ready() -> void:
	_start = global_position
	StageModels.sphere(self, "Shot", Vector3.ONE * (0.30 if lobbed else 0.20), Vector3.ZERO, color)
	direction = direction.normalized()


func set_start(origin: Vector3) -> void:
	_start = origin


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age > 7.0:
		queue_free()
		return
	var previous := global_position
	var next := previous + direction * speed * delta
	if is_finite(target_lane_z):
		next.z = lerpf(_start.z, target_lane_z, smoothstep(0.0, 3.6, _age * speed))
	if lobbed:
		if not is_instance_valid(target) or not target.is_alive():
			queue_free()
			return
		var progress := minf(_age / _lob_duration, 1.0)
		next = _start.lerp(target.global_position + Vector3.UP * target.target_height(), progress)
		next.y += sin(progress * PI) * 3.0
	elif anti_air and is_instance_valid(target) and target.is_flying():
		next = previous.move_toward(target.global_position + Vector3.UP * target.target_height(), speed * delta)
	# Only zombies interact with ordinary shots; the tiled roof is handled below.
	var query := PhysicsRayQueryParameters3D.create(previous, next, 4)
	query.hit_from_inside = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	while not result.is_empty():
		var zombie := result.get("collider") as StageZombie
		if _can_hit(zombie):
			_hit(zombie)
			if _spent:
				queue_free()
				return
		var excluded := query.exclude
		excluded.append(result.rid)
		query.exclude = excluded
		result = get_world_3d().direct_space_state.intersect_ray(query)
	global_position = next
	if global_position.distance_to(_start) > maximum_distance:
		queue_free()
		return
	if is_instance_valid(stage):
		if not lobbed and stage.stage_number == 5 and next.y < stage.lawn.surface_at(next) + 0.16:
			queue_free()
			return
		if torch_compatible and not burning:
			for plant: StagePlant in stage.live_plants():
				if plant.plant_kind == "torchwood" and not plant.get_instance_id() in _torch_ids and absf(plant.global_position.z - next.z) < 0.55 and absf(plant.global_position.x - next.x) < 0.50:
					_torch_ids.append(plant.get_instance_id())
					if cold:
						cold = false
						get_node("Shot").material_override = StageModels.material(Color("83c751"))
					else:
						burning = true
						damage *= 2
						get_node("Shot").material_override = StageModels.material(Color("ffb03b"), true)
	if lobbed and _age >= _lob_duration and _can_hit(target):
		_hit(target)
		queue_free()


func _can_hit(zombie: StageZombie) -> bool:
	return zombie != null and zombie.is_alive() and not zombie.hypnotized and not zombie.get_instance_id() in _hit_ids and not zombie.is_hidden_target() and (anti_air or not zombie.is_flying())


func _hit(zombie: StageZombie) -> void:
	_hit_ids.append(zombie.get_instance_id())
	if cold:
		zombie.apply_slow(0.5, 10.0)
	if butter:
		zombie.apply_freeze(4.0)
	zombie.receive_hit(damage, direction, lobbed or piercing or backward, burning)
	if splash and is_instance_valid(stage):
		for other: StageZombie in stage.live_enemies():
			if other != zombie and not other.hypnotized and not other.is_hidden_target() and other.global_position.distance_to(zombie.global_position) < stage.lawn.cell_size * 1.5:
				other.receive_hit(damage / 3, direction, true)
	if not piercing:
		_spent = true
