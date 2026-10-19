"""Standalone reference zombie. Run with Blender 4.5: blender -b -t 8 -P build_zombie.py.

Only writes inside this asset directory. The original game is never opened.
Blender Z is up; the character faces -Y. glTF export converts to Y up.
"""
import bpy
import math
import random
import json
import sys
import bmesh
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector

ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / "source" / "textures"
PREVIEWS = ROOT / "previews"
TEXTURES.mkdir(parents=True, exist_ok=True)
PREVIEWS.mkdir(parents=True, exist_ok=True)
random.seed(19)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for block in list(bpy.data.collections):
    if block.name != "Collection":
        bpy.data.collections.remove(block)
model = bpy.data.collections.get("Collection")
model.name = "NORMAL_ZOMBIE | reference model"
studio = bpy.data.collections.new("STUDIO | preview only, excluded from GLB")
bpy.context.scene.collection.children.link(studio)


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def in_collection(obj, collection=model):
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def smooth(obj):
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def apply(obj, modifier):
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def smart_uv(obj):
    activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.1, island_margin=0.015)
    bpy.ops.object.mode_set(mode="OBJECT")


def mesh(name, vertices, faces, material, uvs=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    model.objects.link(obj)
    if material:
        data.materials.append(material)
    if uvs:
        uv_layer = data.uv_layers.new(name="UVMap")
        for face in data.polygons:
            for loop in face.loop_indices:
                uv_layer.data[loop].uv = uvs[data.loops[loop].vertex_index]
    return smooth(obj)


def image_file(name, pixels, linear=False):
    height, width = pixels.shape[:2]
    img = bpy.data.images.new(name, width=width, height=height, alpha=False)
    img.colorspace_settings.name = "Non-Color" if linear else "sRGB"
    rgba = np.ones((height, width, 4), np.float32)
    rgba[:, :, :3] = pixels
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(TEXTURES / (name + ".png"))
    img.file_format = "PNG"
    img.save()
    return img


def textured_material(name, color, kind="skin", roughness=0.75, size=1024):
    """Portable PBR texture maps, including micro normal and packed ORM.

    A periodic Fourier field makes the tile boundaries continuous. Fabric maps
    add two crossing thread directions. There are no render-only shader nodes.
    """
    rng = np.random.default_rng(sum(ord(c) for c in name))
    v, u = np.mgrid[0:size, 0:size].astype(np.float32) / size
    field = np.zeros((size, size), np.float32)
    for frequency, amplitude in [(2, 0.55), (5, 0.23), (13, 0.11), (37, 0.055)]:
        for _ in range(6):
            a, b = rng.integers(-frequency, frequency + 1, size=2)
            field += amplitude / 6 * np.sin(2 * math.pi * (a * u + b * v) + rng.uniform(0, 6.28))
    field /= max(float(field.std()), 0.01)
    grain = rng.normal(0, 1, (size, size)).astype(np.float32)
    if kind in ("cloth", "denim"):
        weave = .5*(np.sin(2 * math.pi * u * 156)+np.sin(2 * math.pi * v * 160+.7))
        if kind == "denim":
            weave += 0.5 * np.sin(2 * math.pi * (u * 90 + v * 90))
        height = weave * 0.012 + grain * 0.02 + field * 0.035
        variation = 0.060 * field + 0.020 * grain + 0.007 * weave
        normal_strength = 1.6
    elif kind == "leather":
        cells = np.abs(np.sin(2 * math.pi * (u * 103 + v * 53)))
        height = field * 0.075 + cells * 0.015 + grain * 0.02
        variation = field * 0.068 + grain * 0.012
        normal_strength = 1.1
    else:
        height = field * 0.045 + grain * 0.016
        variation = field * 0.045 + grain * 0.009
        normal_strength = 1.7
    # Fine scattered stains/pores, continuous across the periodic texture tile.
    spots = np.zeros_like(field)
    if kind in ("skin", "leather"):
        for _ in range(100):
            sx, sy = rng.uniform(0,1,2)
            radius = rng.uniform(.0035,.009)
            ddx = np.minimum(np.abs(u-sx),1-np.abs(u-sx))
            ddy = np.minimum(np.abs(v-sy),1-np.abs(v-sy))
            spots += np.exp(-(ddx*ddx+ddy*ddy)/(radius*radius))
        variation -= spots * (0.075 if kind == "skin" else 0.07)
        height -= spots * 0.04
    base = np.clip(np.array(color)[None, None, :] * (1 + variation[:, :, None]), 0, 1)
    if kind == "skin":
        base[:, :, 0] += field * 0.006
        base[:, :, 2] -= field * 0.004
    base = np.clip(base, 0, 1)
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * normal_strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * normal_strength
    normal = np.stack((-dx, -dy, np.ones_like(dx)), axis=2)
    normal /= np.linalg.norm(normal, axis=2)[:, :, None]
    orm = np.zeros((size, size, 3), np.float32)
    orm[:, :, 0] = 1
    orm[:, :, 1] = np.clip(roughness + 0.025 * field, 0, 1)
    albedo = image_file(name + "_basecolor", base)
    normal_map = image_file(name + "_normal", normal * 0.5 + 0.5, True)
    packed = image_file(name + "_orm", orm, True)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Specular IOR Level"].default_value = 0.26
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    base_tex = nodes.new("ShaderNodeTexImage")
    base_tex.image = albedo
    links.new(base_tex.outputs["Color"], shader.inputs["Base Color"])
    ntex = nodes.new("ShaderNodeTexImage")
    ntex.image = normal_map
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 0.9
    links.new(ntex.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], shader.inputs["Normal"])
    rtex = nodes.new("ShaderNodeTexImage")
    rtex.image = packed
    separate = nodes.new("ShaderNodeSeparateColor")
    links.new(rtex.outputs["Color"], separate.inputs["Color"])
    links.new(separate.outputs["Green"], shader.inputs["Roughness"])
    # Match the glTF exporter's recognized separate-color ORM topology.
    mat.diffuse_color = (*color, 1)
    return mat


def solid_material(name, color, roughness=0.7):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    # Values passed here are sRGB palette colors; shader uses linear colors.
    shader.inputs["Base Color"].default_value = tuple(c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055)**2.4 for c in color) + (1,)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = 0.25
    return mat


