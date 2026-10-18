class_name DemoZombieCorpse
extends Node3D
## Independent animated body survives the actor's one-second respawn.

var visual: DemoZombieVisual
var lifetime := 5.0
var age := 0.0
var _fade_duration := 0.5
var _fall_rate := 1.0


func _ready() -> void:
	add_to_group("animated_zombie_corpses")
	visual = DemoZombieVisual.new()
	visual.name = "FallingBody"
	visual.scale = Vector3.ONE * DemoZombieVisual.MODEL_HEIGHT
	visual.rotation.y = PI
	add_child(visual)
	visual.begin_fall()
	_fade_duration = minf(0.5, lifetime * 0.25)
	var fall_duration := visual.player.get_animation(visual.clip_names[&"Fall"]).length
	_fall_rate = maxf(1.0, fall_duration / maxf(0.01, lifetime - _fade_duration))


func _physics_process(delta: float) -> void:
	age += delta
	visual.advance_fall(delta * _fall_rate)
	if age > lifetime - _fade_duration:
		visual.skinned_mesh.transparency = clampf((age - lifetime + _fade_duration) / _fade_duration, 0.0, 1.0)
	if age >= lifetime:
		queue_free()
