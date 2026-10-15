"""Build the standalone Conehead Zombie from the user-approved sheet A.

blender --background --threads 8 --python build_conehead.py
Only this asset directory is written. The included packed base is a copy;
the original normal zombie and game files are never opened for writing.
"""
import bpy
import bmesh
import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path

import numpy as np
from mathutils import Euler, Vector
from mathutils.noise import noise_vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source"
TEXTURES = SOURCE / "textures"
PREVIEWS = ROOT / "previews"
TEXTURES.mkdir(parents=True, exist_ok=True)
PREVIEWS.mkdir(parents=True, exist_ok=True)
BASE = SOURCE / "base_normal_zombie.blend"
BASE_SHA256 = "62637ee6baa7e497c7a043af0f894747b07c904f44b05a0e4a49942769bf559c"
assert hashlib.sha256(BASE.read_bytes()).hexdigest() == BASE_SHA256
bpy.ops.wm.open_mainfile(filepath=str(BASE))
scene = bpy.context.scene
model = bpy.data.collections["NORMAL_ZOMBIE | reference model"]
model.name = "CONEHEAD_ZOMBIE | A reference model"
studio = bpy.data.collections["STUDIO | preview only, excluded from GLB"]
root = bpy.data.objects["NormalZombie_Reference"]
root.name = "ConeheadZombie_Reference_A"
root["approved_reference"] = "source/reference_A_approved.png"
root["asset_description"] = "Standalone Conehead Zombie based on approved sheet A; static pose, no animation."
root["base_model_sha256"] = BASE_SHA256


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply(obj, modifier):
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def smooth(obj):
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def solid_material(name, color, roughness):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = tuple(linear(c) for c in color) + (1,)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = .24
    material.diffuse_color = (*color, 1)
    return material


def export_source_textures():
    """Keep every copied texture independent of the original asset directory."""
    for image in bpy.data.images:
        if image.packed_file:
            path = TEXTURES / (image.name.removesuffix(".png") + ".png")
            path.write_bytes(image.packed_file.data)
            image.filepath = "//textures/" + path.name


export_source_textures()
print("Adjusting only the copied character toward reference A", flush=True)
head_prefixes = ("Head_sculpt", "Eyeball_", "Pupil_", "Deep_open_mouth", "Lower_gum_inside", "Irregular_tooth_", "Deep_nostril_", "Sparse_bent_hair_")
for obj in list(model.objects):
    if obj.type == "MESH" and obj.name.startswith(head_prefixes):
        matrix = obj.matrix_world.copy()
        inverse = matrix.inverted()
        for vertex in obj.data.vertices:
            p = matrix @ vertex.co
            p.x = -.01 + (p.x + .01) * 1.06
            p.y = .015 + (p.y - .015) * .98
            p.z = 1.58 + (p.z - 1.58) * .91
            vertex.co = inverse @ p
        obj.data.update()
head = next(obj for obj in model.objects if obj.name.startswith("Head_sculpt"))
head.name = "Head_sculpt_round_A_reference"
# Fine actual skin relief supplements the packed pore normal map in close-ups.
surface_normals = [vertex.normal.copy() for vertex in head.data.vertices]
for vertex, normal_direction in zip(head.data.vertices, surface_normals):
    point = head.matrix_world @ vertex.co
    relief = noise_vector(point * 46).x * .0013 + noise_vector(point * 13).x * .0007
    vertex.co += normal_direction * relief
head.data.update()

# The reference cone hides the upper strands; retain fine side/rear hairs only.
removed_hairs = []
for obj in list(model.objects):
    if obj.name.startswith("Sparse_bent_hair_"):
        bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
        if max(p.z for p in bounds) > 2.35:
            removed_hairs.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)


