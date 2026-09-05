# Brown mud and leaves PBR replacement

The original `brown_mud_leaves_01` maps were replaced in place on 2026-08-28.
The filenames and Godot import metadata were preserved so existing Forge worlds
continue to resolve the same material paths and UIDs.

The albedo was generated with OpenAI ImageGen, then resized to the project's 1K
runtime budget. The normal and roughness maps were derived from that exact
albedo with `res://tools/forge_pbr_map_builder.gd`; this keeps every PBR channel
spatially aligned and avoids unrelated generated surface details.

## ImageGen prompt

> Use case: stylized-concept. Asset type: tileable game texture, replacement
> albedo for an existing Godot PBR material. Primary request: a seamless ancient
> Mediterranean damp brown mud surface with many very small scattered olive and
> muted green fallen leaves, tiny twigs and fine organic debris. Distribution
> must be statistically uniform across the entire image: no large bare mud patch,
> no dense green patch, no diagonal band, no dark blob, no focal cluster, no
> quadrant structure, no macro-scale feature larger than one tenth of the image.
> Style/medium: believable natural surface with slightly stylized readability,
> albedo/base-color only. Composition/framing: orthographic top-down surface scan,
> square, homogeneous micro-detail suitable for being tiled at least 8 by 8
> across a large terrain. Lighting/mood: completely even neutral diffuse lighting,
> no directional light, no highlights, no shadows, no baked ambient occlusion,
> no wet specular shine. Constraints: left edge connects continuously to right
> edge and top edge to bottom edge; no visible seams; no obvious repeated motif
> or square-grid cue; balanced low-frequency color with most variation at small
> and medium scale; opaque; no text, symbols, logo, border, frame, or watermark.
