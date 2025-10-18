extends Node3D
#main
@onready var dice_manager = $DiceManager
@onready var game_manager = $GameManager 

func _ready():
	# Připoj signály
	dice_manager.all_dice_stopped.connect(_on_all_dice_stopped)
	dice_manager.dice_rolling_started.connect(_on_dice_rolling_started)
	
	print("\n" + "=".repeat(60))
	print("🎲 HERNÍ SCÉNA INICIALIZACE")
	print("=".repeat(60))
	
	# ✅ NOVÝ KÓD - Načti konfiguraci z MainMenu
	var game_config = get_tree().root.get_meta("game_config") if get_tree().root.has_meta("game_config") else {}
	
	if not game_config.is_empty():
		print("\n📋 Načtena konfigurace hry:")
		print("   Režim: ", game_config.mode)
		print("   Hráč: ", game_config.current_player_display)
		print("   AI: ", game_config.ai_count)
		
		# Inicializuj hru s těmito hráči
		_initialize_game_with_config(game_config)
	else:
		print("⚠️ Žádná konfigurace z MainMenu - Default nastavení")
		# Výchozí - 2 hráči (test)
		game_manager.start_new_game(2, ["Hráč 1", "Hráč 2"])
	
	print("\n✅ Hra připravena k hraní!")
	print("   MEZERNÍK - Hoď všemi kostkami")
	print("   R - Reset pozic")
	print("=".repeat(60) + "\n")

func _initialize_game_with_config(config: Dictionary) -> void:
	"""Inicializuj hru podle konfigurace z MainMenu"""
	var mode = config.mode
	var current_player = config.current_player_display
	var ai_count = config.ai_count
	var players_count = config.players_count
	
	# Vytvoř seznam jmen hráčů
	var player_names = [current_player]
	
	match mode:
		"single":
			# 1 hráč + 1 AI
			player_names.append("AI")
			game_manager.start_new_game(2, player_names)
		
		"local":
			# 2+ hráčů
			for i in range(1, players_count):
				player_names.append("Hráč " + str(i + 1))
			game_manager.start_new_game(players_count, player_names)
		
		"online":
			# 2 hráči online (připraveno pro PHASE 3)
			player_names.append("Online Hráč")
			game_manager.start_new_game(2, player_names)
		
		_:
			print("❌ Neznámý režim: ", mode)
			game_manager.start_new_game(2, ["Hráč 1", "Hráč 2"])

func _on_dice_rolling_started():
	print("Házím kostkami...")

func _on_all_dice_stopped(values: Array):
	print("\n=== VÝSLEDEK ===")
	print("Hodnoty kostek: ", values)
	
	# Vyhodnoť pomocí Farkle pravidel
	var result = FarkleRules.evaluate_dice(values)
	
	print("\n--- BODOVÁNÍ ---")
	if result.is_farkle:
		print("❌ FARKLE! Žádné body!")
	else:
		print("✓ Celkové body: ", result.total_score)
		print("Kombinace:")
		for combo in result.scoring_combinations:
			print("  - ", combo)
		print("Bodující kostky (indexy): ", result.available_dice)
	print("==================\n")
