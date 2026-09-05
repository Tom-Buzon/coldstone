# Camera Occlusion Readability

## Goal

Keep the player readable during dense combat and mobility sequences by fading every
3D visual that enters the corridor between the active TPS camera and the player's
upper body. The feature must work in every playable scene, remain reversible, and
be configurable from the existing global settings menu.

## Runtime tree

```text
HopliteUALNativePlayer (CharacterBody3D)
└── CameraOcclusionFader (Node)
    └── observes CameraYaw/SpringArm3D/Camera3D and the current scene visuals
```

The component is owned by the player because the player is the only runtime object
shared by the combat lab, authored battles, procedural campaign, and Forge worlds.

## Responsibilities

| Owner | Responsibility |
| --- | --- |
| `HopliteCameraOcclusionFader` | Cache scene `GeometryInstance3D` nodes, combine a strict camera-player depth test with a nine-ray corridor and camera-overlap query, animate per-instance material alpha, suppress stale opaque shadows, and restore original render state. |
| `HopliteUALNativePlayer` | Construct and configure the component with the TPS camera rig. |
| `HopliteAudioSettings` | Expose enable, opacity, corridor radius, and outline controls; persist them in `user://hoplite_global_settings_v1.cfg`; broadcast live changes. |

## Data flow

```text
settings changed
  -> ConfigFile display section
  -> nodes in camera_occlusion_fader group
  -> fader applies settings immediately

physics refresh
  -> camera-to-player corridor truncated before the player
  -> cached small-visual AABB intersection + centre-depth validation
  -> nine physics rays for layered buildings, roofs and corridor edges
  -> sphere overlap for walls touching or containing the camera
  -> desired occluder set
  -> render-frame material alpha toward target opacity
  -> original material/shadow/overlay restored on exit
```

No gameplay collision or scene-specific setup is modified. While an object blocks
the camera, the component installs per-instance copies of its `BaseMaterial3D`
surface materials (or a neutral fallback for unsupported shader materials). This
makes alpha fading work with the project's GL Compatibility renderer without
mutating shared authored resources. Exact surface overrides are restored afterward.
The SpringArm collision mask is temporarily cleared so the camera keeps its
requested distance; disabling the feature restores the exact original mask.

## Settings

- Enabled: default `true`.
- Occluder opacity: default `0.12`, range `0.02..0.45`.
- Corridor radius: default `0.42 m`, range `0.10..1.20 m`.
- No outline pass: faded geometry keeps only its authored silhouette.

## Failure handling

- Freed or newly spawned visuals are removed from or added to the cache through
  SceneTree signals.
- Player-owned visuals are always ignored.
- Base terrain nodes are ignored through the `camera_occlusion_ignore` group,
  matching metadata, or the established `terrain` / `ground` / `floor` naming
  convention used by the existing worlds.
- Empty/invalid AABBs are ignored.
- Original render properties are captured per visual and restored on disable,
  scene exit, or when the visual stops occluding.

## Implementation tasks and skills

- [x] Implement global visual detection and reversible fading.
  Skills: `camera-system`, `physics-system`, `3d-essentials`, `shader-basics`.
- [x] Integrate persistent display controls.
  Skills: `godot-ui`, `save-load`.
- [x] Validate parsing, runtime behavior, and settings propagation.
  Skills: `godot-debugging`, `godot-code-review`.
