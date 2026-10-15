"""Read-only binary glTF checks for the independently exported Conehead Zombie."""
import hashlib
import io
import json
import math
import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
data = (ROOT / "conehead_zombie.glb").read_bytes()
magic, version, length = struct.unpack_from("<4sII", data)
assert (magic, version, length) == (b"glTF", 2, len(data))
json_len, json_tag = struct.unpack_from("<I4s", data, 12)
assert json_tag == b"JSON"
doc = json.loads(data[20:20 + json_len])
binary_offset = 20 + json_len
binary_len, binary_tag = struct.unpack_from("<I4s", data, binary_offset)
assert binary_tag == b"BIN\x00"
binary = memoryview(data)[binary_offset + 8:binary_offset + 8 + binary_len]
assert not doc.get("animations") and not doc.get("skins") and not doc.get("cameras")
assert not doc.get("extensions", {}).get("KHR_lights_punctual")
assert all("uri" not in buffer for buffer in doc["buffers"])
for view in doc["bufferViews"]:
    assert view.get("byteOffset", 0) + view["byteLength"] <= len(binary)
for image in doc["images"]:
    assert "uri" not in image and "bufferView" in image
    view = doc["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    with Image.open(io.BytesIO(bytes(binary[start:start + view["byteLength"]]))) as png:
        png.verify()
triangles = surfaces = 0
for mesh in doc["meshes"]:
    for primitive in mesh["primitives"]:
        attrs = primitive["attributes"]
        assert {"POSITION", "NORMAL", "TEXCOORD_0"}.issubset(attrs)
        pos = doc["accessors"][attrs["POSITION"]]
        assert pos["count"] > 0 and all(math.isfinite(n) for n in pos["min"] + pos["max"])
        for key in ("NORMAL", "TEXCOORD_0"):
            assert doc["accessors"][attrs[key]]["count"] == pos["count"]
        material = doc["materials"][primitive["material"]]
        if "normalTexture" in material:
            assert "TANGENT" in attrs, mesh.get("name")
        assert primitive.get("mode", 4) == 4
        indices = doc["accessors"][primitive["indices"]]["count"]
        assert indices % 3 == 0
        triangles += indices // 3
        surfaces += 1
names = {node.get("name", ""): i for i, node in enumerate(doc["nodes"])}
for name in ("ConeheadZombie_Reference_A", "TrafficCone_removable", "Cone_outer_shell_A", "Cone_inner_hollow_shell", "Cone_open_top_rounded_broken_lip", "Cone_square_flange_rounded_open_base", "Head_sculpt_round_A_reference", "Exposed_left_sage_shin"):
    assert name in names, name
assert not any(name.startswith(("Preview_", "STUDIO", "Temporary_")) for name in names)
cone = doc["nodes"][names["TrafficCone_removable"]]
assert len(cone["children"]) == 7
assert all(doc["nodes"][child]["name"].startswith("Cone_") for child in cone["children"])
textured = [material for material in doc["materials"] if "baseColorTexture" in material.get("pbrMetallicRoughness", {})]
assert len(textured) == 10
for material in textured:
    assert "normalTexture" in material
    assert "metallicRoughnessTexture" in material["pbrMetallicRoughness"]
assert len(doc["materials"]) == 25 and len(doc["images"]) == 30
manifest = json.loads((ROOT / "model_manifest.json").read_text(encoding="utf-8"))
assert triangles == manifest["triangles"]
assert manifest["cone"]["hollow_shell"] and manifest["cone"]["open_top"]
assert manifest["cone"]["skull_clearance_error_m"] < .005
assert manifest["shin_skin_srgb"] == [.405, .49, .425]
reference = ROOT.parent / "conehead_zombie_reference_sheets/2026-10-15/A_front_side_rear.png"
assert hashlib.sha256(reference.read_bytes()).digest() == hashlib.sha256((ROOT / "source/reference_A_approved.png").read_bytes()).digest()
report = {"result": "PASS", "glb_version": 2, "bytes": len(data), "meshes": len(doc["meshes"]), "surfaces": surfaces, "triangles": triangles, "materials": len(doc["materials"]), "embedded_images": len(doc["images"]), "pbr_textured_materials": len(textured), "external_dependencies": 0, "normal_mapped_meshes_have_tangents": True, "cone_parts_under_removable_parent": 7, "approved_A_reference_matches": True, "studio_exported": False, "animations": 0, "sha256": hashlib.sha256(data).hexdigest()}
(ROOT / "validation_glb.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
