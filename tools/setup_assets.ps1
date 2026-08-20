$ErrorActionPreference = 'Stop'
$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $tools
$downloads = Join-Path $root '_downloads'
$source = Join-Path $root '_source'
$runtime = Join-Path $root 'assets\runtime'
$ual1Name = 'universal_animation_librarystandard.zip'
$ual2Name = 'universal_animation_library_2standard.zip'
$ual1Url = 'https://opengameart.org/sites/default/files/universal_animation_librarystandard.zip'
$ual2Url = 'https://opengameart.org/sites/default/files/universal_animation_library_2standard.zip'
New-Item -ItemType Directory -Force -Path $downloads,$source,$runtime | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $downloads '.gdignore') | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $source '.gdignore') | Out-Null
function Find-InDownloads([string]$name) {
    $direct = Join-Path $downloads $name
    if (Test-Path -LiteralPath $direct) { return (Get-Item -LiteralPath $direct) }
    $userDownloads = Join-Path $env:USERPROFILE 'Downloads'
    if (-not (Test-Path $userDownloads)) { return $null }
    return Get-ChildItem -LiteralPath $userDownloads -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $name } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}
function Ensure-Download([string]$name,[string]$url) {
    $dest = Join-Path $downloads $name
    if (Test-Path -LiteralPath $dest) { Write-Host "[FOUND] $name" -ForegroundColor Green; return $dest }
    $existing = Find-InDownloads $name
    if ($existing) { Write-Host "[REUSE] $($existing.FullName)" -ForegroundColor Green; Copy-Item -LiteralPath $existing.FullName -Destination $dest -Force; return $dest }
    Write-Host "[DOWNLOAD] $name" -ForegroundColor Cyan
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $dest
    return $dest
}
Write-Host 'PROJECT HOPLITE - UAL NATIVE LAB ASSET SETUP V2' -ForegroundColor Cyan
$ual1Zip = Ensure-Download $ual1Name $ual1Url
$ual2Zip = Ensure-Download $ual2Name $ual2Url
$ual1Source = Join-Path $source 'ual1'
$ual2Source = Join-Path $source 'ual2'
foreach ($folder in @($ual1Source,$ual2Source)) { if (Test-Path $folder) { Remove-Item $folder -Recurse -Force }; New-Item -ItemType Directory -Force -Path $folder | Out-Null }
Write-Host '[EXTRACT] UAL1 + UAL2 outside Godot import...' -ForegroundColor Cyan
Expand-Archive -LiteralPath $ual1Zip -DestinationPath $ual1Source -Force
Expand-Archive -LiteralPath $ual2Zip -DestinationPath $ual2Source -Force
$ual1 = Get-ChildItem -Path $ual1Source -Recurse -File | Where-Object { $_.Extension -eq '.glb' -and $_.Name -match 'Standard' -and $_.FullName -notmatch 'Mannequin' } | Where-Object { $_.FullName -match 'Godot' } | Select-Object -First 1
if (-not $ual1) { $ual1 = Get-ChildItem -Path $ual1Source -Recurse -File | Where-Object { $_.Extension -eq '.glb' -and $_.Name -match 'Standard' -and $_.FullName -notmatch 'Mannequin' } | Select-Object -First 1 }
if (-not $ual1) { throw 'UAL1 Standard Godot GLB not found.' }
$ual2 = Get-ChildItem -Path $ual2Source -Recurse -File -Filter 'UAL2_Standard.glb' | Where-Object { $_.FullName -match 'Godot|Unreal' } | Select-Object -First 1
if (-not $ual2) { $ual2 = Get-ChildItem -Path $ual2Source -Recurse -File -Filter 'UAL2_Standard.glb' | Select-Object -First 1 }
if (-not $ual2) { throw 'UAL2_Standard.glb not found.' }
$ual1Runtime = Join-Path $runtime 'ual1'
$ual2Runtime = Join-Path $runtime 'ual2'
if (Test-Path $runtime) { Remove-Item $runtime -Recurse -Force }
New-Item -ItemType Directory -Force -Path $ual1Runtime,$ual2Runtime | Out-Null
Copy-Item -LiteralPath $ual1.FullName -Destination (Join-Path $ual1Runtime 'UAL1_Standard.glb') -Force
Copy-Item -LiteralPath $ual2.FullName -Destination (Join-Path $ual2Runtime 'UAL2_Standard.glb') -Force
$cache = Join-Path $root '.godot'
if (Test-Path $cache) { Remove-Item $cache -Recurse -Force }
$report = @"
PROJECT HOPLITE UAL NATIVE LAB V2

VISIBLE PLAYER / LOCOMOTION:
$($ual1.FullName)
-> assets/runtime/ual1/UAL1_Standard.glb

AUTHORED COMBAT DONOR:
$($ual2.FullName)
-> assets/runtime/ual2/UAL2_Standard.glb

No Universal Base Character. No retargeting between different rigs.
UAL2 clips are copied onto the UAL1 mannequin's matching Universal skeleton.
"@
$report | Set-Content -Path (Join-Path $root 'ASSET_REPORT.txt') -Encoding UTF8
Write-Host ''
Write-Host 'SUCCESS - ONLY TWO GLB FILES ARE VISIBLE TO GODOT.' -ForegroundColor Green
Write-Host 'Open project.godot and let Godot import both files before running.'
