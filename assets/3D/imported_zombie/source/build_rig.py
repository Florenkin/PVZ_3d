"""Rig and animate the user-supplied Tripo zombie without rebuilding its mesh.

blender -b --threads 8 --python-exit-code 1 -P build_rig.py
Coordinates: Blender Z-up, facing -Y, original normalized height 1 metre.
"""
import bpy
import hashlib
import json
import math
import os
from pathlib import Path

import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source"
PREVIEWS = ROOT / "previews"
TEXTURES = SOURCE / "textures"
TEXTURES.mkdir(parents=True, exist_ok=True)
PREVIEWS.mkdir(parents=True, exist_ok=True)
ORIGINAL = SOURCE / "original_zombie.glb"
ORIGINAL_HASH = "b7d828a23f494b60198b15f1cc472aa560c57bfc335fba88fd94395f14c91a3e"
assert hashlib.sha256(ORIGINAL.read_bytes()).hexdigest() == ORIGINAL_HASH
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ORIGINAL))
body = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
body.name = "Zombie_SkinnedBody"
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for image in list(bpy.data.images):
    if image.packed_file:
        extension = ".jpg" if image.packed_file.data[:2] == b"\xff\xd8" else ".png"
        name = "zombie_" + ("basecolor" if "basecolor" in image.name else "normal" if "normal" in image.name else "metallic_roughness") + extension
        path = TEXTURES / name
        packed_bytes = image.packed_file.data
        if not path.exists() or path.read_bytes() != packed_bytes:
            temporary = path.with_suffix(path.suffix + ".pending")
            temporary.write_bytes(packed_bytes)
            os.replace(temporary, path)
        color_space = image.colorspace_settings.name
        replacement = bpy.data.images.load(str(path), check_existing=False)
        replacement.colorspace_settings.name = color_space
        replacement.pack()
        image.user_remap(replacement)
        bpy.data.images.remove(image)

model = body.users_collection[0]
model.name = "RIGGED_ZOMBIE | user supplied model"
arm_data = bpy.data.armatures.new("Zombie_HumanoidSkeleton")
arm = bpy.data.objects.new("ZombieRig", arm_data)
model.objects.link(arm)
arm.show_in_front = True
arm.data.display_type = "STICK"
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
specs = {}


def bone(name, head, tail, parent=None):
    item = arm_data.edit_bones.new(name)
    item.head, item.tail = head, tail
    if parent:
        item.parent = arm_data.edit_bones[parent]
    specs[name] = {"head": list(head), "tail": list(tail), "parent": parent}


bone("Root", (0, 0, 0), (0, 0, .075))
bone("Hips", (-.035, .13, .385), (-.025, .11, .455), "Root")
bone("Spine", (-.025, .11, .455), (-.02, .08, .535), "Hips")
bone("Chest", (-.02, .08, .535), (-.02, .055, .61), "Spine")
bone("Neck", (-.02, .055, .61), (-.02, .045, .65), "Chest")
bone("Head", (-.02, .045, .65), (-.015, .03, .93), "Neck")
bone("Jaw", (-.02, -.01, .684), (-.02, -.10, .653), "Head")
bone("TieUpper", (.008, -.012, .574), (.018, -.025, .49), "Chest")
bone("TieLower", (.018, -.025, .49), (.03, -.025, .405), "TieUpper")
for side, sign in [("L", 1), ("R", -1)]:
    shoulder = (.125, .10, .585) if side == "L" else (-.145, .03, .595)
    elbow = (.177, .035, .505) if side == "L" else (-.183, -.09, .53)
    wrist = (.208, -.055, .457) if side == "L" else (-.205, -.17, .49)
    palm = (.218, -.11, .425) if side == "L" else (-.22, -.214, .465)
    bone("UpperArm." + side, shoulder, elbow, "Chest")
    bone("Forearm." + side, elbow, wrist, "UpperArm." + side)
    bone("Hand." + side, wrist, palm, "Forearm." + side)
    bone("Fingers." + side, palm, (.22, -.145, .395) if side == "L" else (-.22, -.235, .447), "Hand." + side)
    hip = (.055, .13, .385) if side == "L" else (-.103, .13, .385)
    knee = (.051, .085, .237) if side == "L" else (-.126, .10, .237)
    ankle = (.085, .145, .080) if side == "L" else (-.158, .17, .075)
    toe = (.10, .005, .035) if side == "L" else (-.16, .015, .032)
    bone("Thigh." + side, hip, knee, "Hips")
    bone("Shin." + side, knee, ankle, "Thigh." + side)
    bone("Foot." + side, ankle, toe, "Shin." + side)
    bone("Toes." + side, toe, (.10, -.035, .025) if side == "L" else (-.16, -.025, .025), "Foot." + side)
