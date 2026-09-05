"""Bake one shared PBR atlas and publish the three Hoplite V2 body LODs.

The sources are never overwritten. UVMap is the original texture UV,
UVMap.001 is rebuilt deterministically as the visual atlas UV, and UVMap.002
is the 3DGen dismemberment-zone contract that must remain untouched.

Run from the project root:
  blender --background --factory-startup --python \
    tools/enemy_v2/build_hoplite_body_atlas.py -- [resolution]
"""

from __future__ import annotations

from array import array
import hashlib
import json
from pathlib import Path
import sys
from typing import Iterable

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_LODS = (
    PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/lods/hoplite_body_lod0_22k.gltf",
    PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/lods/hoplite_body_lod1_8k.gltf",
    PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/lods/hoplite_body_lod2_2k.gltf",
)
OUTPUT_ROOT = PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/atlased"
OUTPUT_LODS = OUTPUT_ROOT / "lods"
OUTPUT_TEXTURES = OUTPUT_ROOT / "textures"
REPORT_PATH = OUTPUT_ROOT / "hoplite_body_atlas.report.json"

BODY_NAME = "SPARTAN_character_body"
SOURCE_UV = "UVMap"
ATLAS_UV = "UVMap.001"
ZONE_UV = "UVMap.002"
CUTOUT_MATERIALS = {"M_Crest.001", "M_Sclera.001"}
BRONZE_MATERIALS = {"M_Armor3.001", "M_Armor.001", "M_Armor2.001", "Armor.001", "Armor2.001"}
ATLAS_BASENAME = "hoplite_body_atlas"
BAKE_MARGIN = 16
ATLAS_COLUMNS = 4
# The source's bronze is authored as a very dark metallic albedo and gets most
# of its visible colour from per-material reflections. After consolidation that
# made the cuirass read as black in Godot's battlefield lighting. Preserve the
# authored hue, but bake a conservative bronze floor into warm metallic texels
# and keep a small diffuse contribution so the armour remains bronze even when
# reflection probes or sky lighting are weak.
WARM_METAL_MAX_METALLIC = 0.72
WARM_METAL_MIN_ROUGHNESS = 0.30
WARM_METAL_GAMMA = 0.56
WARM_METAL_LINEAR_FLOOR = (0.34, 0.25, 0.11)


def cli_resolution() -> int:
    separator = sys.argv.index("--") if "--" in sys.argv else -1
    value = int(sys.argv[separator + 1]) if separator >= 0 and separator + 1 < len(sys.argv) else 4096
    if value not in {512, 1024, 2048, 4096, 8192}:
        raise ValueError("Atlas resolution must be 512, 1024, 2048, 4096 or 8192")
    return value


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_source(path: Path) -> bpy.types.Object:
    if not path.is_file():
        raise FileNotFoundError(path)
    bpy.ops.import_scene.gltf(filepath=str(path))
    body = bpy.data.objects.get(BODY_NAME)
    if body is None or body.type != "MESH":
        raise RuntimeError(f"{BODY_NAME} missing from {path}")
    required_uvs = {SOURCE_UV, ATLAS_UV, ZONE_UV}
    actual_uvs = set(body.data.uv_layers.keys())
    if not required_uvs.issubset(actual_uvs):
        raise RuntimeError(f"{path.name} UV contract mismatch: {sorted(actual_uvs)}")
    if len(body.vertex_groups) != 23:
        raise RuntimeError(f"{path.name} has {len(body.vertex_groups)} vertex groups instead of 23")
    # Imported material previews/helpers must never enter the runtime package.
    helper = bpy.data.objects.get("Icosphere")
    if helper is not None:
        bpy.data.objects.remove(helper, do_unlink=True)
    return body


def material_principled(material: bpy.types.Material) -> bpy.types.Node | None:
    if material.node_tree is None:
        return None
    return next((node for node in material.node_tree.nodes if node.bl_idname == "ShaderNodeBsdfPrincipled"), None)


def material_output(material: bpy.types.Material) -> bpy.types.Node:
    if material.node_tree is None:
        raise RuntimeError(f"Material {material.name} has no node tree")
    result = next((node for node in material.node_tree.nodes if node.bl_idname == "ShaderNodeOutputMaterial" and node.is_active_output), None)
    if result is None:
        raise RuntimeError(f"Material {material.name} has no active output")
    return result


