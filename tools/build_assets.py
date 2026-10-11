"""Author the original meshes and editable Godot scenes. No third-party packages."""
from pathlib import Path
import argparse
import math
import re
from config_values import read_config, entity_stats

ROOT = Path(__file__).resolve().parents[1]
CONFIG = read_config()


def obj_mesh(path, vertices, faces):
    normals = [[0.0, 0.0, 0.0] for _ in vertices]
    triangles = []
    for face in faces:
        for j in range(1, len(face) - 1):
            tri = (face[0], face[j], face[j + 1])
            triangles.append(tri)
            a, b, c = (vertices[i] for i in tri)
            u = [b[k] - a[k] for k in range(3)]
            v = [c[k] - a[k] for k in range(3)]
            n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            for i in tri:
                for k in range(3):
                    normals[i][k] += n[k]
    lines = ["# Original procedural mesh for PVZ 3D", "o " + path.stem]
    lines.extend("v %.6f %.6f %.6f" % v for v in vertices)
    for n in normals:
        length = math.sqrt(sum(a * a for a in n)) or 1.0
        lines.append("vn %.6f %.6f %.6f" % tuple(a / length for a in n))
    lines.append("s 1")
    lines.extend("f " + " ".join(f"{i + 1}//{i + 1}" for i in tri) for tri in triangles)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def leaf_mesh():
    vertices, faces = [], []
    steps, across = 18, 8
    for side in (1, -1):
        for i in range(steps + 1):
            u = i / steps
            width = 0.25 * math.sin(math.pi * u) ** 0.9 + 0.002
            for j in range(across + 1):
                v = j / across * 2 - 1
                ridge = 0.08 * math.sin(math.pi * u) * (1 - v * v)
                y = 0.085 * u * u + ridge + side * 0.013 * math.sin(math.pi * u)
                vertices.append((u * 0.79, y, v * width))
    layer = (steps + 1) * (across + 1)
    for side in range(2):
        for i in range(steps):
            for j in range(across):
                a = side * layer + i * (across + 1) + j
                face = (a, a + 1, a + across + 2, a + across + 1)
                faces.append(face if side == 0 else tuple(reversed(face)))
    for i in range(steps):
        a, b = i * (across + 1), (i + 1) * (across + 1)
        faces.append((a, b, b + layer, a + layer))
        a, b = a + across, b + across
        faces.append((a + layer, b + layer, b, a))
    for j in range(across):
        faces.append((j + layer, j + layer + 1, j + 1, j))
        a = steps * (across + 1) + j
        faces.append((a, a + 1, a + layer + 1, a + layer))
    obj_mesh(ROOT / "assets/meshes/leaf.obj", vertices, faces)


def rounded_tile(name, half, bottom, top, radius, bevel):
    vertices, faces = [], []
    segments = 10
    for h, y in ((half - bevel, bottom), (half, bottom + bevel), (half, top - bevel), (half - bevel, top)):
        r = radius
        for cx, cz, start in ((h - r, h - r, 0), (-h + r, h - r, 90), (-h + r, -h + r, 180), (h - r, -h + r, 270)):
            for step in range(segments + 1):
                angle = math.radians(start + step * 90 / segments)
                vertices.append((cx + r * math.cos(angle), y, cz + r * math.sin(angle)))
    count = 4 * (segments + 1)
    for layer in range(3):
        for i in range(count):
            j = (i + 1) % count
            a, b = layer * count + i, layer * count + j
            faces.append((a, a + count, b + count, b))
    vertices.extend(((0, bottom, 0), (0, top, 0)))
    for i in range(count):
        j = (i + 1) % count
        faces.append((4 * count, i, j))
        faces.append((4 * count + 1, 3 * count + j, 3 * count + i))
    obj_mesh(ROOT / f"assets/meshes/{name}.obj", vertices, faces)


def grass_mesh():
    vertices, faces = [], []
    for angle, height, lean in ((0, 0.17, 0.055), (2.1, 0.13, 0.06), (4.2, 0.11, 0.048)):
        tangent = (math.cos(angle), math.sin(angle))
        side = (-tangent[1], tangent[0])
        base = len(vertices)
        vertices.extend(((-side[0] * 0.023, 0, -side[1] * 0.023), (side[0] * 0.023, 0, side[1] * 0.023), (tangent[0] * lean, height, tangent[1] * lean)))
        faces.append((base, base + 1, base + 2))
    obj_mesh(ROOT / "assets/meshes/grass.obj", vertices, faces)


class Scene:
    def __init__(self):
        self.external, self.resources, self.nodes = [], [], []

    def ext(self, kind, path, name):
        self.external.append(f'[ext_resource type="{kind}" path="res://{path}" id="{name}"]')
        return f'ExtResource("{name}")'

    def res(self, kind, name, properties):
        self.resources.append(f'[sub_resource type="{kind}" id="{name}"]\n{properties}')
        return f'SubResource("{name}")'

    def material(self, name, color, roughness=0.7, extra=""):
        rgb = tuple(int(color[i:i + 2], 16) / 255 for i in (0, 2, 4))
        return self.res("StandardMaterial3D", name, f'albedo_color = Color({rgb[0]:.5f}, {rgb[1]:.5f}, {rgb[2]:.5f}, 1)\nroughness = {roughness}\n{extra}')

    def node(self, name, kind=None, parent=None, properties="", instance=None):
        attrs = [f'name="{name}"']
        if kind:
            attrs.append(f'type="{kind}"')
        if parent is not None:
            attrs.append(f'parent="{parent}"')
        if instance:
            attrs.append(f'instance={instance}')
        self.nodes.append('[node ' + ' '.join(attrs) + ']\n' + properties)

    def mesh(self, name, parent, mesh, material, pos=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), layers=1):
        self.node(name, "MeshInstance3D", parent, f'position = Vector3{pos}\nrotation = Vector3{rot}\nscale = Vector3{scale}\nlayers = {layers}\nmesh = {mesh}\nmaterial_override = {material}')

    def save(self, path):
        # Preview authored combat/layout values from the same startup snapshot.
        # Geometry remains the baseline: runtime config applies model dimensions
        # before animation setup, so regeneration is unnecessary and cannot double scale.
        key = Path(path).stem
        stats = entity_stats(CONFIG, key)
        for index, node in enumerate(self.nodes):
            if 'parent=' not in node.split('\n', 1)[0]:
                for field, value in stats.items():
                    if field in {"movement_bounds", "derive_bounds_from_lawn", "boundary_inset", "frost_color"}:
                        continue
                    if field in {"maximum_recoil_degrees", "idle_bend_degrees", "idle_bend_speed", "leaf_sway_degrees", "leaf_sway_speed", "target_lane_tolerance", "flash_duration", "recoil_degrees", "recoil_recovery_time", "armor_drop_health", "hand_drop_health", "walk_animation_speed", "walk_bob_height", "leg_swing_degrees", "frost_color_strength", "pole_length", "pole_radius", "pole_release_fraction", "planted_tip_offset", "vault_lean_degrees", "flight_leg_degrees", "prepare_time", "pitch_limit_degrees"}:
                        # These members are script defaults/configuration; scene inheritance
                        # may not expose them until the editor imports the changed script.
                        continue
                    literal = str(value).lower() if isinstance(value, bool) else str(value)
                    node = re.sub(r'^' + re.escape(field) + r' = .*\n?', '', node, flags=re.M)
                    node += f'\n{field} = {literal}\n'
                self.nodes[index] = node
            if key == "main":
                match = re.search(r'instance=ExtResource\("([^"]+)"\)', node)
                if match:
                    ext = next((e for e in self.external if f'id="{match[1]}"' in e), '')
                    scene = re.search(r'path="res://([^\"]+)"', ext)
                    entity = Path(scene[1]).stem if scene else ''
                    if entity in CONFIG['placements']:
                        place, lawn = CONFIG['placements'][entity], CONFIG['lawn']
                        position = ((place['column']-1-(lawn['columns']-1)/2)*lawn['cell_size'], lawn['surface_height'], (place['row']-1-(lawn['rows']-1)/2)*lawn['cell_size'])
                        node = re.sub(r'^(position|rotation) = .*\n?', '', node, flags=re.M)
                        node += f'\nposition = Vector3{position}\nrotation = Vector3(0, {math.radians(place["yaw_degrees"])}, 0)\n'
                        self.nodes[index] = node
        path = ROOT / path
        path.parent.mkdir(parents=True, exist_ok=True)
        count = len(self.external) + len(self.resources) + 1
        path.write_text(f'[gd_scene load_steps={count} format=3]\n\n' + '\n\n'.join(self.external + self.resources + self.nodes) + '\n', encoding="utf-8")