bpy.ops.object.mode_set(mode="OBJECT")
for item in arm.pose.bones:
    item.rotation_mode = "QUATERNION"
body.parent = arm
modifier = body.modifiers.new("Humanoid smooth skin deformation", "ARMATURE")
modifier.object = arm
modifier.use_deform_preserve_volume = False  # Match standard glTF/Godot linear skinning.

print("Painting anatomically restricted, blended skin weights", flush=True)
coords = np.empty((len(body.data.vertices), 3), dtype=np.float32)
body.data.vertices.foreach_get("co", coords.ravel())
names = list(specs)
columns = {name: i for i, name in enumerate(names)}
weights = np.zeros((len(coords), len(names)), dtype=np.float32)
x, y, z = coords.T


def smoothstep(a, b, values):
    t = np.clip((values - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def blend_chain(candidates, mask):
    indices = np.flatnonzero(mask > .00001)
    if not len(indices):
        return
    points = coords[indices]
    ds = []
    for name in candidates:
        start = np.array(specs[name]["head"], np.float32)
        segment = np.array(specs[name]["tail"], np.float32) - start
        t = np.clip(((points - start) @ segment) / (segment @ segment), 0, 1)
        distance = np.linalg.norm(points - start - t[:, None] * segment, axis=1)
        ds.append(1 / np.maximum(distance, .009) ** 4)
    ds = np.stack(ds, axis=1)
    ds /= ds.sum(axis=1, keepdims=True)
    for i, name in enumerate(candidates):
        weights[indices, columns[name]] += mask[indices] * ds[:, i]


head_mask = smoothstep(.611, .655, z)
# Limit jaw flex to the lower mouth/chin, preserving eyeballs and upper teeth.
jaw_mask = (1 - smoothstep(.668, .697, z)) * smoothstep(-.025, -.085, y) * (1 - smoothstep(.075, .128, np.abs(x+.02))) * head_mask
weights[:, columns["Head"]] = head_mask - jaw_mask * .86
weights[:, columns["Jaw"]] = jaw_mask * .86
remaining = 1 - head_mask
arm_boundary = np.interp(z, [.35, .43, .50, .56, .62], [.16, .148, .131, .12, .108])
arms_mask = smoothstep(arm_boundary - .008, arm_boundary + .022, np.abs(x)) * smoothstep(.348, .405, z) * remaining
for side, sign in [("L", 1), ("R", -1)]:
    region = arms_mask * (x * sign > 0)
    blend_chain(["UpperArm." + side, "Forearm." + side, "Hand." + side], region)
    fingers = (smoothstep(.447, .410, z) * smoothstep(-.070, -.140, y) if side == "L" else smoothstep(.487, .453, z) * smoothstep(-.19, -.23, y)) * region * .85
    prior = weights[:, [columns["UpperArm." + side], columns["Forearm." + side], columns["Hand." + side]]].sum(axis=1)
    ratio = np.divide(fingers, prior, out=np.zeros_like(prior), where=prior > 0)
    for name in ("UpperArm.", "Forearm.", "Hand."):
        weights[:, columns[name + side]] *= 1 - ratio
    weights[:, columns["Fingers." + side]] += fingers
remaining -= arms_mask
legs_mask = (1 - smoothstep(.352, .420, z)) * remaining
for side, sign in [("L", 1), ("R", -1)]:
    region = legs_mask * ((x+.035) * sign >= 0)
    blend_chain(["Thigh." + side, "Shin." + side, "Foot." + side], region)
    toes = smoothstep(.045, -.025, y) * (1 - smoothstep(.065, .105, z)) * region * .9
    prior = weights[:, [columns["Thigh." + side], columns["Shin." + side], columns["Foot." + side]]].sum(axis=1)
    ratio = np.divide(toes, prior, out=np.zeros_like(prior), where=prior > 0)
    for name in ("Thigh.", "Shin.", "Foot."):
        weights[:, columns[name + side]] *= 1 - ratio
    weights[:, columns["Toes." + side]] += toes
remaining -= legs_mask
blend_chain(["Hips", "Spine", "Chest", "Neck"], remaining)
tie = (1 - smoothstep(.032, .052, np.abs(x-.008))) * smoothstep(.02, -.025, y) * smoothstep(.39, .425, z) * (1 - smoothstep(.563, .60, z)) * remaining * .75
weights *= (1 - tie[:, None])
lower_tie = 1 - smoothstep(.465, .505, z)
weights[:, columns["TieUpper"]] += tie * (1 - lower_tie)
weights[:, columns["TieLower"]] += tie * lower_tie
# Four influences, integer-normalized to 255, with identical weights at UV seams.
indices = np.argsort(weights, axis=1)[:, -4:]
values = np.take_along_axis(weights, indices, axis=1)
assert np.all(values.sum(axis=1) > .0001), "Unweighted source vertices"
values /= values.sum(axis=1, keepdims=True)
quantized = np.rint(values * 255).astype(np.int16)
quantized[:, -1] += 255 - quantized.sum(axis=1)
for i, name in enumerate(names):
    group = body.vertex_groups.new(name=name)
    rows, cols = np.where((indices == i) & (quantized > 0))
    entries = quantized[rows, cols]
    for value in np.unique(entries):
        group.add(rows[entries == value].tolist(), int(value) / 255.0, "REPLACE")
assert np.all(quantized.sum(axis=1) == 255)
weight_counts = {name: int(np.count_nonzero((indices == i) & (quantized > 0))) for i, name in enumerate(names)}
del weights, values, quantized

FPS = 30
scene = bpy.context.scene
scene.render.fps = FPS
arm.animation_data_create()
rest_rotations = {name: arm_data.bones[name].matrix_local.to_quaternion() for name in names}


def rotation(name, degrees):
    # Author rotations in character axes, independent of each bone's roll.
    q = Quaternion((1, 0, 0), math.radians(degrees[0])) @ Quaternion((0, 1, 0), math.radians(degrees[1])) @ Quaternion((0, 0, 1), math.radians(degrees[2]))
    rest = rest_rotations[name]
    arm.pose.bones[name].rotation_quaternion = rest.inverted() @ q @ rest


def root_location(world):
    arm.pose.bones["Root"].location = arm_data.bones["Root"].matrix_local.to_3x3().inverted() @ Vector(world)


def aim_bone(name, head, tail):
    original = arm_data.bones[name]
    delta = (original.tail_local - original.head_local).rotation_difference(tail - head)
    q = delta @ original.matrix_local.to_quaternion()
    arm.pose.bones[name].matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4()


def plant_leg(side, phase, bob):
    thigh = "Thigh." + side
    shin = "Shin." + side
    foot = "Foot." + side
    h = arm.pose.bones[thigh].head.copy()
    a = Vector(specs[foot]["head"])
    if phase < .5:
        offset = -.075 + .15 * phase / .5
        lift = 0
        pitch = 0
    else:
        s = (phase - .5) / .5
        offset = .075 - .15 * s
        lift = .040 * math.sin(math.pi * s)
        pitch = -8 * math.sin(math.pi * s)
    a.y += offset
    a.z += lift
    d = a - h
    distance = d.length
    l1 = arm_data.bones[thigh].length
    l2 = arm_data.bones[shin].length
    distance = min(distance, l1 + l2 - .0002)
    direction = d.normalized()
    along = (l1*l1 - l2*l2 + distance*distance)/(2*distance)
    height = math.sqrt(max(0, l1*l1 - along*along))
    forward = Vector((0, -1, 0))
    perpendicular = (forward - direction * forward.dot(direction)).normalized()
    knee = h + direction * along + perpendicular * height
    aim_bone(thigh, h, knee)
    bpy.context.view_layer.update()
    aim_bone(shin, knee, a)
    bpy.context.view_layer.update()
    foot_rest = arm_data.bones[foot]
    foot_q = Quaternion((1, 0, 0), math.radians(pitch)) @ foot_rest.matrix_local.to_quaternion()
    arm.pose.bones[foot].matrix = Matrix.Translation(a) @ foot_q.to_matrix().to_4x4()
    bpy.context.view_layer.update()
    rotation("Toes." + side, (max(0, pitch) * .7, 0, 0))


clips = {"Idle": 3.2, "Walk": 1.10, "Eat": 1.2, "Hit": .4, "Fall": 1.8}
actions = {}
ground_corrections = []
print("Authoring bone-keyed Idle, Walk, Eat, Hit and Fall clips", flush=True)
for name, duration in clips.items():
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data.action = action
    actions[name] = action
    frames = round(duration * FPS)
    for frame in range(frames + 1):
        scene.frame_set(frame)
        t = frame / frames
        phase = 2 * math.pi * t
        for pb in arm.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.scale = (1, 1, 1)
        if name == "Idle":
            root_location((.0015*math.sin(phase), 0, .0015*(1-math.cos(phase))))
            rotation("Chest", (.8*math.sin(phase), 0, .6*math.sin(phase)))
            rotation("Head", (.6*math.sin(phase+.4), 0, 1.6*math.sin(phase)))
            for side, sign in [("L",1),("R",-1)]:
                rotation("Hand."+side, (1.3*math.sin(phase+.8*sign), 0, sign*.7*math.cos(phase)))
                rotation("Fingers."+side, (2*math.sin(phase+sign), 0, 0))
        elif name == "Walk":
            bob = .0025*(1-math.cos(phase*2))
            root_location((.002*math.sin(phase), 0, bob))
            rotation("Hips", (0, 1.3*math.sin(phase), 1.2*math.sin(phase)))
            rotation("Chest", (2 + 1.8*math.sin(phase*2), 0, -2*math.sin(phase)))
            rotation("Neck", (-1*math.sin(phase*2), 0, 0))
            rotation("Head", (-1.2*math.sin(phase*2+.3), .5*math.sin(phase), 1.3*math.sin(phase+.3)))
            for side, sign in [("L",1),("R",-1)]:
                rotation("UpperArm."+side, (3.5*math.sin(phase)*sign, sign*.6, sign*1.3*math.sin(phase)))
                rotation("Forearm."+side, (2.5*math.sin(phase+.5)*sign, 0, 0))
                rotation("Hand."+side, (2.0*math.sin(phase+1)*sign, 0, 0))
                rotation("Fingers."+side, (3*math.sin(phase+.6*sign), 0, 0))
            rotation("TieUpper", (-2*math.sin(phase*2+.5), 0, 1.5*math.sin(phase)))
            rotation("TieLower", (-3*math.sin(phase*2+.8), 0, 2*math.sin(phase+.3)))
            bpy.context.view_layer.update()
            plant_leg("L", t % 1, bob)
            plant_leg("R", (t+.5) % 1, bob)
        elif name == "Eat":
            chew = .5 - .5*math.cos(phase*2)
            root_location((.002*math.sin(phase), -.006, -.006))
            rotation("Spine", (5, 0, 0))
            rotation("Chest", (5+2.2*chew, 0, 1.2*math.sin(phase)))
            rotation("Neck", (2*math.sin(phase*2+.4), 0, 0))
            rotation("Head", (2.0*math.sin(phase*2), 0, 1.8*math.sin(phase)))
            rotation("Jaw", (-4.5*chew, 0, 0))
            for side, sign in [("L",1),("R",-1)]:
                rotation("UpperArm."+side, (-8-2*math.sin(phase+.4*sign), 0, sign*-2))
                rotation("Forearm."+side, (-7-2.5*chew, 0, sign*1.5*math.sin(phase)))
                rotation("Hand."+side, (3*math.sin(phase*2+.3*sign), 0, sign*2))
                rotation("Fingers."+side, (7+3*chew, 0, 0))
            rotation("TieUpper", (-3*math.sin(phase), 0, 0))
        elif name == "Hit":
            kick = math.sin(math.pi*t) * (1-t)
            rotation("Spine", (-10*kick, 0, -2*kick))
            rotation("Head", (-12*kick, 0, 5*kick))
            rotation("Jaw", (-3*kick, 0, 0))
            for side, sign in [("L",1),("R",-1)]:
                rotation("UpperArm."+side, (-9*kick, 0, sign*5*kick))
                rotation("Hand."+side, (-8*kick, 0, 0))
        else:
            falling = max(0, min(1, (t-.14)/.49))
            ease = falling*falling*(3-2*falling)
            impact = math.exp(-((t-.68)/.10)**2)
            # Fall onto the back: this character's head, jacket back and heels
            # share the posterior support plane, so the full body can rest.
            rotation("Root", (-90*ease + 2.5*impact, 2.0*math.sin(math.pi*falling), 3*ease))
            root_location((0, .055*ease, .247*ease))
            rotation("Spine", (-5*(1-ease)*math.sin(math.pi*min(1,t/.3)), 0, 0))
            rotation("Head", (3*impact, 0, 2*impact))
            rotation("Jaw", (-2*ease, 0, 0))
            for side, sign in [("L",1),("R",-1)]:
                rotation("UpperArm."+side, (-15*math.sin(math.pi*falling)+5*ease, 0, sign*7*ease))
                rotation("Forearm."+side, (-12*math.sin(math.pi*falling), 0, sign*3*ease))
                rotation("Hand."+side, (10*ease, 0, 0))
                rotation("Thigh."+side, (sign*4*math.sin(math.pi*falling), 0, sign*2*ease))
                rotation("Shin."+side, (10*math.sin(math.pi*falling), 0, 0))
            bpy.context.view_layer.update()
            if ease > .05:
                evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
                posed=evaluated.to_mesh()
                positions=np.empty((len(posed.vertices),3),np.float32)
                posed.vertices.foreach_get("co",positions.ravel())
                low=float(positions[:,2].min())
                evaluated.to_mesh_clear()
                correction=max(0,.002-low)
                if correction:
                    root_location((0,.055*ease,.247*ease+correction))
                ground_corrections.append(correction)
        for pb in arm.pose.bones:
            pb.keyframe_insert(data_path="location", frame=frame, group=pb.name)
            pb.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=pb.name)
            pb.keyframe_insert(data_path="scale", frame=frame, group=pb.name)
    print("AUTHORED CLIP: "+name, flush=True)

arm.animation_data.action=actions["Idle"]
scene.frame_start=0
scene.frame_end=round(clips["Idle"]*FPS)
scene.frame_set(0)
arm["original_file_sha256"]=ORIGINAL_HASH
arm["animation_notes"]="In-place walk with planted-foot IK baked to bone keys; chewing jaw, reaching hands, breathing, recoil and complete fall."
arm["nominal_game_height_m"]=1.82
arm["nominal_walk_speed_m_s"]=.5
for image in bpy.data.images:
    if image.source=="FILE":
        image.pack()
        image.filepath=bpy.path.relpath(image.filepath,start=str(SOURCE))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"zombie_animated.blend"),compress=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active=arm