print("Creating portable PBR material textures", flush=True)
SKIN = textured_material("Skin_sage_mottled", (0.405, 0.49, 0.425), roughness=0.8, size=2048)
SHIN = textured_material("Shin_sage_green", (0.405, 0.49, 0.425), roughness=0.8)
JACKET = textured_material("Jacket_worn_brown_twill", (0.38, 0.25, 0.18), "cloth", 0.86)
LAPEL = textured_material("Lapel_brown_twill", (0.39, 0.26, 0.184), "cloth", 0.83)
DENIM = textured_material("Trousers_indigo_denim", (0.18, 0.25, 0.38), "denim", 0.87)
SHIRT = textured_material("Shirt_aged_ivory_cotton", (0.81, 0.79, 0.66), "cloth", 0.87)
TIE = textured_material("Tie_faded_brick_red", (0.55, 0.20, 0.16), "cloth", 0.82)
LEATHER = textured_material("Shoes_scuffed_brown_leather", (0.385, 0.248, 0.163), "leather", 0.65)
EYE = textured_material("Eyeballs_yellowed_ivory", (0.84, 0.8, 0.61), roughness=0.5, size=512)
SOCKET = solid_material("Eye_socket_dark_olive", (0.26, 0.30, 0.20), 0.89)
LIP = solid_material("Mouth_rim_sage", (0.43, 0.51, 0.44), 0.82)
CREASE = solid_material("Skin_crease_muted", (0.36, 0.43, 0.36), 0.86)
MOUTH = solid_material("Mouth_cavity_dark_umber", (0.17, 0.063, 0.035), 0.9)
INNER = solid_material("Inner_gum_muted_brown", (0.29, 0.14, 0.095), 0.86)
TEETH = solid_material("Teeth_aged_bone", (0.83, 0.80, 0.65), 0.58)
NAIL = solid_material("Nails_pallid_keratin", (0.71, 0.75, 0.65), 0.68)
PUPIL = solid_material("Pupils_almost_black", (0.065, 0.054, 0.032), 0.43)
HAIR = solid_material("Sparse_wiry_hair", (0.065, 0.052, 0.04), 0.75)
SEAM = solid_material("Brown_cloth_seams", (0.31, 0.20, 0.145), 0.88)
DENIM_EDGE = solid_material("Denim_frayed_edges", (0.15, 0.21, 0.32), 0.91)
THREAD = solid_material("Denim_faded_loose_threads", (0.49, 0.51, 0.49), 0.9)
SOLE = solid_material("Shoes_dark_outsole", (0.23, 0.16, 0.11), 0.86)
WELT = solid_material("Shoes_welt_stitching", (0.42, 0.30, 0.21), 0.83)


