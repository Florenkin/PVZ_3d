"""Render actual model views matching the selected B sheet; never save a mesh.

blender -b normal_zombie.blend -P render_reference_views.py
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
model=bpy.data.collections["NORMAL_ZOMBIE | reference model"]
studio=bpy.data.collections["STUDIO | preview only, excluded from GLB"]
camera=scene.camera
scene.render.engine="CYCLES"
scene.cycles.samples=96
scene.cycles.use_denoising=True
try:
    prefs=bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type="OPTIX"
    prefs.get_devices()
    for device in prefs.devices:
        device.use=device.type!="CPU"
    if any(d.type!="CPU" for d in prefs.devices):
        scene.cycles.device="GPU"
except Exception:
    pass

def render(name,position,target,scale,width,height):
    camera.location=position
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type="ORTHO"
    camera.data.ortho_scale=scale*max(1,width/height)
    scene.render.resolution_x=width
    scene.render.resolution_y=height
    scene.render.resolution_percentage=100
    scene.render.filepath=str(ROOT/"previews"/(name+".png"))
    print("REFERENCE VIEW: "+name,flush=True)
    bpy.ops.render.render(write_still=True)

render("side",(6,0,1.8),(0,.02,1.33),3.025,1050,1400)
render("head_side",(6,0,2.10),(0,.01,2.10),1.36,1400,1400)
render("head_three_quarter",(4,-5,2.19),(0,.04,2.10),1.36,1400,1400)

# Collection instances are the same real mesh in all three panels.
# Unlinking the source collection here affects only this temporary render scene.
scene.collection.children.unlink(model)
for index,(x,angle) in enumerate([(-1.62,-45),(0,45),(1.62,135)]):
    instance=bpy.data.objects.new("Preview_B_turnaround_%d"%index,None)
    instance.instance_type="COLLECTION"
    instance.instance_collection=model
    instance.location=(x,0,0)
    instance.rotation_euler.z=math.radians(angle)
    studio.objects.link(instance)
for obj in studio.objects:
    if obj.type=="LIGHT":
        obj.hide_render=True
light_data=bpy.data.lights.new("Turnaround broad softbox","AREA")
light_data.energy=1350
light_data.shape="RECTANGLE"
light_data.size=8
light_data.size_y=5
light_data.color=(1,.94,.87)
light=bpy.data.objects.new("Turnaround broad softbox",light_data)
studio.objects.link(light)
light.location=(-2,-5.4,5.2)
light.rotation_euler=(Vector((0,0,1.3))-light.location).to_track_quat("-Z","Y").to_euler()
render("turnaround_B",(0,-8,2.05),(0,.02,1.33),3.00,2400,1300)
print("ACTUAL MODEL REFERENCE VIEWS COMPLETE",flush=True)
