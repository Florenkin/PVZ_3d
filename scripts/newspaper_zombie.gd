class_name NewspaperZombie
extends Zombie
## A lost newspaper causes one stationary outburst, then faster walking.

signal newspaper_dropped
signal rage_started

@export var newspaper_drop_health: int = 200
@export var anger_pause_duration: float = 1.0
@export var enraged_speed_multiplier: float = 2.0

@onready var _newspaper: Node3D = $Visuals/Newspaper
var has_newspaper: bool = true
var is_angry: bool = false
var is_enraged: bool = false
var _anger_remaining: float = 0.0
var _reading_head_rotation: Vector3


func _ready() -> void:
	_reading_head_rotation = _head.rotation
	super._ready()


func reset_combat() -> void:
	has_newspaper = true
	is_angry = false
	is_enraged = false
	_anger_remaining = 0.0
	super.reset_combat()
	_newspaper.show()
	_head.rotation = _reading_head_rotation
	_show_angry_face(false)


func take_damage(amount: int, incoming_direction: Vector3) -> void:
	if not is_alive() or amount <= 0:
		return
	var remaining_health := maxi(health - amount, 0)
	if has_newspaper and remaining_health <= newspaper_drop_health:
		_drop_newspaper(incoming_direction, remaining_health > 0)
	super.take_damage(amount, incoming_direction)


func _drop_newspaper(incoming_direction: Vector3, start_anger: bool) -> void:
	has_newspaper = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.12, 0.66, 0.20)
	var paper := _make_part(_newspaper, &"newspaper", Vector3.ZERO, shape)
	var backward := Vector3(incoming_direction.x, 0, incoming_direction.z).normalized()
	if backward.is_zero_approx():
		backward = global_basis.z.normalized()
	_launch_part(paper, "newspaper", backward)
	_publish_part(paper)
	if start_anger:
		is_angry = true
		_anger_remaining = anger_pause_duration
		velocity.x = 0.0
		velocity.z = 0.0
		_knockback_velocity = Vector3.ZERO
		_show_angry_face(true)
	newspaper_dropped.emit()


func _walk_speed_multiplier() -> float:
	return super._walk_speed_multiplier() * (enraged_speed_multiplier if is_enraged else 1.0)


func _physics_process(delta: float) -> void:
	if is_alive() and _anger_remaining > 0.0:
		_update_slow(delta)
		_update_hit_effect(delta)
		# Ignore horizontal recoil throughout the outburst, but retain grounding.
		_knockback_velocity = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
		move_and_slide()
		_anger_remaining = maxf(0.0, _anger_remaining - delta)
		_head.rotation = _reading_head_rotation + Vector3(0, 0, sin((anger_pause_duration - _anger_remaining) * 24.0) * deg_to_rad(8.0))
		if _anger_remaining <= 0.000001:
			_anger_remaining = 0.0
			_head.rotation = _reading_head_rotation
			is_enraged = true
			rage_started.emit()
		return
	super._physics_process(delta)


func _show_angry_face(angry: bool) -> void:
	_head.get_node("Glasses").visible = not angry
	_head.get_node("AngryEyes").visible = angry
	for side: String in ["Left", "Right"]:
		_head.get_node(side + "EyeWhite").visible = not angry
		_head.get_node(side + "Pupil").visible = not angry
		_head.get_node(side + "Eyelid").visible = not angry


func _die(backward: Vector3) -> void:
	_anger_remaining = 0.0
	is_angry = false
	is_enraged = false
	_head.rotation = _reading_head_rotation
	super._die(backward)
