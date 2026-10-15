"""Render real mesh turnarounds and cone details without saving scene edits.

blender -b conehead_zombie.blend -P render_reference_views.py
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
scene = bpy.context.scene
model = bpy.data.collections["CONEHEAD_ZOMBIE | A reference model"]
studio = bpy.data.collections["STUDIO | preview only, excluded from GLB"]
camera = scene.camera
scene.render.engine = "CYCLES"
scene.cycles.samples = 112
scene.cycles.use_denoising = True
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "OPTIX"
    prefs.get_devices()
    for device in prefs.devices:
        device.use = device.type != "CPU"
    if any(device.type != "CPU" for device in prefs.devices):
        scene.cycles.device = "GPU"
except Exception:
    pass


def render(name, position, target, scale, width, height):
    camera.location = position
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = scale * max(1, width / height)
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(ROOT / "previews" / (name + ".png"))
    print("REFERENCE RENDER " + name, flush=True)
    bpy.ops.render.render(write_still=True)


render("front", (.25, -7, 2.4), (.03, -.01, 1.73), 3.85, 1050, 1400)
render("three_quarter", (4.3, -6, 2.5), (.03, -.01, 1.73), 3.85, 1050, 1400)
render("back", (3.4, 6, 2.5), (.03, -.01, 1.73), 3.85, 1050, 1400)
render("side", (-7, 0, 2.0), (0, .01, 1.70), 3.70, 1050, 1400)
render("head_cone_close", (4.5, -6, 3.0), (.03, -.02, 2.52), 2.05, 1500, 1500)
render("cone_top_close", (2.8, -4, 6.2), (.10, .01, 2.80), 1.90, 1500, 1500)
render("head_cone_side", (-6, .0, 2.65), (.02, .02, 2.50), 1.90, 1500, 1500)

# Each panel instances the same real geometry, not an AI-generated reference.
scene.collection.children.unlink(model)
for index, (x, angle) in enumerate([(-1.8, -8), (0, 73), (1.8, 145)]):
    instance = bpy.data.objects.new("Preview_A_turnaround_" + str(index), None)
    instance.instance_type = "COLLECTION"
    instance.instance_collection = model
    instance.location = (x, 0, 0)
    instance.rotation_euler.z = math.radians(angle)
    studio.objects.link(instance)
for obj in studio.objects:
    if obj.type == "LIGHT":
        obj.hide_render = True
light_data = bpy.data.lights.new("Turnaround softbox", "AREA")
light_data.energy = 1450
light_data.shape = "RECTANGLE"
light_data.size, light_data.size_y = 9, 6
light_data.color = (1, .95, .89)
light = bpy.data.objects.new("Turnaround softbox", light_data)
studio.objects.link(light)
light.location = (-2, -5.4, 6)
light.rotation_euler = (Vector((0, 0, 1.7)) - light.location).to_track_quat("-Z", "Y").to_euler()
render("turnaround_A", (0, -9, 2.35), (0, .01, 1.68), 3.7, 2700, 1500)
print("ACTUAL CONEHEAD REFERENCE VIEWS COMPLETE", flush=True)
