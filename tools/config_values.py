"""Read startup values for scene authoring, without ever changing user JSON."""
from pathlib import Path
import json
import math
import warnings

ROOT = Path(__file__).resolve().parents[1]


def defaults():
    source = (ROOT / "scripts/game_config_defaults.gd").read_text(encoding="utf-8")
    return json.loads(source.split('"""', 2)[1])


def _number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def valid(value, baseline, key):
    if isinstance(baseline, bool):
        return isinstance(value, bool)
    if isinstance(baseline, list):
        if not isinstance(value, list) or len(value) != len(baseline) or not all(_number(x) for x in value):
            return False
        if key.endswith("color"):
            return all(0 <= x <= 1 for x in value)
        if key == "scale" or key.endswith("size"):
            return all(x > 0 for x in value)
        return key != "movement_bounds" or value[2] > 0 and value[3] > 0
    if not _number(value):
        return False
    integer_keys = {"version", "rows", "columns", "row", "column", "pea_damage", "maximum_health", "burst_size", "armor_drop_health", "hand_drop_health", "window_width", "window_height", "minimum_width", "minimum_height", "viewport_width", "viewport_height", "medium_value", "initial_value"}
    if key in integer_keys and int(value) != value:
        return False
    if key in {"spawn_interval", "medium_value", "fall_speed"}:
        return value > 0
    if key == "version":
        return value == 1
    if key in {"rows", "columns", "row", "column", "burst_size"}:
        return 1 <= value <= 64
    if key in {"recoil_degrees", "maximum_recoil_degrees", "vault_lean_degrees"}:
        return 0 <= value <= 30
    if key in {"slow_multiplier", "frost_color_strength", "pole_release_fraction", "bounce", "friction"}:
        return 0 <= value <= 1
    if key == "fov":
        return 1 < value < 179
    if key == "pitch_limit_degrees":
        return 0 < value < 90
    if key == "door_open_degrees":
        return 90 <= value <= 170
    if key in {"depth", "wall_thickness", "roof_rise", "door_trigger_distance", "door_speed_degrees"}:
        return value > 0
    positive = {"maximum_health", "shot_interval", "burst_spacing", "recoil_recovery_time", "knockback_deceleration", "maximum_walk_distance", "respawn_delay", "prepare_time", "vault_height", "landing_clearance", "pole_length", "pole_radius", "gravity", "mass", "lifetime", "cell_size", "tile_width", "tile_thickness", "scale", "font_scale", "radius", "height", "inner_radius", "outer_radius", "maximum_distance", "minimum_size", "maximum_size", "distance", "size", "near", "far", "lane_spread_distance", "target_lane_tolerance", "vault_trigger_distance", "zoom_in_factor", "zoom_out_factor"}
    if key in positive or key.endswith("width") or key.endswith("height") and key not in {"surface_height", "ground_height", "walk_bob_height", "lift_height"}:
        return value > 0
    if key in {"yaw_degrees", "pitch_degrees", "minimum_pitch_degrees", "maximum_pitch_degrees", "surface_height", "ground_height", "spin_x_min", "spin_x_max", "spin_y", "spin_z", "offset_z"}:
        return True
    return value >= 0


def read_config(path=None):
    path = Path(path) if path else ROOT / "config/game_config.json"
    baseline = defaults()
    result = json.loads(json.dumps(baseline))
    try:
        raw = json.loads(path.read_text(encoding="utf-8-sig"))
        if not isinstance(raw, dict):
            raise ValueError("top-level must be an object")
    except (OSError, ValueError) as error:
        warnings.warn(f"{path}: {error}; using embedded defaults")
        return result

    def merge(raw, base, location=""):
        result = json.loads(json.dumps(base))
        allowed = dict(base)
        if location.count(".") == 2 and location.startswith(("plants.types.", "zombies.types.")):
            allowed = {**baseline[location.split('.')[0]]["common"], **base}
        for key, value in raw.items():
            current = f"{location}.{key}" if location else key
            if key not in allowed:
                warnings.warn(f"{path} [{current}]: unknown field ignored")
            elif isinstance(allowed[key], dict):
                if isinstance(value, dict):
                    result[key] = merge(value, allowed[key], current)
                else:
                    warnings.warn(f"{path} [{current}]: expected object; using default")
            elif valid(value, allowed[key], key):
                result[key] = value
            else:
                warnings.warn(f"{path} [{current}]: invalid type/range; using default")
        return result

    result = merge(raw, result)
    house = result["house"]
    if house['width'] <= house['door_width'] + house['wall_thickness'] * 2 or house['depth'] <= house['wall_thickness'] * 2 or house['wall_height'] <= house['door_height'] + .15 or house['door_height'] < 2 or house['door_width'] < 1:
        warnings.warn(f"{path} [house]: invalid house/door dimensions; using default house")
        result["house"] = baseline["house"]
    lawn = result["lawn"]
    if lawn["tile_width"] > lawn["cell_size"] or any(p["row"] > lawn["rows"] or p["column"] > lawn["columns"] for p in result["placements"].values()):
        warnings.warn(f"{path} [lawn / placements]: layout conflict; using default layout")
        result["lawn"] = baseline["lawn"]
        result["placements"] = baseline["placements"]
    return result


def entity_stats(config, key):
    for group in ("plants", "zombies"):
        if key in config[group]["types"]:
            return {**config[group]["common"], **config[group]["types"][key]}
    if key == "crazy_dave":
        return config["dave"]
    if key == "main":
        return config["respawn"]
    return {}
