extends Node
class_name HopliteCombatAudio

const TRACK_DIR: String = "res://audio/track"
const SUNO_SFX_DIR: String = "res://audio/sfxSuno"
const SOUNDBANK_DIR: String = "res://audio/soundbank"
const SETTINGS_PATH: String = "user://hoplite_audio.cfg"
const SETTINGS_MIX_VERSION: int = 2
const MUSIC_BUS: StringName = &"HopliteMusic"
const SFX_BUS: StringName = &"HopliteSFX"

# V0.0.15: the old placeholder SFX bank is intentionally no longer used.
# These defaults are deliberately conservative because the Suno files are mastered
# much louder than the previous placeholders. The ² menu still exposes all buses.
var master_volume: float = 0.82
var music_volume: float = 0.64
var sfx_volume: float = 0.34

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_banks: Dictionary = {}
var sfx_category_volumes: Dictionary = {}
var tracks: Array[String] = []
var last_track_index: int = -1
var preferred_track_file: String = ""
var sfx_cursor: int = 0
var rng := RandomNumberGenerator.new()
var last_category_play_ms: Dictionary = {}
var last_bank_stream_index: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    rng.randomize()
    _ensure_audio_buses()
    _build_players()
    _load_banks()
    _initialize_sfx_category_volumes()
    _discover_tracks()
    _load_settings()
    _apply_mix()
    _play_start_track()

func _ensure_audio_buses() -> void:
    _ensure_bus(MUSIC_BUS)
    _ensure_bus(SFX_BUS)

func _ensure_bus(bus_name: StringName) -> int:
    var index: int = AudioServer.get_bus_index(String(bus_name))
    if index >= 0:
        return index
    AudioServer.add_bus(AudioServer.bus_count)
    index = AudioServer.bus_count - 1
    AudioServer.set_bus_name(index, String(bus_name))
    AudioServer.set_bus_send(index, "Master")
    return index

func _build_players() -> void:
    music_player = AudioStreamPlayer.new()
    music_player.name = "BattleMusic"
    music_player.bus = MUSIC_BUS
    music_player.volume_db = 0.0
    add_child(music_player)
    music_player.finished.connect(_play_next_track)

    for i: int in range(14):
        var player := AudioStreamPlayer.new()
        player.name = "CombatSFX_%02d" % i
        player.bus = SFX_BUS
        add_child(player)
        sfx_players.append(player)

