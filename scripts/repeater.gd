class_name Repeater
extends Peashooter
## Configurable burst from one muzzle. Target loss cancels remaining shots.

@export var burst_size: int = 2
@export var burst_spacing: float = 0.18
var _burst_shots_remaining: int = 0
var _burst_countdown: float = 0.0


func reset_combat() -> void:
	super.reset_combat()
	_burst_shots_remaining = 0
	_burst_countdown = 0.0


func _physics_process(delta: float) -> void:
	_update_recoil(delta)
	if not combat_enabled or not _has_ground_target():
		_shot_countdown = shot_interval
		_burst_shots_remaining = 0
		_burst_countdown = 0.0
		return
	_shot_countdown -= delta
	if _burst_shots_remaining > 0:
		_burst_countdown -= delta
		while _burst_countdown <= 0.000001 and _burst_shots_remaining > 0:
			_fire()
			_burst_shots_remaining -= 1
			_burst_countdown += maxf(burst_spacing, 0.01)
	if _shot_countdown <= 0.000001 and _burst_shots_remaining == 0:
		_fire()
		_burst_shots_remaining = burst_size - 1
		_burst_countdown = maxf(burst_spacing, 0.01)
		_shot_countdown += maxf(shot_interval, burst_spacing * (burst_size - 1) + 0.01)