def value_noise(size, cells_x, cells_y, seed):
    rng = np.random.default_rng(seed)
    grid = rng.random((cells_y + 1, cells_x + 1), dtype=np.float32)
    grid[:, -1] = grid[:, 0]
    grid[-1, :] = grid[0, :]
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    xx *= cells_x / size
    yy *= cells_y / size
    xi, yi = xx.astype(np.int32), yy.astype(np.int32)
    fx, fy = xx - xi, yy - yi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = grid[yi, xi] * (1 - fx) + grid[yi, xi + 1] * fx
    b = grid[yi + 1, xi] * (1 - fx) + grid[yi + 1, xi + 1] * fx
    return a * (1 - fy) + b * fy


def save_texture(name, pixels, non_color=False):
    height, width = pixels.shape[:2]
    image = bpy.data.images.new(name, width=width, height=height, alpha=False)
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    rgba = np.ones((height, width, 4), dtype=np.float32)
    rgba[:, :, :3] = pixels
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(TEXTURES / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    # Reload the PNG explicitly: generated-image shader interpretation must not
    # differ from the FILE image later embedded in GLB or re-opened in Blender.
    path = image.filepath_raw
    bpy.data.images.remove(image)
    image = bpy.data.images.load(path, check_existing=False)
    image.name = name
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    image.pack()
    image.filepath = "//textures/" + name + ".png"
    return image


print("Creating 2048px orange plastic, edge wear, dirt and scratch maps", flush=True)
size = 2048
rng = np.random.default_rng(150025)
v, u = np.mgrid[0:size, 0:size].astype(np.float32) / size
coarse = value_noise(size, 7, 13, 21)
medium = value_noise(size, 83, 127, 22)
fine = value_noise(size, 239, 347, 23)
grain = rng.normal(0, 1, (size, size)).astype(np.float32)
field = .42 * coarse + .37 * medium + .21 * fine
edge = np.exp(-v * 25) + np.exp(-(1 - v) * 30)
chips = np.clip((.55 * medium + .28 * fine + .17 * coarse + .065 * edge - .685) * 18, 0, 1)
dirt = np.clip((coarse - .43) * .65, 0, .27)
scratches = np.zeros_like(field)
for _ in range(200):
    sx, sy = rng.uniform(0, 1, 2)
    length = rng.uniform(.003, .045)
    angle = rng.uniform(-math.pi, math.pi)
    dx = np.minimum(np.abs(u - sx), 1 - np.abs(u - sx))
    dx *= np.where((u - sx + .5) % 1 < .5, 1, -1)
    dy = v - sy
    along = dx * math.cos(angle) + dy * math.sin(angle)
    across = -dx * math.sin(angle) + dy * math.cos(angle)
    width = rng.uniform(.00018, .00065)
    scratch = np.exp(-(across / width) ** 2) * np.clip(1 - (along / length) ** 8, 0, 1)
    scratches = np.maximum(scratches, scratch * rng.uniform(.3, .9))
orange = np.array((.95, .36, .025), np.float32)
base = orange[None, None, :] * (1 + (field[:, :, None] - .5) * .24 + grain[:, :, None] * .009)
base *= 1 - dirt[:, :, None]
scuff_color = np.array((.16, .17, .15), np.float32)
base = base * (1 - chips[:, :, None] * .92) + scuff_color * chips[:, :, None] * .92
base *= 1 - scratches[:, :, None] * .27
height = .12 * field + grain * .012 - chips * .07 - scratches * .07
dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 2.6
dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 2.6
normal = np.stack((-dx, -dy, np.ones_like(dx)), axis=2)
normal /= np.linalg.norm(normal, axis=2)[:, :, None]
orm = np.zeros((size, size, 3), np.float32)
orm[:, :, 0] = 1
orm[:, :, 1] = np.clip(.62 + .12 * (field - .5) + chips * .21 + dirt * .4, .48, .91)
albedo_image = save_texture("Cone_worn_orange_plastic_basecolor", np.clip(base, 0, 1))
normal_image = save_texture("Cone_worn_orange_plastic_normal", normal * .5 + .5, True)
orm_image = save_texture("Cone_worn_orange_plastic_orm", orm, True)
cone_material = bpy.data.materials.new("Cone_worn_orange_plastic")
cone_material.use_nodes = True
nodes, links = cone_material.node_tree.nodes, cone_material.node_tree.links
shader = nodes.get("Principled BSDF")
shader.inputs["Metallic"].default_value = 0
shader.inputs["Specular IOR Level"].default_value = .27
base_node = nodes.new("ShaderNodeTexImage")
base_node.image = albedo_image
links.new(base_node.outputs["Color"], shader.inputs["Base Color"])
normal_node = nodes.new("ShaderNodeTexImage")
normal_node.image = normal_image
normal_map = nodes.new("ShaderNodeNormalMap")
normal_map.inputs["Strength"].default_value = .7
links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
orm_node = nodes.new("ShaderNodeTexImage")
orm_node.image = orm_image
split = nodes.new("ShaderNodeSeparateColor")
links.new(orm_node.outputs["Color"], split.inputs["Color"])
links.new(split.outputs["Green"], shader.inputs["Roughness"])
inner_material = solid_material("Cone_interior_dark_orange", (.355, .125, .025), .89)
del base, height, normal, orm, coarse, medium, fine, grain, field, scratches, dx, dy, v, u


def mesh(name, vertices, faces, material, uvs):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    model.objects.link(obj)
    data.materials.append(material)
    layer = data.uv_layers.new(name="UVMap")
    for polygon in data.polygons:
        for loop in polygon.loop_indices:
            layer.data[loop].uv = uvs[data.loops[loop].vertex_index]
    smooth(obj)
    return obj


cone_root = bpy.data.objects.new("TrafficCone_removable", None)
model.objects.link(cone_root)
cone_root.parent = root
cone_root.empty_display_type = "CIRCLE"
cone_root.empty_display_size = .6
cone_root.rotation_euler = Euler((math.radians(-2.5), math.radians(14), math.radians(-2.0)), "XYZ")
cone_root.location = (-.015, .005, 2.35)
cone_root["part"] = "Removable hollow traffic cone; all cone parts parented here"
cone_root["sideways_tilt_degrees"] = 14.0
cone_root["nominal_shell_height_m"] = .88

N = 192
H = .88
R0 = .408
R1 = .105
THICKNESS = .012


def top_variation(theta):
    # An irregular open top with a shallow torn notch on the front-left edge.
    theta_notch = math.atan2(math.sin(theta + 2.1), math.cos(theta + 2.1))
    return .004 * math.sin(theta * 3 + .2) + .003 * math.sin(theta * 5) - .015 * math.exp(-(theta_notch / .23) ** 2)


def radial(t, theta):
    radius = R0 * (1 - t) + R1 * t + .005 * math.sin(math.pi * t)
    radius += .0025 * math.sin(theta * 3 + t * 2) * math.sin(math.pi * t)
    dent_angle = math.atan2(math.sin(theta - .65), math.cos(theta - .65))
    radius -= .015 * math.exp(-(dent_angle / .35) ** 2) * math.exp(-((t - .72) / .22) ** 2)
    radius += .0015 * math.sin(theta * 7 + t * 17) * (t ** 4)
    return radius


def shell_surface(name, inner):
    vertices, faces, uvs = [], [], []
    rows = 96
    for j in range(rows + 1):
        t = j / rows
        for i in range(N + 1):
            theta = 2 * math.pi * i / N
            radius = radial(t, theta) - (THICKNESS if inner else 0)
            z = .046 + t * H + top_variation(theta) * t ** 9
            vertices.append((radius * math.cos(theta), radius * math.sin(theta), z))
            uvs.append((i / N, t))
    for j in range(rows):
        for i in range(N):
            a = j * (N + 1) + i
            face = (a, a + 1, a + N + 2, a + N + 1)
            faces.append(tuple(reversed(face)) if inner else face)
    return mesh(name, vertices, faces, inner_material if inner else cone_material, uvs)


shell_surface("Cone_outer_shell_A", False)
shell_surface("Cone_inner_hollow_shell", True)

# Rounded annular lip around the open top: visible thickness, never a closed cap.
verts, faces, uv = [], [], []
for j in range(9):
    alpha = math.pi * j / 8
    for i in range(N + 1):
        theta = 2 * math.pi * i / N
        radius = radial(1, theta) - THICKNESS / 2 + THICKNESS / 2 * math.cos(alpha)
        z = .046 + H + top_variation(theta) + THICKNESS / 2 * math.sin(alpha)
        verts.append((radius * math.cos(theta), radius * math.sin(theta), z))
        uv.append((i / N, 1 - j * .002))
for j in range(8):
    for i in range(N):
        a = j * (N + 1) + i
        faces.append((a, a + 1, a + N + 2, a + N + 1))
mesh("Cone_open_top_rounded_broken_lip", verts, faces, cone_material, uv)


def rounded_square_radius(theta, extent=.49, corner=.20):
    x, y = abs(math.cos(theta)), abs(math.sin(theta))
    if x < 1e-7 or y < 1e-7:
        return extent
    t = extent / max(x, y)
    if min(x, y) * t <= extent - corner:
        return t
    center = extent - corner
    projection = center * (x + y)
    return projection + math.sqrt(max(0, projection * projection - (2 * center * center - corner * corner)))


# One continuous annular square base with rounded outside edges and an open center.
profile = [(.0, .006), (.0, .016), (.008, .032), (.025, .039), (.060, .042), (.16, .044), (.40, .045), (.72, .045), (1.0, .045), (1.0, .011), (.75, .009), (.40, .008), (.12, .007)]
vertices, faces, uvs = [], [], []
for j, (blend, z) in enumerate(profile):
    for i in range(N + 1):
        theta = i / N * 2 * math.pi
        outer = rounded_square_radius(theta)
        radius = outer * (1 - blend) + (R0 - THICKNESS) * blend
        if j == 0:
            radius -= .012
        if j == 1:
            radius -= .003
        # Low dents/chips mostly confined to the rounded flange perimeter.
        z += (1 - blend) * (.0015 * math.sin(theta * 11) + .0008 * math.sin(theta * 23))
        vertices.append((radius * math.cos(theta), radius * math.sin(theta), z))
        uvs.append((.5 + vertices[-1][0] / 1.10, .5 + vertices[-1][1] / 1.10))
for j in range(len(profile)):
    following = (j + 1) % len(profile)
    for i in range(N):
        a, b = j * (N + 1) + i, following * (N + 1) + i
        faces.append((a, a + 1, b + 1, b))
mesh("Cone_square_flange_rounded_open_base", vertices, faces, cone_material, uvs)


def molding_ring(name, t, height, bulge):
    # A slim shaped molding follows the real conical taper.
    vertices, faces, uvs = [], [], []
    for j in range(13):
        alpha = 2 * math.pi * j / 12
        tj = t + math.sin(alpha) * height / H
        for i in range(N + 1):
            theta = i / N * 2 * math.pi
            radius = radial(tj, theta) + .002 + math.cos(alpha) * bulge
            z = .046 + tj * H
            vertices.append((radius * math.cos(theta), radius * math.sin(theta), z))
            uvs.append((i / N, tj))
    for j in range(12):
        for i in range(N):
            a = j * (N + 1) + i
            faces.append((a, a + 1, a + N + 2, a + N + 1))
    return mesh(name, vertices, faces, cone_material, uvs)


molding_ring("Cone_lower_molded_collar", .062, .021, .010)
molding_ring("Cone_horizontal_molding_upper", .227, .005, .005)
molding_ring("Cone_horizontal_molding_lower", .207, .004, .004)

# Assign a coherent removable root before measuring the real fit to the skull.
cone_parts = []
for obj in model.objects:
    if obj.type == "MESH" and obj.name.startswith("Cone_"):
        obj.parent = cone_root
        cone_parts.append(obj)
bpy.context.view_layer.update()
head_points = [head.matrix_world @ vertex.co for vertex in head.data.vertices]
fit_error = 0
for _ in range(40):
    bpy.context.view_layer.update()
    inverse = cone_root.matrix_world.inverted()
    fit_error = 0
    for p in head_points:
        local = inverse @ p
        if local.z > .025:
            t = max(0, min(1, (local.z - .046) / H))
            allowed = R0 * (1 - t) + R1 * t - THICKNESS - .004
            fit_error = max(fit_error, math.hypot(local.x, local.y) - allowed)
    if fit_error <= .004:
        break
    cone_root.location.z += .005
cone_root["seated_base_height_m"] = cone_root.location.z
cone_root["maximum_skull_shell_penetration_m"] = max(0, fit_error)
print("Cone fit: base_z=%.3f, skull clearance error=%.4f" % (cone_root.location.z, fit_error), flush=True)

# A few small physical notches around the flange edge complement the texture.
for angle, width in [(-2.35, .018), (-1.02, .013), (.24, .015), (2.8, .013)]:
    radius = rounded_square_radius(angle) - .002
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1)
    cutter = bpy.context.object
    cutter.name = "Temporary_flange_edge_chip"
    cutter.parent = cone_root
    cutter.location = (radius * math.cos(angle), radius * math.sin(angle), .027)
    cutter.scale = (width, width, .008)
    flange = bpy.data.objects["Cone_square_flange_rounded_open_base"]
    boolean = flange.modifiers.new("Tiny worn flange notch", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.solver = "EXACT"
    boolean.object = cutter
    apply(flange, boolean)
    bpy.data.objects.remove(cutter, do_unlink=True)

for obj in model.objects:
    if obj.type == "MESH":
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000004)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        # Boolean chips can create n-gons; triangulate these before tangent export.
        bmesh.ops.triangulate(bm, faces=[face for face in bm.faces if len(face.verts) > 4], ngon_method="BEAUTY")
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.validate(verbose=False)
        obj.data.update()
        smooth(obj)

