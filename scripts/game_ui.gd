extends Control

@onready var game_manager = get_node("/root/Main/GameManager")
@onready var dice_manager = get_node("/root/Main/DiceManager")

var audio_manager: Node = null

# UI elementy - vytvoř je v editoru nebo dynamicky
@onready var lbl_player_name = $VBoxContainer/PlayerInfo/PlayerName
@onready var lbl_total_score = $VBoxContainer/PlayerInfo/TotalScore
@onready var lbl_round_bank = $VBoxContainer/RoundInfo/RoundBank
@onready var lbl_available_dice = $VBoxContainer/RoundInfo/AvailableDice
@onready var lbl_last_roll = $VBoxContainer/RollInfo/LastRoll
@onready var btn_roll = $VBoxContainer/Actions/BtnRoll
@onready var btn_bank = $VBoxContainer/Actions/BtnBank
@onready var btn_select = $VBoxContainer/Actions/BtnSelect
@onready var lbl_message = $VBoxContainer/Message

var auto_select_mode: bool = false  # Vypnuto automatické bankování - hráč vybírá sám

func _ready():
	# Připoj signály z game manageru
	game_manager.turn_started.connect(_on_turn_started)
	game_manager.turn_ended.connect(_on_turn_ended)
	game_manager.round_scored.connect(_on_round_scored)
	game_manager.player_busted.connect(_on_player_busted)
	game_manager.game_won.connect(_on_game_won)
	game_manager.dice_reset_requested.connect(_on_dice_reset_requested)
	
	# Připoj signály z dice manageru
	dice_manager.all_dice_stopped.connect(_on_dice_stopped)
	
	# Připoj tlačítka
	btn_roll.pressed.connect(_on_roll_pressed)
	btn_bank.pressed.connect(_on_bank_pressed)
	btn_select.pressed.connect(_on_select_pressed)
	
	# Začni hru
	game_manager.start_new_game(2, ["Hráč 1", "Hráč 2"])
	update_ui()

func _on_dice_reset_requested():
	"""Reset všech kostek na začátku tahu"""
	dice_manager.clear_selection()
	# Auto-select je vypnutý, takže tlačítko bude jen POTVRDIT
	btn_select.text = "POTVRDIT VÝBĚR"

func can_roll() -> bool:
	"""Kontrola, jestli může házet - musí nejdřív vybrat kostky z předchozího hodu"""
	# Pokud je ve stavu SELECTING, NEMŮŽE házet dokud nevybere kostky
	if game_manager.current_state == GameManager.GameState.SELECTING:
		return false
	return game_manager.can_roll()

func _on_roll_pressed():
	if can_roll():
		btn_roll.disabled = true
		btn_bank.disabled = true
		btn_select.disabled = true
		
		if game_manager.roll_dice():
			# Hoď jen těmi kostkami, které NEJSOU zabanované
			var banked = dice_manager.get_banked_dice()
			print("🎮 UI: Posílám zabanované kostky: ", banked)
			dice_manager.roll_all_dice(banked)
			lbl_message.text = "Házím..."

func _on_bank_pressed():
	if game_manager.can_bank():
		game_manager.bank_points()
		# Kostky se resetují automaticky při dalším tahu (dice_reset_requested signál)
		update_ui()

func _on_select_pressed():
	"""Potvrď výběr kostek"""
	var selected = dice_manager.get_selected_dice()
	if selected.size() > 0:
		if game_manager.select_dice(selected):
			# Přesuň kostky do banked
			dice_manager.mark_dice_as_banked(selected)
			lbl_message.text = "✅ Vybrané kostky započítány!"
			update_ui()
	else:
		lbl_message.text = "⚠️ Nevybral jsi žádné kostky!"

func _on_dice_stopped(values: Array):
	game_manager.on_dice_rolled(values)
	update_ui()
	
	# Po zastavení kostek - zobraz možné kombinace a čekaj na výběr hráče
	if not game_manager.last_roll_result.is_farkle:
		btn_select.disabled = false
		btn_roll.disabled = true  # NELZE házet dokud nevybereš kostky!
		var scoring = game_manager.last_roll_result.scoring_combinations
		lbl_message.text = "🎯 Možnosti: " + str(scoring) + "\n⚠️ MUSÍŠ vybrat alespoň některé kostky!"
	else:
		# FARKLE - automaticky přejde na dalšího hráče
		lbl_message.text = "❌ FARKLE! Žádné bodující kostky!\n⏭️ Přechod na dalšího hráče..."
		btn_select.disabled = true
		btn_roll.disabled = true
		btn_bank.disabled = true

func _on_turn_started(_player_id: int):
	lbl_message.text = "🎲 Tah hráče: " + game_manager.get_current_player_name()
	update_ui()

func _on_turn_ended(_player_id: int, total_score: int):
	lbl_message.text = "Body uloženy! Celkem: " + str(total_score)
	update_ui()

func _on_round_scored(_points: int, _bank: int):
	update_ui()

func _on_player_busted(_player_id: int):
	lbl_message.text = "❌ FARKLE! Ztraceno vše!"
	update_ui()

func _on_game_won(player_id: int, _final_score: int):
	lbl_message.text = "🏆 " + game_manager.player_names[player_id] + " VYHRÁVÁ!"
	btn_roll.disabled = true
	btn_bank.disabled = true

func update_ui():
	# Aktualizuj informace o hráči
	lbl_player_name.text = "Hráč: " + game_manager.get_current_player_name()
	lbl_total_score.text = "Celkem: " + str(game_manager.get_player_score(game_manager.current_player))
	
	# Aktualizuj info o kole
	lbl_round_bank.text = "Banka: " + str(game_manager.get_current_bank())
	lbl_available_dice.text = "Kostek: " + str(game_manager.get_available_dice())
	
	# Poslední hod
	if game_manager.last_roll_values.size() > 0:
		lbl_last_roll.text = "Poslední: " + str(game_manager.last_roll_values)
	
	# Tlačítka
	btn_roll.disabled = not can_roll()  # Použij naši funkci
	btn_bank.disabled = not game_manager.can_bank()
	
	# Select tlačítko - vždy "POTVRDIT VÝBĚR"
	btn_select.text = "POTVRDIT VÝBĚR"
	btn_select.disabled = game_manager.current_state != GameManager.GameState.SELECTING