def force_source_uv(material: bpy.types.Material) -> None:
    """Keep source textures on UV0 while UV1 is active for the bake target."""
    if material.node_tree is None:
        return
    tree = material.node_tree
    uv = tree.nodes.new("ShaderNodeUVMap")
    uv.name = "ATLAS_SourceUV"
    uv.uv_map = SOURCE_UV
    for node in tree.nodes:
        if node.bl_idname != "ShaderNodeTexImage" or node.name.startswith("ATLAS_Target"):
            continue
        vector = node.inputs.get("Vector")
        if vector is not None and not vector.is_linked:
            tree.links.new(uv.outputs["UV"], vector)


def body_materials(body: bpy.types.Object) -> list[bpy.types.Material]:
    result = [material for material in body.data.materials if material is not None]
    if len(result) < 2:
        raise RuntimeError("Body does not contain the expected source materials")
    return result


def build_material_layout(body: bpy.types.Object, resolution: int) -> dict[str, dict[str, object]]:
    """Allocate one deterministic cell per source material.

    Source UVs are normalized by their actual material bounds instead of being
    wrapped. This preserves intentional 0..2 tiling and gives every material the
    same transform on every decimated LOD.
    """
    names = [material.name if material is not None else "" for material in body.data.materials]
    source = body.data.uv_layers[SOURCE_UV]
    bounds: dict[str, list[float]] = {}
    for polygon in body.data.polygons:
        name = names[polygon.material_index]
        current = bounds.setdefault(name, [float("inf"), float("inf"), float("-inf"), float("-inf")])
        for loop_index in polygon.loop_indices:
            uv = source.data[loop_index].uv
            current[0] = min(current[0], uv.x)
            current[1] = min(current[1], uv.y)
            current[2] = max(current[2], uv.x)
            current[3] = max(current[3], uv.y)
    ordered_names = [name for name in names if name in bounds]
    rows = (len(ordered_names) + ATLAS_COLUMNS - 1) // ATLAS_COLUMNS
    padding = BAKE_MARGIN / float(resolution)
    cell_width = 1.0 / float(ATLAS_COLUMNS)
    cell_height = 1.0 / float(rows)
    result: dict[str, dict[str, object]] = {}
    for index, name in enumerate(ordered_names):
        minimum_u, minimum_v, maximum_u, maximum_v = bounds[name]
        column = index % ATLAS_COLUMNS
        row = index // ATLAS_COLUMNS
        result[name] = {
            "slot": index,
            "bounds": [minimum_u, minimum_v, maximum_u, maximum_v],
            "cell": [column, row],
            "offset": [column * cell_width + padding, row * cell_height + padding],
            "scale": [cell_width - padding * 2.0, cell_height - padding * 2.0],
        }
    return result


def apply_material_layout(body: bpy.types.Object, layout: dict[str, dict[str, object]]) -> None:
    names = [material.name if material is not None else "" for material in body.data.materials]
    source = body.data.uv_layers[SOURCE_UV]
    target = body.data.uv_layers[ATLAS_UV]
    for polygon in body.data.polygons:
        name = names[polygon.material_index]
        if name not in layout:
            raise RuntimeError(f"No atlas layout for {name} on {body.name}")
        entry = layout[name]
        minimum_u, minimum_v, maximum_u, maximum_v = entry["bounds"]
        offset_u, offset_v = entry["offset"]
        scale_u, scale_v = entry["scale"]
        extent_u = max(maximum_u - minimum_u, 1.0e-6)
        extent_v = max(maximum_v - minimum_v, 1.0e-6)
        for loop_index in polygon.loop_indices:
            uv = source.data[loop_index].uv
            target.data[loop_index].uv = (
                offset_u + (uv.x - minimum_u) / extent_u * scale_u,
                offset_v + (uv.y - minimum_v) / extent_v * scale_v,
            )
    target.active_render = True


def create_bake_image(name: str, resolution: int, colorspace: str, color: tuple[float, float, float, float]) -> bpy.types.Image:
    existing = bpy.data.images.get(name)
    if existing is not None:
        bpy.data.images.remove(existing)
    image = bpy.data.images.new(name, width=resolution, height=resolution, alpha=True, float_buffer=False)
    image.generated_color = color
    image.colorspace_settings.name = colorspace
    return image


