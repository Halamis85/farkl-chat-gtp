# UIEffectsManager.gd - Debug verze
extends Node

@onready var game_manager = get_node("/root/Main/GameManager")
@onready var dice_manager = get_node("/root/Main/DiceManager")
@onready var main = get_node("/root/Main")

var audio_manager: Node = null
var floating_score_scene = null
var particle_effect_scene = null

var tween: Tween

func _ready():
	print("\n" + "=".repeat(60))
	print("✨ UIEffectsManager INICIALIZACE")
	print("=".repeat(60))
	
	# KROK 1: Najdi audio manager
	print("\n🔊 Hledání audio manageru...")
	if has_node("/root/AudioManager"):
		audio_manager = get_node("/root/AudioManager")
		print("✅ Audio Manager nalezen")
	else:
		print("⚠️ Audio Manager nenalezen")
	
	# KROK 2: Načti FloatingScore scénu
	floating_score_scene = load("res://scenes/floating_score.tscn")
	if floating_score_scene:
		print()
	else:
		print("❌ FloatingScore scéna NENALEZENA! (res://scenes/floating_score.tscn)")
	
	# KROK 3: Načti ParticleEffect scénu
	particle_effect_scene = load("res://scenes/particle_effect.tscn")
	if particle_effect_scene:
		print()
	else:
		print("⚠️ ParticleEffect scéna nenalezena (volitelné)")
	
	# KROK 4: Připoj signály
	print("\n📡 Připojování signálů...")
	if game_manager:
		game_manager.round_scored.connect(_on_round_scored)
		print("✅ round_scored")
		game_manager.player_busted.connect(_on_player_busted)
		print("✅ player_busted")
		game_manager.turn_ended.connect(_on_turn_ended)
		print("✅ turn_ended")
		game_manager.game_won.connect(_on_game_won)
		print("✅ game_won")
	else:
		print("❌ GameManager nenalezen!")
	
	if dice_manager:
		dice_manager.all_dice_stopped.connect(_on_dice_stopped)
		print("✅ all_dice_stopped")
	else:
		print("❌ DiceManager nenalezen!")
	
	print("\n✅ UIEffectsManager HOTOV")
	print("=".repeat(60) + "\n")

func _on_round_scored(points: int, bank: int):
	"""Efekt když hráč zaznamená body"""
	print("\n⭐ _on_round_scored: points=" + str(points) + ", bank=" + str(bank))
	
	if points <= 0:
		return
	
	if not floating_score_scene:
		return
	
	# 1. Vytvoř floating score
	var table_center = Vector3(9.0, 2.0, -6.0)
	var floating = floating_score_scene.instantiate()
	main.add_child(floating)
	floating.global_position = table_center
	floating.set_duration(6.5) #Bude vidět 
	floating.set_rise_height(2.0)  #Zvedne se vyšší
	floating.set_text_size(6.0) # Větší text
	floating.set_score_text(points, true, Color.YELLOW)
	
	# 2. Zvuk
	if audio_manager and audio_manager.has_method("play_score"):
		audio_manager.play_score()
		print("  ✅ Zvuk přehrán")

func _on_dice_stopped(_values: Array):
	"""Efekt po zastavení kostek"""
	print("\n🎲 _on_dice_stopped")

func _on_player_busted(_player_id: int):
	"""FARKLE efekt"""
	print("\n❌ _on_player_busted")
	
	if not floating_score_scene:
		print("  ❌ FloatingScore scéna není načtena!")
		return
	
	# 1. Velké červené texty
	var table_center = Vector3(0, 2.5, 0)
	var farkle_text = floating_score_scene.instantiate()
	main.add_child(farkle_text)
	farkle_text.set_duration(6.5)#Bude vidět 
	farkle_text.set_rise_height(2.0) #Zvedne se vyšší
	farkle_text.global_position = table_center
	farkle_text.set_score_text(0, false, Color.RED)
	farkle_text.set_text_size(6.0)# Větší text
	
	# 2. Zvuk
	if audio_manager and audio_manager.has_method("play_farkle"):
		audio_manager.play_farkle()

func _on_turn_ended(player_id: int, total_score: int):
	"""Efekt na konci tahu"""
	print("\n⏹️ _on_turn_ended: player=" + str(player_id) + ", score=" + str(total_score))

func _on_game_won(player_id: int, final_score: int):
	"""VÍTĚZSTVÍ efekt"""
	print("\n🏆 _on_game_won: player=" + str(player_id) + ", score=" + str(final_score))

func spawn_particle_effect(position: Vector3, _color: Color):
	"""Vytvoř částicový efekt"""
	if particle_effect_scene:
		var particles = particle_effect_scene.instantiate()
		main.add_child(particles)
		particles.global_position = position

func create_screen_flash(color: Color, duration: float):
	"""Filmový efekt"""
	var flash_rect = ColorRect.new()
	get_tree().get_root().add_child(flash_rect)
	flash_rect.color = color
	flash_rect.anchor_right = 4.0
	flash_rect.anchor_bottom = 4.0
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, duration)
	
	await tween.finished
	flash_rect.queue_free()
