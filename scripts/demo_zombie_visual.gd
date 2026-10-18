class_name DemoZombieVisual
extends Node3D
## Manually advances imported bone clips on the same physics clock as combat.

const MODEL_PATH := "res://assets/3D/imported_zombie/zombie_animated.glb"
const MODEL_HEIGHT := 1.82
const BLEND_TIME := 0.16
static var _model_scene: PackedScene
var player: AnimationPlayer
var skeleton: Skeleton3D
var skinned_mesh: MeshInstance3D
var clip_names: Dictionary = {}
var current_state: StringName = &"Idle"
var _hit_remaining := 0.0


func _ready() -> void:
	if _model_scene == null:
		_model_scene = load(MODEL_PATH) as PackedScene
	var imported := _model_scene.instantiate() as Node3D
	imported.name = "RiggedModel"
	add_child(imported)
	player = imported.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for candidate: Node in imported.find_children("*", "Skeleton3D", true, false):
		skeleton = candidate as Skeleton3D
		break
	for candidate: Node in imported.find_children("*", "MeshInstance3D", true, false):
		skinned_mesh = candidate as MeshInstance3D
		break
	assert(player != null and skeleton != null and skinned_mesh != null)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip: StringName in player.get_animation_list():
		var short_name := String(clip).get_slice("/", String(clip).count("/"))
		clip_names[StringName(short_name)] = clip
		if short_name in ["Idle", "Walk", "Eat"]:
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		else:
			player.get_animation(clip).loop_mode = Animation.LOOP_NONE
	reset_pose()


func reset_pose() -> void:
	_hit_remaining = 0.0
	current_state = &""
	player.stop()
	_play(&"Idle", 0.0)
	player.advance(0.0)


func notify_hit() -> void:
	_hit_remaining = 0.4
	_play(&"Hit", 0.06, true)
	player.advance(0.0)


func animate(delta: float, state: StringName, rate: float = 1.0) -> void:
	if state == &"Frozen":
		return
	var next := state
	if _hit_remaining > 0.0:
		_hit_remaining = maxf(0.0, _hit_remaining - delta)
		next = &"Hit" if _hit_remaining > 0.0 else state
	_play(next, BLEND_TIME)
	player.speed_scale = 1.0 if next == &"Hit" else maxf(0.0, rate)
	player.advance(delta)


func begin_fall() -> void:
	_hit_remaining = 0.0
	player.stop()
	_play(&"Fall", 0.0, true)
	player.speed_scale = 1.0
	player.advance(0.0)


func advance_fall(delta: float) -> void:
	player.advance(delta)


func _play(state: StringName, blend: float, restart: bool = false) -> void:
	if not clip_names.has(state):
		state = &"Idle"
	if current_state == state and not restart:
		return
	current_state = state
	player.play(clip_names[state], blend)
