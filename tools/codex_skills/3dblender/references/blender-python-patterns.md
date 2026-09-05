# Blender Python patterns for game assets

Use these patterns when adapting the static asset template or writing a specialized generator.

## Reliability and reruns

- Target a declared Blender minimum and prefer capability checks for renamed nodes/properties.
- Make the script idempotent: delete only its `GEN_<asset>` collection and generated data blocks, then recreate stable names.
- Resolve output relative to the saved script, saved `.blend`, or an explicit configuration path. Never hard-code a user's home path.
- Seed a local `random.Random(seed)` instance instead of global time-based randomness. Print the seed.
- Keep render/export actions in `main()` behind configuration switches.

## Data API before context-sensitive operators

Use `bpy.data.meshes.new`, `mesh.from_pydata`, `bpy.data.objects.new`, collection linking, object copies, and `bmesh` for deterministic construction. Operators remain reasonable for primitives, applying modifiers, conversion, UV unwrap, origin changes, rendering, and export, but explicitly set:

1. Object mode.
2. Selection.
3. Active object.
4. Required operator arguments.

Avoid UI-area operators such as `view3d.camera_to_view_selected`; they can fail from the Text Editor or background mode.

## Mesh construction

- `Mesh.from_pydata(vertices, edges, faces)` is ideal for known topology. Follow with `mesh.validate()` and `mesh.update(calc_edges=True)`.
- Use `bmesh` for topology editing, welding, extrusion, bevel-specific preparation, and face-normal recalculation.
- Maintain consistent winding. Recalculate outward normals after procedural booleans or assembled topology.
- Use explicit low segment counts for cylinders, spheres, toruses, and curves. Choose them from projected size, not Blender defaults.
- Overlap hidden structural parts slightly when this prevents visible light gaps after beveling, but remove accidental coplanar faces and z-fighting.
- Apply transforms before a width-sensitive bevel. Use one to three bevel segments in most real-time hard-surface assets.
- Convert construction curves to mesh before export and validate their evaluated triangle count.

## Materials and color

- Set `material.use_nodes = True`; find the Principled BSDF node by type/name.
- Stable core sockets are `Base Color`, `Metallic`, and `Roughness`. Probe alternatives for renamed inputs such as `Specular` / `Specular IOR Level` and `Emission` / `Emission Color`.
- Convert design colors supplied as sRGB hex to linear RGBA before assigning shader inputs. Also set `material.diffuse_color` for viewport previews.
- Keep one material data block per intended shared material. Reuse it across parts and LODs.
- After joining parts, collapse duplicate material slots while remapping polygon indices; otherwise `.001` slots and redundant surfaces can survive export.
- Prefer a metal/rough PBR graph compatible with glTF. Treat Blender-only procedural nodes as preview-only unless baked.

## Instances, collections, and joining

- `copy = source.copy(); copy.data = source.data` creates linked mesh instances. Use this for repeated construction details and preview copies.
- Keep game exports and preview rig in separate collections.
- Joining reduces object/node count but does not eliminate material surfaces. Join static pieces when they share lifetime and transform; keep articulated, destructible, socketed, or reusable pieces separate.
- Do not join collision and render meshes.

## Normals, UVs, and triangulation

- Set smooth shading per polygon deliberately. Mark hard edges or use angle-based smoothing appropriate to the target Blender version.
- Validate normals after booleans, mirror operations, negative scaling, or procedural face creation.
- For textured assets, mark seams according to form, unwrap, normalize texel density, and pack with padding. Smart Project is acceptable for low-priority hard-surface props, not a substitute for inspecting hero assets.
- Flat shading and UV seams split vertices during glTF export. Triangle count alone therefore understates vertex cost; keep needless hard edges and seams low.
- Let glTF triangulate ordinary quads/ngons, or add/apply a Triangulate modifier when fixed diagonals affect shading, animation, baking, or collision.

## Validation evidence

Every generator should report at least:

- Blender version and seed;
- object names and output variants;
- metric dimensions and origin/pivot expectation;
- evaluated triangle count per LOD;
- material slot and surface count;
- unapplied scale/rotation;
- non-manifold or loose geometry when a closed mesh is required;
- UV-layer presence when textures are used;
- exported file paths.

Fail fast when a hard contract is violated. Warnings are appropriate for soft budget overruns only when the user explicitly accepts them.

## Preview for artistic quality

Generate a neutral three-light preview or turntable separate from the export:

- key light reveals the main planes;
- broad fill preserves dark material information;
- warm/cool rim separates the silhouette;
- camera framing derives from the world-space bounding box;
- ground and background stay neutral enough to expose shading errors.

The preview is a diagnostic: it should reveal silhouette, seams, faceting, floating parts, material separation, and ground contact. Do not hide flaws behind bloom, extreme depth of field, or saturated lighting.

## Lessons retained from `blender_plus_python`

Useful reusable ideas from the repository include collection helpers, linked duplication, palette conversion, curve profiles, camera tracking, world/area-light rigs, deterministic scene setup, and standalone `main()` scripts. Adapt them rather than copying the tutorial scaffolds wholesale:

- replace time-based seeds with explicit seeds;
- replace full-file destructive cleanup with generated-collection cleanup;
- replace 128/512-point presentation curves with screen-space segment budgets;
- replace repeated helper copies with one coherent script scaffold;
- add UV, topology, LOD, collision, export, manifest, and measured validation stages;
- avoid obsolete EEVEE and Principled socket assumptions by probing capabilities.

Source: https://github.com/CGArtPython/blender_plus_python (MIT).