def plant_scene():
    s = Scene()
    script = s.ext("Script", "scripts/peashooter.gd", "plant_script")
    leaf = s.ext("ArrayMesh", "assets/meshes/leaf.obj", "leaf_mesh")
    head_color = s.material("HeadGreen", "80c951", 0.58)
    lip_color = s.material("LipGreen", "91d661", 0.57)
    stem_color = s.material("StemGreen", "4a9d42", 0.8)
    leaf_dark = s.material("LeafGreen", "57aa46", 0.76)
    leaf_light = s.material("LeafLight", "77be50", 0.76)
    inside = s.material("MuzzleInterior", "254d24", 0.9, "cull_mode = 2")
    eye = s.material("EyeDark", "172e21", 0.23)
    glint = s.material("EyeGlint", "f9ffe8", 0.2)
    sphere = s.res("SphereMesh", "SmoothSphere", "radius = 0.5\nheight = 1.0\nradial_segments = 48\nrings = 24")
    stem_lower = s.res("CylinderMesh", "LowerStem", "top_radius = 0.072\nbottom_radius = 0.095\nheight = 0.61\nradial_segments = 24")
    stem_upper = s.res("CylinderMesh", "UpperStem", "top_radius = 0.105\nbottom_radius = 0.072\nheight = 0.5\nradial_segments = 24")
    tube = s.res("CylinderMesh", "HollowOuterTube", "top_radius = 0.232\nbottom_radius = 0.165\nheight = 0.41\nradial_segments = 48\ncap_top = false\ncap_bottom = false")
    cavity = s.res("CylinderMesh", "InnerCavity", "top_radius = 0.185\nbottom_radius = 0.145\nheight = 0.17\nradial_segments = 48\ncap_top = false\ncap_bottom = true")
    rim = s.res("TorusMesh", "MuzzleLip", "inner_radius = 0.181\nouter_radius = 0.258\nrings = 48\nring_segments = 16")

    s.node("Peashooter", "Node3D", properties=f'script = {script}')
    s.node("Stem", "Node3D", ".")
    s.mesh("Root", "Stem", sphere, stem_color, (0, 0.12, 0), (0.29, 0.25, 0.29))
    s.mesh("Lower", "Stem", stem_lower, stem_color, (0.025, 0.415, 0), rot=(0, 0, -0.09))
    s.mesh("Upper", "Stem", stem_upper, stem_color, (0.03, 0.91, 0), rot=(0, 0, 0.095))
    s.node("Leaves", "Node3D", ".", "position = Vector3(0, 0.105, 0)")
    for i, (angle, size, color) in enumerate(((0.25, 1.0, leaf_light), (1.95, 0.94, leaf_dark), (3.4, 1.04, leaf_dark), (5.15, 1.1, leaf_light))):
        s.mesh(f"Leaf{i + 1}", "Leaves", leaf, color, scale=(size, size, size), rot=(0, angle, 0))
    s.node("Head", "Node3D", ".", "position = Vector3(0.03, 1.225, 0)")
    s.mesh("HeadBody", "Head", sphere, head_color, scale=(1.04, 0.87, 0.87))
    s.mesh("BackBud", "Head", sphere, head_color, (-0.43, -0.1, 0), (0.24, 0.3, 0.33), (0, 0, -0.35))
    s.node("Muzzle", "Node3D", "Head", "position = Vector3(0, -0.03, 0)")
    s.mesh("OuterTube", "Head/Muzzle", tube, head_color, (0.545, 0, 0), rot=(0, 0, -math.pi / 2))
    s.mesh("InnerCavity", "Head/Muzzle", cavity, inside, (0.66, 0, 0), rot=(0, 0, -math.pi / 2))
    s.mesh("Lip", "Head/Muzzle", rim, lip_color, (0.756, 0, 0), rot=(0, 0, -math.pi / 2))
    s.node("MuzzleTip", "Marker3D", "Head/Muzzle", "position = Vector3(0.81, 0, 0)")
    s.node("Eyes", "Node3D", "Head")
    for name, sign in (("Near", 1), ("Far", -1)):
        s.mesh(name + "Eye", "Head/Eyes", sphere, eye, (0.025, 0.14, 0.405 * sign), (0.145, 0.215, 0.058), (-0.18 * sign, 0, 0))
        s.mesh(name + "Highlight", "Head/Eyes", sphere, glint, (0.012, 0.183, 0.435 * sign), (0.038, 0.052, 0.021))
    s.save("scenes/plants/peashooter.tscn")


def repeater_scene():
    s = Scene()
    base = s.ext("PackedScene", "scenes/plants/peashooter.tscn", "base_plant")
    script = s.ext("Script", "scripts/repeater.gd", "repeater_script")
    leaf = s.ext("ArrayMesh", "assets/meshes/leaf.obj", "leaf_mesh")
    head_color = s.material("RepeaterGreen", "60b343", 0.58)
    lip_color = s.material("RepeaterLip", "7bc84e", 0.57)
    leaf_dark = s.material("RepeaterLeaves", "449939", 0.76)
    leaf_light = s.material("RepeaterLeafLight", "61b444", 0.76)
    brow_color = s.material("BrowGreen", "337d32", 0.7)
    sphere = s.res("SphereMesh", "BrowShape", "radius = 0.5\nheight = 1.0\nradial_segments = 32\nrings = 16")

    s.node("Repeater", instance=base, properties=f'script = {script}')
    s.node("Head", parent=".", properties="scale = Vector3(1.06, 1.04, 1.04)")
    for path in ("Head/HeadBody", "Head/BackBud", "Head/Muzzle/OuterTube"):
        parent, name = path.rsplit("/", 1)
        s.node(name, parent=parent, properties=f'material_override = {head_color}')
    s.node("Lip", parent="Head/Muzzle", properties=f'material_override = {lip_color}')
    for i in range(4):
        color = leaf_light if i in (0, 3) else leaf_dark
        s.node(f"Leaf{i + 1}", parent="Leaves", properties=f'material_override = {color}')
    for name, sign in (("Near", 1), ("Far", -1)):
        s.mesh(name + "Brow", "Head/Eyes", sphere, brow_color,
               (0.065, 0.25, sign * 0.422), (0.25, 0.07, 0.08), (0, 0, -0.28))
    s.node("Crest", "Node3D", "Head")
    for i, (z, yaw, tilt, size) in enumerate(((-0.15, -0.35, 2.20, 0.65), (0, 0, 2.05, 0.76), (0.15, 0.35, 2.20, 0.65))):
        s.mesh(f"Leaf{i + 1}", "Head/Crest", leaf, leaf_dark,
               (-0.39, 0.22, z), (size, size, size), (0, yaw, tilt))
    s.save("scenes/plants/repeater.tscn")


def snow_pea_scene():
    s = Scene()
    base = s.ext("PackedScene", "scenes/plants/peashooter.tscn", "base_plant")
    script = s.ext("Script", "scripts/snow_pea.gd", "snow_script")
    blue = s.material("SnowBlue", "7fcbee", 0.42)
    lip = s.material("SnowLip", "b9eff8", 0.34)
    stalk = s.material("SnowStem", "5ca8bd", 0.75)
    leaf_dark = s.material("SnowLeaves", "72c9d9", 0.62)
    leaf_light = s.material("SnowLeafLight", "a6e5ec", 0.58)
    cavity = s.material("SnowInterior", "285775", 0.85, "cull_mode = 2")
    eyes = s.material("SnowEyes", "1c4664", 0.23)
    ice = s.material("IceCrystal", "b8effa", 0.25, "emission_enabled = true\nemission = Color(0.30, 0.65, 0.85, 1)\nemission_energy_multiplier = 0.12")
    crystal = s.res("CylinderMesh", "CrystalShape", "top_radius = 0\nbottom_radius = 0.08\nheight = 0.30\nradial_segments = 5")

    s.node("SnowPea", instance=base, properties=f'script = {script}')
    for path in ("Head/HeadBody", "Head/BackBud", "Head/Muzzle/OuterTube"):
        parent, name = path.rsplit("/", 1)
        s.node(name, parent=parent, properties=f'material_override = {blue}')
    s.node("Lip", parent="Head/Muzzle", properties=f'material_override = {lip}')
    s.node("InnerCavity", parent="Head/Muzzle", properties=f'material_override = {cavity}')
    for name in ("Root", "Lower", "Upper"):
        s.node(name, parent="Stem", properties=f'material_override = {stalk}')
    for i in range(4):
        s.node(f"Leaf{i + 1}", parent="Leaves", properties=f'material_override = {leaf_light if i in (0, 3) else leaf_dark}')
    for name in ("NearEye", "FarEye"):
        s.node(name, parent="Head/Eyes", properties=f'material_override = {eyes}')
    s.node("IceCrest", "Node3D", "Head")
    for i, (z, size, tilt) in enumerate(((-0.18, 0.85, 0.85), (0, 1.25, 0.65), (0.18, 0.85, 0.85))):
        s.mesh(f"Crystal{i + 1}", "Head/IceCrest", crystal, ice, (-0.32, 0.25, z),
               (size, size, size), (0, z * 1.5, tilt))
    s.save("scenes/plants/snow_pea.tscn")

    p = Scene()
    pea = p.ext("PackedScene", "scenes/projectiles/pea.tscn", "base_pea")
    icy_blue = p.material("IcePeaBlue", "91dbfa", 0.18,
                          "emission_enabled = true\nemission = Color(0.25, 0.55, 0.75, 1)\nemission_energy_multiplier = 0.10")
    p.node("SnowPeaProjectile", instance=pea, properties="slow_multiplier = 0.5\nslow_duration = 10.0")
    p.node("Mesh", parent=".", properties=f'material_override = {icy_blue}')
    p.save("scenes/projectiles/snow_pea.tscn")


