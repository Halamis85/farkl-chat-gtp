extends Node

## Centrální systém pro všechny zvuky ve hře

# Audio streamy - přiřadíš v inspectoru nebo načteš ze složky
@export_group("Sound Effects")
@export var dice_roll_sounds: Array[AudioStream] = []
@export var dice_impact_sounds: Array[AudioStream] = []
@export var dice_select_sound: AudioStream
@export var button_click_sound: AudioStream
@export var score_sound: AudioStream
@export var farkle_sound: AudioStream
@export var win_sound: AudioStream
@export var cup_shake_sounds: Array[AudioStream] = []

@export_group("Music")
@export var background_music: AudioStream
@export var music_volume: float = 0.3

# Audio players
var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer = null
var current_sfx_index: int = 0
var max_sfx_players: int = 8

func _ready():
	# Vytvoř pool audio playerů pro SFX
	for i in range(max_sfx_players):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"  # Předpokládá že máš SFX audio bus
		add_child(player)
		sfx_players.append(player)
	
	# Vytvoř music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = linear_to_db(music_volume)
	add_child(music_player)
	
	# Spusť hudbu na pozadí
	if background_music:
		play_music()		

func play_sfx(sound: AudioStream, volume: float = 1.0, pitch: float = 1.0):
	"""Přehraj zvukový efekt"""
	if not sound:
		return
	
	# Najdi volný player
	var player = get_available_player()
	if player:
		player.stream = sound
		player.volume_db = linear_to_db(volume)
		player.pitch_scale = pitch
		player.play()

func get_available_player() -> AudioStreamPlayer:
	"""Najdi volný audio player"""
	# Zkus najít volný
	for player in sfx_players:
		if not player.playing:
			return player
	
	# Pokud není volný, použij round-robin
	current_sfx_index = (current_sfx_index + 1) % max_sfx_players
	return sfx_players[current_sfx_index]

func play_dice_roll():
	"""Zvuk házení kostkou"""
	if dice_roll_sounds.size() > 0:
		var sound = dice_roll_sounds[randi() % dice_roll_sounds.size()]
		play_sfx(sound, 0.8, randf_range(0.9, 1.1))

func play_dice_impact():
	"""Zvuk dopadu kostky"""
	if dice_impact_sounds.size() > 0:
		var sound = dice_impact_sounds[randi() % dice_impact_sounds.size()]
		play_sfx(sound, 0.6, randf_range(0.95, 1.05))

func play_dice_select():
	"""Zvuk výběru kostky"""
	if dice_select_sound:
		play_sfx(dice_select_sound, 0.7, 1.0)

func play_button_click():
	"""Zvuk kliknutí na tlačítko"""
	if button_click_sound:
		play_sfx(button_click_sound, 0.5, 1.0)

func play_score():
	"""Zvuk získání bodů"""
	if score_sound:
		play_sfx(score_sound, 0.8, 1.0)

func play_farkle():
	"""Zvuk Farkle (prohra)"""
	if farkle_sound:
		play_sfx(farkle_sound, 1.0, 1.0)

func play_win():
	"""Zvuk výhry"""
	if win_sound:
		play_sfx(win_sound, 1.0, 1.0)

func play_cup_shake():
	"""Zvuk třesení kelímku"""
	if cup_shake_sounds.size() > 0:
		var sound = cup_shake_sounds[randi() % cup_shake_sounds.size()]
		play_sfx(sound, 0.9, 1.0)

func play_music():
	"""Spusť pozadovou hudbu"""
	if background_music and music_player:
		music_player.stream = background_music
		music_player.play()

func stop_music():
	"""Zastav hudbu"""
	if music_player:
		music_player.stop()

func set_music_volume(volume: float):
	"""Nastav hlasitost hudby (0.0 - 1.0)"""
	if music_player:
		music_player.volume_db = linear_to_db(clamp(volume, 0.01, 1.0))

func set_sfx_volume(volume: float):
	"""Nastav hlasitost SFX (0.0 - 1.0)"""
	# Změň volume v audio bus
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamp(volume, 0.01, 1.0)))

func fade_out_music(duration: float = 1.0):
	"""Plynule ztlum hudbu"""
	if music_player:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, duration)
		await tween.finished
		music_player.stop()

func fade_in_music(duration: float = 1.0):
	"""Plynule zesiluj hudbu"""
	if music_player and background_music:
		music_player.volume_db = -80
		music_player.play()
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), duration)
		
