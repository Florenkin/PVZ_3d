"""Render real saved rig poses, never save changes to the authoring file."""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
arm=bpy.data.objects["ZombieRig"]
studio=bpy.data.collections.new("STUDIO | pose previews only")
scene.collection.children.link(studio)
world=bpy.data.worlds.new("Pose preview environment")
world.use_nodes=True
world.node_tree.nodes.get("Background").inputs["Color"].default_value=(.4,.4,.4,1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value=.4
scene.world=world
for location,energy,size in [((-2,-3,3),150,3),((2,-1,2),70,3),((1,2,3),120,2)]:
    data=bpy.data.lights.new("Softbox","AREA")
    data.energy,data.size=energy,size
    light=bpy.data.objects.new("Softbox",data)
    studio.objects.link(light)
    light.location=location
    light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat("-Z","Y").to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.003))
ground=bpy.context.object
ground.name="Preview_floor"
mat=bpy.data.materials.new("Preview gray floor")
mat.diffuse_color=(.3,.3,.3,1)
ground.data.materials.append(mat)
bpy.ops.object.camera_add()
camera=bpy.context.object
camera.data.type="ORTHO"
scene.camera=camera
scene.render.engine="CYCLES"
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_x=900
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
try:
    prefs=bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type="OPTIX"
    prefs.get_devices()
    for device in prefs.devices: device.use=device.type!="CPU"
    if any(device.type!="CPU" for device in prefs.devices): scene.cycles.device="GPU"
except Exception: pass
for name,action,frame in [("idle","Idle",0),("walk","Walk",8),("eat","Eat",10),("fall","Fall",45)]:
    arm.animation_data.action=bpy.data.actions[action]
    scene.frame_set(frame)
    target=Vector((-.02,.34,.20)) if action=="Fall" else Vector((-.02,.02,.49))
    camera.location=target+Vector((1.2,-3,.72))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.ortho_scale=1.30
    scene.render.filepath=str(ROOT/"previews"/(name+".png"))
    bpy.ops.render.render(write_still=True)
print("RIG POSE PREVIEWS COMPLETE",flush=True)
