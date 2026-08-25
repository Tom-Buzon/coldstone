$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Dest = Join-Path $Root "audio\sfx"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$Files = @(
    @{ Name = "sword_swing_01.wav"; Url = "https://opengameart.org/sites/default/files/snd_enemysword.wav" },
    @{ Name = "sword_swing_02.wav"; Url = "https://opengameart.org/sites/default/files/spear.wav" },
    @{ Name = "sword_swing_03.wav"; Url = "https://opengameart.org/sites/default/files/snd_throw1.wav" },
    @{ Name = "flesh_hit_01.wav"; Url = "https://opengameart.org/sites/default/files/player_hit.wav" },
    @{ Name = "flesh_hit_02.wav"; Url = "https://opengameart.org/sites/default/files/snd_splathit.wav" },
    @{ Name = "flesh_hit_03.wav"; Url = "https://opengameart.org/sites/default/files/snd_bullethit.wav" },
    @{ Name = "gore_splat_01.wav"; Url = "https://opengameart.org/sites/default/files/snd_splat.wav" },
    @{ Name = "gore_splat_02.wav"; Url = "https://opengameart.org/sites/default/files/snd_splurt.wav" },
    @{ Name = "decapitation.wav"; Url = "https://opengameart.org/sites/default/files/crush.wav" },
    @{ Name = "combo_tick.wav"; Url = "https://opengameart.org/sites/default/files/snd_menu_move.wav" },
    @{ Name = "kill_confirm.wav"; Url = "https://opengameart.org/sites/default/files/snd_menu_select.wav" },
    @{ Name = "player_hurt.wav"; Url = "https://opengameart.org/sites/default/files/uff.wav" },
    @{ Name = "death_01.wav"; Url = "https://opengameart.org/sites/default/files/snd_death1.wav" }
)

Write-Host "PROJECT HOPLITE - downloading CC0 combat SFX..."
foreach ($File in $Files) {
    $Target = Join-Path $Dest $File.Name
    Write-Host ("  -> " + $File.Name)
    Invoke-WebRequest -Uri $File.Url -OutFile $Target -UseBasicParsing
}

Write-Host "Done. Godot will import the WAV files automatically on next scan/start."