def gatling_pea_scene():
    s = Scene()
    base = s.ext("PackedScene", "scenes/plants/peashooter.tscn", "base_plant")
    script = s.ext("Script", "scripts/gatling_pea.gd", "gatling_script")
    green = s.material("GatlingGreen", "65ad43", 0.58)
    leaf_dark = s.material("GatlingLeaves", "43923a", 0.76)
    leaf_light = s.material("GatlingLeafLight", "69b74a", 0.76)
    helmet_color = s.material("HelmetOlive", "557746", 0.74)
    helmet_rim_color = s.material("HelmetRimOlive", "384f2f", 0.8)
    hardware = s.material("HelmetHardware", "c4bd78", 0.52, "metallic = 0.15")
    gun_color = s.material("BarrelGreen", "3a682f", 0.65)
    gun_rim_color = s.material("BarrelLipGreen", "86bc59", 0.55)
    inside = s.material("BarrelInterior", "1b301a", 0.95, "cull_mode = 2")
    brow_color = s.material("BrowGreen", "2e6d2c", 0.7)
    sphere = s.res("SphereMesh", "SmoothSphere", "radius = 0.5\nheight = 1.0\nradial_segments = 32\nrings = 16")
    helmet = s.res("SphereMesh", "HelmetDome", "radius = 0.5\nheight = 1.0\nis_hemisphere = true\nradial_segments = 48\nrings = 24")
    brim = s.res("TorusMesh", "HelmetBrim", "inner_radius = 0.47\nouter_radius = 0.59\nrings = 48\nring_segments = 16")
    tube = s.res("CylinderMesh", "BarrelTube", "top_radius = 0.128\nbottom_radius = 0.128\nheight = 0.60\nradial_segments = 32\ncap_top = false\ncap_bottom = false")
    cavity = s.res("CylinderMesh", "BarrelCavity", "top_radius = 0.106\nbottom_radius = 0.106\nheight = 0.16\nradial_segments = 32\ncap_top = false\ncap_bottom = true")
    lip = s.res("TorusMesh", "BarrelLip", "inner_radius = 0.105\nouter_radius = 0.143\nrings = 32\nring_segments = 12")
    collar = s.res("CylinderMesh", "GunCollar", "top_radius = 0.34\nbottom_radius = 0.32\nheight = 0.16\nradial_segments = 48\ncap_top = false\ncap_bottom = false")
    band = s.res("TorusMesh", "BarrelBand", "inner_radius = 0.292\nouter_radius = 0.331\nrings = 48\nring_segments = 12")

    s.node("GatlingPea", instance=base, properties=f'script = {script}')
    s.node("Head", parent=".", properties="scale = Vector3(1.03, 1.02, 1.02)")
    for name in ("HeadBody", "BackBud"):
        s.node(name, parent="Head", properties=f'material_override = {green}')
    for name in ("OuterTube", "InnerCavity", "Lip"):
        s.node(name, parent="Head/Muzzle", properties="visible = false")
    s.node("MuzzleTip", parent="Head/Muzzle", properties="position = Vector3(0.96, 0, 0)")
    for i in range(4):
        s.node(f"Leaf{i + 1}", parent="Leaves", properties=f'material_override = {leaf_light if i in (0, 3) else leaf_dark}')
    for name, sign in (("Near", 1), ("Far", -1)):
        s.mesh(name + "Brow", "Head/Eyes", sphere, brow_color,
               (0.065, 0.25, sign * 0.422), (0.25, 0.07, 0.08), (0, 0, -0.28))

    s.node("Helmet", "Node3D", "Head")
    s.mesh("Dome", "Head/Helmet", helmet, helmet_color, (0, 0.25, 0), (1.13, 0.32, 1.10))
    s.mesh("Brim", "Head/Helmet", brim, helmet_rim_color, (0, 0.26, 0), (1.03, 0.8, 1.0))
    for name, sign in (("Near", 1), ("Far", -1)):
        s.mesh(name + "Strap", "Head/Helmet", sphere, helmet_rim_color,
               (-0.13, 0.05, sign * 0.424), (0.065, 0.44, 0.035))
        s.mesh(name + "Rivet", "Head/Helmet", sphere, hardware,
               (-0.13, 0.25, sign * 0.555), (0.065, 0.065, 0.025))
    s.mesh("RearCollar", "Head/Muzzle", collar, gun_color, (0.32, 0, 0), rot=(0, 0, -math.pi / 2))
    s.node("BarrelRotor", "Node3D", "Head/Muzzle", "position = Vector3(0.60, 0, 0)")
    for i, (y, z) in enumerate(((0.13, 0.13), (-0.13, 0.13), (-0.13, -0.13), (0.13, -0.13))):
        path = f"Head/Muzzle/BarrelRotor/Barrel{i + 1}"
        s.node(f"Barrel{i + 1}", "Node3D", "Head/Muzzle/BarrelRotor", f"position = Vector3(0, {y}, {z})")
        s.mesh("Tube", path, tube, gun_color, rot=(0, 0, -math.pi / 2))
        s.mesh("Cavity", path, cavity, inside, (0.232, 0, 0), rot=(0, 0, -math.pi / 2))
        s.mesh("Lip", path, lip, gun_rim_color, (0.315, 0, 0), rot=(0, 0, -math.pi / 2))
        s.node("MuzzleTip", "Marker3D", path, "position = Vector3(0.36, 0, 0)")
    for name, x in (("RearBand", -0.12), ("FrontBand", 0.24)):
        s.mesh(name, "Head/Muzzle/BarrelRotor", band, helmet_rim_color, (x, 0, 0), rot=(0, 0, -math.pi / 2))
    s.save("scenes/plants/gatling_pea.tscn")


def threepeater_scene():
    s = Scene()
    head_height = 1.34
    side_head_drop = 0.32
    side_head_spread = 0.64
    script = s.ext("Script", "scripts/threepeater.gd", "threepeater_script")
    leaf = s.ext("ArrayMesh", "assets/meshes/leaf.obj", "leaf_mesh")
    green = s.material("ThreepeaterGreen", "72be48", 0.58)
    lip = s.material("ThreepeaterLip", "97d966", 0.57)
    stem = s.material("StemGreen", "41963b", 0.8)
    leaf_dark = s.material("LeafGreen", "4ca23e", 0.76)
    leaf_light = s.material("LeafLight", "79c450", 0.76)
    inside = s.material("MuzzleInterior", "254d24", 0.9, "cull_mode = 2")
    eye = s.material("EyeDark", "172e21", 0.23)
    glint = s.material("EyeGlint", "f9ffe8", 0.2)
    sphere = s.res("SphereMesh", "SmoothSphere", "radius = 0.5\nheight = 1.0\nradial_segments = 48\nrings = 24")
    stalk = s.res("CylinderMesh", "Stalk", "top_radius = 0.085\nbottom_radius = 0.105\nheight = 1.0\nradial_segments = 24")
    branch = s.res("CylinderMesh", "Branch", "top_radius = 0.073\nbottom_radius = 0.086\nheight = 1.0\nradial_segments = 24")
    tube = s.res("CylinderMesh", "HollowOuterTube", "top_radius = 0.232\nbottom_radius = 0.165\nheight = 0.41\nradial_segments = 48\ncap_top = false\ncap_bottom = false")
    cavity = s.res("CylinderMesh", "InnerCavity", "top_radius = 0.185\nbottom_radius = 0.145\nheight = 0.17\nradial_segments = 48\ncap_top = false\ncap_bottom = true")
    rim = s.res("TorusMesh", "MuzzleLip", "inner_radius = 0.181\nouter_radius = 0.258\nrings = 48\nring_segments = 16")

    s.node("Threepeater", "Node3D", properties=f'script = {script}')
    s.node("Stem", "Node3D", ".")
    s.mesh("Root", "Stem", sphere, stem, (0, 0.12, 0), (0.34, 0.25, 0.34))
    s.mesh("MainStalk", "Stem", stalk, stem, (0, 0.71, 0), (1, 1.16, 1))
    for name, sign in (("Left", -1), ("Right", 1)):
        start, end = (0, 0.57, 0), (-0.11, head_height - side_head_drop - 0.02, sign * side_head_spread)
        dx, dy, dz = (end[i] - start[i] for i in range(3))
        length = math.sqrt(dx * dx + dy * dy + dz * dz)
        rotation = (math.atan2(dz, dy), 0, -math.atan2(dx, math.hypot(dy, dz)))
        midpoint = tuple((start[i] + end[i]) * 0.5 for i in range(3))
        s.mesh(name + "Branch", "Stem", branch, stem, midpoint, (1, length, 1), rotation)
        s.mesh(name + "StemLeaf", "Stem", leaf, leaf_dark, (-0.02, 0.60, sign * 0.20),
               (0.50, 0.50, 0.50), (0, -sign * math.pi / 2, 0.30))
    s.node("Leaves", "Node3D", ".", "position = Vector3(0, 0.105, 0)")
    for i in range(6):
        size = 1.02 if i % 2 else 1.12
        s.mesh(f"Leaf{i + 1}", "Leaves", leaf, leaf_light if i % 2 else leaf_dark,
               scale=(size, size, size), rot=(0, 0.20 + i * math.pi / 3, 0))
    s.node("Head", "Node3D", ".", f"position = Vector3(0, {head_height}, 0)")

    def head_parts(parent, size=1.0):
        def part(name, mesh, material, pos=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), path=None):
            s.mesh(name, path or parent, mesh, material,
                   tuple(v * size for v in pos), tuple(v * size for v in scale), rot)
        part("HeadBody", sphere, green, scale=(1.04, 0.87, 0.87))
        part("BackBud", sphere, green, (-0.43, -0.1, 0), (0.24, 0.3, 0.33), (0, 0, -0.35))
        muzzle = parent + "/Muzzle"
        s.node("Muzzle", "Node3D", parent, f"position = Vector3(0, {-0.03 * size}, 0)")
        part("OuterTube", tube, green, (0.545, 0, 0), rot=(0, 0, -math.pi / 2), path=muzzle)
        part("InnerCavity", cavity, inside, (0.66, 0, 0), rot=(0, 0, -math.pi / 2), path=muzzle)
        part("Lip", rim, lip, (0.756, 0, 0), rot=(0, 0, -math.pi / 2), path=muzzle)
        s.node("MuzzleTip", "Marker3D", muzzle, f"position = Vector3({0.81 * size}, 0, 0)")
        eyes = parent + "/Eyes"
        s.node("Eyes", "Node3D", parent)
        for name, sign in (("Near", 1), ("Far", -1)):
            part(name + "Eye", sphere, eye, (0.025, 0.14, sign * 0.405),
                 (0.145, 0.215, 0.058), (-sign * 0.18, 0, 0), path=eyes)
            part(name + "Highlight", sphere, glint, (0.012, 0.183, sign * 0.435),
                 (0.038, 0.052, 0.021), path=eyes)
        part("CrownLeaf", leaf, leaf_light, (-0.34, 0.24, 0), (0.42, 0.42, 0.42), (0, 0, 2.0))

    head_parts("Head", 0.72)
    for name, sign in (("Left", -1), ("Right", 1)):
        s.node(name + "Head", "Node3D", "Head",
               f"position = Vector3(-0.11, {-side_head_drop}, {sign * side_head_spread})\nrotation = Vector3(0, {-sign * 0.36}, 0)\nscale = Vector3(0.66, 0.66, 0.66)")
        head_parts("Head/" + name + "Head")
    s.save("scenes/plants/threepeater.tscn")