func _load_banks() -> void:
    # User-authored Suno SFX. We use ONLY this folder now. If a category is missing,
    # it stays silent instead of falling back to the old placeholder pack.
    sfx_banks[&"player_swing"] = _load_many([
        SUNO_SFX_DIR + "/sword.mp3",
        SUNO_SFX_DIR + "/sword2.mp3"
    ])
    sfx_banks[&"enemy_swing"] = _load_many([
        SUNO_SFX_DIR + "/sword2.mp3",
        SUNO_SFX_DIR + "/sword.mp3"
    ])
    sfx_banks[&"jump"] = _load_many([SUNO_SFX_DIR + "/warriorJump.mp3"])
    sfx_banks[&"dash"] = _load_many([SUNO_SFX_DIR + "/warriorDash.mp3"])
    sfx_banks[&"slide"] = _load_many([SUNO_SFX_DIR + "/warriorSlide.mp3"])
    sfx_banks[&"enemy_death"] = _load_many([SUNO_SFX_DIR + "/enemyDead.mp3"])
    sfx_banks[&"boss_death"] = _load_many([SUNO_SFX_DIR + "/bossDead.mp3"])

    # Future Suno slots are already wired. Add these exact filenames later and the
    # game will pick them up automatically without another code patch. Missing banks
    # simply stay silent; the discarded placeholder pack is never used.
    sfx_banks[&"spear_swing"] = _load_many([SUNO_SFX_DIR + "/spearThrust.mp3"])
    sfx_banks[&"hit"] = _load_many([
        SUNO_SFX_DIR + "/fleshHit1.mp3",
        SUNO_SFX_DIR + "/fleshHit2.mp3",
        SUNO_SFX_DIR + "/fleshHit3.mp3"
    ])
    sfx_banks[&"hit_confirm"] = _load_many([
        SUNO_SFX_DIR + "/hitConfirm1.mp3",
        SUNO_SFX_DIR + "/hitConfirm2.mp3"
    ])
    # The confirmation tick is gameplay information rather than a physical impact.
    # Keep a tiny generated fallback so a missing sound bank never makes contacts
    # unreadable (and never crashes the game).
    if _bank_empty(&"hit_confirm"):
        sfx_banks[&"hit_confirm"] = [_make_hit_confirm_fallback()]
    sfx_banks[&"gore"] = _load_many([SUNO_SFX_DIR + "/dismemberment.mp3"])
    sfx_banks[&"decap"] = _load_many([SUNO_SFX_DIR + "/decapitation.mp3"])
    sfx_banks[&"combo"] = _load_many([SUNO_SFX_DIR + "/comboMilestone.mp3"])
    sfx_banks[&"hurt"] = _load_many([SUNO_SFX_DIR + "/warriorHurt.mp3"])
    sfx_banks[&"enemy_hurt"] = _load_many([
        SUNO_SFX_DIR + "/enemyHurt1.mp3",
        SUNO_SFX_DIR + "/enemyHurt2.mp3",
        SUNO_SFX_DIR + "/enemyHurt3.mp3"
    ])

    # Layered physical feedback. Every entry is optional: _load_many filters out
    # missing files and _play_bank treats an empty bank as intentional silence.
    sfx_banks[&"whoosh_light"] = _load_many([
        SUNO_SFX_DIR + "/whooshLight1.mp3",
        SUNO_SFX_DIR + "/whooshLight2.mp3",
        SUNO_SFX_DIR + "/whooshLight3.mp3"
    ])
    sfx_banks[&"whoosh_heavy"] = _load_many([
        SUNO_SFX_DIR + "/whooshHeavy1.mp3",
        SUNO_SFX_DIR + "/whooshHeavy2.mp3",
        SUNO_SFX_DIR + "/whooshHeavy3.mp3"
    ])
    sfx_banks[&"whoosh_spiral"] = _load_many([
        SUNO_SFX_DIR + "/whooshSpiral1.mp3",
        SUNO_SFX_DIR + "/whooshSpiral2.mp3",
        SUNO_SFX_DIR + "/whooshSpiral3.mp3"
    ])
    sfx_banks[&"impact_transient"] = _load_many([
        SUNO_SFX_DIR + "/impactTransient1.mp3",
        SUNO_SFX_DIR + "/impactTransient2.mp3",
        SUNO_SFX_DIR + "/impactTransient3.mp3"
    ])
    sfx_banks[&"flesh_body"] = _load_many([
        SUNO_SFX_DIR + "/fleshBody1.mp3",
        SUNO_SFX_DIR + "/fleshBody2.mp3",
        SUNO_SFX_DIR + "/fleshBody3.mp3"
    ])
    sfx_banks[&"metal_clang"] = _load_many([
        SUNO_SFX_DIR + "/metalClang1.mp3",
        SUNO_SFX_DIR + "/metalClang2.mp3",
        SUNO_SFX_DIR + "/metalClang3.mp3"
    ])
    sfx_banks[&"metal_resonance"] = _load_many([
        SUNO_SFX_DIR + "/metalResonance1.mp3",
        SUNO_SFX_DIR + "/metalResonance2.mp3"
    ])
    sfx_banks[&"shield_thump"] = _load_many([
        SUNO_SFX_DIR + "/shieldThump1.mp3",
        SUNO_SFX_DIR + "/shieldThump2.mp3"
    ])
    sfx_banks[&"bone_crack"] = _load_many([
        SUNO_SFX_DIR + "/boneCrack1.mp3",
        SUNO_SFX_DIR + "/boneCrack2.mp3"
    ])
    sfx_banks[&"parry"] = _load_many([
        SUNO_SFX_DIR + "/parry1.mp3",
        SUNO_SFX_DIR + "/parry2.mp3"
    ])
    sfx_banks[&"charge_max"] = _load_many([
        SUNO_SFX_DIR + "/heavyChargeMax.mp3"
    ])
    sfx_banks[&"impact_wood"] = _load_many([
        SUNO_SFX_DIR + "/woodImpact1.mp3",
        SUNO_SFX_DIR + "/woodImpact2.mp3"
    ])
    sfx_banks[&"impact_stone"] = _load_many([
        SUNO_SFX_DIR + "/stoneImpact1.mp3",
        SUNO_SFX_DIR + "/stoneImpact2.mp3"
    ])

    # Context-specific sword bank. These clips never share one catch-all pool:
    # each bank is selected by the actual attack/contact event below, and only
    # variants belonging to that event are randomized together.
    sfx_banks[&"sword_light_1"] = _load_many([
        SOUNDBANK_DIR + "/swordLight1.mp3"
    ])
    sfx_banks[&"sword_light"] = _load_many([
        SOUNDBANK_DIR + "/swordSimpleLight.mp3"
    ])
    sfx_banks[&"sword_light_air"] = _load_many([
        SOUNDBANK_DIR + "/swordLightWhileJumping.mp3"
    ])
    sfx_banks[&"sword_attack_air"] = _load_many([
        SOUNDBANK_DIR + "/swordFromTheAir.mp3"
    ])
    sfx_banks[&"sword_heavy"] = _load_many([
        SUNO_SFX_DIR + "/sword.mp3",
        SUNO_SFX_DIR + "/sword2.mp3"
    ])
    sfx_banks[&"sword_spiral_ground"] = _load_many([
        SOUNDBANK_DIR + "/swordHeavy1.mp3"
    ])
    sfx_banks[&"sword_slide"] = _load_many([
        SOUNDBANK_DIR + "/swordFromSliding.mp3",
        SOUNDBANK_DIR + "/swordFromSliding2.mp3"
    ])
    sfx_banks[&"sword_counter"] = _load_many([
        SOUNDBANK_DIR + "/swordCounterAttack.mp3"
    ])
    sfx_banks[&"sword_ground_smash"] = _load_many([
        SOUNDBANK_DIR + "/swordFallingOnTheGround.mp3"
    ])
    sfx_banks[&"sword_armor_impact"] = _load_many([
        SOUNDBANK_DIR + "/swordHitArmor.mp3"
    ])
    sfx_banks[&"sword_shield_impact"] = _load_many([
        SOUNDBANK_DIR + "/swordHitAShield.mp3",
        SOUNDBANK_DIR + "/swordHitAShield2.mp3",
        SOUNDBANK_DIR + "/swordHitAShield3.mp3"
    ])
    sfx_banks[&"sever_head"] = _load_many([
        SOUNDBANK_DIR + "/DecapitaionAndDemembrement.mp3",
        SOUNDBANK_DIR + "/decapitationOrDemembrement2.mp3"
    ])
    sfx_banks[&"sever_limb"] = _load_many([
        SOUNDBANK_DIR + "/demembrement.mp3",
        SOUNDBANK_DIR + "/DecapitaionAndDemembrement.mp3",
        SOUNDBANK_DIR + "/decapitationOrDemembrement2.mp3"
    ])
    # Loaded and registered now, but intentionally not played until the game has
    # a real draw/sheath event. Treating a draw as a random swing would be false.
    sfx_banks[&"weapon_draw"] = _load_many([
        SOUNDBANK_DIR + "/creatorshome-draw-a-sword-327726.mp3"
    ])