def set_bake_targets(materials: Iterable[bpy.types.Material], image: bpy.types.Image) -> None:
    for material in materials:
        if material.node_tree is None:
            continue
        tree = material.node_tree
        node = tree.nodes.get("ATLAS_Target")
        if node is None:
            node = tree.nodes.new("ShaderNodeTexImage")
            node.name = "ATLAS_Target"
            node.label = "ATLAS bake target"
        node.image = image
        for candidate in tree.nodes:
            candidate.select = False
        node.select = True
        tree.nodes.active = node


def configure_bake(body: bpy.types.Object) -> None:
    scene = bpy.context.scene
    # Baking is a Cycles operation in Blender 5.2. One sample is sufficient for
    # deterministic material-channel transfer because no lighting is evaluated.
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.render.bake.margin = BAKE_MARGIN
    scene.render.bake.use_clear = True
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    body.data.uv_layers.active = body.data.uv_layers[ATLAS_UV]
    body.data.uv_layers[ATLAS_UV].active_render = True


def bake_diffuse(body: bpy.types.Object, materials: list[bpy.types.Material], image: bpy.types.Image) -> None:
    set_bake_targets(materials, image)
    configure_bake(body)
    bpy.ops.object.bake(type="DIFFUSE")


def bake_normal(body: bpy.types.Object, materials: list[bpy.types.Material], image: bpy.types.Image) -> None:
    set_bake_targets(materials, image)
    configure_bake(body)
    bpy.context.scene.render.bake.normal_space = "TANGENT"
    bpy.ops.object.bake(type="NORMAL")


def bake_scalar(
    body: bpy.types.Object,
    materials: list[bpy.types.Material],
    image: bpy.types.Image,
    socket_name: str,
) -> None:
    restorations: list[tuple[bpy.types.Material, bpy.types.Node, bpy.types.Node, bpy.types.NodeSocket]] = []
    for material in materials:
        tree = material.node_tree
        shader = material_principled(material)
        output = material_output(material)
        if tree is None or shader is None:
            raise RuntimeError(f"Cannot bake {socket_name} from {material.name}")
        source_input = shader.inputs.get(socket_name)
        if source_input is None:
            raise RuntimeError(f"{material.name} has no {socket_name} socket")
        original_shader_socket = next((link.from_socket for link in output.inputs["Surface"].links), shader.outputs[0])
        emission = tree.nodes.new("ShaderNodeEmission")
        if source_input.is_linked:
            tree.links.new(source_input.links[0].from_socket, emission.inputs["Color"])
        else:
            value = float(source_input.default_value)
            emission.inputs["Color"].default_value = (value, value, value, 1.0)
        for link in list(output.inputs["Surface"].links):
            tree.links.remove(link)
        tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
        restorations.append((material, output, emission, original_shader_socket))
    set_bake_targets(materials, image)
    configure_bake(body)
    bpy.ops.object.bake(type="EMIT")
    for material, output, emission, original_socket in restorations:
        tree = material.node_tree
        for link in list(output.inputs["Surface"].links):
            tree.links.remove(link)
        tree.links.new(original_socket, output.inputs["Surface"])
        tree.nodes.remove(emission)