def grass_tile_scene():
    s = Scene()
    script = s.ext("Script", "scripts/grass_tile.gd", "tile_script")
    soil = s.ext("ArrayMesh", "assets/meshes/soil_tile.obj", "soil_mesh")
    turf = s.ext("ArrayMesh", "assets/meshes/grass_tile.obj", "turf_mesh")
    grass = s.ext("ArrayMesh", "assets/meshes/grass.obj", "grass_mesh")
    turf_color = s.ext("Material", "assets/materials/turf_light.tres", "turf_material")
    soil_color = s.material("WarmSoil", "9e7650", 1)
    grass_color = s.material("GrassBlades", "639443", 0.9, "cull_mode = 2")
    rock_color = s.material("Pebble", "c9b38a", 1)
    rock = s.res("SphereMesh", "PebbleShape", "radius = 0.5\nheight = 1.0\nradial_segments = 12\nrings = 6")
    collision = s.res("BoxShape3D", "TileCollision", "size = Vector3(2.36, 0.435, 2.36)")

    s.node("GrassTile", "Node3D", properties=f'script = {script}')
    s.mesh("Soil", ".", soil, soil_color)
    s.mesh("Turf", ".", turf, turf_color)
    s.node("GrassTufts", "Node3D", ".")
    points = ((-0.84, -0.88), (-0.35, -0.96), (0.53, -0.88), (0.88, -0.55), (0.96, 0.10), (0.87, 0.74), (0.36, 0.95), (-0.26, 0.94), (-0.88, 0.66), (-0.98, 0.12), (-0.72, -0.45), (0.73, 0.44), (-0.48, 0.71), (0.22, -0.73))
    for i, (x, z) in enumerate(points):
        size = 0.65 + (i % 4) * 0.15
        s.mesh(f"Tuft{i + 1:02}", "GrassTufts", grass, grass_color, (x, 0.02, z), (size, size, size), (0, i * 1.7, 0))
    for i, (x, z, size) in enumerate(((-0.86, 0.85, 0.14), (-0.72, 0.91, 0.085), (0.92, -0.85, 0.12))):
        s.mesh(f"Pebble{i + 1}", ".", rock, rock_color, (x, 0.036, z), (size, size * 0.55, size * 0.85))
    s.node("GroundBody", "StaticBody3D", ".")
    s.node("CollisionShape3D", "CollisionShape3D", "GroundBody", f'position = Vector3(0, -0.1925, 0)\nshape = {collision}')
    s.save("scenes/terrain/grass_tile.tscn")


def lawn_grid_scene():
    s = Scene()
    script = s.ext("Script", "scripts/lawn_grid.gd", "grid_script")
    tile = s.ext("PackedScene", "scenes/terrain/grass_tile.tscn", "tile_scene")
    s.node("LawnGrid", "Node3D", properties=f'script = {script}')
    s.node("Tiles", "Node3D", ".")
    lawn = CONFIG["lawn"]
    for row in range(int(lawn["rows"])):
        for column in range(int(lawn["columns"])):
            x, z = round((column - (lawn["columns"] - 1) / 2) * lawn["cell_size"], 4), round((row - (lawn["rows"] - 1) / 2) * lawn["cell_size"], 4)
            shade = "true" if (row + column) % 2 else "false"
            s.node(f"Tile_R{row + 1}_C{column + 1}", parent="Tiles", instance=tile,
                   properties=f'position = Vector3({x}, 0, {z})\ngrid_coordinates = Vector2i({column}, {row})\nalternate_shade = {shade}')
    s.save("scenes/terrain/lawn_grid.tscn")