func _load_many(paths: Array) -> Array[AudioStream]:
    var result: Array[AudioStream] = []
    for path: String in paths:
        if not ResourceLoader.exists(path):
            continue
        var stream := load(path) as AudioStream
        if stream != null:
            result.append(stream)
    return result

func _initialize_sfx_category_volumes() -> void:
    for raw_key: Variant in sfx_banks.keys():
        var key := StringName(raw_key)
        if not sfx_category_volumes.has(key):
            sfx_category_volumes[key] = 1.0

func _make_hit_confirm_fallback() -> AudioStreamWAV:
    const SAMPLE_RATE: int = 44100
    const SAMPLE_COUNT: int = 1544
    var bytes := PackedByteArray()
    bytes.resize(SAMPLE_COUNT * 2)
    for sample_index: int in range(SAMPLE_COUNT):
        var t: float = float(sample_index) / float(SAMPLE_RATE)
        var envelope: float = exp(-t * 92.0)
        var tone: float = sin(TAU * 1260.0 * t) * 0.72 + sin(TAU * 2180.0 * t) * 0.28
        var sample_value: int = clampi(int(tone * envelope * 6800.0), -32768, 32767)
        bytes.encode_s16(sample_index * 2, sample_value)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
    stream.data = bytes
    return stream

func _discover_tracks() -> void:
    tracks.clear()
    var dir := DirAccess.open(TRACK_DIR)
    if dir == null:
        push_warning("[AUDIO] Missing track directory: " + TRACK_DIR)
        return
    for file_name: String in dir.get_files():
        var lower := file_name.to_lower()
        if lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav"):
            tracks.append(TRACK_DIR.path_join(file_name))
    tracks.sort()