def save_png(image: bpy.types.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()


def pixels(image: bpy.types.Image) -> array:
    result = array("f", [0.0]) * (image.size[0] * image.size[1] * 4)
    image.pixels.foreach_get(result)
    return result


def pack_base_alpha(base: bpy.types.Image, alpha: bpy.types.Image) -> None:
    base_pixels = pixels(base)
    alpha_pixels = pixels(alpha)
    for index in range(0, len(base_pixels), 4):
        base_pixels[index + 3] = alpha_pixels[index]
    base.pixels.foreach_set(base_pixels)
    base.update()


def stabilize_warm_metal_appearance(
    base: bpy.types.Image,
    roughness: bpy.types.Image,
    metallic: bpy.types.Image,
    layout: dict[str, dict[str, object]],
) -> dict[str, int | float]:
    """Keep the source bronze readable without turning non-metal skin/cloth bronze.

    Blender image pixels are linear here. Only metallic texels inside the known
    bronze source-material cells are adjusted. This intentionally duplicates a
    little of the reflected bronze into base colour: the visual contract is more
    important than relying on a particular runtime sky/reflection setup.
    """
    base_pixels = pixels(base)
    roughness_pixels = pixels(roughness)
    metallic_pixels = pixels(metallic)
    adjusted = 0
    metallic_sum_before = 0.0
    metallic_sum_after = 0.0
    width, height = base.size
    for material_name in BRONZE_MATERIALS:
        if material_name not in layout:
            continue
        entry = layout[material_name]
        offset_u, offset_v = entry["offset"]
        scale_u, scale_v = entry["scale"]
        minimum_x = max(0, int(offset_u * width))
        maximum_x = min(width, int((offset_u + scale_u) * width) + 1)
        minimum_y = max(0, int(offset_v * height))
        maximum_y = min(height, int((offset_v + scale_v) * height) + 1)
        for y in range(minimum_y, maximum_y):
            for x in range(minimum_x, maximum_x):
                index = (y * width + x) * 4
                metal = max(0.0, min(1.0, metallic_pixels[index]))
                if metal < 0.30:
                    continue
                strength = min(1.0, (metal - 0.30) / 0.70)
                for channel, floor in enumerate(WARM_METAL_LINEAR_FLOOR):
                    source = max(0.0, min(1.0, base_pixels[index + channel]))
                    lifted = max(source ** WARM_METAL_GAMMA, floor)
                    base_pixels[index + channel] = source + (lifted - source) * strength
                metallic_sum_before += metal
                stabilized_metal = min(metal, WARM_METAL_MAX_METALLIC)
                metallic_pixels[index] = stabilized_metal
                metallic_pixels[index + 1] = stabilized_metal
                metallic_pixels[index + 2] = stabilized_metal
                metallic_sum_after += stabilized_metal
                stabilized_roughness = max(roughness_pixels[index], WARM_METAL_MIN_ROUGHNESS)
                roughness_pixels[index] = stabilized_roughness
                roughness_pixels[index + 1] = stabilized_roughness
                roughness_pixels[index + 2] = stabilized_roughness
                adjusted += 1
    base.pixels.foreach_set(base_pixels)
    base.update()
    roughness.pixels.foreach_set(roughness_pixels)
    roughness.update()
    metallic.pixels.foreach_set(metallic_pixels)
    metallic.update()
    return {
        "adjusted_texels": adjusted,
        "metallic_sum_before": metallic_sum_before,
        "metallic_sum_after": metallic_sum_after,
    }


def pack_metallic_roughness(
    roughness: bpy.types.Image,
    metallic: bpy.types.Image,
    output: bpy.types.Image,
) -> None:
    roughness_pixels = pixels(roughness)
    metallic_pixels = pixels(metallic)
    packed = array("f", [1.0]) * len(roughness_pixels)
    for index in range(0, len(packed), 4):
        packed[index] = 1.0
        packed[index + 1] = roughness_pixels[index]
        packed[index + 2] = metallic_pixels[index]
        packed[index + 3] = 1.0
    output.pixels.foreach_set(packed)
    output.update()


def bake_atlases(
    body: bpy.types.Object,
    resolution: int,
) -> tuple[dict[str, Path], dict[str, dict[str, object]], dict[str, int | float]]:
    materials = body_materials(body)
    layout = build_material_layout(body, resolution)
    apply_material_layout(body, layout)
    for material in materials:
        force_source_uv(material)
    base = create_bake_image("HopliteAtlas_BaseColor", resolution, "sRGB", (0.0, 0.0, 0.0, 1.0))
    alpha = create_bake_image("HopliteAtlas_Alpha", resolution, "Non-Color", (1.0, 1.0, 1.0, 1.0))
    normal = create_bake_image("HopliteAtlas_Normal", resolution, "Non-Color", (0.5, 0.5, 1.0, 1.0))
    roughness = create_bake_image("HopliteAtlas_Roughness", resolution, "Non-Color", (0.5, 0.5, 0.5, 1.0))
    metallic = create_bake_image("HopliteAtlas_Metallic", resolution, "Non-Color", (0.0, 0.0, 0.0, 1.0))
    mr = create_bake_image("HopliteAtlas_MetallicRoughness", resolution, "Non-Color", (1.0, 0.5, 0.0, 1.0))

    bake_diffuse(body, materials, base)
    bake_scalar(body, materials, alpha, "Alpha")
    bake_normal(body, materials, normal)
    bake_scalar(body, materials, roughness, "Roughness")
    bake_scalar(body, materials, metallic, "Metallic")
    appearance_report = stabilize_warm_metal_appearance(base, roughness, metallic, layout)
    pack_base_alpha(base, alpha)
    pack_metallic_roughness(roughness, metallic, mr)

    paths = {
        "base": OUTPUT_TEXTURES / f"{ATLAS_BASENAME}_basecolor.png",
        "normal": OUTPUT_TEXTURES / f"{ATLAS_BASENAME}_normal.png",
        "mr": OUTPUT_TEXTURES / f"{ATLAS_BASENAME}_metallic_roughness.png",
    }
    save_png(base, paths["base"])
    save_png(normal, paths["normal"])
    save_png(mr, paths["mr"])
    return paths, layout, appearance_report


def load_atlas_images(paths: dict[str, Path]) -> dict[str, bpy.types.Image]:
    result: dict[str, bpy.types.Image] = {}
    for key, path in paths.items():
        image = bpy.data.images.load(str(path), check_existing=True)
        image.colorspace_settings.name = "sRGB" if key == "base" else "Non-Color"
        result[key] = image
    return result


def atlas_material(name: str, images: dict[str, bpy.types.Image], cutout: bool) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    uv = tree.nodes.new("ShaderNodeUVMap")
    uv.uv_map = ATLAS_UV
    base = tree.nodes.new("ShaderNodeTexImage")
    base.image = images["base"]
    base.interpolation = "Linear"
    normal = tree.nodes.new("ShaderNodeTexImage")
    normal.image = images["normal"]
    normal.interpolation = "Linear"
    mr = tree.nodes.new("ShaderNodeTexImage")
    mr.image = images["mr"]
    mr.interpolation = "Linear"
    separate = tree.nodes.new("ShaderNodeSeparateColor")
    normal_map = tree.nodes.new("ShaderNodeNormalMap")
    tree.links.new(uv.outputs["UV"], base.inputs["Vector"])
    tree.links.new(uv.outputs["UV"], normal.inputs["Vector"])
    tree.links.new(uv.outputs["UV"], mr.inputs["Vector"])
    tree.links.new(base.outputs["Color"], shader.inputs["Base Color"])
    if cutout:
        # Blender 5's glTF exporter derives MASK from the node graph itself.
        # An explicit alpha comparison exports alphaMode=MASK instead of the
        # slower sorted BLEND mode.
        alpha_clip = tree.nodes.new("ShaderNodeMath")
        alpha_clip.operation = "GREATER_THAN"
        alpha_clip.inputs[1].default_value = 0.5
        tree.links.new(base.outputs["Alpha"], alpha_clip.inputs[0])
        tree.links.new(alpha_clip.outputs[0], shader.inputs["Alpha"])
        if hasattr(material, "surface_render_method"):
            material.surface_render_method = "DITHERED"
        material.alpha_threshold = 0.5
    tree.links.new(mr.outputs["Color"], separate.inputs["Color"])
    tree.links.new(separate.outputs["Green"], shader.inputs["Roughness"])
    tree.links.new(separate.outputs["Blue"], shader.inputs["Metallic"])
    tree.links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    tree.links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
    tree.links.new(shader.outputs[0], output.inputs["Surface"])
    material["spartan_atlas"] = True
    material["spartan_surface_class"] = "cutout" if cutout else "opaque"
    return material


def replace_body_materials(body: bpy.types.Object, images: dict[str, bpy.types.Image]) -> None:
    old_names = [material.name if material is not None else "" for material in body.data.materials]
    polygon_classes = [1 if old_names[polygon.material_index] in CUTOUT_MATERIALS else 0 for polygon in body.data.polygons]
    opaque = atlas_material("HopliteBodyAtlas_Opaque", images, False)
    cutout = atlas_material("HopliteBodyAtlas_Cutout", images, True)
    body.data.materials.clear()
    body.data.materials.append(opaque)
    body.data.materials.append(cutout)
    for polygon, material_class in zip(body.data.polygons, polygon_classes):
        polygon.material_index = material_class
    body.data.uv_layers[ATLAS_UV].active_render = True


def export_scene(source: Path, body: bpy.types.Object) -> Path:
    OUTPUT_LODS.mkdir(parents=True, exist_ok=True)
    output = OUTPUT_LODS / f"{source.stem}_atlas.gltf"
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLTF_SEPARATE",
        export_image_format="AUTO",
        export_keep_originals=True,
        export_extras=True,
        export_yup=True,
        export_animations=False,
        export_skins=True,
        export_morph=False,
        export_lights=False,
        export_cameras=False,
    )
    if not output.is_file():
        raise RuntimeError(f"glTF export failed: {output}")
    return output


