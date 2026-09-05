param(
    [string]$SourceRoot = "C:\Users\suean\Downloads\dismemberedSpartanV2",
    [string]$Lod0Source = "",
    [string]$Lod1Source = "",
    [string]$Lod2Source = "",
    [string]$BlenderPath = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    [string]$GodotPath = "C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

Set-StrictMode -Version Latest

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $algorithm = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = $algorithm.ComputeHash($stream)
            return ([System.BitConverter]::ToString($bytes)).Replace("-", "").ToLowerInvariant()
        }
        finally {
            $algorithm.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$resolvedSource = (Resolve-Path -LiteralPath $SourceRoot -ErrorAction Stop).Path
$manifestPath = Join-Path $resolvedSource "spartan_character_manifest.json"
$bodyPath = Join-Path $resolvedSource "character_body.glb"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing 3DGen manifest: $manifestPath"
}
if (-not (Test-Path -LiteralPath $bodyPath -PathType Leaf)) {
    throw "Missing 3DGen body: $bodyPath"
}
if (-not (Test-Path -LiteralPath $BlenderPath -PathType Leaf)) {
    throw "Blender executable not found: $BlenderPath"
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedFragments = @(
    "head", "upper_arm_l", "forearm_l", "upper_arm_r", "forearm_r",
    "thigh_l", "shin_l", "thigh_r", "shin_r"
)
foreach ($zone in $expectedFragments) {
    $fragment = $manifest.fragments.$zone
    if ($null -eq $fragment) {
        throw "Manifest is missing fragment: $zone"
    }
    $fragmentPath = Join-Path $resolvedSource ([string]$fragment.path)
    if (-not (Test-Path -LiteralPath $fragmentPath -PathType Leaf)) {
        throw "Fragment file is missing: $fragmentPath"
    }
}
if (@($manifest.shared_textures).Count -ne 22) {
    throw "Expected 22 shared textures, found $(@($manifest.shared_textures).Count)"
}
foreach ($texture in $manifest.shared_textures) {
    $texturePath = Join-Path $resolvedSource ([string]$texture.path)
    if (-not (Test-Path -LiteralPath $texturePath -PathType Leaf)) {
        throw "Shared texture is missing: $texturePath"
    }
    $actualHash = Get-Sha256Hex -Path $texturePath
    if ($actualHash -ne ([string]$texture.sha256).ToLowerInvariant()) {
        throw "Shared texture hash mismatch: $texturePath"
    }
}

$packageRoot = Join-Path $projectRoot "assets\characters\enemy_v2\hoplite"
$fragmentRoot = Join-Path $packageRoot "fragments"
$textureRoot = Join-Path $packageRoot "textures"
New-Item -ItemType Directory -Force -Path $fragmentRoot -ErrorAction Stop | Out-Null
New-Item -ItemType Directory -Force -Path $textureRoot -ErrorAction Stop | Out-Null
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $packageRoot "source_3dgen_manifest.json") -Force -ErrorAction Stop
foreach ($zone in $expectedFragments) {
    $fragment = $manifest.fragments.$zone
    Copy-Item -LiteralPath (Join-Path $resolvedSource ([string]$fragment.path)) -Destination $fragmentRoot -Force -ErrorAction Stop
}
foreach ($texture in $manifest.shared_textures) {
    Copy-Item -LiteralPath (Join-Path $resolvedSource ([string]$texture.path)) -Destination $textureRoot -Force -ErrorAction Stop
}

$preprocessor = Join-Path $projectRoot "tools\enemy_v2\prepare_hoplite_body.py"
$bodyOutput = Join-Path $packageRoot "hoplite_body_v2.gltf"
$bodyReport = Join-Path $packageRoot "hoplite_body_v2.report.json"
& $BlenderPath --background --factory-startup --python $preprocessor -- `
    --input $bodyPath `
    --output $bodyOutput `
    --shared-textures-dir $textureRoot `
    --report $bodyReport
if ($LASTEXITCODE -ne 0) {
    throw "Blender HopliteV2 preprocessing failed with exit code $LASTEXITCODE"
}

