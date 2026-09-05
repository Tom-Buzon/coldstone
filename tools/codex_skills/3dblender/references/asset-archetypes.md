# Asset archetypes and budgets

Choose an archetype before choosing mesh operations. Budgets below are starting ranges for a stylized desktop/console game, not universal limits. Lower them for mobile, large crowds, or tiny screen coverage; raise them only when silhouette or deformation visibly benefits.

## Shared decision rules

1. Estimate maximum on-screen size and simultaneous instance count.
2. Reserve geometry for silhouette, deformation, and shadow-casting forms.
3. Budget materials and surfaces alongside triangles: every extra surface can become another draw call.
4. Design collision and attachment contracts before decorative passes.
5. Build LODs by visual error, not by a fixed percentage alone.

| Archetype | Typical LOD0 starting range | Materials | Package priorities |
|---|---:|---:|---|
| Tiny repeated prop / debris | 50-800 tris | 1 | shared mesh/material, no collision unless interactive |
| Repeated foliage clump | 20-500 tris | 1 | alpha scissor/hash, normals, wind data if needed, no unique materials |
| Handheld weapon / equipment | 800-5,000 tris | 1-4 | grip pivot/socket, readable profile, simple hit/collision proxy |
| Ordinary interactive prop | 500-4,000 tris | 1-3 | grounded pivot, convex or primitive collision, damage/interaction metadata |
| Hero prop | 3,000-15,000 tris | 1-4 | close-range bevels, intentional UVs, LODs, authored collision |
| Small modular architecture piece | 1,000-12,000 tris | 1-3 | exact module dimensions, connector pivot, watertight seams, collision proxy |
| Large architecture / traversal module | 8,000-50,000 tris | 1-4 | walkable dimensions, preserved openings, coarse collision, optional occluder |
| Crowd character | 8,000-20,000 tris | 1-3 | one armature, deformation loops, LODs, shared atlas/materials |
| Hero character | 25,000-60,000 tris | 2-6 | deformation quality, facial/hand needs, rig and animation contract |

## Static prop

- Put the origin on the ground at the placement pivot; use center of mass only for physics-driven props.
- Prefer a single render mesh with a small shared material set.
- For a movable `RigidBody3D`, use primitives or a modest convex hull. Never ship a concave render-mesh collider on a moving object.
- If repeated dozens of times, design for shared mesh data and remove unique baked color variation; vary transforms or per-instance shader data instead.

## Weapon or equipment

- Establish grip origin, forward/blade axis, contact segment, overall reach, and attachment transform before modeling.
- Preserve the blade/profile silhouette at every LOD. Reduce studs, wraps, grooves, and radial segments first.
- Use geometry for the edge/ridge only when it changes highlights or profile; use normals/textures for shallow engravings.
- Keep collision/hit geometry separate from the visual mesh. Gameplay may use a capsule/box segment rather than the exported render mesh.

## Modular environment

- Use exact metric module lengths and a consistent grid. Put pivots on connection corners or the center of the base according to placement behavior.
- Keep boundary vertices aligned so adjacent modules do not crack.
- Do not merge deliberate doorways, arches, stairs, mantle lips, or traversal gaps in lower LODs or collision.
- Large opaque modules may need a coarse occluder proxy; thin, perforated, or frequently viewed-through pieces usually do not.

## Traversal geometry

- Treat gameplay dimensions as hard constraints: clear width, rise/run, cover height, mantle lip, gap width, headroom, and slope.
- Author collision as ramps/boxes/low-count hulls. A visually stepped stair often needs a single smooth ramp collider.
- Validate that collision does not bridge gaps or close arches.
- Preserve foot-contact planes and ledge silhouettes before decorative damage.

## Repeated foliage and clutter

- Aim for one surface and one shared material per species or atlas group.
- Use crossed cards, low-sided stems, or compact clumps; do not model leaf veins or tiny stems.
- Disable collision, GI, and shadows for dense ground cover unless gameplay clearly requires them.
- Provide a very cheap far representation or allow Godot import LOD; the primary win comes from `MultiMesh`, shared resources, and culling.

## Destructible asset

- Export intact visual, fractured visual/pieces, and collision variants distinctly.
- Each dynamic fragment needs a meaningful local origin and primitive/convex collision. Keep fragment count proportional to the maximum simultaneous destruction events.
- Close fracture interiors and assign an interior material without multiplying the whole asset's material count.
- LOD the intact object; do not keep high-detail hidden fracture geometry active before destruction.

## Rigged or deforming asset

- Do not generate a new skeleton when the project expects an existing one. Obtain the bone naming, rest pose, scale, and animation contract first.
- Use one armature, clean parent transforms, stable bone names, and no leaf/helper bones in export unless required.
- Spend loops at shoulders, elbows, hips, knees, face, and other deforming areas; reduce density on rigid armor plates.
- Limit weights per vertex to the target engine's supported influence count and normalize them.
- Generate static accessories separately when sharing/instancing them is cheaper than skinning.

## LOD design

- LOD1 usually targets roughly 35-60% of LOD0 triangles; LOD2 often targets 8-25%. These ratios are diagnostics, not goals.
- Preserve silhouette, openings, contact points, and UV/material continuity.
- Remove microdetail objects, bevel segments, radial segments, unseen thickness, and interior detail in that order.
- A hand-authored low LOD is preferable when automatic decimation damages modular borders, hard-surface planes, or gameplay holes.
- Use the same pivot, orientation, bounding intent, material names, and attachment metadata across LODs.