func _load_settings() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        return
    master_volume = clampf(float(config.get_value("audio", "master", master_volume)), 0.0, 1.0)
    music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
    sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
    preferred_track_file = String(config.get_value("audio", "track", preferred_track_file))
    for raw_key: Variant in sfx_banks.keys():
        var key := StringName(raw_key)
        sfx_category_volumes[key] = clampf(float(config.get_value("sfx_detail", String(key), 1.0)), 0.0, 1.0)

    # One-time migration from the louder placeholder mix. This only lowers an older
    # saved SFX setting; once the new version is stored, the player's chosen value wins.
    var saved_mix_version: int = int(config.get_value("audio", "mix_version", 0))
    if saved_mix_version < SETTINGS_MIX_VERSION:
        sfx_volume = minf(sfx_volume, 0.34)
        config.set_value("audio", "sfx", sfx_volume)
        config.set_value("audio", "mix_version", SETTINGS_MIX_VERSION)
        config.save(SETTINGS_PATH)

func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "master", master_volume)
    config.set_value("audio", "music", music_volume)
    config.set_value("audio", "sfx", sfx_volume)
    config.set_value("audio", "mix_version", SETTINGS_MIX_VERSION)
    if last_track_index >= 0 and last_track_index < tracks.size():
        config.set_value("audio", "track", tracks[last_track_index].get_file())
    elif preferred_track_file != "":
        config.set_value("audio", "track", preferred_track_file)
    for raw_key: Variant in sfx_category_volumes.keys():
        var key := StringName(raw_key)
        config.set_value("sfx_detail", String(key), float(sfx_category_volumes[key]))
    config.save(SETTINGS_PATH)

func _apply_mix() -> void:
    _set_bus_linear("Master", master_volume)
    _set_bus_linear(String(MUSIC_BUS), music_volume)
    _set_bus_linear(String(SFX_BUS), sfx_volume)

func _set_bus_linear(bus_name: String, linear_value: float) -> void:
    var index: int = AudioServer.get_bus_index(bus_name)
    if index < 0:
        return
    var value: float = clampf(linear_value, 0.0, 1.0)
    AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
    AudioServer.set_bus_mute(index, value <= 0.0001)

func set_master_volume(value: float) -> void:
    master_volume = clampf(value, 0.0, 1.0)
    _set_bus_linear("Master", master_volume)
    _save_settings()

func set_music_volume(value: float) -> void:
    music_volume = clampf(value, 0.0, 1.0)
    _set_bus_linear(String(MUSIC_BUS), music_volume)
    _save_settings()

func set_sfx_volume(value: float) -> void:
    sfx_volume = clampf(value, 0.0, 1.0)
    _set_bus_linear(String(SFX_BUS), sfx_volume)
    _save_settings()

func get_master_volume() -> float:
    return master_volume

func get_music_volume() -> float:
    return music_volume