$lodRoot = Join-Path $packageRoot "lods"
New-Item -ItemType Directory -Force -Path $lodRoot -ErrorAction Stop | Out-Null
$lodSpecs = @(
    @{ Source = $Lod0Source; Stem = "hoplite_body_lod0_22k" },
    @{ Source = $Lod1Source; Stem = "hoplite_body_lod1_8k" },
    @{ Source = $Lod2Source; Stem = "hoplite_body_lod2_2k" }
)
$providedLodCount = @($lodSpecs | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Source) }).Count
if ($providedLodCount -ne 0 -and $providedLodCount -ne $lodSpecs.Count) {
    throw "Provide all three LOD sources together: -Lod0Source, -Lod1Source and -Lod2Source"
}
if ($providedLodCount -eq $lodSpecs.Count) {
    foreach ($spec in $lodSpecs) {
        $resolvedLod = (Resolve-Path -LiteralPath ([string]$spec.Source) -ErrorAction Stop).Path
        $lodOutput = Join-Path $lodRoot ("{0}.gltf" -f [string]$spec.Stem)
        $lodReport = Join-Path $lodRoot ("{0}.report.json" -f [string]$spec.Stem)
        & $BlenderPath --background --factory-startup --python $preprocessor -- `
            --input $resolvedLod `
            --output $lodOutput `
            --shared-textures-dir $textureRoot `
            --material-source $bodyOutput `
            --report $lodReport
        if ($LASTEXITCODE -ne 0) {
            throw "Blender HopliteV2 LOD preprocessing failed for $resolvedLod with exit code $LASTEXITCODE"
        }
    }
}
else {
    foreach ($spec in $lodSpecs) {
        $expectedLod = Join-Path $lodRoot ("{0}.gltf" -f [string]$spec.Stem)
        if (-not (Test-Path -LiteralPath $expectedLod -PathType Leaf)) {
            throw "LOD output is missing. Provide all three LOD source parameters: $expectedLod"
        }
    }
    Write-Host "HOPLITE V2 LOD sources omitted; preserving the three validated outputs."
}

# The runtime catalog consumes the two-surface atlas chain. Rebuild it whenever
# the source body or any LOD changes so a package sync cannot silently leave the
# game on stale atlased geometry/textures.
$atlasBuilder = Join-Path $projectRoot "tools\enemy_v2\build_hoplite_body_atlas.py"
& $BlenderPath --background --factory-startup --python $atlasBuilder
if ($LASTEXITCODE -ne 0) {
    throw "Blender HopliteV2 atlas build failed with exit code $LASTEXITCODE"
}
$atlasReport = Join-Path $packageRoot "atlased\hoplite_body_atlas.report.json"
if (-not (Test-Path -LiteralPath $atlasReport -PathType Leaf)) {
    throw "HopliteV2 atlas report is missing: $atlasReport"
}

Push-Location $projectRoot
try {
    & $GodotPath --headless --editor --path . --log-file ".tmp_tools\hoplite_v2_import.log" --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot import failed with exit code $LASTEXITCODE" }
    & $GodotPath --headless --path . --log-file ".tmp_tools\hoplite_v2_source_animation_build.log" --script "res://tools/build_hoplite_animation_library.gd" -- --v2
    if ($LASTEXITCODE -ne 0) { throw "HopliteV2 53-bone source bake failed with exit code $LASTEXITCODE" }
    & $GodotPath --headless --path . --log-file ".tmp_tools\hoplite_v2_animation_build.log" --script "res://tools/enemy_v2/build_hoplite_v2_animation_library.gd"
    if ($LASTEXITCODE -ne 0) { throw "HopliteV2 animation bake failed with exit code $LASTEXITCODE" }
    & $GodotPath --headless --path . --log-file ".tmp_tools\hoplite_v2_foundation_probe.log" --script "res://tools/enemy_v2/hoplite_v2_foundation_probe.gd"
    if ($LASTEXITCODE -ne 0) { throw "HopliteV2 foundation probe failed with exit code $LASTEXITCODE" }
    & $GodotPath --headless --path . --log-file ".tmp_tools\hoplite_v2_lod_contract_probe.log" --script "res://tools/enemy_v2/hoplite_v2_lod_contract_probe.gd"
    if ($LASTEXITCODE -ne 0) { throw "HopliteV2 LOD contract probe failed with exit code $LASTEXITCODE" }
    & $GodotPath --headless --path . --log-file ".tmp_tools\enemy_runtime_migration_probe.log" --script "res://tools/enemy_runtime_migration_probe.gd"
    if ($LASTEXITCODE -ne 0) { throw "Enemy migration safety probe failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

Write-Host "HOPLITE V2 PACKAGE PASS - source synced, 23-bone atlased LOD chain baked, donor published, V1 gate preserved."