def sphere(name, center, scale, material, segments=48, rings=32, lumpy=0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = in_collection(bpy.context.object)
    obj.name = name
    obj.scale = scale
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if lumpy:
        for vert in obj.data.vertices:
            n = vert.co.normalized()
            value = noise_vector(vert.co * 8 + Vector((11, 2, 7))).x
            vert.co += n * value * lumpy
    if material:
        obj.data.materials.append(material)
    return smooth(obj)


def box(name, center, dimensions, material, radius=0.01, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = in_collection(bpy.context.object)
    obj.name = name
    obj.scale = dimensions
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("Rounded edges", "BEVEL")
    bevel.width = radius
    bevel.segments = 4
    apply(obj, bevel)
    smooth(obj)
    weighted = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    apply(obj, weighted)
    smart_uv(obj)
    return obj


def curve(name, points, radius, material, collection=model):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 14
    data.bevel_depth = radius
    data.bevel_resolution = 3
    data.use_fill_caps = True
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for i, (bp, coord) in enumerate(zip(spline.bezier_points, points)):
        bp.co = coord
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
        bp.radius = 0.35 if i in (0, len(points) - 1) else 1
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    data.materials.append(material)
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    smart_uv(obj)
    return smooth(obj)


def loft(name, rings, material, count=64, opening=0, torn=False, cap=True, wave=0, thickness=.007):
    """Cloth tube in Z: ring is (z, xcenter, ycenter, xradius, yradius)."""
    vertices, uvs, faces = [], [], []
    arc = 2 * math.pi - 2 * opening
    closed = opening == 0
    for j, (z, cx, cy, rx, ry) in enumerate(rings):
        for i in range(count + 1):
            t = i / count
            angle = opening + t * arc
            offset = wave * math.sin(angle * 5.0 + j * 1.7)
            zz = z
            if j == 0 and torn:
                zz += 0.03 * math.sin(angle * 7.0) + 0.018 * math.sin(angle * 11.0 + 1)
            vertices.append((cx + math.sin(angle) * (rx + offset), cy - math.cos(angle) * (ry + offset), zz))
            uvs.append((t, j / (len(rings) - 1)))
    for j in range(len(rings) - 1):
        for i in range(count):
            a = j * (count + 1) + i
            faces.append((a, a + 1, a + count + 2, a + count + 1))
    if cap and closed:
        faces.append(tuple(reversed(range(count))))
        faces.append(tuple((len(rings) - 1) * (count + 1) + i for i in range(count)))
    obj = mesh(name, vertices, faces, material, uvs)
    if not cap or opening:
        thick = obj.modifiers.new("Fabric thickness", "SOLIDIFY")
        thick.thickness = thickness
        apply(obj, thick)
    return obj


def tube(name, points, radii, material, count=24, detail=4, wrinkles=0):
    """Catmull-Rom swept organic tube, with elliptical section and UVs."""
    controls = [Vector(p) for p in points]
    samples, widths = [], []
    for j in range(len(controls) - 1):
        p0, p1, p2, p3 = controls[max(j - 1, 0)], controls[j], controls[j + 1], controls[min(j + 2, len(controls) - 1)]
        r1, r2 = np.array(radii[j]), np.array(radii[j + 1])
        if r1.ndim == 0:
            r1 = np.array([r1, r1])
        if r2.ndim == 0:
            r2 = np.array([r2, r2])
        for k in range(detail):
            t = k / detail
            position = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t*t + (-p0 + 3 * p1 - 3 * p2 + p3) * t*t*t)
            samples.append(position)
            widths.append(r1 * (1-t) + r2*t)
    samples.append(controls[-1])
    widths.append(np.array([radii[-1], radii[-1]]) if np.array(radii[-1]).ndim == 0 else np.array(radii[-1]))
    vertices, uvs, faces = [], [], []
    for j, (point, radius) in enumerate(zip(samples, widths)):
        tangent = (samples[min(j + 1, len(samples) - 1)] - samples[max(j - 1, 0)]).normalized()
        normal = tangent.cross(Vector((0, 1, 0))).normalized()
        if normal.length < 0.001:
            normal = tangent.cross(Vector((1, 0, 0))).normalized()
        binormal = tangent.cross(normal).normalized()
        for i in range(count + 1):
            t = i / count
            angle = 2 * math.pi * t
            shift = wrinkles * (math.sin(j * 1.25 + angle * 3) * 0.55 + math.cos(j * 0.9 - angle * 5) * 0.45)
            p = point + normal * (radius[0] + shift) * math.cos(angle) + binormal * (radius[1] + shift) * math.sin(angle)
            vertices.append(tuple(p))
            uvs.append((t, j / (len(samples) - 1)))
    for j in range(len(samples) - 1):
        for i in range(count):
            a = j * (count + 1) + i
            faces.append((a, a + 1, a + count + 2, a + count + 1))
    faces.append(tuple(reversed(range(count))))
    faces.append(tuple((len(samples) - 1) * (count + 1) + i for i in range(count)))
    return mesh(name, vertices, faces, material, uvs)


def merge_skin(name, objects, voxel=0.006, material=None, relax_iterations=4, relax_factor=.65):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    remesh = obj.modifiers.new("Organic sculpt union", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.use_smooth_shade = True
    apply(obj, remesh)
    relax = obj.modifiers.new("Sculpt surface relaxation", "SMOOTH")
    relax.factor = relax_factor
    relax.iterations = relax_iterations
    apply(obj, relax)
    obj.data.materials.clear()
    obj.data.materials.append(material or SKIN)
    return smooth(obj)


def subtract(obj, cutter):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.00001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    boolean = obj.modifiers.new("Carved cavity", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.solver = "EXACT"
    boolean.object = cutter
    apply(obj, boolean)
    bpy.data.objects.remove(cutter, do_unlink=True)


def cloth_patch(name, outline, material, bulge=0.009):
    # Several inset rings give broad fabric panels a softly convex surface.
    rounded=[]
    for i,point in enumerate(outline):
        p=Vector(point)
        incoming=p+(Vector(outline[i-1])-p)*.07
        outgoing=p+(Vector(outline[(i+1)%len(outline)])-p)*.07
        for t in (0,.25,.5,.75,1):
            rounded.append(tuple(incoming*(1-t)**2+p*(2*t*(1-t))+outgoing*t*t))
    outline=rounded
    center = sum((Vector(p) for p in outline), Vector()) / len(outline)
    vertices, faces = [], []
    for r in (1, 0.95, 0.75, 0.48, 0.2):
        for p in outline:
            v = center + (Vector(p) - center) * r
            v.y -= bulge * (1-r*r)
            vertices.append(tuple(v))
    n = len(outline)
    for row in range(4):
        for i in range(n):
            a = row*n + i
            b = row*n + (i+1) % n
            faces.append((a, b, b+n, a+n))
    faces.append(tuple(4*n + i for i in range(n)))
    obj = mesh(name, vertices, faces, material)
    solid = obj.modifiers.new("Soft folded fabric thickness", "SOLIDIFY")
    solid.thickness = 0.009
    apply(obj, solid)
    bevel = obj.modifiers.new("Soft hem edges", "BEVEL")
    bevel.width = 0.004
    bevel.segments = 3
    apply(obj, bevel)
    smart_uv(obj)
    return obj


print("Sculpting head, recessed sockets, mouth and asymmetry", flush=True)
head_parts = [
    sphere("Cranium_full_round_occiput", (-0.012, 0.100, 2.094), (0.446, 0.464, 0.435), SKIN, 96, 64, 0.009),
    sphere("Tapered_jaw", (-0.014, -0.055, 1.824), (0.288, 0.273, 0.182), SKIN, 64, 48, 0.003),
    sphere("Left_orbital_plane", (-0.227,-0.070,2.087),(.199,.295,.216),SKIN,64,48),
    sphere("Right_orbital_plane", (.216,-0.068,2.072),(.204,.297,.222),SKIN,64,48),
    sphere("Nose_subtle_bridge", (-0.006, -0.311, 1.964), (0.072, 0.045, 0.078), SKIN),
    sphere("Integrated_lower_lip",(-.01,-.184,1.743),(.229,.151,.047),SKIN,64,40),
    sphere("Integrated_upper_lip",(-.01,-.187,1.875),(.219,.147,.027),SKIN,64,32),
]
head = merge_skin("Head_sculpt_full_volume_B_reference", head_parts, 0.007,relax_iterations=32)
for side, cx, cz, radius in [("L", -0.227, 2.094, 0.123), ("R", 0.216, 2.075, 0.162)]:
    cutter = sphere("Socket_cutter", (cx, -0.279, cz), (radius+0.014, 0.143, radius+0.021), None, 64, 48)
    subtract(head, cutter)
    eye_y=-0.292
    eye = sphere("Eyeball_"+side, (cx, eye_y, cz), (radius, radius*0.80, radius*1.02), EYE, 64, 48)
    px = cx + (-0.023 if side == "L" else 0.008)
    pz = cz + (0.012 if side == "L" else -0.011)
    sphere("Pupil_"+side, (px, eye_y-radius*0.80+0.002, pz), (0.022 if side == "R" else 0.019, 0.006, 0.022 if side == "R" else 0.019), PUPIL, 40, 24)

mouth_cutter = sphere("Mouth_cutter", (-0.011, -0.305, 1.805), (0.221, 0.172, 0.082), None, 64, 48)
subtract(head, mouth_cutter)
sphere("Deep_open_mouth", (-0.011, -0.182, 1.805), (0.217, 0.095, 0.077), MOUTH, 64, 40)
curve("Lower_gum_inside", [(-0.16,-0.241,1.760),(-0.04,-0.265,1.750),(0.15,-0.239,1.761)],0.010,INNER)
for i, (x,z,w,h,angle) in enumerate([(-0.143,1.828,0.064,0.059,-0.06),(-0.035,1.833,0.054,0.042,0.06),(0.094,1.825,0.043,0.031,0.18),(-0.158,1.743,0.055,0.039,0.1),(0.077,1.734,0.065,0.048,-0.1)]):
    box("Irregular_tooth_%02d"%i, (x,-0.301,z+(.014 if i<3 else .022)),(w,0.035,h),TEETH,0.012,(0,angle,0))
for i, x in enumerate((-0.039,0.035)):
    nostril = sphere("Nostril_cutter", (x,-0.365,1.959), (0.020,0.045,0.028),None,40,28)
    nostril.rotation_euler.y = -0.29 if i == 0 else 0.28
    subtract(head, nostril)
    sphere("Deep_nostril_%d"%i,(x,-0.334,1.960),(0.016,0.010,0.024),PUPIL,32,24)
# Shallow actual skin grooves replace floating dark wire decorations.
def head_crease(name,points,radius):
    projected=[]
    inverse=head.matrix_world.inverted()
    for x,y,z in points:
        origin=inverse @ Vector((x,-2,z))
        hit,p,n,face=head.ray_cast(origin,Vector((0,1,0)))
        if hit:
            p=head.matrix_world @ p
            p.y+=radius*.4
            projected.append(tuple(p))
        else:
            projected.append((x,y,z))
    cutter=curve(name+"_groove_cutter",projected,radius,CREASE)
    subtract(head,cutter)
head_crease("Forehead_long_worry_crease",[(-0.235,-0.274,2.306),(-0.15,-0.323,2.284),(-0.041,-0.334,2.285),(0.062,-0.317,2.310)],0.0025)
head_crease("Forehead_short_worry_crease",[(-0.145,-0.292,2.352),(-0.079,-0.309,2.337),(-0.015,-0.316,2.345)],0.002)
head_crease("Left_eye_underfold",[(-0.34,-0.23,1.939),(-0.258,-0.27,1.904),(-0.171,-0.302,1.909)],0.002)
head_crease("Right_eye_underfold",[(0.118,-0.298,1.869),(0.214,-0.258,1.861),(0.312,-0.201,1.908)],0.002)
decimate=head.modifiers.new("Preserve silhouette with fewer sculpt triangles","DECIMATE")
decimate.ratio=.70
decimate.use_collapse_triangulate=True
apply(head,decimate)
rim=head.modifiers.new("Soft sculpted cavity edges","BEVEL")
rim.limit_method="ANGLE"
rim.angle_limit=.45
rim.width=.006
rim.segments=3
rim.use_clamp_overlap=True
apply(head,rim)
# Continuous cylindrical UVs prevent abrupt mottling boundaries on the face.
while head.data.uv_layers:
    head.data.uv_layers.remove(head.data.uv_layers[0])
uv_layer=head.data.uv_layers.new(name="UVMap")
for loop in head.data.loops:
    co=head.data.vertices[loop.vertex_index].co
    world=head.matrix_world @ co
    uv_layer.data[loop.index].uv=(.5+math.atan2(world.x+.014,.10-world.y)/(2*math.pi),max(.001,min(.999,(world.z-1.62)/.94)))
for polygon in head.data.polygons:
    coords=[uv_layer.data[i].uv.x for i in polygon.loop_indices]
    if max(coords)-min(coords)>.5:
        for i in polygon.loop_indices:
            if uv_layer.data[i].uv.x<.5:
                uv_layer.data[i].uv.x+=1
# Dark olive is confined to the deep inside surfaces of the real cavities.
head.data.materials.append(SOCKET)
for polygon in head.data.polygons:
    point=head.matrix_world @ polygon.center
    for cx,cz,radius in [(-.227,2.094,.137),(.216,2.075,.176)]:
        if ((point.x-cx)/radius)**2+((point.z-cz)/radius)**2<.9 and -.16<point.y<-.07:
            polygon.material_index=1

hair_paths = [
    [(-.25,.012,2.463),(-.288,.013,2.524),(-.31,.007,2.586),(-.294,.014,2.626),(-.331,.022,2.649)],
    [(-.31,.029,2.407),(-.357,.019,2.457),(-.383,.018,2.507)],
    [(-.394,.045,2.318),(-.456,.019,2.33),(-.49,.013,2.32)],
    [(-.421,.018,2.25),(-.466,.001,2.263),(-.491,.004,2.257)],
    [(-.431,-.005,2.192),(-.478,-.013,2.211),(-.505,-.009,2.20)],
    [(.167,.066,2.49),(.176,.075,2.533),(.162,.086,2.572)],
    [(.299,.053,2.427),(.345,.063,2.491),(.362,.071,2.539)],
    [(.329,.04,2.404),(.397,.041,2.457),(.448,.039,2.447)],
    [(.405,.016,2.329),(.469,.008,2.361),(.48,.025,2.404)],
    [(.422,.013,2.241),(.483,.016,2.248),(.519,.024,2.23)],
    [(.404,.012,2.138),(.461,-.005,2.116),(.483,.004,2.074)],
    [(.361,.015,2.034),(.425,.014,2.001),(.46,.012,2.012),(.492,.02,1.982)],
]
hair_paths += [
    [(-.17,.46,2.32),(-.19,.51,2.36),(-.23,.54,2.35)],
    [(.20,.44,2.33),(.24,.49,2.36),(.25,.54,2.34)],
    [(-.07,.43,2.40),(-.08,.46,2.46),(-.12,.48,2.49)],
    [(.09,.44,2.40),(.11,.47,2.46),(.10,.50,2.49)],
]
for i, points in enumerate(hair_paths):
    center=Vector((-.012,.10,2.094))
    direction=(Vector(points[0])-center).normalized()
    inverse=head.matrix_world.inverted()
    hit,p,n,face=head.ray_cast(inverse @ (center+direction*2),-direction)
    if hit:
        delta=head.matrix_world @ p-Vector(points[0])
        points=[tuple(Vector(point)+delta) for point in points]
    curve("Sparse_bent_hair_%02d"%i,points,0.0044,HAIR)
HEAD_OBJECTS=list(model.objects)
sphere("Neck",(-0.006,0.028,1.602),(.095,.091,.12),SKIN)

print("Tailoring shirt, open jacket, folded lapels and striped tie", flush=True)
shirt = loft("Shirt_torso_ragged_hem", [
    (.955,0,.029,.205,.116),(1.017,0,.026,.24,.136),(1.15,0,.018,.243,.151),
    (1.33,0,.023,.244,.166),(1.445,0,.039,.233,.148),(1.51,0,.048,.137,.086)
], SHIRT, count=80, torn=True, wave=.0025)
jacket_rings=[
    (.917,0,.063,.253,.137),(.956,0,.060,.276,.149),(1.075,0,.052,.272,.163),
    (1.20,0,.048,.263,.18),(1.34,0,.064,.275,.173),(1.445,0,.069,.263,.157),
    (1.515,0,.062,.17,.098)
]
jacket_rings=[(z,x,y-.030,rx,ry) for z,x,y,rx,ry in jacket_rings]
jacket = loft("Jacket_open_body_with_split_front",jacket_rings,JACKET,count=104,opening=.43,cap=False,torn=True,wave=.004,thickness=.018)
for garment in (shirt,jacket):
    subdivision=garment.modifiers.new("Rounded tailored silhouette","SUBSURF")
    subdivision.levels=1
    apply(garment,subdivision)
def jacket_front(x,z):
    for low,high in zip(jacket_rings,jacket_rings[1:]):
        if low[0]<=z<=high[0]:
            t=(z-low[0])/(high[0]-low[0])
            cy=low[2]*(1-t)+high[2]*t
            rx=low[3]*(1-t)+high[3]*t
            ry=low[4]*(1-t)+high[4]*t
            return cy-ry*math.sqrt(max(.04,1-(x/rx)**2))
    return -.11
def jacket_back(x,z):
    for low,high in zip(jacket_rings,jacket_rings[1:]):
        if low[0]<=z<=high[0]:
            t=(z-low[0])/(high[0]-low[0])
            cy=low[2]*(1-t)+high[2]*t
            return 2*cy-jacket_front(x,z)
    return .15
for side in (-1,1):
    sx = lambda x: side*x
    lapel_outline = [
        (sx(.096),-.113,1.518),(sx(.20),-.117,1.476),(sx(.226),-.143,1.409),
        (sx(.192),-.154,1.385),(sx(.234),-.158,1.343),(sx(.137),-.191,1.227),
        (sx(.069),-.161,1.402)
    ]
    lapel_outline=[(x,jacket_front(x,z)-.017,z) for x,y,z in lapel_outline]
    if side < 0:
        lapel_outline.reverse()
    cloth_patch("Jacket_folded_notched_lapel_"+str(side),lapel_outline,LAPEL,.012)
    collar_outline = [(sx(.044),-.151,1.527),(sx(.109),-.126,1.542),(sx(.136),-.163,1.469),(sx(.084),-.18,1.443)]
    if side < 0:
        collar_outline.reverse()
    cloth_patch("Shirt_pointed_collar_"+str(side),collar_outline,SHIRT,.005)
    curve("Jacket_front_hem_seam_"+str(side),[(sx(.154),-.064,.938),(sx(.173),-.072,1.031),(sx(.152),-.096,1.152),(sx(.138),-.112,1.25)],.0018,SEAM)
    curve("Jacket_side_seam_"+str(side),[(sx(.269),.043,.96),(sx(.263),.049,1.15),(sx(.273),.055,1.34)],.0018,SEAM)
    curve("Jacket_soft_waist_fold_"+str(side),[(sx(.209),-.049,1.088),(sx(.247),-.014,1.112),(sx(.264),.034,1.104)],.004,LAPEL)
    curve("Shirt_chest_crease_"+str(side),[(sx(.092),-.121,1.157),(sx(.15),-.10,1.179),(sx(.196),-.069,1.169)],.0021,SHIRT)
    # Small shaped shirt tails reproduce the uneven three-point lower edge.
    cloth_patch("Shirt_torn_tail_"+str(side),[(sx(.015),-.122,.993),(sx(.109),-.115,1.019),(sx(.102),-.131,.953),(sx(.064),-.139,.916)],SHIRT,.002)
curve("Jacket_back_center_seam",[(x,jacket_back(x,z)+.0015,z) for x,y,z in [(0,.203,.946),(0,.225,1.07),(0,.229,1.28),(0,.223,1.44),(0,.159,1.514)]],.0018,SEAM)
curve("Jacket_back_shoulder_seam",[(x,jacket_back(x,z)+.0015,z) for x,y,z in [(-.217,.143,1.45),(-.12,.205,1.459),(0,.219,1.458),(.12,.205,1.459),(.217,.143,1.45)]],.0018,SEAM)
for index,z in enumerate((1.18,1.10,1.026)):
    x=-.136
    hit,p,n,face=jacket.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
    y=p.y-.004 if hit else jacket_front(x,z)-.004
    sphere("Jacket_front_button_"+str(index),(x,y,z),(.009,.0035,.009),SEAM,32,20)
# Sleeves follow the two asymmetric bent arms, rather than straight cylinders.
jacket_parts=[jacket]
arm_specs = [
    ("L",[(-.185,.065,1.400),(-.325,.017,1.345),(-.405,-.007,1.235),(-.448,-.076,1.176),(-.466,-.209,1.166),(-.476,-.296,1.184)],
     [(.103,.097),(.10,.095),(.091,.088),(.086,.08),(.082,.073),(.081,.068)]),
    ("R",[(.185,.065,1.400),(.337,.018,1.338),(.40,-.006,1.217),(.449,-.085,1.112),(.481,-.212,1.093),(.488,-.286,1.079)],
     [(.107,.101),(.103,.094),(.094,.087),(.087,.080),(.083,.075),(.08,.066)])
]
for label, points, radii in arm_specs:
    sleeve=tube("Jacket_bent_sleeve_"+label,points,radii,JACKET,count=36,detail=6,wrinkles=.0055)
    jacket_parts.append(sleeve)
    end = Vector(points[-1])
    previous = Vector(points[-2])
    tangent = (end-previous).normalized()
    tube("Jacket_rolled_cuff_"+label,[tuple(end-tangent*.034),tuple(end-tangent*.014),tuple(end+tangent*.007)],[(.084,.069),(.088,.073),(.08,.067)],LAPEL,count=40,detail=3,wrinkles=.002)
    outer = -1 if label == "L" else 1
    curve("Sleeve_outer_seam_"+label,[(p[0]+outer*r[0]*.92,p[1]+.015,p[2]) for p,r in zip(points,radii)],.0017,SEAM)
    for j in (2,3,4):
        x,y,z = points[j]
        curve("Sleeve_fold_"+label+str(j),[(x-outer*.047,y-.054,z+.022),(x,y-.078,z+.013),(x+outer*.047,y-.05,z-.008)],.0028,LAPEL)

# Draped tie: width and front depth vary continuously from knot to tip.
def tie_shape(z):
    t = max(0,min(1,(1.444-z)/.374))
    cx = .004 + .037*t + .009*math.sin(t*3)
    width = .032 + .067*t
    if z < 1.086:
        width = .097*max(0,(z-1.018)/.068)
    y = -.172 - .024*math.sin(t*2.6) - .013*t
    return cx,width,y

tie_vertices, tie_uvs, tie_faces = [],[],[]
zs = list(np.linspace(1.444,1.086,35)) + [1.06,1.035,1.018]
for row,z in enumerate(zs):
    cx,w,y = tie_shape(z)
    for i in range(13):
        u = i/12
        x = cx+(u*2-1)*max(w,.001)
        tie_vertices.append((x,y-.008*(1-(u*2-1)**2),z))
        tie_uvs.append((u,1-row/(len(zs)-1)))
for row in range(len(zs)-1):
    for i in range(12):
        a=row*13+i
        tie_faces.append((a,a+1,a+14,a+13))
tie = mesh("Tie_curved_tapered_blade",tie_vertices,tie_faces,TIE,tie_uvs)
solid = tie.modifiers.new("Tie fabric thickness","SOLIDIFY")
solid.thickness=.007
apply(tie,solid)
knot=box("Tie_soft_trapezoid_knot",(.002,-.166,1.473),(.073,.052,.078),TIE,.012,(0,-.10,0))
for vertex in knot.data.vertices:
    t=max(0,min(1,vertex.co.z/.078+.5))
    vertex.co.x*=.67+.37*t
for index, base_z in enumerate(np.arange(1.416,1.055,-.066)):
    vertices,uvs,faces=[],[],[]
    for row in range(3):
        for i in range(21):
            t=i/20
            # Iterate world-space diagonal intersections with changing tie width.
            z=base_z
            for _ in range(4):
                cx,w,y=tie_shape(z)
                x=cx+(t*2-1)*w*.992
                z=base_z-.31*x+(row-1)*.007
            cx,w,y=tie_shape(z)
            x=cx+(t*2-1)*w*.992
            vertices.append((x,y-.008*(1-(t*2-1)**2)-.0105,z))
            uvs.append((t,row/2))
    for row in range(2):
        for i in range(20):
            a=row*21+i
            faces.append((a,a+1,a+22,a+21))
    mesh("Tie_ivory_diagonal_stripe_%02d"%index,vertices,faces,SHIRT,uvs)

print("Sculpting palms, five curved fingers per hand, nails and knuckle folds", flush=True)
for side, wrist in [("L",(-.476,-.307,1.180)),("R",(.488,-.302,1.075))]:
    existing_hand_objects=set(model.objects)
    sign=-1 if side=="L" else 1
    wx,wy,wz=wrist
    palm_center=(wx+sign*.006,wy-.092,wz-.029)
    parts=[sphere("Palm",palm_center,(.099,.093,.059),SKIN,48,36)]
    parts.append(tube("Wrist",[(wx,wy+.042,wz),(wx,wy-.024,wz-.005),palm_center],[.055,.061,(.073,.047)],SKIN,count=32,detail=3))
    fingers=[]
    for i,(offset,length,radius) in enumerate([(-.078,.136,.027),(-.026,.157,.030),(.029,.154,.029),(.078,.126,.025)]):
        # Outer little fingers are shorter; the left hand hangs less steeply.
        x=wx+offset
        basez=wz-.038 + (.012 if i in (0,3) else 0)
        basey=wy-.14
        points=[(x,basey+.009,basez),(x+sign*.004,basey-.038,basez-.027),(x+sign*.004,basey-.052,basez-length*.62),(x-sign*.007,basey-.04,basez-length),(x-sign*.01,basey-.024,basez-length-.007)]
        if side=="L":
            points=[(p[0],p[1]-.009,p[2]+.027*k/4) for k,p in enumerate(points)]
        parts.append(tube("Finger",points,[radius*1.08,radius,radius*.9,radius*.80,radius*.34],SKIN,count=24,detail=5))
        parts.append(sphere("Knuckle",points[0],(radius*1.2,radius*1.1,radius*.87),SKIN,32,20))
        fingers.append((points,radius))
    # Thumb curls inward, beside the palm, and is visibly separate from fingers.
    tx=wx-sign*.084
    thumb=[(tx,wy-.049,wz-.014),(tx-sign*.032,wy-.097,wz-.025),(tx-sign*.053,wy-.139,wz-.073),(tx-sign*.033,wy-.166,wz-.102)]
    parts.append(tube("Thumb",thumb,[.035,.033,.029,.018],SKIN,count=28,detail=5))
    hand=merge_skin("Hand_anatomical_sculpt_"+side,parts,.0035)
    smart_uv(hand)
    for i,(points,radius) in enumerate(fingers):
        end=points[-2]
        nail=box("Fingernail_"+side+str(i),(end[0],end[1]-radius*.75,end[2]+.016),(radius*1.20,.009,.026),NAIL,.005,(.16,0,0))
        middle=points[2]
        for fold in (-1,1):
            curve("Finger_joint_crease_"+side+str(i)+str(fold),[(middle[0]-radius*.63,middle[1]-radius*.81,middle[2]+fold*.004),(middle[0],middle[1]-radius*.94,middle[2]+fold*.004+.002),(middle[0]+radius*.62,middle[1]-radius*.82,middle[2]+fold*.004)],.00115,CREASE)
    box("Thumbnail_"+side,(thumb[-1][0],thumb[-1][1]-.013,thumb[-1][2]+.012),(.023,.008,.025),NAIL,.005)
    for i in range(3):
        x=wx+(i-1)*.037
        curve("Back_of_hand_tendon_"+side+str(i),[(x,wy-.038,wz+.023),(x,wy-.083,wz+.027),(x,wy-.127,wz+.014)],.0025,LIP)
    pivot=Vector(wrist)
    hand_scale=Vector((1.26,1.16,1.14))
    for obj in model.objects:
        if obj not in existing_hand_objects:
            offset=obj.location-pivot
            obj.location=pivot+Vector(tuple(offset[i]*hand_scale[i] for i in range(3)))
            obj.scale=Vector(tuple(obj.scale[i]*hand_scale[i] for i in range(3)))

print("Building torn denim, exposed knees, shin and scuffed leather shoes", flush=True)
loft("Trousers_hip_and_seat",[(.85,0,.04,.14,.092),(.9,0,.03,.23,.118),(.97,0,.04,.242,.121),(1.035,0,.037,.218,.102)],DENIM,count=80,wave=.002)
long_leg = loft("Trousers_long_right_leg_with_real_knee_hole",[
    (.198,-.251,.018,.112,.108),(.236,-.246,.014,.116,.105),(.30,-.233,.022,.112,.110),
    (.40,-.216,.023,.099,.110),(.49,-.203,.022,.099,.112),(.57,-.184,.03,.106,.114),
    (.65,-.161,.039,.119,.117),(.74,-.139,.043,.12,.128),(.84,-.131,.049,.121,.137),(.94,-.12,.002,.123,.095),(.989,-.119,.0,.115,.09)
],DENIM,count=72,wave=.003)
sphere("Right_knee_visible_through_hole",(-.200,.003,.518),(.084,.093,.092),SKIN,64,40,.002)
hole_outline = [(-.243,.551),(-.219,.589),(-.18,.58),(-.169,.548),(-.153,.52),(-.18,.487),(-.193,.458),(-.222,.471),(-.241,.506)]
hole_outline=[(-.201+(x+.201)*1.05,.523+(z-.523)*1.10) for x,z in hole_outline]
vertices = [(x,y,z) for y in (-.30,-.037) for x,z in hole_outline]
count=len(hole_outline)
faces=[tuple(reversed(range(count))),tuple(range(count,2*count))]
faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
hole=mesh("Ragged_knee_hole_cutter",vertices,faces,None)
subtract(long_leg,hole)
curve("Ragged_knee_denim_edge",[(x,-.081,z) for x,z in hole_outline]+[(hole_outline[0][0],-.081,hole_outline[0][1])],.0045,DENIM_EDGE)
for i in range(27):
    j=i%count
    t=random.uniform(.1,.9)
    x=hole_outline[j][0]*(1-t)+hole_outline[(j+1)%count][0]*t
    z=hole_outline[j][1]*(1-t)+hole_outline[(j+1)%count][1]*t
    length=random.uniform(.006,.015)
    curve("Knee_hole_loose_fiber_%02d"%i,[(x,-.087,z),(x+random.uniform(-.005,.005),-.09,z-length)],.0006,THREAD)
short_leg=loft("Trousers_left_thigh_jagged_torn_hem",[
    (.602,.184,.033,.113,.117),(.65,.176,.041,.117,.119),(.726,.154,.046,.122,.123),
    (.816,.139,.049,.124,.132),(.912,.121,.01,.123,.104),(.989,.117,.0,.115,.09)
],DENIM,count=64,torn=True,cap=False,wave=.002)
# Make long torn points on the entire circular hem, including the back.
for vert in short_leg.data.vertices:
    if vert.co.z < .66:
        angle=math.atan2(vert.co.x-.184,-(vert.co.y-.033))
        a=(angle+2*math.pi)%(2*math.pi)
        # Broad alternating rips, rather than a uniform sawtooth.
        distance=min(abs(a-c) for c in (.20,1.55,2.35,3.65,4.72,5.6))
        vert.co.z-=.035*max(0,1-distance/.28)
sphere("Exposed_left_knee",(.196,.018,.506),(.091,.096,.11),SKIN,64,40,.003)
shin=tube("Exposed_left_sage_shin",[(.196,.022,.475),(.206,.016,.403),(.219,-.003,.305),(.226,-.013,.22)],[(.066,.07),(.064,.061),(.049,.047),(.05,.051)],SHIN,count=48,detail=7,wrinkles=.001)
# Torn-off trouser cuff slumps around the visible ankle like the reference.
loft("Detached_denim_ankle_cuff",[(.147,.232,-.008,.114,.101),(.182,.23,-.004,.121,.107),(.224,.229,.001,.117,.108),(.259,.228,.005,.123,.107)],DENIM,count=64,torn=True,cap=False,wave=.006)
curve("Ankle_cuff_fold",[(.106,-.02,.228),(.146,-.103,.207),(.23,-.123,.203),(.311,-.096,.216),(.351,-.005,.237)],.010,DENIM_EDGE)
for i in range(15):
    angle=random.uniform(-.9,.9)
    x=.184+math.sin(angle)*.11
    y=.033-math.cos(angle)*.121
    z=.602+.025*math.sin(angle*7)
    curve("Short_trouser_hem_loose_fiber_%02d"%i,[(x,y,z),(x+random.uniform(-.005,.005),y-.002,z-random.uniform(.009,.023))],.0007,THREAD)

for sign,label in [(-1,"L"),(1,"R")]:
    cx=-.251 if sign<0 else .234
    for z,amount in [(.266,.103),(.368,.11),(.676,.117),(.779,.12)]:
        if sign>0 and z<.62:
            continue
        centerx=cx if z<.4 else sign*(.216 if z<.55 else .16 if z<.72 else .136)
        obj=long_leg if sign<0 else short_leg
        projected=[]
        for x,y,zz in [(centerx-amount*.7,-.047,z+.012),(centerx-.015,-.088,z),(centerx+amount*.75,-.045,z+.025)]:
            hit,p,n,face=obj.ray_cast(Vector((x,-2,zz)),Vector((0,1,0)))
            projected.append((x,p.y-.0005 if hit else y,zz))
        curve("Denim_front_fold_"+label+str(z),projected,.0025,DENIM)
    curve("Trouser_outer_stitched_seam_"+label,[(sign*.257,.041,.929),(sign*.26,.025,.756),(sign*.284,.020,.662)]+([] if sign>0 else [(-.31,.003,.475),(-.354,-.005,.242)]),.002,DENIM_EDGE)

def shoe(name,cx):
    body=loft(name+"_rounded_leather_upper",[
        (.035,cx,-.091,.138,.239),(.047,cx,-.095,.148,.248),(.072,cx,-.094,.151,.250),
        (.104,cx,-.081,.15,.238),(.135,cx,-.056,.137,.206),(.165,cx,-.018,.117,.163),
        (.188,cx,.016,.099,.118),(.198,cx,.028,.082,.084),(.204,cx,.025,.029,.033)
    ],LEATHER,count=80,wave=.0018)
    for vertex in body.data.vertices:
        if vertex.co.z>.05:
            vertex.co.z=.05+(vertex.co.z-.05)*1.20
    body.data.update()
    def shoe_seam(label,points,radius,material):
        projected=[]
        for x,y,z in points:
            hit,p,n,face=body.ray_cast(Vector((x,y,1)),Vector((0,0,-1)))
            projected.append((x,y,p.z+.0005 if hit else z))
        return curve(name+"_"+label,projected,radius,material)
    loft(name+"_outsole",[(.009,cx,-.091,.136,.235),(.019,cx,-.093,.146,.246),(.044,cx,-.094,.147,.246),(.051,cx,-.094,.14,.24)],SOLE,count=80)
    curve(name+"_welt_seam",[(cx+math.sin(a)*.147,-.094-math.cos(a)*.245,.06+.002*math.cos(a)) for a in np.linspace(0,2*math.pi,49)],.0028,WELT)
    shoe_seam("toe_vamp_seam",[(cx-.123,-.216,.122),(cx-.082,-.246,.14),(cx,-.258,.151),(cx+.082,-.245,.141),(cx+.122,-.212,.123)],.0018,SOLE)
    shoe_seam("vamp_highlight",[(cx-.113,-.216,.129),(cx-.07,-.244,.145),(cx+.03,-.252,.151),(cx+.11,-.219,.13)],.0012,WELT)
    for i in range(44):
        a=2*math.pi*i/44
        p=(cx+math.sin(a)*.148,-.094-math.cos(a)*.246,.061)
        q=(cx+math.sin(a+.016)*.148,-.094-math.cos(a+.016)*.246,.061)
        curve(name+"_welt_stitch_%02d"%i,[p,q],.0007,WELT)
    # Small creases over the instep emphasize supple worn leather.
    for i in range(2):
        y=-.11+i*.035
        shoe_seam("instep_crease_"+str(i),[(cx-.083,y,.175),(cx-.02,y-.012,.181),(cx+.064,y,.177)],.0012,SOLE)
    return body

shoe("Shoe_anatomical_right",-.252)
shoe("Shoe_anatomical_left",.233)

print("Cleaning mesh seams, creating named asset root and packing source",flush=True)
for obj in HEAD_OBJECTS:
    obj.location.x*=1.04
    obj.location.y=-.02+(obj.location.y+.02)*1.04
    obj.location.z=1.54+(obj.location.z-1.54)*1.08-.080
    obj.scale.x*=1.04
    obj.scale.y*=1.04
    obj.scale.z*=1.08
# Broader arm stance and shoulders keep the large head from dominating the width.
for obj in model.objects:
    if any(token in obj.name for token in ("sleeve","cuff_L","cuff_R","Sleeve_","Hand_","Fingernail_","Finger_joint_","Thumbnail_","Back_of_hand_")):
        obj.location.x*=1.10
        obj.scale.x*=1.10
bpy.context.view_layer.update()
jacket=merge_skin("Jacket_continuous_tailoring",jacket_parts,.0045,JACKET,relax_iterations=18,relax_factor=.45)
decimate=jacket.modifiers.new("Tailored cloth topology reduction","DECIMATE")
decimate.ratio=.55
apply(jacket,decimate)
smart_uv(jacket)
for uv in jacket.data.uv_layers.active.data:
    uv.uv*=3
# A small continuous forward bend gives the torso and head a hunched posture.
for obj in model.objects:
    if obj.type=="MESH":
        matrix=obj.matrix_world.copy()
        inverse=matrix.inverted()
        for vertex in obj.data.vertices:
            point=matrix @ vertex.co
            point.y-=.065*max(0,min(1.1,point.z-1.04))
            vertex.co=inverse @ point
root=bpy.data.objects.new("NormalZombie_Reference",None)
model.objects.link(root)
root.empty_display_type="PLAIN_AXES"
root["asset_description"]="Standalone normal zombie optimized against the user-approved B turnaround with sage-green exposed shin. Static pose; no animation."
root["approved_reference"]="source/reference_B_approved.png"
root["coordinate_system"]="Blender Z-up, facing -Y; GLB Y-up, facing +Z. Feet at ground origin."
for obj in list(model.objects):
    if obj==root:
        continue
    obj.parent=root
    if obj.type=="MESH":
        bm=bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000005)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bmesh.ops.triangulate(bm,faces=[face for face in bm.faces if len(face.verts)>4],ngon_method="BEAUTY")
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.validate(verbose=False)
        obj.data.update()
        if not obj.data.uv_layers:
            smart_uv(obj)
        smooth(obj)

scene=bpy.context.scene
scene.unit_settings.system="METRIC"
scene.unit_settings.scale_length=1
scene.render.engine="CYCLES"
scene.cycles.samples=64
scene.cycles.use_denoising=True
scene.render.resolution_x=1050
scene.render.resolution_y=1400
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.view_settings.view_transform="AgX"
scene.view_settings.look="AgX - Medium High Contrast"
scene.view_settings.exposure=0
scene.world.color=(.25,.25,.25)
world=bpy.data.worlds.new("Studio soft environment")
world.use_nodes=True
world.node_tree.nodes.get("Background").inputs["Color"].default_value=(.28,.34,.39,1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value=.45
scene.world=world

def area_light(name,location,energy,size,color):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=energy
    data.shape="DISK"
    data.size=size
    data.color=color
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=location
    obj.rotation_euler=(Vector((0,0,1.3))-obj.location).to_track_quat("-Z","Y").to_euler()
    return obj

area_light("Large warm window key",(-3,-4,5),430,3.4,(1,.88,.72))
area_light("Soft neutral frontal fill",(3,-4,2.7),160,3.2,(.78,.87,1))
area_light("Shoulder and scalp rim",(1,2.8,4.4),450,2.3,(1,.93,.80))
area_light("Top diffusion",(-.5,0,5),180,2,(1,1,.96))
ground_mat=solid_material("Studio ground",(.26,.32,.33),.92)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,.005))
ground=in_collection(bpy.context.object,studio)
ground.name="Preview_ground_NOT_IN_EXPORT"
ground.data.materials.append(ground_mat)
camera_data=bpy.data.cameras.new("Preview camera")
camera=bpy.data.objects.new("Preview camera",camera_data)
studio.objects.link(camera)
camera.data.type="ORTHO"
camera.data.ortho_scale=3.025
scene.camera=camera

def set_camera(position,target=(0,-.035,1.33)):
    camera.location=position
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()

set_camera((.28,-6,2.20))
# Open source file directly into a useful material-preview camera view.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective="CAMERA"
            area.spaces.active.shading.type="MATERIAL"
            area.spaces.active.shading.use_scene_world=True
            area.spaces.active.shading.use_scene_lights=True
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active=root
for img in bpy.data.images:
    if img.source=="FILE" or img.filepath_raw:
        img.pack()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"source"/"normal_zombie.blend"),compress=True)

