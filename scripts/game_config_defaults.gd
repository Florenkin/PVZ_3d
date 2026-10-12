extends RefCounted
## Startup fallback; config/game_config.json is the editable source.
const TEXT = """
{
  "version": 1,
  "sun": {
    "enabled": true,
    "spawn_interval": 10.0,
    "medium_value": 50,
    "initial_value": 0,
    "spawn_height": 7.0,
    "fall_speed": 1.4,
    "radius": 0.62,
    "lifetime": 20.0
  },
  "lawn": {
    "rows": 5,
    "columns": 9,
    "cell_size": 2.4,
    "surface_height": 0.025,
    "tile_width": 2.36,
    "tile_thickness": 0.435,
    "light_color": [
      0.52157,
      0.71373,
      0.35686,
      1
    ],
    "dark_color": [
      0.43529,
      0.63529,
      0.29804,
      1
    ]
  },
  "placements": {
    "peashooter": {
      "row": 3,
      "column": 2,
      "yaw_degrees": 0
    },
    "repeater": {
      "row": 2,
      "column": 2,
      "yaw_degrees": 0
    },
    "threepeater": {
      "row": 4,
      "column": 2,
      "yaw_degrees": 0
    },
    "gatling_pea": {
      "row": 1,
      "column": 2,
      "yaw_degrees": 0
    },
    "snow_pea": {
      "row": 5,
      "column": 2,
      "yaw_degrees": 0
    },
    "wall_nut": {
      "row": 5,
      "column": 8,
      "yaw_degrees": 0
    },
    "crazy_dave": {
      "row": 3,
      "column": 1,
      "yaw_degrees": -90
    },
    "zombie": {
      "row": 3,
      "column": 9,
      "yaw_degrees": 90
    },
    "conehead_zombie": {
      "row": 2,
      "column": 9,
      "yaw_degrees": 90
    },
    "buckethead_zombie": {
      "row": 1,
      "column": 9,
      "yaw_degrees": 90
    },
    "pole_vaulting_zombie": {
      "row": 5,
      "column": 9,
      "yaw_degrees": 90
    },
    "newspaper_zombie": {
      "row": 4,
      "column": 9,
      "yaw_degrees": 90
    }
  },
  "plants": {
    "common": {
      "idle_animation_enabled": true,
      "idle_amplitude": 0.018,
      "idle_speed": 1.5,
      "combat_enabled": true,
      "shot_interval": 1.5,
      "pea_damage": 20,
      "pea_speed": 10.0,
      "recoil_degrees": 20.0,
      "recoil_recovery_time": 0.28,
      "maximum_recoil_degrees": 30.0,
      "idle_bend_degrees": 1.0313240312354817,
      "idle_bend_speed": 0.7,
      "leaf_sway_degrees": 0.8594366926962348,
      "leaf_sway_speed": 0.65,
      "target_lane_tolerance": 0.6
    },
    "types": {
      "peashooter": {},
      "repeater": {
        "burst_size": 2,
        "burst_spacing": 0.18
      },
      "gatling_pea": {
        "burst_size": 4,
        "burst_spacing": 0.18
      },
      "threepeater": {
        "lane_spread_distance": 3.6
      },
      "snow_pea": {
        "slow_multiplier": 0.5,
        "slow_duration": 10.0
      }
    }
  },
  "zombies": {
    "common": {
      "maximum_health": 200,
      "walk_speed": 0.5,
      "is_ground_zombie": true,
      "movement_enabled": true,
      "knockback_speed": 1.4,
      "knockback_deceleration": 10.0,
      "maximum_walk_distance": 19.9,
      "flash_duration": 0.5,
      "recoil_degrees": 30.0,
      "recoil_recovery_time": 0.5,
      "armor_drop_health": 200,
      "hand_drop_health": 100,
      "walk_animation_speed": 3.0,
      "walk_bob_height": 0.012,
      "leg_swing_degrees": 4.583662361046586,
      "frost_color": [
        0.4784313725,
        0.7882352941,
        0.9333333333,
        1
      ],
      "frost_color_strength": 0.48
    },
    "types": {
      "zombie": {},
      "conehead_zombie": {
        "maximum_health": 570
      },
      "buckethead_zombie": {
        "maximum_health": 1370
      },
      "pole_vaulting_zombie": {
        "maximum_health": 500,
        "vault_enabled": true,
        "vault_trigger_distance": 1.3,
        "vault_height": 1.85,
        "landing_clearance": 1.1,
        "prepare_time": 0.28,
        "pole_length": 3.6,
        "pole_radius": 0.04,
        "pole_release_fraction": 0.45,
        "planted_tip_offset": 0.3,
        "vault_lean_degrees": 16.04281826366305,
        "flight_leg_degrees": 34.37746770784939,
        "target_lane_tolerance": 0.6
      },
      "newspaper_zombie": {
        "maximum_health": 350,
        "newspaper_drop_health": 200,
        "anger_pause_duration": 1.0,
        "enraged_speed_multiplier": 2.0
      }
    }
  },
  "respawn": {
    "auto_respawn_enabled": true,
    "respawn_delay": 1.0
  },
  "projectiles": {
    "maximum_distance": 30.0,
    "radius": 0.12,
    "color": [
      0.37,
      0.78,
      0.15,
      1
    ],
    "snow_color": [
      0.56863,
      0.85882,
      0.98039,
      1
    ]
  },
  "physics": {
    "gravity": 9.8,
    "debris": {
      "lifetime": 10.0,
      "mass": 1.0,
      "linear_damp": 0.12,
      "angular_damp": 0.8,
      "friction": 0.75,
      "bounce": 0.16
    },
    "parts": {
      "cone": {
        "mass": 0.45,
        "lifetime": 10.0,
        "backward_speed": 1.5,
        "upward_speed": 3.4,
        "side_speed": 0.4,
        "spin_x_min": 5.3,
        "spin_x_max": 5.3,
        "spin_y": 1.2,
        "spin_z": 0.0,
        "bounce": 0.2
      },
      "bucket": {
        "mass": 1.1,
        "lifetime": 10.0,
        "backward_speed": 1.3,
        "upward_speed": 3.0,
        "side_speed": 0.4,
        "spin_x_min": 4.7,
        "spin_x_max": 4.7,
        "spin_y": 1.4,
        "spin_z": 0.8,
        "bounce": 0.14,
        "friction": 0.8
      },
      "hand": {
        "mass": 0.35,
        "lifetime": 10.0,
        "backward_speed": 0.9,
        "upward_speed": 1.8,
        "side_speed": 1.1,
        "spin_x_min": 3.0,
        "spin_x_max": 5.0,
        "spin_y": 0.0,
        "spin_z": 2.0
      },
      "head": {
        "mass": 0.65,
        "lifetime": 10.0,
        "backward_speed": 2.0,
        "upward_speed": 3.2,
        "side_speed": 0.45,
        "spin_x_min": 3.5,
        "spin_x_max": 5.0,
        "spin_y": 1.0,
        "spin_z": 0.0
      },
      "corpse": {
        "mass": 6.0,
        "lifetime": 5.0,
        "backward_speed": 1.1,
        "upward_speed": 0.5,
        "side_speed": 0.0,
        "spin_x_min": 3.8,
        "spin_x_max": 3.8,
        "spin_y": 0.0,
        "spin_z": 0.0,
        "angular_damp": 0.65,
        "bounce": 0.06,
        "initial_tilt_degrees": 6.875493541569878,
        "lift_height": 0.1
      },
      "corpse_arm": {
        "mass": 0.35,
        "lifetime": 5.0
      },
      "pole": {
        "mass": 0.45,
        "lifetime": 10.0,
        "backward_speed": 0.6,
        "upward_speed": 0.7,
        "side_speed": 0.0,
        "spin_x_min": 1.4,
        "spin_x_max": 1.4,
        "spin_y": 0.5,
        "spin_z": 0.0,
        "bounce": 0.1,
        "friction": 0.85
      },
      "newspaper": {
        "mass": 0.12,
        "lifetime": 10.0,
        "backward_speed": 0.8,
        "upward_speed": 1.2,
        "side_speed": 0.3,
        "spin_x_min": 2.0,
        "spin_x_max": 3.0,
        "spin_y": 1.2,
        "spin_z": 0.4,
        "linear_damp": 0.5,
        "angular_damp": 1.2,
        "friction": 0.95,
        "bounce": 0.03
      }
    }
  },
  "dave": {
    "movement_speed": 3.0,
    "mouse_sensitivity": 0.003,
    "waist_height": 0.94,
    "restrict_to_lawn": true,
    "movement_bounds": [
      -10.35,
      -5.55,
      20.7,
      11.1
    ],
    "derive_bounds_from_lawn": true,
    "boundary_inset": 0.45,
    "pitch_limit_degrees": 60.160568488736445
  },
  "cameras": {
    "first_person": {
      "fov": 75.0,
      "near": 0.03,
      "far": 150.0
    },
    "orbit": {
      "minimum_size": 3.0,
      "maximum_size": 30.0,
      "distance": 7.0,
      "yaw_sensitivity": 0.008,
      "pitch_sensitivity": 0.005,
      "minimum_pitch_degrees": 6.875493541569878,
      "maximum_pitch_degrees": 65.89014644004466,
      "zoom_in_factor": 0.91,
      "zoom_out_factor": 1.09
    },
    "plant_view": {
      "yaw_degrees": 37.24225668350351,
      "pitch_degrees": 21.772396214971284,
      "size": 11.8,
      "offset": [
        -0.65,
        0.85,
        0
      ]
    },
    "enemy_view": {
      "yaw_degrees": -37.24225668350351,
      "pitch_degrees": 14.32394487827058,
      "size": 3.4,
      "pole_size": 4.8,
      "target_height": 0.78,
      "armor_target_height": 1.0,
      "newspaper_yaw_degrees": -80.0
    }
  },
  "models": {
    "peashooter": {
      "scale": 1.0,
      "parts": {
        "Stem": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Leaves": {
          "position": [
            0.0,
            0.105,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head": {
          "position": [
            0.03,
            1.225,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head/HeadBody": {
          "position": [
            0.0,
            0.0,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.04,
            0.87,
            0.87
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.50196,
            0.78824,
            0.31765,
            1.0
          ]
        },
        "Head/Muzzle": {
          "position": [
            0.0,
            -0.03,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Stem/Lower": {
          "position": [
            0.025,
            0.415,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            -5.156620156177409
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "height": 0.61,
            "top_radius": 0.072,
            "bottom_radius": 0.095
          },
          "color": [
            0.2902,
            0.61569,
            0.25882,
            1.0
          ]
        },
        "Stem/Upper": {
          "position": [
            0.03,
            0.91,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            5.443099053742821
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "height": 0.5,
            "top_radius": 0.105,
            "bottom_radius": 0.072
          },
          "color": [
            0.2902,
            0.61569,
            0.25882,
            1.0
          ]
        }
      }
    },
    "repeater": {
      "scale": 1.0,
      "parts": {
        "Stem": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Leaves": {
          "position": [
            0.0,
            0.105,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head": {
          "position": [
            0.03,
            1.225,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.06,
            1.04,
            1.04
          ]
        },
        "Head/HeadBody": {
          "position": [
            0.0,
            0.0,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.04,
            0.87,
            0.87
          ],
          "color": [
            0.37647,
            0.70196,
            0.26275,
            1.0
          ]
        },
        "Head/Muzzle": {
          "position": [
            0.0,
            -0.03,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Stem/Lower": {
          "position": [
            0.025,
            0.415,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            -5.156620156177409
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Stem/Upper": {
          "position": [
            0.03,
            0.91,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            5.443099053742821
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        }
      }
    },
    "threepeater": {
      "scale": 1.0,
      "parts": {
        "Stem": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Stem/MainStalk": {
          "position": [
            0.0,
            0.71,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.0,
            1.16,
            1.0
          ],
          "mesh_dimensions": {
            "height": 1.0,
            "top_radius": 0.085,
            "bottom_radius": 0.105
          },
          "color": [
            0.2549,
            0.58824,
            0.23137,
            1.0
          ]
        },
        "Stem/LeftBranch": {
          "position": [
            -0.055,
            0.7849999999999999,
            -0.32
          ],
          "rotation_degrees": [
            -56.10383343663609,
            0.0,
            8.119300632277481
          ],
          "scale": [
            1.0,
            0.7788452991448301,
            1.0
          ],
          "mesh_dimensions": {
            "height": 1.0,
            "top_radius": 0.073,
            "bottom_radius": 0.086
          },
          "color": [
            0.2549,
            0.58824,
            0.23137,
            1.0
          ]
        },
        "Stem/RightBranch": {
          "position": [
            -0.055,
            0.7849999999999999,
            0.32
          ],
          "rotation_degrees": [
            56.10383343663609,
            0.0,
            8.119300632277481
          ],
          "scale": [
            1.0,
            0.7788452991448301,
            1.0
          ],
          "mesh_dimensions": {
            "height": 1.0,
            "top_radius": 0.073,
            "bottom_radius": 0.086
          },
          "color": [
            0.2549,
            0.58824,
            0.23137,
            1.0
          ]
        },
        "Leaves": {
          "position": [
            0.0,
            0.105,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head": {
          "position": [
            0.0,
            1.34,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head/HeadBody": {
          "position": [
            0.0,
            0.0,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            0.7488,
            0.6264,
            0.6264
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.44706,
            0.7451,
            0.28235,
            1.0
          ]
        },
        "Head/Muzzle": {
          "position": [
            0.0,
            -0.021599999999999998,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head/LeftHead": {
          "position": [
            -0.11,
            -0.32,
            -0.64
          ],
          "rotation_degrees": [
            0.0,
            20.626480624709636,
            0.0
          ],
          "scale": [
            0.66,
            0.66,
            0.66
          ]
        },
        "Head/LeftHead/HeadBody": {
          "position": [
            0.0,
            0.0,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.04,
            0.87,
            0.87
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.44706,
            0.7451,
            0.28235,
            1.0
          ]
        },
        "Head/LeftHead/Muzzle": {
          "position": [
            0.0,
            -0.03,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head/RightHead": {
          "position": [
            -0.11,
            -0.32,
            0.64
          ],
          "rotation_degrees": [
            0.0,
            -20.626480624709636,
            0.0
          ],
          "scale": [
            0.66,
            0.66,
            0.66
          ]
        },
        "Head/RightHead/HeadBody": {
          "position": [
            0.0,
            0.0,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.04,
            0.87,
            0.87
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.44706,
            0.7451,
            0.28235,
            1.0
          ]
        },
        "Head/RightHead/Muzzle": {
          "position": [
            0.0,
            -0.03,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        }
      }
    },
    "gatling_pea": {
      "scale": 1.0,
      "parts": {
        "Stem": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Leaves": {
          "position": [
            0.0,
            0.105,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head": {
          "position": [
            0.03,
            1.225,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.03,
            1.02,
            1.02
          ]
        },
        "Head/HeadBody": {
          "position": [
            0.0,
            0.0,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.04,
            0.87,
            0.87
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.39608,
            0.67843,
            0.26275,
            1.0
          ]
        },
        "Head/Muzzle": {
          "position": [
            0.0,
            -0.03,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Stem/Lower": {
          "position": [
            0.025,
            0.415,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            -5.156620156177409
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Stem/Upper": {
          "position": [
            0.03,
            0.91,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            5.443099053742821
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Head/Helmet": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head/Helmet/Dome": {
          "position": [
            0.0,
            0.25,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.13,
            0.32,
            1.1
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.33333,
            0.46667,
            0.27451,
            1.0
          ]
        }
      }
    },
    "snow_pea": {
      "scale": 1.0,
      "parts": {
        "Stem": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Leaves": {
          "position": [
            0.0,
            0.105,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head": {
          "position": [
            0.03,
            1.225,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Head/HeadBody": {
          "position": [
            0.0,
            0.0,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.04,
            0.87,
            0.87
          ],
          "color": [
            0.49804,
            0.79608,
            0.93333,
            1.0
          ]
        },
        "Head/Muzzle": {
          "position": [
            0.0,
            -0.03,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Stem/Lower": {
          "position": [
            0.025,
            0.415,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            -5.156620156177409
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "color": [
            0.36078,
            0.65882,
            0.74118,
            1.0
          ]
        },
        "Stem/Upper": {
          "position": [
            0.03,
            0.91,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            5.443099053742821
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "color": [
            0.36078,
            0.65882,
            0.74118,
            1.0
          ]
        }
      }
    },
    "wall_nut": {
      "scale": 1.0,
      "parts": {
        "Visuals/Shell": {
          "position": [
            0.0,
            0.7,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.04,
            1.4,
            0.88
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.7098,
            0.54118,
            0.31373,
            1.0
          ]
        }
      }
    },
    "zombie": {
      "scale": 1.0,
      "parts": {
        "Visuals/Torso": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs/LeftLeg": {
          "position": [
            -0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.092,
            "height": 0.591058
          },
          "color": [
            0.30588,
            0.42745,
            0.52941,
            1.0
          ]
        },
        "Visuals/Arms/LeftSleeve": {
          "position": [
            -0.315,
            1.0335,
            -0.1075
          ],
          "rotation_degrees": [
            -138.35240724710306,
            0.0,
            11.681206920954326
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.08,
            "height": 0.345737
          },
          "color": [
            0.46275,
            0.32549,
            0.23922,
            1.0
          ]
        },
        "Visuals/Arms/LeftHandAssembly": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/LeftHandAssembly/LeftForearm": {
          "position": [
            -0.35,
            0.942,
            -0.39
          ],
          "rotation_degrees": [
            -81.11934084947974,
            0.0,
            -0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.06,
            "height": 0.323883
          },
          "color": [
            0.5098,
            0.58431,
            0.45882,
            1.0
          ]
        },
        "Visuals/Legs/RightLeg": {
          "position": [
            0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            -3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.092,
            "height": 0.591058
          },
          "color": [
            0.30588,
            0.42745,
            0.52941,
            1.0
          ]
        },
        "Visuals/Arms/RightSleeve": {
          "position": [
            0.315,
            1.0565,
            -0.1075
          ],
          "rotation_degrees": [
            -132.61405596961117,
            0.0,
            -12.895957242358305
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.08,
            "height": 0.313646
          },
          "color": [
            0.46275,
            0.32549,
            0.23922,
            1.0
          ]
        },
        "Visuals/Arms/RightHandAssembly": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/RightHandAssembly/RightForearm": {
          "position": [
            0.35,
            0.988,
            -0.39
          ],
          "rotation_degrees": [
            -81.11934084947977,
            0.0,
            -0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.06,
            "height": 0.323883
          },
          "color": [
            0.5098,
            0.58431,
            0.45882,
            1.0
          ]
        },
        "Visuals/Head": {
          "position": [
            0.0,
            1.475,
            -0.055
          ],
          "rotation_degrees": [
            2.8647889756541165,
            0.0,
            -1.4323944878270582
          ],
          "scale": [
            1,
            1,
            1
          ]
        }
      }
    },
    "conehead_zombie": {
      "scale": 1.0,
      "parts": {
        "Visuals/Torso": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs/LeftLeg": {
          "position": [
            -0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/LeftSleeve": {
          "position": [
            -0.315,
            1.0335,
            -0.1075
          ],
          "rotation_degrees": [
            -138.35240724710306,
            0.0,
            11.681206920954326
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/LeftHandAssembly": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/LeftHandAssembly/LeftForearm": {
          "position": [
            -0.35,
            0.942,
            -0.39
          ],
          "rotation_degrees": [
            -81.11934084947974,
            0.0,
            -0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Legs/RightLeg": {
          "position": [
            0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            -3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/RightSleeve": {
          "position": [
            0.315,
            1.0565,
            -0.1075
          ],
          "rotation_degrees": [
            -132.61405596961117,
            0.0,
            -12.895957242358305
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/RightHandAssembly": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/RightHandAssembly/RightForearm": {
          "position": [
            0.35,
            0.988,
            -0.39
          ],
          "rotation_degrees": [
            -81.11934084947977,
            0.0,
            -0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Head": {
          "position": [
            0.0,
            1.475,
            -0.055
          ],
          "rotation_degrees": [
            2.8647889756541165,
            0.0,
            -1.4323944878270582
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Head/Cone": {
          "position": [
            0.0,
            0.29,
            0.015
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            -4.010704565915763
          ],
          "scale": [
            1,
            1,
            1
          ]
        }
      }
    },
    "buckethead_zombie": {
      "scale": 1.0,
      "parts": {
        "Visuals/Torso": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs/LeftLeg": {
          "position": [
            -0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/LeftSleeve": {
          "position": [
            -0.315,
            1.0335,
            -0.1075
          ],
          "rotation_degrees": [
            -138.35240724710306,
            0.0,
            11.681206920954326
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/LeftHandAssembly": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/LeftHandAssembly/LeftForearm": {
          "position": [
            -0.35,
            0.942,
            -0.39
          ],
          "rotation_degrees": [
            -81.11934084947974,
            0.0,
            -0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Legs/RightLeg": {
          "position": [
            0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            -3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/RightSleeve": {
          "position": [
            0.315,
            1.0565,
            -0.1075
          ],
          "rotation_degrees": [
            -132.61405596961117,
            0.0,
            -12.895957242358305
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/RightHandAssembly": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/RightHandAssembly/RightForearm": {
          "position": [
            0.35,
            0.988,
            -0.39
          ],
          "rotation_degrees": [
            -81.11934084947977,
            0.0,
            -0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Head": {
          "position": [
            0.0,
            1.475,
            -0.055
          ],
          "rotation_degrees": [
            2.8647889756541165,
            0.0,
            -1.4323944878270582
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Head/Bucket": {
          "position": [
            0.0,
            0.18,
            0.015
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            4.010704565915763
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Head/Bucket/Body": {
          "position": [
            0.0,
            0.17,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "height": 0.42,
            "top_radius": 0.265,
            "bottom_radius": 0.335
          },
          "color": [
            0.52941,
            0.60784,
            0.61961,
            1.0
          ]
        }
      }
    },
    "pole_vaulting_zombie": {
      "scale": 1.0,
      "parts": {
        "Visuals/Torso": {
          "position": [
            0.0,
            0.0,
            -0.09
          ],
          "rotation_degrees": [
            -6.875493541569878,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs/LeftLeg": {
          "position": [
            -0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/LeftSleeve": {
          "position": [
            -0.30000000000000004,
            1.2650000000000001,
            -0.28500000000000003
          ],
          "rotation_degrees": [
            -44.99999999999998,
            0.0,
            7.670834784274468
          ],
          "scale": [
            1.0,
            0.8667471893119704,
            1.0
          ],
          "color": [
            0.5098,
            0.58431,
            0.45882,
            1.0
          ]
        },
        "Visuals/Arms/LeftHandAssembly": {
          "position": [
            0.04999999999999999,
            0.8430000000000001,
            0.24699999999999994
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/LeftHandAssembly/LeftForearm": {
          "position": [
            -0.36,
            0.747,
            -0.612
          ],
          "rotation_degrees": [
            6.4830736928972446,
            0.0,
            -2.5859421445402484
          ],
          "scale": [
            1.0,
            1.3686535658861134,
            1.0
          ]
        },
        "Visuals/Legs/RightLeg": {
          "position": [
            0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            -3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ]
        },
        "Visuals/Arms/RightSleeve": {
          "position": [
            0.32,
            1.0699999999999998,
            -0.12
          ],
          "rotation_degrees": [
            146.30993247402023,
            0.0,
            -20.294400347770083
          ],
          "scale": [
            1.0,
            0.7353864963693783,
            1.0
          ],
          "color": [
            0.5098,
            0.58431,
            0.45882,
            1.0
          ]
        },
        "Visuals/Arms/RightHandAssembly": {
          "position": [
            0.020000000000000018,
            1.3769999999999998,
            0.9429999999999998
          ],
          "rotation_degrees": [
            -90.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/RightHandAssembly/RightForearm": {
          "position": [
            0.345,
            1.008,
            -0.4919999999999999
          ],
          "rotation_degrees": [
            -86.98721249581666,
            0.0,
            -3.00863097348483
          ],
          "scale": [
            1.0,
            0.588254920325313,
            1.0
          ]
        },
        "Visuals/Head": {
          "position": [
            0.0,
            1.475,
            -0.25
          ],
          "rotation_degrees": [
            2.8647889756541165,
            0.0,
            -1.4323944878270582
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs/LeftRunnerLeg": {
          "position": [
            -0.13,
            0.68,
            -0.12
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs/RightRunnerLeg": {
          "position": [
            0.13,
            0.68,
            -0.12
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Pole": {
          "position": [
            -0.3,
            1.83,
            0.05
          ],
          "rotation_degrees": [
            90.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        }
      }
    },
    "crazy_dave": {
      "scale": 1.0,
      "parts": {
        "Visuals/Body": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Body/Shirt": {
          "position": [
            0.0,
            1.015,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            0.87,
            0.64,
            0.59
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.95686,
            0.94118,
            0.87451,
            1.0
          ]
        },
        "Visuals/Legs": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs/LeftLeg": {
          "position": [
            -0.175,
            0.37,
            0.025
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            2.0053522829578814
          ],
          "scale": [
            1.0,
            1.0,
            1.12
          ],
          "mesh_dimensions": {
            "radius": 0.115,
            "height": 0.57
          },
          "color": [
            0.30196,
            0.47451,
            0.63137,
            1.0
          ]
        },
        "Visuals/Arms/LeftSleeve": {
          "position": [
            -0.375,
            1.185,
            0.005
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            -14.32394487827058
          ],
          "scale": [
            0.3,
            0.28,
            0.32
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.95686,
            0.94118,
            0.87451,
            1.0
          ]
        },
        "Visuals/Arms/LeftForearm": {
          "position": [
            -0.49,
            0.85,
            -0.025
          ],
          "rotation_degrees": [
            -11.459155902616466,
            0.0,
            0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.078,
            "height": 0.27
          },
          "color": [
            0.92941,
            0.71373,
            0.54118,
            1.0
          ]
        },
        "Visuals/Legs/RightLeg": {
          "position": [
            0.175,
            0.37,
            0.025
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            -2.0053522829578814
          ],
          "scale": [
            1.0,
            1.0,
            1.12
          ],
          "mesh_dimensions": {
            "radius": 0.115,
            "height": 0.57
          },
          "color": [
            0.30196,
            0.47451,
            0.63137,
            1.0
          ]
        },
        "Visuals/Arms/RightSleeve": {
          "position": [
            0.375,
            1.185,
            0.005
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            14.32394487827058
          ],
          "scale": [
            0.3,
            0.28,
            0.32
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.95686,
            0.94118,
            0.87451,
            1.0
          ]
        },
        "Visuals/Arms/RightForearm": {
          "position": [
            0.49,
            0.85,
            -0.025
          ],
          "rotation_degrees": [
            -11.459155902616466,
            0.0,
            0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.078,
            "height": 0.27
          },
          "color": [
            0.92941,
            0.71373,
            0.54118,
            1.0
          ]
        },
        "Visuals/Head": {
          "position": [
            0.0,
            1.5,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Head/CookingPot": {
          "position": [
            0.0,
            0.245,
            0.015
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Head/CookingPot/PotBody": {
          "position": [
            0.0,
            0.005,
            0.0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "height": 0.14,
            "top_radius": 0.285,
            "bottom_radius": 0.307
          },
          "color": [
            0.52941,
            0.62353,
            0.63922,
            1.0
          ]
        }
      }
    },
    "newspaper_zombie": {
      "scale": 1.0,
      "parts": {
        "Visuals/Torso": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Legs/LeftLeg": {
          "position": [
            -0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.092,
            "height": 0.591058
          },
          "color": [
            0.5098,
            0.58431,
            0.45882,
            1.0
          ]
        },
        "Visuals/Arms/LeftSleeve": {
          "position": [
            -0.315,
            1.0335,
            -0.1075
          ],
          "rotation_degrees": [
            -138.35240724710306,
            0.0,
            11.681206920954326
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.08,
            "height": 0.345737
          },
          "color": [
            0.18824,
            0.20784,
            0.18039,
            1.0
          ]
        },
        "Visuals/Arms/LeftHandAssembly": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/LeftHandAssembly/LeftForearm": {
          "position": [
            -0.35,
            0.942,
            -0.39
          ],
          "rotation_degrees": [
            -81.11934084947974,
            0.0,
            -0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.06,
            "height": 0.323883
          },
          "color": [
            0.5098,
            0.58431,
            0.45882,
            1.0
          ]
        },
        "Visuals/Legs/RightLeg": {
          "position": [
            0.14750000000000002,
            0.385,
            0.0275
          ],
          "rotation_degrees": [
            179.51445416999186,
            0.0,
            -3.394801924729904
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.092,
            "height": 0.591058
          },
          "color": [
            0.5098,
            0.58431,
            0.45882,
            1.0
          ]
        },
        "Visuals/Arms/RightSleeve": {
          "position": [
            0.315,
            1.0565,
            -0.1075
          ],
          "rotation_degrees": [
            -132.61405596961117,
            0.0,
            -12.895957242358305
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.08,
            "height": 0.313646
          },
          "color": [
            0.18824,
            0.20784,
            0.18039,
            1.0
          ]
        },
        "Visuals/Arms/RightHandAssembly": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0.0,
            0.0,
            0.0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Arms/RightHandAssembly/RightForearm": {
          "position": [
            0.35,
            0.988,
            -0.39
          ],
          "rotation_degrees": [
            -81.11934084947977,
            0.0,
            -0.0
          ],
          "scale": [
            1.0,
            1.0,
            1.0
          ],
          "mesh_dimensions": {
            "radius": 0.06,
            "height": 0.323883
          },
          "color": [
            0.5098,
            0.58431,
            0.45882,
            1.0
          ]
        },
        "Visuals/Head": {
          "position": [
            0.0,
            1.475,
            -0.055
          ],
          "rotation_degrees": [
            2.8647889756541165,
            0.0,
            -1.4323944878270582
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Torso/Jacket": {
          "position": [
            0,
            0.955,
            0.02
          ],
          "rotation_degrees": [
            0,
            0,
            0
          ],
          "scale": [
            0.6,
            0.61,
            0.38
          ],
          "mesh_dimensions": {
            "radius": 0.5,
            "height": 1.0
          },
          "color": [
            0.18824,
            0.20784,
            0.18039,
            1.0
          ]
        },
        "Visuals/Newspaper": {
          "position": [
            0,
            1.095,
            -0.66
          ],
          "rotation_degrees": [
            -6.875493541569878,
            0,
            0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Head/Glasses": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0,
            0,
            0
          ],
          "scale": [
            1,
            1,
            1
          ]
        },
        "Visuals/Head/AngryEyes": {
          "position": [
            0,
            0,
            0
          ],
          "rotation_degrees": [
            0,
            0,
            0
          ],
          "scale": [
            1,
            1,
            1
          ]
        }
      }
    }
  },
  "display": {
    "window_width": 1280,
    "window_height": 800,
    "minimum_width": 960,
    "minimum_height": 600,
    "viewport_width": 1280,
    "viewport_height": 800
  },
  "environment": {
    "sun_energy": 0.8,
    "fill_energy": 0.08,
    "ambient_energy": 0.4,
    "sun_color": [
      1,
      0.96,
      0.88,
      1
    ],
    "fill_color": [
      0.84,
      0.92,
      1,
      1
    ],
    "ambient_color": [
      0.86,
      0.92,
      1,
      1
    ],
    "sun_rotation_degrees": [
      -53.85803274229738,
      -37.24225668350351,
      -10.313240312354818
    ],
    "fill_rotation_degrees": [
      -28.64788975654116,
      154.6986046853223,
      0.0
    ],
    "shadow_blur": 2.0,
    "shadow_bias": 0.04,
    "shadow_distance": 35.0,
    "backdrop_color": [
      0.62745,
      0.6902,
      0.54902,
      1
    ],
    "ground_size": 200.0,
    "ground_height": -0.55,
    "sky_top_color": [
      0.42,
      0.71,
      0.85,
      1
    ],
    "sky_horizon_color": [
      0.84,
      0.92,
      0.85,
      1
    ],
    "ground_bottom_color": [
      0.46,
      0.57,
      0.36,
      1
    ]
  },
  "ui": {
    "scale": 1.0,
    "font_scale": 1.0,
    "ink_color": [
      0.1607843137254902,
      0.28627450980392155,
      0.21176470588235294,
      1
    ],
    "muted_color": [
      0.4196078431372549,
      0.5019607843137255,
      0.41568627450980394,
      1
    ],
    "panel_color": [
      0.9647058823529412,
      0.9725490196078431,
      0.9294117647058824,
      1
    ],
    "health_bar_size": [
      210,
      8
    ],
    "button_size": [
      112,
      42
    ],
    "sidebar_width": 320.0,
    "sidebar_margin": 24.0
  },
  "house": {
    "enabled": true,
    "width": 9.6,
    "depth": 7.6,
    "wall_height": 3.3,
    "roof_rise": 2.1,
    "wall_thickness": 0.22,
    "front_gap": 1.8,
    "offset_z": 0.0,
    "door_width": 1.8,
    "door_height": 2.65,
    "door_open_degrees": 95.0,
    "door_speed_degrees": 150.0,
    "door_trigger_distance": 2.8,
    "door_close_delay": 1.2,
    "apron_margin": 1.0,
    "porch_depth": 1.4,
    "interior_light_energy": 1.1,
    "wall_color": [
      0.89,
      0.9,
      0.75,
      1.0
    ],
    "trim_color": [
      0.97,
      0.97,
      0.86,
      1.0
    ],
    "roof_color": [
      0.64,
      0.23,
      0.14,
      1.0
    ],
    "roof_tile_color": [
      0.76,
      0.33,
      0.2,
      1.0
    ],
    "brick_color": [
      0.57,
      0.31,
      0.22,
      1.0
    ],
    "window_color": [
      0.47,
      0.75,
      0.83,
      1.0
    ],
    "wood_color": [
      0.54,
      0.34,
      0.2,
      1.0
    ]
  }
}
"""
