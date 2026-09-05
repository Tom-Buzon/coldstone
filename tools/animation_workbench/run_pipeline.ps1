param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Manifest', 'OpenBlender', 'Publish')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$logDirectory = Join-Path $projectRoot '.tmp_tools\animation_workbench'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

function Resolve-GodotConsole {
    $candidates = @(
        $env:GODOT_CONSOLE,
        'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe',
        (Join-Path $projectRoot 'Godot_v4.7-stable_win64_console.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $command = Get-Command 'godot*console*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    throw 'Godot console introuvable. Definir la variable GODOT_CONSOLE avec le chemin de Godot 4.7.'
}

function Resolve-Blender {
    $candidates = @(
        $env:BLENDER_EXE,
        'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe',
        'C:\Program Files\Blender Foundation\Blender 4.3\blender.exe',
        'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe'
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $command = Get-Command blender -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'Blender 4.2+ introuvable. Definir la variable BLENDER_EXE avec le chemin de blender.exe.'
}

function Invoke-GodotTool([string]$scriptPath, [string]$logName) {
    $godot = Resolve-GodotConsole
    $logPath = Join-Path $logDirectory $logName
    & $godot --headless --path $projectRoot --log-file $logPath --script $scriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot a interrompu $scriptPath (code $LASTEXITCODE). Voir $logPath"
    }
}

function Build-Manifest {
    Write-Host 'Regeneration du manifeste des personnages et animations...' -ForegroundColor Cyan
    Invoke-GodotTool 'res://tools/animation_workbench/build_manifest.gd' 'manifest.log'
    Write-Host 'Manifeste pret.' -ForegroundColor Green
}

Set-Location -LiteralPath $projectRoot

switch ($Action) {
    'Manifest' {
        Build-Manifest
    }
    'OpenBlender' {
        Build-Manifest
        $blender = Resolve-Blender
        $workbench = Join-Path $projectRoot 'tools\animation_workbench\blender_workbench.py'
        $manifest = Join-Path $projectRoot 'tools\animation_workbench\data\animation_workbench_manifest.json'
        $overrides = Join-Path $projectRoot 'tools\animation_workbench\data\workbench_overrides.json'
        $arguments = @(
            '--factory-startup',
            '--python', ('"{0}"' -f $workbench),
            '--',
            '--project-root', ('"{0}"' -f $projectRoot),
            '--manifest', ('"{0}"' -f $manifest),
            '--overrides', ('"{0}"' -f $overrides)
        )
        Start-Process -FilePath $blender -ArgumentList $arguments -WorkingDirectory $projectRoot
        Write-Host 'Blender est ouvert. Panneau N > Spartan Anim.' -ForegroundColor Green
    }
    'Publish' {
        Build-Manifest
        Write-Host 'Validation et publication des correspondances dans le runtime actuel...' -ForegroundColor Cyan
        Invoke-GodotTool 'res://tools/animation_workbench/publish_runtime.gd' 'publish.log'
        Write-Host 'Publication terminee. Le rapport est dans tools\animation_workbench\data\publish_report.json.' -ForegroundColor Green
    }
}
