# scripts/main.gd
extends Node3D

@onready var dice_manager = $DiceManager
@onready var game_manager = $GameManager
@onready var camera = $Camera3D

func _ready():
	# Připoj signály
	dice_manager.all_dice_stopped.connect(_on_all_dice_stopped)
	dice_manager.dice_rolling_started.connect(_on_dice_rolling_started)
	
	# Camera signály
	if camera:
		camera.camera_movement_complete.connect(_on_camera_complete)
	
	# Game manager signály
	game_manager.turn_started.connect(_on_turn_started)
	game_manager.player_busted.connect(_on_player_busted)
	game_manager.round_scored.connect(_on_round_scored)
	
	# Načti konfiguraci z MainMenu
	var game_config = get_tree().root.get_meta("game_config") if get_tree().root.has_meta("game_config") else {}
	
	if not game_config.is_empty():
		print("\n📋 Načtena konfigurace hry:")
		print("   Režim: ", game_config.mode)
		print("   Hráč: ", game_config.current_player_display)
		print("   AI: ", game_config.ai_count)
		
		#  Inicializuj hru  AI
		game_manager.init_with_ai(game_config)
	else:
		print("⚠️ Žádná konfigurace - Default ")
		game_manager.start_new_game(2, ["Hráč 1", "Hráč 2"])
	
	print("\n✅ Hra připravena!")
	print("=".repeat(60) + "\n")

func _initialize_game_with_config(config: Dictionary) -> void:
	"""Inicializuj hru podle konfigurace"""
	var mode = config.mode
	var current_player = config.current_player_display
	var ai_count = config.ai_count
	var players_count = config.players_count
	
	var player_names = [current_player]
	
	match mode:
		"single":
			player_names.append("AI")
			game_manager.start_new_game(2, player_names)
		"local":
			for i in range(1, players_count):
				player_names.append("Hráč " + str(i + 1))
			game_manager.start_new_game(players_count, player_names)
		"online":
			player_names.append("Online Hráč")
			game_manager.start_new_game(2, player_names)
		_:
			game_manager.start_new_game(2, ["Hráč 1", "Hráč 2"])

# ========================================
# SIGNÁLY - DICE
# ========================================

func _on_dice_rolling_started():
	"""HOD ZAČÍNÁ - ZAMKNI kameru"""
	print("🎬 🔒 Hod začíná - LOCK camera")
	
	if camera:
		camera.lock_camera()

func _on_all_dice_stopped(values: Array):
	"""Kostky se zastavily - ODEMKNI a zaměř"""
	
	# ⚠️ DEBUG: Tento výpis je ZAVÁDĚJÍCÍ - vyhodnocuje i zabanované kostky!
	# GameManager.on_dice_rolled() dělá správné vyhodnocení
	print("\n==========================================")
	print("🎲 DEBUG: Všechny kostky zastaveny")
	print("   Hodnoty (všechny): ", values)
	print("   ⚠️ (GameManager vyhodnotí jen nové kostky)")
	print("==========================================\n")
	
	# ⭐ CAMERA HANDLING
	if camera:
		print("🎬 🔓 Kostky zastaveny - UNLOCK camera")
		camera.unlock_camera()
		
		# Počkej chvíli na usazení
		await get_tree().create_timer(0.3).timeout
		
		# Získej pozice VIDITELNÝCH kostek
		var dice_positions = []
		for dice in dice_manager.dice_array:
			if dice.visible:
				dice_positions.append(dice.global_position)
		
		print("📍 Zarámovávám ", dice_positions.size(), " kostek")
		
		# Zaměř na kostky
		camera.move_to_focused(dice_positions, false)
		
		# Lehký shake po dopadu
		await camera.camera_movement_complete
		camera.add_camera_shake(0.15, 0.2)

# ========================================
# SIGNÁLY - GAME MANAGER
# ========================================

func _on_turn_started(_player_id: int):
	"""Začátek tahu - ODEMKNI a overview"""
	print("🎬 Začátek tahu - overview")
	
	if camera:
		camera.unlock_camera()
		camera.move_to_overview(false)

func _on_round_scored(points: int, _bank: int):
	"""Body započítány - jen efekt"""
	print("🎬 Skóre: ", points)
	
	# Lehký shake podle počtu bodů
	if camera:
		var intensity = clamp(points / 300.0, 0.05, 0.15)
		camera.add_camera_shake(intensity, 0.3)

func _on_player_busted(_player_id: int):
	"""FARKLE - lehký efekt"""
	print("🎬 FARKLE!")
	
	if camera:
		camera.add_camera_shake(0.3, 0.5)

func _on_camera_complete():
	"""Kamera dokončila přesun"""
	print("✅ Camera transition complete")

# ========================================
# DEBUG KLÁVESY
# ========================================

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F9:
				if camera:
					camera.debug_print_state()
			KEY_F12:
				if camera:
					camera.force_stop()
					camera.unlock_camera()
					camera.move_to_overview(true)
