"""Regenerate the five fixed-roster adventure scenes from StageCatalog."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
catalog = (ROOT / "scripts/stage_catalog.gd").read_text(encoding="utf-8")
plants = re.findall(r'"([a-z_]+)"', catalog.split("const PLANT_ORDER")[1].split("const PLANT_COUNTS")[0])
enemies = [re.findall(r'"([a-z_]+)"', row) for row in re.findall(r'\[([^\[\]]+)\]', catalog.split("const ENEMIES")[1].split("const AQUATIC")[0])]
original = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
environment = original[original.index('[sub_resource type="BoxShape3D"'):original.index('[node name="Garden"')]
world_nodes = original[original.index('[node name="WorldEnvironment"'):original.index('[node name="LawnGrid"')]
bases = ["zombie", "conehead_zombie", "buckethead_zombie", "pole_vaulting_zombie", "newspaper_zombie"]
for number, (filename, count) in enumerate(zip(["day", "night", "pool", "fog", "roof"], [9, 17, 25, 33, 40]), 1):
    resources = []
    for name in ["stage_demo", "stage_lawn", "stage_plant", "stage_zombie", "orbit_camera", "sun_system"]:
        resources.append(f'[ext_resource type="Script" path="res://scripts/{name}.gd" id="{name}"]')
    resources.append('[ext_resource type="PackedScene" path="res://scenes/characters/crazy_dave.tscn" id="dave"]')
    if number != 5:
        resources.append('[ext_resource type="PackedScene" path="res://scenes/environment/dave_house.tscn" id="house"]')
    for base in bases:
        resources.append(f'[ext_resource type="PackedScene" path="res://scenes/enemies/{base}.tscn" id="{base}"]')
    nodes = [f'[node name="{filename.title()}Stage" type="Node3D"]\nscript = ExtResource("stage_demo")\nstage_number = {number}\n', world_nodes]
    nodes.append('[node name="LawnGrid" type="Node3D" parent="."]\nscript = ExtResource("stage_lawn")\n\n[node name="Tiles" type="Node3D" parent="LawnGrid"]\n')
    nodes.append('[node name="Plants" type="Node3D" parent="."]\n')
    for kind in plants[:count]:
        name = ''.join(word.title() for word in kind.split('_'))
        nodes.append(f'[node name="{name}" type="Node3D" parent="Plants"]\nscript = ExtResource("stage_plant")\nplant_kind = "{kind}"\n')
    nodes.append('[node name="Characters" type="Node3D" parent="."]\n\n[node name="CrazyDave" parent="Characters" instance=ExtResource("dave")]\nrestrict_to_lawn = true\n')
    nodes.append('[node name="Enemies" type="Node3D" parent="."]\n')
    for kind in enemies[number - 1]:
        name = ''.join(word.title() for word in kind.split('_'))
        base = kind if kind in bases else 'zombie'
        nodes.append(f'[node name="{name}" parent="Enemies" instance=ExtResource("{base}")]\nscript = ExtResource("stage_zombie")\nenemy_kind = "{kind}"\n')
    for container in ['Projectiles', 'Debris', 'Effects', 'Decor']:
        nodes.append(f'[node name="{container}" type="Node3D" parent="."]\n')
    nodes.append('[node name="OrbitRig" type="Node3D" parent="."]\nscript = ExtResource("orbit_camera")\nenabled = false\n\n[node name="Camera3D" type="Camera3D" parent="OrbitRig"]\nprojection = 1\ncull_mask = 3\nnear = 0.1\nfar = 300.0\n')
    nodes.append('[node name="SunSystem" type="Node3D" parent="."]\nscript = ExtResource("sun_system")\n')
    if number != 5:
        nodes.append('[node name="House" parent="." instance=ExtResource("house")]\n')
    output = ROOT / f'scenes/stages/{filename}.tscn'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(f'[gd_scene load_steps={len(resources) + 7} format=3]\n\n' + '\n\n'.join(resources) + '\n\n' + environment + '\n'.join(nodes), encoding='utf-8')
    print(f'{output.name}: {count} plants / {len(enemies[number - 1])} zombie types')
