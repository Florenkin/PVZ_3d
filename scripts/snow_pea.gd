class_name SnowPea
extends Peashooter
## An icy pea slows the living target while retaining the shared firing pose.

const SNOW_PEA_SCENE: PackedScene = preload("res://scenes/projectiles/snow_pea.tscn")

@export_range(0.0, 1.0, 0.05) var slow_multiplier: float = 0.5
@export_range(0.1, 30.0, 0.1) var slow_duration: float = 10.0


func _fire() -> void:
	var pea := SNOW_PEA_SCENE.instantiate() as PeaProjectile
	GameConfiguration.current().configure_projectile(pea)
	pea.damage = pea_damage
	pea.speed = pea_speed
	pea.direction = _horizontal_forward()
	pea.slow_multiplier = slow_multiplier
	pea.slow_duration = slow_duration
	var parent: Node = _projectile_parent if is_instance_valid(_projectile_parent) else get_parent()
	parent.add_child(pea)
	pea.global_position = _muzzle_tip.global_position
	_trigger_recoil()
	shot_fired.emit(pea)