# Only character objects enter the portable file, never camera/lights/ground.
bpy.ops.object.select_all(action="DESELECT")
for obj in model.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(ROOT/"normal_zombie.glb"),export_format="GLB",use_selection=True,export_yup=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials="EXPORT",export_animations=False,export_cameras=False,export_lights=False)
mesh_objects=[obj for obj in model.objects if obj.type=="MESH"]
vertices=sum(len(obj.data.vertices) for obj in mesh_objects)
triangles=sum(sum(len(poly.vertices)-2 for poly in obj.data.polygons) for obj in mesh_objects)
bounds=[obj.matrix_world @ Vector(corner) for obj in mesh_objects for corner in obj.bound_box]
minimum=[min(p[i] for p in bounds) for i in range(3)]
maximum=[max(p[i] for p in bounds) for i in range(3)]
manifest={"asset":"normal_zombie","authoring_tool":bpy.app.version_string,"mesh_objects":len(mesh_objects),"vertices":vertices,"triangles":triangles,"materials":len({slot.material.name for obj in mesh_objects for slot in obj.material_slots if slot.material}),"bounds_blender_z_up_m":{"min":minimum,"max":maximum},"dimensions_m":[maximum[i]-minimum[i] for i in range(3)],"pose":"static reference pose, no armature or animations","textures":"embedded in GLB and packed in BLEND; source PNGs in source/textures","game_integration":"none"}
head_corners=[head.matrix_world @ Vector(corner) for corner in head.bound_box]
head_dimensions=[max(p[i] for p in head_corners)-min(p[i] for p in head_corners) for i in range(3)]
manifest["approved_reference"]="source/reference_B_approved.png"
manifest["head_dimensions_blender_xyz_m"]=head_dimensions
manifest["head_depth_to_width_ratio"]=head_dimensions[1]/head_dimensions[0]
manifest["shin_skin_srgb"]=[.405,.49,.425]
(ROOT/"model_manifest.json").write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding="utf-8")
print(json.dumps(manifest,ensure_ascii=False),flush=True)
try:
    preferences=bpy.context.preferences.addons["cycles"].preferences
    preferences.compute_device_type="OPTIX"
    preferences.get_devices()
    devices=[device for device in preferences.devices if device.type!="CPU"]
    if devices:
        for device in preferences.devices:
            device.use=device.type!="CPU"
        scene.cycles.device="GPU"
        print("Rendering with OPTIX: "+", ".join(d.name for d in devices),flush=True)
except Exception as error:
    print("CPU render fallback: "+str(error),flush=True)
if "--skip-render" not in sys.argv:
    for name,position in [("front",(.28,-6,2.20)),("three_quarter",(3.9,-5.4,2.35)),("back",(2.6,5.8,2.25))]:
        print("Rendering "+name,flush=True)
        set_camera(position)
        scene.render.filepath=str(PREVIEWS/(name+".png"))
        bpy.ops.render.render(write_still=True)
print("ASSET COMPLETE: "+str(ROOT),flush=True)


