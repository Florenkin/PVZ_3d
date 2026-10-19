"""Check the delivered binary glTF without touching the original Godot project."""
import json
import hashlib
import math
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
path = root / "normal_zombie.glb"
data = path.read_bytes()
magic, version, total = struct.unpack_from("<4sII", data)
assert magic == b"glTF" and version == 2 and total == len(data)
chunk_len, chunk_type = struct.unpack_from("<I4s", data, 12)
assert chunk_type == b"JSON"
document = json.loads(data[20:20 + chunk_len])
assert document["asset"]["version"] == "2.0"
assert document.get("meshes") and document.get("materials")
assert not document.get("animations") and not document.get("skins")
assert not document.get("cameras")
assert not document.get("extensions", {}).get("KHR_lights_punctual")
assert all("uri" not in item for item in document["images"])
assert all("bufferView" in item for item in document["images"])
assert all("uri" not in item for item in document["buffers"])
assert sum(item["byteLength"] for item in document["buffers"]) <= len(data)
for item in document["bufferViews"]:
    assert item.get("byteOffset", 0) + item["byteLength"] <= document["buffers"][item.get("buffer", 0)]["byteLength"]
primitive_count = triangle_count = 0
for item in document["meshes"]:
    for primitive in item["primitives"]:
        attributes = primitive["attributes"]
        assert {"POSITION", "NORMAL", "TEXCOORD_0"}.issubset(attributes)
        assert primitive.get("mode", 4) == 4
        assert primitive["material"] < len(document["materials"])
        if "normalTexture" in document["materials"][primitive["material"]]:
            assert "TANGENT" in attributes
        positions = document["accessors"][attributes["POSITION"]]
        assert positions["count"] > 0
        assert all(math.isfinite(x) for x in positions["min"] + positions["max"])
        assert document["accessors"][primitive["indices"]]["count"] % 3 == 0
        triangle_count += document["accessors"][primitive["indices"]]["count"] // 3
        primitive_count += 1
node_names = {node.get("name", "") for node in document["nodes"]}
assert "NormalZombie_Reference" in node_names
assert "Head_sculpt_full_volume_B_reference" in node_names
assert "Exposed_left_sage_shin" in node_names
assert "Shin_sage_green" in {m.get("name") for m in document["materials"]}
assert not any(name.startswith("Preview_") or name.startswith("STUDIO") for name in node_names)
textured = [m for m in document["materials"] if "baseColorTexture" in m.get("pbrMetallicRoughness", {})]
assert len(textured) == 9
assert all("normalTexture" in material for material in textured)
assert all("metallicRoughnessTexture" in material["pbrMetallicRoughness"] for material in textured)
report = {"result": "PASS", "glb_version": version, "bytes": len(data), "meshes": len(document["meshes"]), "primitives": primitive_count, "triangles": triangle_count, "materials": len(document["materials"]), "embedded_images": len(document["images"]), "pbr_textured_materials": len(textured), "external_dependencies": 0, "mesh_attributes": ["POSITION", "NORMAL", "TEXCOORD_0"], "normal_mapped_meshes_have_tangents": True, "studio_exported": False, "animations": 0}
report["sha256"] = hashlib.sha256(data).hexdigest()
(root / "validation_glb.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