func get_sfx_volume() -> float:
    return sfx_volume

func get_sfx_category_keys() -> Array[StringName]:
    var result: Array[StringName] = []
    for raw_key: Variant in sfx_banks.keys():
        result.append(StringName(raw_key))
    result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
    return result

func get_sfx_category_volume(key: StringName) -> float:
    return clampf(float(sfx_category_volumes.get(key, 1.0)), 0.0, 1.0)

func set_sfx_category_volume(key: StringName, value: float) -> void:
    if not sfx_banks.has(key):
        return
    sfx_category_volumes[key] = clampf(value, 0.0, 1.0)
    _save_settings()

func get_track_names() -> Array[String]:
    var result: Array[String] = []
    for path: String in tracks:
        result.append(_pretty_track_name(path))
    return result

func get_current_track_index() -> int:
    return last_track_index

func play_track(index: int) -> void:
    if music_player == null or tracks.is_empty():
        return
    var safe_index: int = clampi(index, 0, tracks.size() - 1)
    _play_track_index(safe_index)
    _save_settings()

func _play_start_track() -> void:
    if tracks.is_empty():
        return
    if preferred_track_file != "":
        for i: int in range(tracks.size()):
            if tracks[i].get_file() == preferred_track_file:
                _play_track_index(i)
                return
    _play_next_track()

func _play_next_track() -> void:
    if music_player == null or tracks.is_empty():
        return
    var index: int = 0
    if tracks.size() > 1:
        index = rng.randi_range(0, tracks.size() - 1)
        if index == last_track_index:
            index = (index + 1) % tracks.size()
    _play_track_index(index)

