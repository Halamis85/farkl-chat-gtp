# EnhancedGameUI.gd - ZJEDNODUŠENÁ VERZE s PŘÍMO CESTAMI
extends Control

# Cesty k manažerům
var game_manager = null
var dice_manager = null
var audio_manager = null

# UI Labels
var lbl_player_name = null
var lbl_total_score = null
var lbl_round_bank = null
var lbl_available_dice = null
var lbl_message = null
var progress_dice = null

# Tlačítka
var btn_roll = null
var btn_bank = null
var btn_select = null

var tween: Tween

func _ready():
	print("\n" + "=".repeat(60))
	print("🎮 ENHANCED_GAME_UI INICIALIZACE")
	print("=".repeat(60))
	
	# KROK 1: Najdi GameManager a DiceManager
	print("\n📍 Hledání manažerů...")
	game_manager = get_node("/root/Main/GameManager")
	if game_manager:
		print("✅ GameManager nalezen")
	else:
		print("❌ GameManager NENALEZEN!")
		return
	
	dice_manager = get_node("/root/Main/DiceManager")
	if dice_manager:
		print("✅ DiceManager nalezen")
	else:
		print("❌ DiceManager NENALEZEN!")
		return
	
	# KROK 2: Najdi audio manager
	print("\n🔊 Hledání audio manageru...")
	if has_node("/root/AudioManager"):
		audio_manager = get_node("/root/AudioManager")
		print("✅ AudioManager nalezen")
	else:
		print("⚠️ AudioManager nenalezen (volitelné)")
	
	# KROK 3: Najdi všechny UI prvky - PŘÍMÉ CESTY!
	print("\n🎨 Hledání UI prvků (přímé cesty)...")
	
	lbl_player_name = get_node_or_null("PanelContainer/VBoxContainer/PlayerInfo/VBox/PlayerName")
	if lbl_player_name:
		print("✅ PlayerName nalezen")
	else:
		print("❌ PlayerName NENALEZEN")
	
	lbl_total_score = get_node_or_null("PanelContainer/VBoxContainer/PlayerInfo/VBox/TotalScore")
	if lbl_total_score:
		print("✅ TotalScore nalezen")
	else:
		print("❌ TotalScore NENALEZEN")
	
	lbl_round_bank = get_node_or_null("PanelContainer/VBoxContainer/RoundInfo/VBox/RoundBank")
	if lbl_round_bank:
		print("✅ RoundBank nalezen")
	else:
		print("❌ RoundBank NENALEZEN")
	
	lbl_available_dice = get_node_or_null("PanelContainer/VBoxContainer/RoundInfo/VBox/AvailableDice")
	if lbl_available_dice:
		print("✅ AvailableDice nalezen")
	else:
		print("❌ AvailableDice NENALEZEN")
	
	lbl_message = get_node_or_null("PanelContainer/VBoxContainer/Message")
	if lbl_message:
		print("✅ Message nalezen")
	else:
		print("❌ Message NENALEZEN")
	
	progress_dice = get_node_or_null("PanelContainer/VBoxContainer/RoundInfo/VBox/DiceProgress")
	if progress_dice:
		print("✅ DiceProgress nalezen")
	else:
		print("❌ DiceProgress NENALEZEN")
	
	# KROK 4: Najdi tlačítka
	print("\n🔘 Hledání tlačítek...")
	btn_roll = get_node_or_null("PanelContainer/VBoxContainer/Actions/HBox/BtnRoll")
	if btn_roll:
		print("✅ BtnRoll nalezen")
	else:
		print("❌ BtnRoll NENALEZEN")
	
	btn_bank = get_node_or_null("PanelContainer/VBoxContainer/Actions/HBox/BtnBank")
	if btn_bank:
		print("✅ BtnBank nalezen")
	else:
		print("❌ BtnBank NENALEZEN")
	
	btn_select = get_node_or_null("PanelContainer/VBoxContainer/Actions/HBox/BtnSelect")
	if btn_select:
		print("✅ BtnSelect nalezen")
	else:
		print("❌ BtnSelect NENALEZEN")
	
	# KROK 5: Připoj signály
	print("\n📡 Připojování signálů...")
	if game_manager:
		game_manager.turn_started.connect(_on_turn_started)
		game_manager.turn_ended.connect(_on_turn_ended)
		game_manager.round_scored.connect(_on_round_scored)
		game_manager.player_busted.connect(_on_player_busted)
		game_manager.game_won.connect(_on_game_won)
		game_manager.dice_reset_requested.connect(_on_dice_reset)
		print("✅ GameManager signály připojeny")
	
	if dice_manager:
		dice_manager.all_dice_stopped.connect(_on_dice_stopped)
		print("✅ DiceManager signály připojeny")
	
	# KROK 6: Připoj tlačítka
	print("\n🖱️ Připojování tlačítek...")
	if btn_roll:
		btn_roll.pressed.connect(_on_roll_pressed)
		print("✅ BtnRoll připojen")
	
	if btn_bank:
		btn_bank.pressed.connect(_on_bank_pressed)
		print("✅ BtnBank připojen")
	
	if btn_select:
		btn_select.pressed.connect(_on_select_pressed)
		print("✅ BtnSelect připojen")
	
	# KROK 7: Spusť hru
	print("\n🎲 Spouštění hry...")
	game_manager.start_new_game(2, ["Hráč 1", "Hráč 2"])
	update_ui()
	
	print("\n✅ INICIALIZACE HOTOVA!")
	print("=".repeat(60) + "\n")