def stamp_atlas_contract(body: bpy.types.Object, atlas_paths: dict[str, Path], resolution: int) -> None:
    # The external PNGs are dependencies of the glTF, but their content can
    # change without the JSON topology changing. Embedding the deterministic
    # texture digest forces Godot to reimport the scene on a regenerated atlas.
    body["spartan_atlas_schema"] = 1
    body["spartan_atlas_resolution"] = resolution
    body["spartan_atlas_digest"] = ":".join(sha256(atlas_paths[key])[:16] for key in ("base", "normal", "mr"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_body(body: bpy.types.Object, source: Path) -> dict[str, object]:
    armatures = [modifier.object for modifier in body.modifiers if modifier.type == "ARMATURE" and modifier.object]
    armature = armatures[0] if armatures else None
    return {
        "source": str(source.relative_to(PROJECT_ROOT)),
        "triangles": sum(len(polygon.vertices) - 2 for polygon in body.data.polygons),
        "vertices": len(body.data.vertices),
        "body_materials": len(body.data.materials),
        "body_material_names": [material.name for material in body.data.materials],
        "vertex_groups": len(body.vertex_groups),
        "bones": len(armature.data.bones) if armature is not None else 0,
        "uv_layers": list(body.data.uv_layers.keys()),
        "zone_uv_max": max((datum.uv.x for datum in body.data.uv_layers[ZONE_UV].data), default=-1.0),
    }


def main() -> None:
    resolution = cli_resolution()
    OUTPUT_TEXTURES.mkdir(parents=True, exist_ok=True)
    reports: list[dict[str, object]] = []

    reset_scene()
    lod0_body = import_source(SOURCE_LODS[0])
    atlas_paths, material_layout, appearance_report = bake_atlases(lod0_body, resolution)
    images = load_atlas_images(atlas_paths)
    replace_body_materials(lod0_body, images)
    stamp_atlas_contract(lod0_body, atlas_paths, resolution)
    lod0_output = export_scene(SOURCE_LODS[0], lod0_body)
    lod0_report = validate_body(lod0_body, SOURCE_LODS[0])
    lod0_report["output"] = str(lod0_output.relative_to(PROJECT_ROOT))
    reports.append(lod0_report)

    for source in SOURCE_LODS[1:]:
        reset_scene()
        body = import_source(source)
        apply_material_layout(body, material_layout)
        images = load_atlas_images(atlas_paths)
        replace_body_materials(body, images)
        stamp_atlas_contract(body, atlas_paths, resolution)
        output = export_scene(source, body)
        report = validate_body(body, source)
        report["output"] = str(output.relative_to(PROJECT_ROOT))
        reports.append(report)

    report = {
        "status": "PASS",
        "resolution": resolution,
        "source_uv": SOURCE_UV,
        "atlas_uv": ATLAS_UV,
        "zone_uv": ZONE_UV,
        "material_layout": material_layout,
        "warm_metal_stabilization": {
            **appearance_report,
            "maximum_metallic": WARM_METAL_MAX_METALLIC,
            "minimum_roughness": WARM_METAL_MIN_ROUGHNESS,
            "gamma": WARM_METAL_GAMMA,
            "linear_colour_floor": WARM_METAL_LINEAR_FLOOR,
        },
        "textures": {
            key: {"path": str(path.relative_to(PROJECT_ROOT)), "sha256": sha256(path)}
            for key, path in atlas_paths.items()
        },
        "lods": reports,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("HOPLITE_BODY_ATLAS PASS " + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
