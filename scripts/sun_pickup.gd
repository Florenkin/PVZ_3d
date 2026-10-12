class_name SunPickup
extends Area3D
## A camera-facing sun that falls straight down and rests without rigid-body spin.

signal collected(value: int)

const GLOW_SHADER := preload("res://assets/materials/sun_glow.gdshader")
const PICKUP_LAYER: int = 64

var value: int = 50
var radius: float = 0.62
var fall_speed: float = 1.4
var lifetime: float = 20.0
var landed: bool = false
var landing_position: Vector3
var _age_on_lawn: float = 0.0
var _collected: bool = false
var _visuals: Node3D
var _glow: MeshInstance3D
var _ground_glow: MeshInstance3D


func _ready() -> void:
	collision_layer = PICKUP_LAYER
	collision_mask = 0
	monitoring = false
	input_ray_pickable = false
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)
	_build_visuals()
	_face_camera()
	_ground_glow.global_position = Vector3(landing_position.x, landing_position.y - radius * 1.08 + 0.015, landing_position.z)


func _physics_process(delta: float) -> void:
	if not landed:
		global_position.y = move_toward(global_position.y, landing_position.y, fall_speed * delta)
		if is_equal_approx(global_position.y, landing_position.y):
			global_position = landing_position
			landed = true
	else:
		_age_on_lawn += delta
		if _age_on_lawn >= lifetime:
			queue_free()
			return
		var opacity := clampf((lifetime - _age_on_lawn) / minf(3.0, lifetime), 0.0, 1.0)
		for mesh: MeshInstance3D in _visuals.get_children():
			mesh.transparency = 1.0 - opacity
		_ground_glow.transparency = 1.0 - opacity
	_ground_glow.global_position = Vector3(landing_position.x, landing_position.y - radius * 1.08 + 0.015, landing_position.z)
	_ground_glow.scale = Vector3.ONE * lerpf(0.55, 1.0, clampf(1.0 - (global_position.y - landing_position.y) / 7.0, 0.0, 1.0))


func _process(_delta: float) -> void:
	_face_camera()


func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_visuals.global_basis = camera.global_basis.orthonormalized()


func collect() -> void:
	if _collected or is_queued_for_deletion():
		return
	_collected = true
	collected.emit(value)
	queue_free()


func _build_visuals() -> void:
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_glow = _make_glow(_visuals, radius * 3.2, Color(1.0, 0.8, 0.18, 0.25))
	_glow.position.z = -0.05
	_ground_glow = _make_glow(self, radius * 2.3, Color(1.0, 0.77, 0.12, 0.22))
	_ground_glow.rotation.x = -PI / 2.0
	_ground_glow.top_level = true

	# Twelve broad cream-yellow rays, with a gold edge and lighter inset facets.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 12:
		var angle := -PI / 2.0 + index * TAU / 12.0
		var length := radius * (1.0 if index % 2 == 0 else 0.92)
		var left := _point(angle - TAU / 24.0, radius * 0.43, 0.0)
		var tip := _point(angle, length, 0.0)
		var right := _point(angle + TAU / 24.0, radius * 0.43, 0.0)
		_triangle(surface, Vector3.ZERO, left, right, Color("ffe65c"), Color("ffe46a"), Color("ffe46a"))
		_triangle(surface, left, tip, right, Color("f8c83a"), Color("fff49b"), Color("ffe46a"))
		var inset_left := left * 0.88 + Vector3(0, 0, 0.006)
		var inset_tip := tip * 0.91 + Vector3(0, 0, 0.006)
		var inset_right := right * 0.88 + Vector3(0, 0, 0.006)
		_triangle(surface, inset_left, inset_tip, inset_right, Color("ffe95a"), Color("ffffb0"), Color("fff27e"))
	_add_mesh(surface.commit(), "Rays")

	# A shallow, round dome keeps the center volumetric while matching the reference.
	var center := SurfaceTool.new()
	center.begin(Mesh.PRIMITIVE_TRIANGLES)
	var disk_radius := radius * 0.36
	for index in 64:
		var a := index * TAU / 64.0
		var b := (index + 1) * TAU / 64.0
		_triangle(center, Vector3(0, 0, radius * 0.17), _point(a, disk_radius, radius * 0.09), _point(b, disk_radius, radius * 0.09), Color("fff87a"), Color("ffe129"), Color("ffe129"))
		_triangle(center, _point(a, disk_radius, radius * 0.09), _point(a, disk_radius * 1.12, radius * 0.045), _point(b, disk_radius * 1.12, radius * 0.045), Color("fff8b5"), Color("edae1d"), Color("edae1d"))
		_triangle(center, _point(a, disk_radius, radius * 0.09), _point(b, disk_radius * 1.12, radius * 0.045), _point(b, disk_radius, radius * 0.09), Color("fff8b5"), Color("edae1d"), Color("fff8b5"))
	_add_mesh(center.commit(), "Center")


func _point(angle: float, distance: float, depth: float) -> Vector3:
	return Vector3(cos(angle) * distance, sin(angle) * distance, depth)


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	surface.set_color(ca)
	surface.add_vertex(a)
	surface.set_color(cb)
	surface.add_vertex(b)
	surface.set_color(cc)
	surface.add_vertex(c)


func _add_mesh(mesh: ArrayMesh, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(instance)


func _make_glow(parent: Node3D, diameter: float, tint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * diameter
	instance.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = GLOW_SHADER
	material.set_shader_parameter("tint", tint)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