def dave_scene():
    s = Scene()
    script = s.ext("Script", "scripts/crazy_dave.gd", "dave_script")
    skin = s.material("Skin", "edb68a", 0.85)
    shirt = s.material("WhiteShirt", "f4f0df", 0.95)
    collar = s.material("ShirtCollar", "d5d9cd", 0.95)
    denim = s.material("BlueJeans", "4d79a1", 0.92)
    shoes = s.material("BrownShoes", "594735", 0.95)
    beard = s.material("ChestnutHair", "734728", 0.95)
    moustache = s.material("Moustache", "593921", 0.95)
    white = s.material("EyeWhite", "fffbea", 0.6)
    dark = s.material("Pupils", "242820", 0.4)
    mouth = s.material("Mouth", "38271d", 0.95)
    metal = s.material("PotMetal", "879fa3", 0.55, "metallic = 0.35")
    rim_color = s.material("PotRimMetal", "b0c3c4", 0.5, "metallic = 0.3")
    handle_color = s.material("PotHandle", "484b43", 0.8)
    sphere = s.res("SphereMesh", "SmoothSphere", "radius = 0.5\nheight = 1.0\nradial_segments = 40\nrings = 20")
    legs = s.res("CapsuleMesh", "LegShape", "radius = 0.115\nheight = 0.57\nradial_segments = 24\nrings = 8")
    arm = s.res("CapsuleMesh", "ArmShape", "radius = 0.078\nheight = 0.27\nradial_segments = 24\nrings = 8")
    neck = s.res("CylinderMesh", "NeckShape", "top_radius = 0.095\nbottom_radius = 0.11\nheight = 0.14\nradial_segments = 24")
    collar_ring = s.res("TorusMesh", "CollarRing", "inner_radius = 0.09\nouter_radius = 0.145\nrings = 32\nring_segments = 12")
    pot = s.res("CylinderMesh", "PotShape", "top_radius = 0.285\nbottom_radius = 0.307\nheight = 0.14\nradial_segments = 48")
    rim = s.res("TorusMesh", "PotRim", "inner_radius = 0.282\nouter_radius = 0.326\nrings = 48\nring_segments = 12")
    handle = s.res("CapsuleMesh", "HandleShape", "radius = 0.041\nheight = 0.34\nradial_segments = 24\nrings = 8")
    collision = s.res("CapsuleShape3D", "PlayerCollision", "radius = 0.32\nheight = 1.82")

    def part(name, parent, mesh, material, pos=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
        s.mesh(name, parent, mesh, material, pos, scale, rot, layers=2)

    s.node("CrazyDave", "CharacterBody3D", properties=f'floor_snap_length = 0.2\nscript = {script}')
    s.node("Visuals", "Node3D", ".")
    s.node("Body", "Node3D", "Visuals")
    part("JeansWaist", "Visuals/Body", sphere, denim, (0, 0.70, 0.015), (0.69, 0.26, 0.45))
    part("Shirt", "Visuals/Body", sphere, shirt, (0, 1.015, 0), (0.87, 0.64, 0.59))
    part("Neck", "Visuals/Body", neck, skin, (0, 1.34, -0.005))
    part("Collar", "Visuals/Body", collar_ring, collar, (0, 1.315, -0.005))
    s.node("Legs", "Node3D", "Visuals")
    s.node("Arms", "Node3D", "Visuals")
    for name, sign in (("Left", -1), ("Right", 1)):
        part(name + "Leg", "Visuals/Legs", legs, denim, (sign * 0.175, 0.37, 0.025), (1, 1, 1.12), (0, 0, sign * -0.035))
        part(name + "Shoe", "Visuals/Legs", sphere, shoes, (sign * 0.18, 0.085, -0.065), (0.28, 0.17, 0.43))
        part(name + "Sleeve", "Visuals/Arms", sphere, shirt, (sign * 0.375, 1.185, 0.005), (0.30, 0.28, 0.32), (0, 0, sign * 0.25))
        part(name + "UpperArm", "Visuals/Arms", arm, skin, (sign * 0.465, 1.01, 0.015), rot=(0, 0, sign * 0.12))
        part(name + "Forearm", "Visuals/Arms", arm, skin, (sign * 0.49, 0.85, -0.025), rot=(-0.20, 0, 0))
        part(name + "Hand", "Visuals/Arms", sphere, skin, (sign * 0.49, 0.73, -0.045), (0.165, 0.19, 0.17))
        part(name + "Thumb", "Visuals/Arms", sphere, skin, (sign * 0.432, 0.755, -0.11), (0.09, 0.11, 0.08))
    s.node("Head", "Node3D", "Visuals", "position = Vector3(0, 1.5, 0)")
    part("Hair", "Visuals/Head", sphere, beard, (0, 0.055, 0.045), (0.57, 0.40, 0.46))
    part("Face", "Visuals/Head", sphere, skin, (0, 0.035, -0.035), (0.50, 0.43, 0.45))
    part("Beard", "Visuals/Head", sphere, beard, (0, -0.105, -0.11), (0.43, 0.27, 0.30))
    part("Nose", "Visuals/Head", sphere, skin, (0, 0.025, -0.272), (0.18, 0.16, 0.15))
    for name, sign in (("Left", -1), ("Right", 1)):
        part(name + "Ear", "Visuals/Head", sphere, skin, (sign * 0.265, 0.04, 0.005), (0.125, 0.18, 0.13))
        part(name + "Sideburn", "Visuals/Head", sphere, beard, (sign * 0.224, -0.015, -0.075), (0.085, 0.24, 0.12))
        part(name + "EyeWhite", "Visuals/Head", sphere, white, (sign * 0.105, 0.112, -0.235), (0.155, 0.178, 0.07))
        part(name + "Pupil", "Visuals/Head", sphere, dark, (sign * 0.10, 0.12 + sign * 0.012, -0.269), (0.058, 0.08, 0.025))
        part(name + "Eyebrow", "Visuals/Head", sphere, moustache, (sign * 0.111, 0.202, -0.219), (0.18, 0.044, 0.04), (0, 0, sign * -0.18))
        part(name + "Moustache", "Visuals/Head", sphere, moustache, (sign * 0.076, -0.055, -0.258), (0.185, 0.07, 0.07), (0, 0, sign * -0.12))
    part("Mouth", "Visuals/Head", sphere, mouth, (0, -0.113, -0.255), (0.10, 0.09, 0.025))
    part("Tooth", "Visuals/Head", sphere, white, (0, -0.091, -0.27), (0.060, 0.036, 0.02))
    s.node("CookingPot", "Node3D", "Visuals/Head", "position = Vector3(0, 0.245, 0.015)")
    part("PotBody", "Visuals/Head/CookingPot", pot, metal, (0, 0.005, 0))
    part("PotRim", "Visuals/Head/CookingPot", rim, rim_color, (0, -0.065, 0))
    part("PotHandle", "Visuals/Head/CookingPot", handle, handle_color, (0.455, 0.01, 0), rot=(0, 0, -math.pi / 2))
    part("HandleRivet", "Visuals/Head/CookingPot", sphere, rim_color, (0.30, 0.01, 0), (0.055, 0.06, 0.075))
    s.node("CollisionShape3D", "CollisionShape3D", ".", f'position = Vector3(0, 0.91, 0)\nshape = {collision}')
    s.node("WaistMount", "Node3D", ".", "position = Vector3(0, 0.94, 0)")
    s.node("Camera3D", "Camera3D", "WaistMount", "current = true\ncull_mask = 1\nfov = 75.0\nnear = 0.03\nfar = 150.0")
    s.save("scenes/characters/crazy_dave.tscn")


def zombie_scene():
    s = Scene()
    script = s.ext("Script", "scripts/zombie.gd", "zombie_script")
    skin = s.material("ZombieSkin", "829575", 0.9)
    skin_dark = s.material("SkinShadows", "5a7053", 0.95)
    jacket = s.material("BrownJacket", "76533d", 0.95)
    lapel = s.material("JacketLapels", "89674c", 0.95)
    shirt = s.material("WornShirt", "dddcc8", 0.95)
    tie = s.material("RedTie", "bd5147", 0.85)
    denim = s.material("RippedJeans", "4e6d87", 0.95)
    shoes = s.material("OldShoes", "493d31", 0.95)
    white = s.material("EyesAndTeeth", "f6efd3", 0.6)
    dark = s.material("Pupils", "30362b", 0.4)
    mouth = s.material("OpenMouth", "3a3b2c", 0.95)
    hair_color = s.material("SparseHair", "46503b", 0.95)
    sphere = s.res("SphereMesh", "SmoothSphere", "radius = 0.5\nheight = 1.0\nradial_segments = 40\nrings = 20")
    box = s.res("BoxMesh", "UnitBox", "size = Vector3(1, 1, 1)")
    neck = s.res("CylinderMesh", "NeckShape", "top_radius = 0.085\nbottom_radius = 0.095\nheight = 0.18\nradial_segments = 24")
    hair = s.res("CapsuleMesh", "HairShape", "radius = 0.01\nheight = 0.105\nradial_segments = 12\nrings = 4")
    collision = s.res("CapsuleShape3D", "ZombieCollision", "radius = 0.29\nheight = 1.82")

    def part(name, parent, mesh, material, pos=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
        s.mesh(name, parent, mesh, material, pos, scale, rot)

    def limb(name, parent, material, start, end, radius):
        direction = tuple(end[i] - start[i] for i in range(3))
        length = math.sqrt(sum(v * v for v in direction))
        mesh = s.res("CapsuleMesh", name + "Shape", f"radius = {radius}\nheight = {max(length, radius * 2):.6f}\nradial_segments = 24\nrings = 8")
        center = tuple((start[i] + end[i]) * 0.5 for i in range(3))
        rotation = (math.atan2(direction[2], direction[1]), 0, -math.atan2(direction[0], math.hypot(direction[1], direction[2])))
        part(name, parent, mesh, material, center, rot=rotation)

    # Walking enemy; local -Z faces forward and its origin remains at its feet.
    s.node("Zombie", "CharacterBody3D", properties=f'collision_layer = 4\ncollision_mask = 1\nfloor_snap_length = 0.2\nscript = {script}')
    s.node("Visuals", "Node3D", ".")
    s.node("Torso", "Node3D", "Visuals")
    part("JeansWaist", "Visuals/Torso", sphere, denim, (0, 0.66, 0.025), (0.46, 0.24, 0.34))
    part("Jacket", "Visuals/Torso", sphere, jacket, (0, 0.955, 0.02), (0.60, 0.61, 0.38))
    part("ShirtFront", "Visuals/Torso", sphere, shirt, (0, 0.97, -0.151), (0.27, 0.49, 0.075))
    part("Neck", "Visuals/Torso", neck, skin, (0, 1.30, -0.045))
    for name, sign in (("Left", -1), ("Right", 1)):
        part(name + "Lapel", "Visuals/Torso", box, lapel, (sign * 0.137, 1.10, -0.152), (0.087, 0.255, 0.035), (0, 0, sign * -0.27))
    part("TieKnot", "Visuals/Torso", sphere, tie, (0, 1.145, -0.203), (0.077, 0.08, 0.042))
    part("TieBlade", "Visuals/Torso", box, tie, (0, 1.007, -0.199), (0.059, 0.235, 0.025), (0, 0, -0.045))
    part("TiePoint", "Visuals/Torso", box, tie, (0.006, 0.888, -0.199), (0.043, 0.043, 0.025), (0, 0, math.pi / 4))
    part("WornJacketPatch", "Visuals/Torso", sphere, skin_dark, (-0.205, 0.846, -0.12), (0.075, 0.06, 0.024))
    s.node("Legs", "Node3D", "Visuals")
    s.node("Arms", "Node3D", "Visuals")
    for name, sign in (("Left", -1), ("Right", 1)):
        limb(name + "Leg", "Visuals/Legs", denim, (sign * 0.13, 0.68, 0.025), (sign * 0.165, 0.09, 0.03), 0.092)
        part(name + "Shoe", "Visuals/Legs", sphere, shoes, (sign * 0.165, 0.08, -0.065), (0.26, 0.16, 0.38))
        height_offset = sign * 0.023
        part(name + "Shoulder", "Visuals/Arms", sphere, jacket, (sign * 0.275, 1.15, 0.014), (0.26, 0.245, 0.26))
        limb(name + "Sleeve", "Visuals/Arms", jacket, (sign * 0.28, 1.16, 0.005), (sign * 0.35, 0.93 + height_offset, -0.22), 0.08)
        hand_parent = "Visuals/Arms/" + name + "HandAssembly"
        s.node(name + "HandAssembly", "Node3D", "Visuals/Arms")
        limb(name + "Forearm", hand_parent, skin, (sign * 0.35, 0.94 + height_offset, -0.23), (sign * 0.35, 0.99 + height_offset, -0.55), 0.06)
        part(name + "Hand", hand_parent, sphere, skin, (sign * 0.35, 0.99 + height_offset, -0.587), (0.145, 0.11, 0.205))
        for finger, offset in enumerate((-0.046, 0, 0.046)):
            limb(name + f"Finger{finger + 1}", hand_parent, skin, (sign * 0.35 + offset, 0.99 + height_offset, -0.64), (sign * 0.35 + offset, 0.975 + height_offset, -0.78 + abs(offset) * 0.6), 0.014)
        part(name + "Thumb", hand_parent, sphere, skin, (sign * 0.294, 0.975 + height_offset, -0.565), (0.067, 0.08, 0.15), (0, sign * 0.3, 0))
    part("ExposedShin", "Visuals/Legs", sphere, skin, (-0.16, 0.28, -0.071), (0.125, 0.145, 0.048))
    s.node("Head", "Node3D", "Visuals", "position = Vector3(0, 1.475, -0.055)\nrotation = Vector3(0.05, 0, -0.025)")
    part("Skull", "Visuals/Head", sphere, skin, (0, 0.025, 0), (0.57, 0.565, 0.50))
    part("Jaw", "Visuals/Head", sphere, skin, (0, -0.14, -0.06), (0.45, 0.25, 0.39))
    part("Nose", "Visuals/Head", sphere, skin_dark, (0, 0.012, -0.26), (0.115, 0.13, 0.12))
    for name, sign in (("Left", -1), ("Right", 1)):
        part(name + "Ear", "Visuals/Head", sphere, skin, (sign * 0.284, 0.022, 0.018), (0.10, 0.165, 0.12))
        part(name + "EyeSocket", "Visuals/Head", sphere, skin_dark, (sign * 0.137, 0.101, -0.232), (0.22, 0.238, 0.065))
        part(name + "EyeWhite", "Visuals/Head", sphere, white, (sign * 0.137, 0.103, -0.248), (0.185, 0.21 + sign * 0.015, 0.079))
        part(name + "Pupil", "Visuals/Head", sphere, dark, (sign * 0.130, 0.108 + sign * 0.012, -0.286), (0.057, 0.083, 0.024))
        part(name + "Eyelid", "Visuals/Head", sphere, skin_dark, (sign * 0.137, 0.197, -0.247), (0.205, 0.041, 0.044), (0, 0, sign * 0.10))
        part(name + "Scar", "Visuals/Head", sphere, skin_dark, (sign * 0.213, -0.049, -0.204), (0.064, 0.023, 0.025), (0, 0, sign * 0.35))
    part("Mouth", "Visuals/Head", sphere, mouth, (0, -0.143, -0.259), (0.258, 0.164, 0.043))
    for i, (x, y, height) in enumerate(((-0.079, -0.111, 0.067), (0.006, -0.106, 0.074), (0.077, -0.112, 0.049))):
        part(f"UpperTooth{i + 1}", "Visuals/Head", box, white, (x, y, -0.282), (0.047, height, 0.025), (0, 0, (i - 1) * 0.05))
    part("LowerTooth", "Visuals/Head", box, white, (-0.018, -0.203, -0.282), (0.052, 0.04, 0.024))
    for i, (x, angle) in enumerate(((-0.095, -0.28), (0.047, 0.22), (0.173, 0.35))):
        part(f"Hair{i + 1}", "Visuals/Head", hair, hair_color, (x, 0.293 - abs(x) * 0.08, 0.025), rot=(0.12, 0, angle))
    s.node("CollisionShape3D", "CollisionShape3D", ".", f'position = Vector3(0, 0.91, 0)\nshape = {collision}')
    s.save("scenes/enemies/zombie.tscn")


def conehead_scene():
    s = Scene()
    base = s.ext("PackedScene", "scenes/enemies/zombie.tscn", "base_zombie")
    orange = s.material("ConeOrange", "ed842c", 0.72)
    white = s.material("ReflectiveBands", "f4ecd3", 0.58)
    base_mesh = s.res("BoxMesh", "ConeBase", "size = Vector3(0.56, 0.07, 0.56)")
    cone = s.res("CylinderMesh", "TrafficCone", "top_radius = 0.035\nbottom_radius = 0.255\nheight = 0.65\nradial_segments = 32")
    lower_band = s.res("CylinderMesh", "LowerBand", "top_radius = 0.175\nbottom_radius = 0.215\nheight = 0.11\nradial_segments = 32")
    upper_band = s.res("CylinderMesh", "UpperBand", "top_radius = 0.100\nbottom_radius = 0.127\nheight = 0.075\nradial_segments = 32")
    s.node("ConeheadZombie", instance=base, properties="maximum_health = 570\nhas_cone = true")
    s.node("Cone", "Node3D", "Visuals/Head", "position = Vector3(0, 0.29, 0.015)\nrotation = Vector3(0, 0, -0.07)")
    s.mesh("Base", "Visuals/Head/Cone", base_mesh, orange, (0, 0.035, 0))
    s.mesh("ConeBody", "Visuals/Head/Cone", cone, orange, (0, 0.355, 0))
    s.mesh("LowerStripe", "Visuals/Head/Cone", lower_band, white, (0, 0.22, 0))
    s.mesh("UpperStripe", "Visuals/Head/Cone", upper_band, white, (0, 0.45, 0))
    s.save("scenes/enemies/conehead_zombie.tscn")


def buckethead_scene():
    s = Scene()
    base = s.ext("PackedScene", "scenes/enemies/zombie.tscn", "base_zombie")
    steel = s.material("BucketSteel", "879b9e", 0.45, "metallic = 0.7\ncull_mode = 2")
    edge = s.material("BucketRim", "c0cdcc", 0.35, "metallic = 0.75")
    interior = s.material("BucketInterior", "43565a", 0.75, "metallic = 0.4\ncull_mode = 2")
    scratch = s.material("BucketScuffs", "536a6d", 0.8, "metallic = 0.3")
    body = s.res("CylinderMesh", "BucketBody", "top_radius = 0.265\nbottom_radius = 0.335\nheight = 0.42\nradial_segments = 48\ncap_top = true\ncap_bottom = false")
    lining = s.res("CylinderMesh", "BucketLining", "top_radius = 0.248\nbottom_radius = 0.315\nheight = 0.36\nradial_segments = 48\ncap_top = true\ncap_bottom = false")
    lower_rim = s.res("TorusMesh", "RolledRim", "inner_radius = 0.313\nouter_radius = 0.355\nrings = 48\nring_segments = 12")
    top_seam = s.res("TorusMesh", "TopSeam", "inner_radius = 0.251\nouter_radius = 0.282\nrings = 48\nring_segments = 12")
    handle = s.res("TorusMesh", "WireHandle", "inner_radius = 0.336\nouter_radius = 0.353\nrings = 48\nring_segments = 8")
    sphere = s.res("SphereMesh", "HandleHinge", "radius = 0.5\nheight = 1.0\nradial_segments = 20\nrings = 10")
    scuff = s.res("BoxMesh", "ScuffLine", "size = Vector3(0.055, 0.009, 0.006)")

    s.node("BucketheadZombie", instance=base, properties="maximum_health = 1370\nhas_bucket = true")
    s.node("Bucket", "Node3D", "Visuals/Head", "position = Vector3(0, 0.18, 0.015)\nrotation = Vector3(0, 0, 0.07)")
    s.mesh("Body", "Visuals/Head/Bucket", body, steel, (0, 0.17, 0))
    s.mesh("Interior", "Visuals/Head/Bucket", lining, interior, (0, 0.14, 0))
    s.mesh("LowerRim", "Visuals/Head/Bucket", lower_rim, edge, (0, -0.04, 0))
    s.mesh("TopSeam", "Visuals/Head/Bucket", top_seam, edge, (0, 0.375, 0))
    s.mesh("Handle", "Visuals/Head/Bucket", handle, edge, (0, 0.13, 0), rot=(math.pi / 2, 0, 0))
    for name, sign in (("Left", -1), ("Right", 1)):
        s.mesh(name + "Hinge", "Visuals/Head/Bucket", sphere, edge, (sign * 0.315, 0.13, 0), (0.055, 0.07, 0.07))
    for i, (x, y, angle) in enumerate(((-0.12, 0.11, -0.30), (-0.09, 0.14, -0.30), (0.13, 0.25, 0.25))):
        radius = 0.335 - (y + 0.04) / 0.42 * 0.07
        z = -math.sqrt(radius * radius - x * x) - 0.002
        s.mesh(f"Scuff{i + 1}", "Visuals/Head/Bucket", scuff, scratch, (x, y, z), rot=(0, 0, angle))
    s.save("scenes/enemies/buckethead_zombie.tscn")


def pole_vaulting_scene():
    s = Scene()
    base = s.ext("PackedScene", "scenes/enemies/zombie.tscn", "base_zombie")
    script = s.ext("Script", "scripts/pole_vaulting_zombie.gd", "pole_script")
    red = s.material("AthleticRed", "c84c44", 0.82)
    blue = s.material("RunningShorts", "747c73", 0.88)
    headband = s.material("BlueHeadband", "5287ad", 0.75)
    blond = s.material("BlondHair", "d7b854", 0.88)
    cream = s.material("SportsWhite", "f5f0dc", 0.75)
    skin = s.material("AthleteSkin", "829575", 0.9)
    pole_color = s.material("FiberglassPole", "dac7a0", 0.45)
    rubber = s.material("PoleTip", "52594b", 0.8)
    sphere = s.res("SphereMesh", "AthleteSphere", "radius = 0.5\nheight = 1.0\nradial_segments = 32\nrings = 16")
    box = s.res("BoxMesh", "AthleteBox", "size = Vector3(1, 1, 1)")
    band = s.res("TorusMesh", "HeadbandRing", "inner_radius = 0.269\nouter_radius = 0.300\nrings = 40\nring_segments = 12")
    pole = s.res("CylinderMesh", "PoleShaft", "top_radius = 0.031\nbottom_radius = 0.031\nheight = 3.6\nradial_segments = 20")
    wrap = s.res("CylinderMesh", "PoleWrap", "top_radius = 0.035\nbottom_radius = 0.035\nheight = 0.11\nradial_segments = 20")
    number = s.res("TextMesh", "RunnerNumber", 'text = "07"\nfont_size = 48\npixel_size = 0.0038\ndepth = 0.002')
    s.node("PoleVaultingZombie", instance=base, properties=f"script = {script}\nmaximum_health = 500\ncollision_mask = 33")
    s.node("Torso", parent="Visuals", properties="position = Vector3(0, 0, -0.09)\nrotation = Vector3(-0.12, 0, 0)")
    s.node("Head", parent="Visuals", properties="position = Vector3(0, 1.475, -0.25)")
    s.node("Jacket", parent="Visuals/Torso", properties=f"material_override = {red}")
    s.node("JeansWaist", parent="Visuals/Torso", properties=f"material_override = {blue}")
    for name in ("ShirtFront", "LeftLapel", "RightLapel", "TieKnot", "TieBlade", "TiePoint", "WornJacketPatch"):
        s.node(name, parent="Visuals/Torso", properties="visible = false")
    s.mesh("Bib", "Visuals/Torso", box, cream, (0, 1.015, -0.18), (0.24, 0.23, 0.026))
    s.mesh("Number", "Visuals/Torso", number, red, (0, 1.01, -0.196), rot=(0, math.pi, 0))
    def segment_properties(start, end, original_length):
        direction = tuple(end[i] - start[i] for i in range(3))
        length = math.sqrt(sum(v * v for v in direction))
        center = tuple((start[i] + end[i]) * 0.5 for i in range(3))
        angles = (math.atan2(direction[2], direction[1]), 0, -math.atan2(direction[0], math.hypot(direction[1], direction[2])))
        return f"position = Vector3{center}\nrotation = Vector3{angles}\nscale = Vector3(1, {length / original_length}, 1)"

    for name, sign in (("Left", -1), ("Right", 1)):
        shoulder = (sign * 0.28, 1.16, -0.18)
        elbow = (-0.32, 1.37, -0.39) if sign == -1 else (0.36, 0.98, -0.06)
        hand = (-0.30, 1.81, -0.34) if sign == -1 else (0.37, 0.79, -0.07)
        original_hand = (sign * 0.35, 0.99 + sign * 0.023, -0.587)
        # Palm and fingers turn downward on the relaxed arm, around the wrist.
        angle = 0 if sign == -1 else -math.pi / 2
        def turn(point):
            return (point[0], math.cos(angle) * point[1] - math.sin(angle) * point[2], math.sin(angle) * point[1] + math.cos(angle) * point[2])
        rotated_hand = turn(original_hand)
        translation = tuple(hand[i] - rotated_hand[i] for i in range(3))
        relative_elbow = tuple(elbow[i] - translation[i] for i in range(3))
        elbow_local = (relative_elbow[0], math.cos(angle) * relative_elbow[1] + math.sin(angle) * relative_elbow[2], -math.sin(angle) * relative_elbow[1] + math.cos(angle) * relative_elbow[2])
        s.node(name + "Shoulder", parent="Visuals/Arms", properties=f"position = Vector3({sign * 0.275}, 1.15, -0.18)\nmaterial_override = {skin}")
        sleeve_length = math.sqrt(0.07 ** 2 + (0.23 - sign * 0.023) ** 2 + 0.225 ** 2)
        s.node(name + "Sleeve", parent="Visuals/Arms", properties=segment_properties(shoulder, elbow, sleeve_length) + f"\nmaterial_override = {skin}")
        s.node(name + "HandAssembly", parent="Visuals/Arms", properties=f"position = Vector3{translation}\nrotation = Vector3({angle}, 0, 0)")
        s.node(name + "Forearm", parent="Visuals/Arms/" + name + "HandAssembly", properties=segment_properties(elbow_local, original_hand, math.hypot(0.05, 0.32)))
        # A hip pivot keeps the complete bent leg and shoe connected when walking.
        s.node(name + "Leg", parent="Visuals/Legs", properties="visible = false")
        s.node(name + "Shoe", parent="Visuals/Legs", properties="visible = false")
        leg_parent = "Visuals/Legs/" + name + "RunnerLeg"
        hip = (sign * 0.13, 0.68, -0.12)
        knee = (sign * 0.15, 0.38, -0.26 if sign == -1 else 0.07)
        ankle = (sign * 0.165, 0.10, -0.13 if sign == -1 else 0.16)
        s.node(name + "RunnerLeg", "Node3D", "Visuals/Legs", f"position = Vector3{hip}")
        for part_name, start, end, radius in (("Thigh", hip, knee, 0.085), ("Shin", knee, ankle, 0.073)):
            a, b = tuple(start[i] - hip[i] for i in range(3)), tuple(end[i] - hip[i] for i in range(3))
            mesh = s.res("CapsuleMesh", name + part_name, f"radius = {radius}\nheight = 1.0\nradial_segments = 24\nrings = 8")
            s.node(part_name, "MeshInstance3D", leg_parent, segment_properties(a, b, 1.0) + f"\nmesh = {mesh}\nmaterial_override = {skin}")
        s.mesh("Shorts", leg_parent, sphere, blue, (0, -0.095, 0.03), (0.24, 0.29, 0.25))
        s.mesh("Knee", leg_parent, sphere, skin, tuple(knee[i] - hip[i] for i in range(3)), (0.17, 0.17, 0.17))
        shoe_position = (ankle[0] - hip[0], 0.08 - hip[1], ankle[2] - hip[2] - 0.04)
        s.mesh("Shoe", leg_parent, sphere, red, shoe_position, (0.26, 0.16, 0.38))
        s.mesh("ShoeSole", leg_parent, sphere, cream, (shoe_position[0], shoe_position[1] - 0.045, shoe_position[2]), (0.27, 0.055, 0.39))
        s.mesh("Sock", leg_parent, sphere, cream, (ankle[0] - hip[0], 0.18 - hip[1], ankle[2] - hip[2]), (0.16, 0.17, 0.16))
    s.node("ExposedShin", parent="Visuals/Legs", properties="visible = false")
    s.node("Headband", "Node3D", "Visuals/Head")
    s.mesh("Band", "Visuals/Head/Headband", band, headband, (0, 0.135, 0), (1, 0.8, 0.90))
    s.mesh("Knot", "Visuals/Head/Headband", sphere, headband, (-0.25, 0.135, 0.13), (0.09, 0.075, 0.09))
    s.mesh("Ribbon", "Visuals/Head/Headband", box, headband, (-0.278, 0.075, 0.17), (0.055, 0.16, 0.014), (0.3, 0, -0.22))
    for i in range(3):
        s.node(f"Hair{i + 1}", parent="Visuals/Head", properties="visible = false")
        s.mesh(f"BlondTuft{i + 1}", "Visuals/Head", sphere, blond, (0.02 + i * 0.045, 0.28 - i * 0.012, 0.07), (0.22, 0.055, 0.075), (0, -0.2, 0.20 + i * 0.16))
    s.node("Pole", "Node3D", "Visuals", "position = Vector3(-0.30, 1.83, 0.05)\nrotation = Vector3(1.5707963267948966, 0, 0)")
    s.mesh("Shaft", "Visuals/Pole", pole, pole_color)
    for i, offset in enumerate((-1.55, -0.4, 0.4, 1.55)):
        s.mesh(f"Wrap{i + 1}", "Visuals/Pole", wrap, red, (0, offset, 0))
    for name, sign in (("Bottom", -1), ("Top", 1)):
        s.mesh(name + "Tip", "Visuals/Pole", sphere, rubber, (0, sign * 1.79, 0), (0.08, 0.12, 0.08))
    s.save("scenes/enemies/pole_vaulting_zombie.tscn")


def wall_nut_scene():
    s = Scene()
    script = s.ext("Script", "scripts/wall_nut.gd", "wall_nut_script")
    shell = s.material("GoldenShell", "b58a50", 0.93)
    ridge = s.material("ShellRidges", "99723f", 0.96)
    white = s.material("NutEyes", "fff8dd", 0.6)
    dark = s.material("NutPupils", "332719", 0.5)
    mouth = s.material("NutMouth", "725032", 0.9)
    sphere = s.res("SphereMesh", "NutSphere", "radius = 0.5\nheight = 1.0\nradial_segments = 48\nrings = 24")
    seam = s.res("CapsuleMesh", "ShellSeam", "radius = 0.013\nheight = 1.0\nradial_segments = 12\nrings = 4")
    collider = s.res("CapsuleShape3D", "NutCollision", "radius = 0.43\nheight = 1.35")
    s.node("WallNut", "Node3D", properties=f"script = {script}")
    s.node("Visuals", "Node3D", ".")
    s.mesh("Shell", "Visuals", sphere, shell, (0, 0.70, 0), (1.04, 1.40, 0.88))
    # Fine grooves follow the curved shell, with the front kept clear for the face.
    for index, angle in enumerate((0.7, 1.2, 1.8, 2.4, 3.0, 3.7, 4.3, 4.9, 5.5)):
        for step in range(8):
            points = []
            for amount in (step, step + 1):
                latitude = -1.18 + amount * 2.36 / 8
                azimuth = angle + math.sin(latitude * 3 + index) * 0.06
                points.append((math.cos(latitude) * math.cos(azimuth) * 0.525, 0.70 + math.sin(latitude) * 0.705, math.cos(latitude) * math.sin(azimuth) * 0.445))
            start, end = points
            direction = tuple(end[i] - start[i] for i in range(3))
            length = math.sqrt(sum(v * v for v in direction))
            rotation = (math.atan2(direction[2], direction[1]), 0, -math.atan2(direction[0], math.hypot(direction[1], direction[2])))
            s.mesh(f"Groove{index}_{step}", "Visuals", seam, ridge, tuple((start[i] + end[i]) * 0.5 for i in range(3)), (1, length, 1), rotation)
    s.node("Face", "Node3D", "Visuals")
    for name, sign in (("Left", -1), ("Right", 1)):
        s.mesh(name + "Eye", "Visuals/Face", sphere, white, (0.48, 0.87, sign * 0.17), (0.095, 0.21, 0.165))
        s.mesh(name + "Pupil", "Visuals/Face", sphere, dark, (0.528, 0.865, sign * 0.17), (0.025, 0.085, 0.064))
        s.mesh(name + "Glint", "Visuals/Face", sphere, white, (0.543, 0.89, sign * 0.16), (0.015, 0.026, 0.019))
    s.mesh("Mouth", "Visuals/Face", sphere, mouth, (0.512, 0.58, 0), (0.021, 0.035, 0.16))
    s.node("PlantBody", "StaticBody3D", ".", "collision_layer = 32\ncollision_mask = 4")
    s.node("CollisionShape3D", "CollisionShape3D", "PlantBody", f"position = Vector3(0, 0.675, 0)\nshape = {collider}")
    s.save("scenes/plants/wall_nut.tscn")


def house_scene():
    s = Scene()
    script = s.ext("Script", "scripts/dave_house.gd", "house_script")
    s.node("DaveHouse", "Node3D", properties=f'script = {script}')
    s.save("scenes/environment/dave_house.tscn")


def main_scene():
    s = Scene()
    demo = s.ext("Script", "scripts/demo.gd", "demo_script")
    orbit = s.ext("Script", "scripts/orbit_camera.gd", "orbit_script")
    plant = s.ext("PackedScene", "scenes/plants/peashooter.tscn", "plant_scene")
    repeater = s.ext("PackedScene", "scenes/plants/repeater.tscn", "repeater_scene")
    threepeater = s.ext("PackedScene", "scenes/plants/threepeater.tscn", "threepeater_scene")
    gatling = s.ext("PackedScene", "scenes/plants/gatling_pea.tscn", "gatling_scene")
    snow_pea = s.ext("PackedScene", "scenes/plants/snow_pea.tscn", "snow_pea_scene")
    wall_nut = s.ext("PackedScene", "scenes/plants/wall_nut.tscn", "wall_nut_scene")
    lawn = s.ext("PackedScene", "scenes/terrain/lawn_grid.tscn", "lawn_scene")
    dave = s.ext("PackedScene", "scenes/characters/crazy_dave.tscn", "dave_scene")
    house = s.ext("PackedScene", "scenes/environment/dave_house.tscn", "house_scene")
    zombie = s.ext("PackedScene", "scenes/enemies/zombie.tscn", "zombie_scene")
    conehead = s.ext("PackedScene", "scenes/enemies/conehead_zombie.tscn", "conehead_scene")
    buckethead = s.ext("PackedScene", "scenes/enemies/buckethead_zombie.tscn", "buckethead_scene")
    pole_zombie = s.ext("PackedScene", "scenes/enemies/pole_vaulting_zombie.tscn", "pole_zombie_scene")
    ground_shape = s.res("BoxShape3D", "BackgroundGroundShape", "size = Vector3(200, 0.25, 200)")
    floor_color = s.material("Backdrop", "a0b08c", 1)
    plane = s.res("PlaneMesh", "BackdropPlane", "size = Vector2(200, 200)")
    sky_material = s.res("ProceduralSkyMaterial", "GardenSkyMaterial", "sky_top_color = Color(0.42, 0.71, 0.85, 1)\nsky_horizon_color = Color(0.84, 0.92, 0.85, 1)\nground_bottom_color = Color(0.46, 0.57, 0.36, 1)\nground_horizon_color = Color(0.84, 0.92, 0.85, 1)")
    sky = s.res("Sky", "GardenSky", f'sky_material = {sky_material}')
    env = s.res("Environment", "GardenEnvironment", f"background_mode = 2\nsky = {sky}\nambient_light_source = 3\nambient_light_color = Color(0.86, 0.92, 1, 1)\nambient_light_energy = 0.4\nreflected_light_source = 2\ntonemap_mode = 0")

    s.node("Garden", "Node3D", properties=f'script = {demo}')
    s.node("WorldEnvironment", "WorldEnvironment", ".", f'environment = {env}')
    s.node("Sun", "DirectionalLight3D", ".", 'rotation = Vector3(-0.94, -0.65, -0.18)\nlight_color = Color(1, 0.96, 0.88, 1)\nlight_energy = 0.8\nshadow_enabled = true\nshadow_blur = 2.0\ndirectional_shadow_max_distance = 35.0\nshadow_bias = 0.04')
    s.node("SoftFill", "DirectionalLight3D", ".", 'rotation = Vector3(-0.5, 2.7, 0)\nlight_color = Color(0.84, 0.92, 1, 1)\nlight_energy = 0.08')
    s.mesh("Backdrop", ".", plane, floor_color, (0, -0.425, 0))
    s.node("BackgroundGround", "StaticBody3D", ".", "position = Vector3(0, -0.55, 0)\ncollision_layer = 1\ncollision_mask = 16")
    s.node("CollisionShape3D", "CollisionShape3D", "BackgroundGround", f'shape = {ground_shape}')
    s.node("LawnGrid", parent=".", instance=lawn)
    house_config, lawn_config = CONFIG["house"], CONFIG["lawn"]
    house_position = (-lawn_config["columns"] * lawn_config["cell_size"] / 2 - house_config["front_gap"], lawn_config["surface_height"], house_config["offset_z"])
    s.node("House", parent=".", instance=house, properties=f"position = Vector3{house_position}")
    s.node("Plants", "Node3D", ".")
    s.node("Peashooter", parent="Plants", instance=plant, properties="position = Vector3(-7.2, 0.025, 0)")
    s.node("Repeater", parent="Plants", instance=repeater, properties="position = Vector3(-7.2, 0.025, -2.4)")
    s.node("Threepeater", parent="Plants", instance=threepeater, properties="position = Vector3(-7.2, 0.025, 2.4)")
    s.node("GatlingPea", parent="Plants", instance=gatling, properties="position = Vector3(-7.2, 0.025, -4.8)")
    s.node("SnowPea", parent="Plants", instance=snow_pea, properties="position = Vector3(-7.2, 0.025, 4.8)")
    s.node("WallNut", parent="Plants", instance=wall_nut, properties="position = Vector3(7.2, 0.025, 4.8)")
    s.node("Characters", "Node3D", ".")
    s.node("CrazyDave", parent="Characters", instance=dave, properties="position = Vector3(-9.6, 0.025, 0)\nrotation = Vector3(0, -1.5707963267948966, 0)\nrestrict_to_lawn = true")
    s.node("Enemies", "Node3D", ".")
    s.node("Zombie", parent="Enemies", instance=zombie, properties="position = Vector3(9.6, 0.025, 0)\nrotation = Vector3(0, 1.5707963267948966, 0)")
    s.node("ConeheadZombie", parent="Enemies", instance=conehead, properties="position = Vector3(9.6, 0.025, -2.4)\nrotation = Vector3(0, 1.5707963267948966, 0)")
    s.node("BucketheadZombie", parent="Enemies", instance=buckethead, properties="position = Vector3(9.6, 0.025, -4.8)\nrotation = Vector3(0, 1.5707963267948966, 0)")
    s.node("PoleVaultingZombie", parent="Enemies", instance=pole_zombie, properties="position = Vector3(9.6, 0.025, 4.8)\nrotation = Vector3(0, 1.5707963267948966, 0)")
    s.node("Projectiles", "Node3D", ".")
    s.node("Debris", "Node3D", ".")
    s.node("OrbitRig", "Node3D", ".", f'script = {orbit}\nenabled = false\ndefault_yaw = 0.65\ndefault_pitch = 0.25\ndefault_size = 4.3\nminimum_size = 3.0\ntarget = Vector3(-8.4, 0.775, 0)\ndistance = 7.0')
    s.node("Camera3D", "Camera3D", "OrbitRig", 'position = Vector3(-4.298, 2.507, 5.397)\nrotation = Vector3(-0.25, 0.65, 0)\nprojection = 1\ncurrent = false\ncull_mask = 3\nsize = 4.3\nnear = 0.1\nfar = 200.0')
    s.save("scenes/main.tscn")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, help="Optional isolated configuration for scene generation; does not modify game_config.json.")
    parser.add_argument("--layout-only", action="store_true", help="Rebuild terrain/main scenes without modifying plant scenes or meshes.")
    parser.add_argument("--dave-only", action="store_true", help="Rebuild Dave/main scenes without modifying plant or terrain scenes.")
    parser.add_argument("--zombie-only", action="store_true", help="Rebuild zombie/main scenes without modifying plant, Dave or terrain scenes.")
    parser.add_argument("--repeater-only", action="store_true", help="Rebuild repeater/main scenes without modifying existing models or terrain.")
    parser.add_argument("--threepeater-only", action="store_true", help="Rebuild threepeater/main scenes without modifying existing models or terrain.")
    parser.add_argument("--gatling-only", action="store_true", help="Rebuild gatling pea/main scenes without modifying existing models or terrain.")
    parser.add_argument("--cone-only", action="store_true", help="Rebuild zombie/conehead/main scenes for detachable enemy parts.")
    parser.add_argument("--bucket-only", action="store_true", help="Rebuild buckethead/main scenes without modifying existing models or terrain.")
    parser.add_argument("--snow-only", action="store_true", help="Rebuild snow pea/projectile/main scenes without modifying existing models or terrain.")
    parser.add_argument("--pole-only", action="store_true", help="Rebuild pole-vaulting zombie/main scenes without modifying existing models or terrain.")
    parser.add_argument("--nut-only", action="store_true", help="Rebuild wall-nut/main scenes without modifying existing models or terrain.")
    parser.add_argument("--house-only", action="store_true", help="Rebuild the independent walkable house and main scene.")
    args = parser.parse_args()
    if args.config:
        CONFIG = read_config(args.config)
    if sum((args.layout_only, args.dave_only, args.zombie_only, args.repeater_only, args.threepeater_only, args.gatling_only, args.cone_only, args.bucket_only, args.snow_only, args.pole_only, args.nut_only, args.house_only)) > 1:
        parser.error("Choose only one partial rebuild option.")
    full_rebuild = not any((args.layout_only, args.dave_only, args.zombie_only, args.repeater_only, args.threepeater_only, args.gatling_only, args.cone_only, args.bucket_only, args.snow_only, args.pole_only, args.nut_only, args.house_only))
    if full_rebuild:
        leaf_mesh()
        rounded_tile("soil_tile", 1.15, -0.41, -0.075, 0.16, 0.045)
        rounded_tile("grass_tile", 1.18, -0.085, 0.025, 0.18, 0.025)
        grass_mesh()
        plant_scene()
    if full_rebuild or args.repeater_only or not (ROOT / "scenes/plants/repeater.tscn").exists():
        repeater_scene()
    if full_rebuild or args.threepeater_only or not (ROOT / "scenes/plants/threepeater.tscn").exists():
        threepeater_scene()
    if full_rebuild or args.gatling_only or not (ROOT / "scenes/plants/gatling_pea.tscn").exists():
        gatling_pea_scene()
    if full_rebuild or args.snow_only or not (ROOT / "scenes/plants/snow_pea.tscn").exists() or not (ROOT / "scenes/projectiles/snow_pea.tscn").exists():
        snow_pea_scene()
    if full_rebuild or args.layout_only:
        grass_tile_scene()
        lawn_grid_scene()
    if full_rebuild or args.dave_only or not (ROOT / "scenes/characters/crazy_dave.tscn").exists():
        dave_scene()
    if full_rebuild or args.zombie_only or args.cone_only or not (ROOT / "scenes/enemies/zombie.tscn").exists():
        zombie_scene()
    if full_rebuild or args.cone_only or not (ROOT / "scenes/enemies/conehead_zombie.tscn").exists():
        conehead_scene()
    if full_rebuild or args.bucket_only or not (ROOT / "scenes/enemies/buckethead_zombie.tscn").exists():
        buckethead_scene()
    if full_rebuild or args.pole_only or not (ROOT / "scenes/enemies/pole_vaulting_zombie.tscn").exists():
        pole_vaulting_scene()
    if full_rebuild or args.nut_only or not (ROOT / "scenes/plants/wall_nut.tscn").exists():
        wall_nut_scene()
    if full_rebuild or args.house_only or not (ROOT / "scenes/environment/dave_house.tscn").exists():
        house_scene()
    main_scene()
    print("Generated original meshes and Godot scenes.")
