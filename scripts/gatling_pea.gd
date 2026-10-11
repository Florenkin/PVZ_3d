class_name GatlingPea
extends Peashooter
## Four consecutive peas attack one lane; every shot kicks the complete plant.

const BARREL_COUNT: int = 4
@export var burst_size: int = 4

@export_range(0.01, 1.0, 0.01) var burst_spacing: float = 0.18

@onready var _barrel_rotor: Node3D = $Head/Muzzle/BarrelRotor
var _burst_shots_remaining: int = 0
var _burst_countdown: float = 0.0
var _barrel_index: int = 0


func reset_combat() -> void:
	super.reset_combat()
	_burst_shots_remaining = 0
	_burst_countdown = 0.0
	_barrel_index = 0


func _physics_process(delta: float) -> void:
	_update_recoil(delta)
	if not combat_enabled or not _has_ground_target():
		# Cancel pending peas while the visible recoil continues to recover.
		_shot_countdown = shot_interval
		_burst_shots_remaining = 0
		_burst_countdown = 0.0
		_barrel_index = 0
		return
	_shot_countdown -= delta
	if _burst_shots_remaining > 0:
		_burst_countdown -= delta
		while _burst_countdown <= 0.000001 and _burst_shots_remaining > 0:
			_fire()
			_burst_shots_remaining -= 1
			_burst_countdown += maxf(burst_spacing, 0.01)
	if _shot_countdown <= 0.000001 and _burst_shots_remaining == 0:
		_barrel_index = 0
		_fire()
		_burst_shots_remaining = burst_size - 1
		_burst_countdown = maxf(burst_spacing, 0.01)
		_shot_countdown += maxf(shot_interval, burst_spacing * (burst_size - 1) + 0.01)


func _fire() -> void:
	var muzzle := _barrel_rotor.get_node("Barrel%d/MuzzleTip" % (_barrel_index + 1)) as Marker3D
	var pea := PEA_SCENE.instantiate() as PeaProjectile
	GameConfiguration.current().configure_projectile(pea)
	pea.damage = pea_damage
	pea.speed = pea_speed
	pea.direction = _horizontal_forward()
	var parent: Node = _projectile_parent if is_instance_valid(_projectile_parent) else get_parent()
	parent.add_child(pea)
	pea.global_position = muzzle.global_position
	_barrel_index = (_barrel_index + 1) % BARREL_COUNT
	_trigger_recoil()
	shot_fired.emit(pea)
