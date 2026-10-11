class_name Threepeater
extends Peashooter
## One volley covers the plant's lane and its two neighboring lawn lanes.

@export_range(0.5, 8.0, 0.1) var lane_spread_distance: float = 3.6

@onready var _left_muzzle: Marker3D = $Head/LeftHead/Muzzle/MuzzleTip
@onready var _right_muzzle: Marker3D = $Head/RightHead/Muzzle/MuzzleTip


func _has_ground_target() -> bool:
	if not is_instance_valid(_lawn):
		return false
	var plant_cell := _lawn.world_to_cell(global_position)
	if plant_cell.x < 0:
		return false
	var forward := _horizontal_forward()
	for node: Node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as Zombie
		if zombie == null or not zombie.is_alive() or not zombie.is_ground_zombie or not zombie.is_on_floor():
			continue
		if (zombie.global_position - global_position).dot(forward) <= 0.0:
			continue
		var zombie_cell := _lawn.world_to_cell(zombie.global_position)
		if zombie_cell.x >= 0 and absi(zombie_cell.y - plant_cell.y) <= 1:
			return true
	return false


func _fire() -> void:
	if not is_instance_valid(_lawn):
		return
	var cell := _lawn.world_to_cell(global_position)
	if cell.x < 0:
		return
	var muzzles: Array[Marker3D] = [_left_muzzle, _muzzle_tip, _right_muzzle]
	var volley: Array[PeaProjectile] = []
	var parent: Node = _projectile_parent if is_instance_valid(_projectile_parent) else get_parent()
	# Sample every muzzle before the shared head-and-stem kick starts.
	for index in range(3):
		var row := cell.y + index - 1
		if not _lawn.is_valid_cell(row, cell.x):
			continue
		var pea := PEA_SCENE.instantiate() as PeaProjectile
		GameConfiguration.current().configure_projectile(pea)
		pea.damage = pea_damage
		pea.speed = pea_speed
		pea.direction = _horizontal_forward()
		parent.add_child(pea)
		pea.global_position = muzzles[index].global_position
		pea.configure_lane(_lawn, row, _lawn.cell_to_world(row, cell.x), lane_spread_distance)
		volley.append(pea)
	if not volley.is_empty():
		_trigger_recoil()
		for pea: PeaProjectile in volley:
			shot_fired.emit(pea)