pending=SOURCE/"zombie_animated.pending.glb"
bpy.ops.export_scene.gltf(filepath=str(pending),export_format="GLB",use_selection=True,export_yup=True,export_apply=False,export_texcoords=True,export_normals=True,export_tangents=True,export_materials="EXPORT",export_animations=True,export_animation_mode="ACTIONS",export_anim_single_armature=True,export_frame_range=False,export_force_sampling=True,export_anim_slide_to_zero=True,export_skins=True,export_all_influences=False,export_def_bones=True,export_rest_position_armature=True,export_cameras=False,export_lights=False)
os.replace(pending,ROOT/"zombie_animated.glb")
manifest={"asset":"user_imported_animated_zombie","input_original":"source/original_zombie.glb","input_sha256":ORIGINAL_HASH,"authoring_tool":bpy.app.version_string,"source_vertices":len(body.data.vertices),"source_triangles":sum(len(p.vertices)-2 for p in body.data.polygons),"mesh_geometry_preserved":True,"bones":len(names),"bone_names":names,"weighted_vertex_counts":weight_counts,"maximum_influences":4,"animations_seconds":clips,"looping_animations":["Idle","Walk","Eat"],"one_shot_animations":["Hit","Fall"],"walking":"in place; planted feet solved as two-bone IK and baked to bone rotations","model_height_m":1.0,"game_height_m":1.82,"fall_ground_correction_max_m":max(ground_corrections,default=0),"game_scope":"normal zombies in demo stages 1-5 and original demo 0; adventure retains prior visuals"}
(ROOT/"model_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print("RIGGED ZOMBIE COMPLETE: "+json.dumps(manifest),flush=True)