# ============ TLAČÍTKA ============

func _on_roll_pressed():
	print("\n🎲 [KLIK] BtnRoll")
	if audio_manager and audio_manager.has_method("play_button_click"):
		audio_manager.play_button_click()
	
	if not can_roll():
		return
	
	btn_roll.disabled = true
	btn_bank.disabled = true
	btn_select.disabled = true
	
	if lbl_message:
		lbl_message.text = "🎲 Házím kostkami..."
	
	if game_manager.roll_dice():
		var banked = dice_manager.get_banked_dice()
		dice_manager.roll_all_dice(banked)

func _on_bank_pressed():
	print("\n💾 [KLIK] BtnBank")
	if audio_manager and audio_manager.has_method("play_button_click"):
		audio_manager.play_button_click()
	
	if game_manager.can_bank():
		game_manager.bank_points()
		update_ui()

func _on_select_pressed():
	print("\n✅ [KLIK] BtnSelect")
	if audio_manager and audio_manager.has_method("play_button_click"):
		audio_manager.play_button_click()
	
	var selected = dice_manager.get_selected_dice()
	if selected.size() > 0:
		if game_manager.select_dice(selected):
			dice_manager.mark_dice_as_banked(selected)
			if lbl_message:
				lbl_message.text = "✅ Vybrané kostky započítány!"
			update_ui()
	else:
		if lbl_message:
			lbl_message.text = "⚠️ Nevybral jsi žádné kostky!"

# ============ SIGNÁLY Z HRY ============

func _on_turn_started(_player_id: int):
	print("\n🎮 SIGNÁL: turn_started")
	if lbl_player_name:
		lbl_player_name.text = "🎮 " + game_manager.get_current_player_name()
	if lbl_message:
		lbl_message.text = "🎲 Tvůj tah!"
	update_ui()

func _on_turn_ended(_player_id: int, _total_score: int):
	print("\n⏹️ SIGNÁL: turn_ended")
	if lbl_message:
		lbl_message.text = "💾 Body uloženy!"
	update_ui()

func _on_round_scored(points: int, _bank: int):
	print("\n⭐ SIGNÁL: round_scored (body: " + str(points) + ")")
	update_ui()

func _on_player_busted(_player_id: int):
	print("\n❌ SIGNÁL: player_busted")
	if lbl_message:
		lbl_message.text = "❌ FARKLE! Ztraceno vše!"
	update_ui()

func _on_game_won(_player_id: int, _final_score: int):
	print("\n🏆 SIGNÁL: game_won")
	if lbl_message:
		lbl_message.text = "🏆 VÍTĚZSTVÍ!"
	if btn_roll:
		btn_roll.disabled = true
	if btn_bank:
		btn_bank.disabled = true
	if btn_select:
		btn_select.disabled = true

func _on_dice_stopped(_values: Array):
	print("\n🎲 SIGNÁL: dice_stopped")
	if game_manager:
		game_manager.on_dice_rolled(_values)
	update_ui()

func _on_dice_reset():
	print("\n🔄 SIGNÁL: dice_reset")
	if dice_manager:
		dice_manager.clear_selection()

# ============ UTILITY ============

func can_roll() -> bool:
	if game_manager.current_state == GameManager.GameState.SELECTING:
		return false
	return game_manager.can_roll()

func update_ui():
	"""Aktualizuj všechny UI prvky"""
	if not game_manager:
		return
	
	# Jméno hráče je teď na desce, takže ho tu neaktualizuj
	# if lbl_player_name:
	#	lbl_player_name.text = "🎮 " + game_manager.get_current_player_name()
	
	if lbl_total_score:
		lbl_total_score.text = "Celkem: " + str(game_manager.get_player_score(game_manager.current_player))
	
	if lbl_round_bank:
		lbl_round_bank.text = "💰 Banka: " + str(game_manager.get_current_bank())
	
	if lbl_available_dice:
		lbl_available_dice.text = "🎲 Kostek: " + str(game_manager.get_available_dice()) + "/6"
	
	if progress_dice:
		progress_dice.value = (6 - game_manager.get_available_dice()) * 16.67
	
	if btn_roll:
		btn_roll.disabled = not can_roll()
	if btn_bank:
		btn_bank.disabled = not game_manager.can_bank()
	if btn_select:
		btn_select.disabled = game_manager.current_state != GameManager.GameState.SELECTING