# Bake the fitted tilt into cone meshes, preserving the removable root while
# avoiding inflated world bounds from a rotated conical local bounding box.
tilt_matrix = cone_root.rotation_euler.to_matrix()
for obj in cone_parts:
    for vertex in obj.data.vertices:
        vertex.co = tilt_matrix @ vertex.co
    obj.data.update()
cone_root.rotation_euler = (0, 0, 0)

# A light warm-gray studio matches the A sheet and is never exported with GLB.
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1
scene.render.engine = "CYCLES"
scene.cycles.samples = 80
scene.cycles.use_denoising = True
scene.render.image_settings.file_format = "PNG"
scene.render.resolution_x = 1050
scene.render.resolution_y = 1400
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = -.2
scene.world.node_tree.nodes.get("Background").inputs["Color"].default_value = (.65, .67, .70, 1)
scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value = .28
for obj in studio.objects:
    if obj.type == "LIGHT":
        obj.hide_render = True


def area_light(name, location, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size, data.color = energy, size, color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, 1.6)) - obj.location).to_track_quat("-Z", "Y").to_euler()


area_light("A reference broad key", (-3, -4, 6), 650, 4.5, (1, .92, .83))
area_light("A reference frontal fill", (3, -4, 4), 280, 4, (.88, .93, 1))
area_light("A reference soft rim", (2, 3, 5), 400, 3.5, (1, .95, .88))
ground = next(obj for obj in studio.objects if obj.name.startswith("Preview_ground"))
ground.data.materials.clear()
ground.data.materials.append(solid_material("Preview_warm_gray_floor", (.64, .62, .59), .9))
camera = scene.camera
camera.data.type = "ORTHO"
camera.data.ortho_scale = 3.85