func _play_track_index(index: int) -> void:
    if music_player == null or index < 0 or index >= tracks.size():
        return
    last_track_index = index
    preferred_track_file = tracks[index].get_file()
    var stream := load(tracks[index]) as AudioStream
    if stream == null:
        return
    if stream is AudioStreamMP3:
        (stream as AudioStreamMP3).loop = false
    elif stream is AudioStreamWAV:
        (stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
    music_player.stop()
    music_player.stream = stream
    music_player.play()

func _pretty_track_name(path: String) -> String:
    var file_name: String = path.get_file().get_basename()
    return file_name.replace("_", " ").replace("-", " ").capitalize()

func play_feedback_cue(cue: StringName, zone: StringName = StringName(), intensity: float = 0.5) -> void:
    var strength: float = clampf(intensity, 0.0, 1.0)
    match cue:
        &"whoosh_light", &"whoosh_light1":
            var light_bank: StringName = &"sword_light_1" if cue == &"whoosh_light1" else &"sword_light"
            if zone == &"air":
                light_bank = &"sword_light_air"
            elif zone == &"slide":
                light_bank = &"sword_slide"
            if _bank_empty(light_bank):
                light_bank = &"whoosh_light" if not _bank_empty(&"whoosh_light") else &"player_swing"
            _play_bank(light_bank, lerpf(-15.0, -11.5, strength), 0.97, 1.04, 52)
        &"whoosh_heavy":
            var heavy_bank: StringName = &"sword_heavy"
            if zone == &"air":
                heavy_bank = &"sword_attack_air"
            elif zone == &"slide":
                heavy_bank = &"sword_slide"
            elif zone == &"counter_light" or zone == &"counter_dash":
                heavy_bank = &"sword_counter"
            if _bank_empty(heavy_bank):
                heavy_bank = &"whoosh_heavy" if not _bank_empty(&"whoosh_heavy") else &"player_swing"
            _play_bank(heavy_bank, lerpf(-12.0, -8.5, strength), 0.88, 0.97, 90)
        &"whoosh_spiral":
            var spiral_bank: StringName = &"sword_attack_air" if zone == &"air" else &"sword_spiral_ground"
            if _bank_empty(spiral_bank):
                spiral_bank = &"whoosh_spiral" if not _bank_empty(&"whoosh_spiral") else &"player_swing"
            _play_bank(spiral_bank, lerpf(-13.0, -9.5, strength), 0.92, 1.01, 72)
        &"impact_flesh":
            _play_bank(&"impact_transient", lerpf(-17.0, -11.0, strength), 0.97, 1.03, 38)
            var body_bank: StringName = &"flesh_body" if not _bank_empty(&"flesh_body") else &"hit"
            _play_bank(body_bank, lerpf(-16.0, -10.0, strength), 0.95, 1.04, 42)
            if zone == &"head" or zone == &"neck":
                _play_bank(&"bone_crack", lerpf(-18.0, -12.0, strength), 0.94, 1.02, 95)
        &"impact_metal":
            _play_bank(&"impact_transient", lerpf(-16.0, -9.5, strength), 0.98, 1.03, 42)
            var armor_bank: StringName = &"sword_armor_impact" if not _bank_empty(&"sword_armor_impact") else &"metal_clang"
            _play_bank(armor_bank, lerpf(-13.0, -7.5, strength), 0.96, 1.04, 58)
        &"impact_shield", &"guard_break":
            _play_bank(&"impact_transient", lerpf(-16.0, -9.5, strength), 0.98, 1.03, 42)
            var shield_bank: StringName = &"sword_shield_impact" if not _bank_empty(&"sword_shield_impact") else &"metal_clang"
            _play_bank(shield_bank, lerpf(-13.0, -7.5, strength), 0.96, 1.04, 58)
            if _bank_empty(&"sword_shield_impact"):
                _play_bank(&"shield_thump", lerpf(-17.0, -10.5, strength), 0.94, 1.02, 62)
                _play_bank(&"metal_resonance", lerpf(-20.0, -13.0, strength), 0.97, 1.03, 105)
        &"impact_wood":
            _play_bank(&"impact_wood", lerpf(-16.0, -10.0, strength), 0.96, 1.04, 55)
        &"impact_stone":
            var stone_bank: StringName = &"sword_ground_smash" if zone == &"ground" and not _bank_empty(&"sword_ground_smash") else &"impact_stone"
            _play_bank(stone_bank, lerpf(-16.0, -9.5, strength), 0.97, 1.03, 55)
        &"parry":
            var parry_bank: StringName = &"parry" if not _bank_empty(&"parry") else &"sword_shield_impact"
            _play_bank(parry_bank, lerpf(-12.0, -7.0, strength), 0.98, 1.03, 110)
        &"charge_max":
            _play_bank(&"charge_max", -13.0, 0.99, 1.01, 600)

func play_enemy_swing(weapon_kind: StringName, distance_to_player: float = 0.0) -> void:
    var pitch_min: float = 0.90 if weapon_kind == &"spear" else 0.96
    var pitch_max: float = 0.98 if weapon_kind == &"spear" else 1.03
    # Enemy swings are deliberately background information. Even at point-blank range
    # they sit well below the Spartan's own weapon, then fall off aggressively.
    var distance_ratio: float = clampf(distance_to_player / 9.0, 0.0, 1.0)
    var volume: float = lerpf(-27.0, -40.0, distance_ratio)
    var bank_key: StringName = &"spear_swing" if weapon_kind == &"spear" and not _bank_empty(&"spear_swing") else &"enemy_swing"
    _play_bank(bank_key, volume, pitch_min, pitch_max, 105)

func play_movement_sfx(kind: StringName) -> void:
    match kind:
        &"jump":
            _play_bank(&"jump", -15.0, 0.98, 1.02, 90)
        &"dash":
            _play_bank(&"dash", -13.5, 0.97, 1.03, 115)
        &"slide":
            _play_bank(&"slide", -16.0, 0.98, 1.02, 140)

func play_hit(zone: StringName, damage: float) -> void:
    if _bank_empty(&"hit"):
        return
    var volume: float = lerpf(-16.0, -11.0, clampf(damage / 80.0, 0.0, 1.0))
    var pitch_min: float = 0.96
    var pitch_max: float = 1.04
    if zone == &"head" or zone == &"neck":
        volume += 1.5
        pitch_min = 0.90
        pitch_max = 0.98
    _play_bank(&"hit", volume, pitch_min, pitch_max, 42)
    if not _bank_empty(&"enemy_hurt") and rng.randf() < 0.34:
        _play_bank(&"enemy_hurt", -18.0, 0.96, 1.04, 190)

func play_hit_confirm(zone: StringName, contact_count: int = 1, defended: bool = false) -> void:
    var pitch: float = clampf(1.0 + float(maxi(contact_count - 1, 0)) * 0.055, 1.0, 1.24)
    if zone == &"head" or zone == &"neck":
        pitch += 0.07
    if defended:
        pitch = maxf(0.88, pitch - 0.12)
    _play_bank(&"hit_confirm", -18.5 if defended else -16.5, pitch, pitch, 24)

func play_sever(zone: StringName) -> void:
    if zone == &"head":
        var head_bank: StringName = &"sever_head" if not _bank_empty(&"sever_head") else &"decap"
        _play_bank(head_bank, -9.5, 0.98, 1.02, 220)
    else:
        var limb_bank: StringName = &"sever_limb" if not _bank_empty(&"sever_limb") else &"gore"
        _play_bank(limb_bank, -11.0, 0.96, 1.04, 180)

func play_kill(archetype_id: StringName = &"swordsman") -> void:
    if archetype_id == &"warlord":
        _play_bank(&"boss_death", -8.5, 0.98, 1.02, 280)
    else:
        _play_bank(&"enemy_death", -14.0, 0.97, 1.04, 165)

func play_combo_tick(combo_count: int) -> void:
    if _bank_empty(&"combo") or combo_count < 5:
        return
    # Only milestone hits get a UI sting; normal hits remain tactile rather than noisy.
    if combo_count % 5 == 0:
        var pitch: float = clampf(0.96 + float(combo_count) * 0.006, 0.96, 1.12)
        _play_bank(&"combo", -16.0, pitch, pitch, 260)

func play_player_hurt(damage: float) -> void:
    if _bank_empty(&"hurt"):
        return
    var volume: float = lerpf(-16.0, -11.5, clampf(damage / 45.0, 0.0, 1.0))
    _play_bank(&"hurt", volume, 0.97, 1.03, 210)

func _bank_empty(key: StringName) -> bool:
    var bank: Array = sfx_banks.get(key, [])
    return bank.is_empty()

func _play_bank(key: StringName, volume_db: float, pitch_min: float, pitch_max: float, min_interval_ms: int) -> void:
    var bank: Array = sfx_banks.get(key, [])
    if bank.is_empty() or sfx_players.is_empty():
        return

    var now: int = Time.get_ticks_msec()
    var previous: int = int(last_category_play_ms.get(key, -100000))
    if now - previous < min_interval_ms:
        return
    last_category_play_ms[key] = now

    var stream: AudioStream = _pick_bank_stream(key)
    if stream == null:
        return

    var player: AudioStreamPlayer = _next_sfx_player()
    player.stop()
    player.stream = stream
    var category_volume := clampf(float(sfx_category_volumes.get(key, 1.0)), 0.0, 1.0)
    if category_volume <= 0.0001:
        return
    player.volume_db = volume_db + linear_to_db(category_volume)
    player.pitch_scale = rng.randf_range(pitch_min, pitch_max)
    player.play()

func _pick_bank_stream(key: StringName) -> AudioStream:
    var bank: Array = sfx_banks.get(key, [])
    if bank.is_empty():
        return null
    var index: int = 0
    if bank.size() > 1:
        index = rng.randi_range(0, bank.size() - 1)
        var previous: int = int(last_bank_stream_index.get(key, -1))
        if index == previous:
            index = (index + rng.randi_range(1, bank.size() - 1)) % bank.size()
    last_bank_stream_index[key] = index
    return bank[index] as AudioStream

func _next_sfx_player() -> AudioStreamPlayer:
    for player: AudioStreamPlayer in sfx_players:
        if not player.playing:
            return player
    var result: AudioStreamPlayer = sfx_players[sfx_cursor % sfx_players.size()]
    sfx_cursor = (sfx_cursor + 1) % sfx_players.size()
    return result
