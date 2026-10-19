class_name AdventureBowlingNut
extends Node3D
## Swept bowling hits; normal nuts ricochet into an adjacent lane once per hit.

var stage: AdventureBoard
var explosive: bool = false
var _visuals: Node3D
var _hit_ids: Array[int] = []
var _target_z: float
var _age: float = 0.0


func _ready() -> void:
	_visuals = Node3D.new()
	add_child(_visuals)
	_visuals.position.y = 0.75
	var model := Node3D.new()
	model.position.y = -0.75
	_visuals.add_child(model)
	StageModels.plant(model, "explosive_nut" if explosive else "bowling_nut")
	_target_z = global_position.z


func _physics_process(delta: float) -> void:
	_age += delta
	var before := global_position
	global_position.x += float(stage.settings.bowling_speed) * delta
	global_position.z = move_toward(global_position.z, _target_z, stage.lawn.cell_size * delta * 2.5)
	_visuals.rotation.z -= float(stage.settings.bowling_speed) * delta
	for enemy: StageZombie in stage.live_enemies():
		if enemy.hypnotized or enemy.get_instance_id() in _hit_ids:
			continue
		var closest := Geometry3D.get_closest_point_to_segment(enemy.global_position, before, global_position)
		if Vector2(closest.x - enemy.global_position.x, closest.z - enemy.global_position.z).length() > 0.7:
			continue
		_hit_ids.append(enemy.get_instance_id())
		if explosive:
			for victim: StageZombie in stage.live_enemies():
				var offset := victim.global_position - enemy.global_position
				if absf(offset.x) <= stage.lawn.cell_size * 1.5 and absf(offset.z) <= stage.lawn.cell_size * 1.1:
					victim.receive_hit(int(stage.settings.bowling_explosion_damage), Vector3.RIGHT, true, true)
			stage.effect(enemy.global_position + Vector3.UP * 0.5, Color.ORANGE, 2.2)
			queue_free()
			return
		enemy.receive_hit(int(stage.settings.bowling_damage), Vector3.RIGHT)
		var row := clampi(int(round(global_position.z / stage.lawn.cell_size + 2)), 0, 4)
		var next_row := row + (1 if row == 0 else (-1 if row == 4 else (1 if _hit_ids.size() % 2 else -1)))
		_target_z = stage.lawn.cell_to_world(next_row, 0).z
		break
	if global_position.x > stage.lawn.cell_to_world(2, 8).x + stage.lawn.cell_size * 2.0 or _age > 15.0:
		queue_free()
