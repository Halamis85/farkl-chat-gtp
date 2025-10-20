# scripts/enhanced_game_ui.gd
extends Control

@onready var camera = get_node("/root/Main/Camera3D")

var game_manager = null
var dice_manager = null
var audio_manager = null

# UI prvky
var lbl_player_name = null
var lbl_total_score = null
var lbl_round_bank = null
var lbl_available_dice = null
var lbl_message = null
var progress_dice = null

var btn_roll = null
var btn_bank = null
var btn_select = null

var tween: Tween

func _ready():
	print("\n" + "=".repeat(60))
	print("🎮 ENHANCED_GAME_UI INICIALIZACE")
	print("=".repeat(60))
	
	# Najdi manažery
	game_manager = get_node("/root/Main/GameManager")
	dice_manager = get_node("/root/Main/DiceManager")
	
	if has_node("/root/AudioManager"):
		audio_manager = get_node("/root/AudioManager")
	
	# Najdi UI prvky
	lbl_player_name = get_node_or_null("PlayerInfo/VBox/PlayerName")
	lbl_total_score = get_node_or_null("PlayerInfo/VBox/TotalScore")
	lbl_round_bank = get_node_or_null("RoundInfo/VBox/RoundBank")
	lbl_available_dice = get_node_or_null("RoundInfo/VBox/AvailableDice")
	lbl_message = get_node_or_null("PanelContainer/VBoxContainer/Message")
	progress_dice = get_node_or_null("DiceControl/DiceProgress")
	
	btn_roll = get_node_or_null("Actions/HBox/BtnRoll")
	btn_bank = get_node_or_null("Actions/HBox/BtnBank")
	btn_select = get_node_or_null("Actions/HBox/BtnSelect")
	
	# Připoj signály
	if game_manager:
		game_manager.turn_started.connect(_on_turn_started)
		game_manager.turn_ended.connect(_on_turn_ended)
		game_manager.round_scored.connect(_on_round_scored)
		game_manager.player_busted.connect(_on_player_busted)
		game_manager.game_won.connect(_on_game_won)
		game_manager.dice_reset_requested.connect(_on_dice_reset_requested)
	
	if dice_manager:
		dice_manager.all_dice_stopped.connect(_on_dice_stopped)
	
	# Připoj tlačítka
	if btn_roll:
		btn_roll.pressed.connect(_on_roll_pressed)
	if btn_bank:
		btn_bank.pressed.connect(_on_bank_pressed)
	if btn_select:
		btn_select.pressed.connect(_on_select_pressed)
	
	# Spusť hru
	game_manager.start_new_game(2, ["Hráč 1", "Hráč 2"])
	update_ui()
	
	print("\n✅ INICIALIZACE HOTOVA!")
	print("=".repeat(60) + "\n")

# ============ TLAČÍTKA ============

func _on_roll_pressed():
	print("\n🎮 [UI] ========== ROLL PRESSED ==========")
	
	if audio_manager and audio_manager.has_method("play_button_click"):
		audio_manager.play_button_click()
	
	if not can_roll():
		print("⚠️ Nelze házet")
		return
	
	btn_roll.disabled = true
	btn_bank.disabled = true
	btn_select.disabled = true
	
	if game_manager.roll_dice():
		# při start_turn() → clear_all_for_new_turn()
		var banked = dice_manager.get_banked_dice()
		print("📤 UI posílá zabanované: ", banked)
		
		dice_manager.roll_all_dice(banked)
		
		if lbl_message:
			lbl_message.text = "Házím..."
	
	print("==========================================\n")

func _on_bank_pressed():
	print("\n💾 [KLIK] BtnBank")
	
	if audio_manager and audio_manager.has_method("play_button_click"):
		audio_manager.play_button_click()
	
	if game_manager.can_bank():
		game_manager.bank_points()
		update_ui()

func _on_select_pressed():
	print("\n✅ [UI] ========== SELECT PRESSED ==========")
	
	if audio_manager and audio_manager.has_method("play_button_click"):
		audio_manager.play_button_click()
	
	var selected = dice_manager.get_selected_dice()
	print("📤 Vybrané kostky: ", selected)
	
	if selected.size() > 0:
		if game_manager.select_dice(selected):
			print("✅ GameManager přijal výběr")
			
			dice_manager.mark_dice_as_banked(selected)
			
			if lbl_message:
				lbl_message.text = "✅ Vybrané kostky započítány!"
			update_ui()
	else:
		print("⚠️ Žádné kostky nevybrány!")
		if lbl_message:
			lbl_message.text = "⚠️ Nevybral jsi žádné kostky!"
	
	print("============================================\n")

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
	print("\n⭐ SIGNÁL: round_scored (body: ", points, ")")
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
	"""Kostky se zastavily - předej GameManageru"""
	print("\n🎲 SIGNÁL: dice_stopped")
	if game_manager:
		game_manager.on_dice_rolled(_values)
	update_ui()

func _on_dice_reset_requested():
	"""Reset na začátku NOVÉHO TAHU"""
	print("\n🔄 [UI] SIGNÁL: dice_reset_requested")
	print("   GameManager už resetoval DiceManager")
	
	if btn_select:
		btn_select.text = "POTVRDIT VÝBĚR"
	
	if lbl_message:
		lbl_message.text = "🎲 Tvůj tah - hoď kostkami!"
	
	update_ui()

# ============ UTILITY ============

func can_roll() -> bool:
	"""Může házet?"""
	if game_manager.current_state == GameManager.GameState.SELECTING:
		return false
	return game_manager.can_roll()

func update_ui():
	"""Aktualizuj všechny UI prvky"""
	if not game_manager:
		return
	
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

# ============ CAMERA CONTROLS (VOLITELNÉ) ============

func _on_btn_camera_overview_pressed():
	if camera:
		camera.move_to_overview()

func _on_btn_camera_focused_pressed():
	if camera:
		camera.move_to_focused()
