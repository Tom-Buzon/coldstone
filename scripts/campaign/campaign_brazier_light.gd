extends OmniLight3D
class_name HopliteCampaignBrazierLight

var base_energy := 2.7
var intensity_multiplier := 1.0
var flicker_amount := 0.14
var flicker_phase := 0.0

func _ready() -> void:
	add_to_group("campaign_brazier_light")
	flicker_phase = randf_range(0.0, TAU)

func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var slow_wave := sin(time * 7.1 + flicker_phase)
	var fast_wave := sin(time * 16.7 + flicker_phase * 1.73)
	var flicker := 1.0 + (slow_wave * 0.68 + fast_wave * 0.32) * flicker_amount
	light_energy = maxf(0.0, base_energy * intensity_multiplier * flicker)

func configure_atmosphere(intensity: float, flicker: float) -> void:
	intensity_multiplier = maxf(0.0, intensity)
	flicker_amount = clampf(flicker, 0.0, 0.65)