def set_camera(position, target=(.03, -.01, 1.73)):
    camera.location = position
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


set_camera((.25, -7, 2.4))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"
            area.spaces.active.shading.type = "MATERIAL"
            area.spaces.active.shading.use_scene_world = True
            area.spaces.active.shading.use_scene_lights = True
for image in bpy.data.images:
    if image.source == "FILE" or image.packed_file:
        image.pack()
activate(root)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "conehead_zombie.blend"), compress=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in model.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
# Stage under .gdignore, then atomically replace. A live editor may memory-map
# the old GLB, so truncating that file in place is unsafe on Windows.
pending_export = SOURCE / "conehead_export.pending.glb"
bpy.ops.export_scene.gltf(filepath=str(pending_export), export_format="GLB", use_selection=True, export_yup=True, export_apply=True, export_texcoords=True, export_normals=True, export_tangents=True, export_materials="EXPORT", export_animations=False, export_cameras=False, export_lights=False)
for export_attempt in range(20):
    try:
        os.replace(pending_export, ROOT / "conehead_zombie.glb")
        break
    except OSError:
        if export_attempt == 19:
            raise
        time.sleep(.25)
bpy.context.view_layer.update()
mesh_objects = [obj for obj in model.objects if obj.type == "MESH"]
bounds = [obj.matrix_world @ Vector(corner) for obj in mesh_objects for corner in obj.bound_box]
minimum = [min(p[i] for p in bounds) for i in range(3)]
maximum = [max(p[i] for p in bounds) for i in range(3)]
head_corners = [head.matrix_world @ Vector(corner) for corner in head.bound_box]
head_dims = [max(p[i] for p in head_corners) - min(p[i] for p in head_corners) for i in range(3)]
manifest = {
    "asset": "conehead_zombie", "approved_reference": "source/reference_A_approved.png",
    "authoring_tool": bpy.app.version_string, "mesh_objects": len(mesh_objects),
    "vertices": sum(len(obj.data.vertices) for obj in mesh_objects),
    "triangles": sum(sum(len(face.vertices) - 2 for face in obj.data.polygons) for obj in mesh_objects),
    "materials": len({slot.material.name for obj in mesh_objects for slot in obj.material_slots if slot.material}),
    "bounds_blender_z_up_m": {"min": minimum, "max": maximum},
    "dimensions_m": [maximum[i] - minimum[i] for i in range(3)],
    "head_dimensions_blender_xyz_m": head_dims,
    "head_depth_to_width_ratio": head_dims[1] / head_dims[0],
    "cone": {"parts": [obj.name for obj in cone_parts], "tilt_degrees": 14, "shell_height_m": H, "wall_thickness_m": THICKNESS, "base_width_m": .98, "seated_base_height_m": cone_root.location.z, "skull_clearance_error_m": max(0, fit_error), "open_top": True, "hollow_shell": True, "removable_parent": cone_root.name, "texture_size_px": 2048},
    "removed_covered_hairs": removed_hairs,
    "shin_skin_srgb": [.405, .49, .425],
    "base_source_sha256": BASE_SHA256,
    "pose": "static reference pose, no armature or animations",
    "textures": "embedded GLB, packed BLEND, independent source PNGs",
    "game_integration": "none"
}
(ROOT / "model_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(manifest, ensure_ascii=False), flush=True)
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "OPTIX"
    prefs.get_devices()
    for device in prefs.devices:
        device.use = device.type != "CPU"
    if any(device.type != "CPU" for device in prefs.devices):
        scene.cycles.device = "GPU"
except Exception as error:
    print("CPU render fallback: " + str(error), flush=True)
if "--skip-render" not in sys.argv:
    for name, position in [("front", (.25, -7, 2.4)), ("three_quarter", (4.3, -6, 2.5)), ("back", (3.4, 6, 2.5))]:
        set_camera(position)
        scene.render.filepath = str(PREVIEWS / (name + ".png"))
        print("RENDERING " + name, flush=True)
        bpy.ops.render.render(write_still=True)
print("CONEHEAD ASSET COMPLETE: " + str(ROOT), flush=True)
