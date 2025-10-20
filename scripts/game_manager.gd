# scripts/game_manager.gd
extends Node

class_name GameManager

signal turn_started(player_id: int)
signal turn_ended(player_id: int, total_score: int)
signal round_scored(points: int, bank: int)
signal player_busted(player_id: int)
signal game_won(player_id: int, final_score: int)
signal dice_selected(selected_indices: Array)
signal dice_reset_requested()

const MIN_SCORE_TO_ENTER = 500
const WINNING_SCORE = 10000

enum GameState {
	WAITING,
	ROLLING,
	SELECTING,
	ROUND_END,
	GAME_OVER
}

var current_state: GameState = GameState.WAITING
var current_player: int = 0
var num_players: int = 2

var player_scores: Array = []
var player_names: Array = []
var player_has_entered: Array = []
var is_ai: Array = []
var ai_players: Array = []

var current_round_bank: int = 0
var available_dice: int = 6
var selected_dice_indices: Array = []
var last_roll_values: Array = []
var last_roll_result: Dictionary = {}

var dice_manager: DiceManager = null

func _ready():
	pass

func init_with_ai(game_config: Dictionary) -> void:
	print("\n" + "=".repeat(60))
	print("🎲 INICIALIZACE HRY S AI")
	print("=".repeat(60))
	
	var mode = game_config.get("mode", "single")
	var current_player_name = game_config.get("current_player_display", "Hráč")
	var ai_count = game_config.get("ai_count", 1)
	var players_count = game_config.get("players_count", 2)
	
	var player_names_list = [current_player_name]
	var is_ai_list = [false]
	var ai_levels = []
	
	print("Režim: ", mode)
	print("Aktuální hráč: ", current_player_name)
	print("AI hráči: ", ai_count)
	
	match mode:
		"single":
			player_names_list.append("AI")
			is_ai_list.append(true)
			ai_levels.append(AIPlayer.AILevel.NORMAL)
		"local":
			for i in range(1, players_count):
				player_names_list.append("Hráč " + str(i + 1))
				is_ai_list.append(false)
		"online":
			player_names_list.append("Online Hráč")
			is_ai_list.append(false)
	
	start_new_game(player_names_list.size(), player_names_list, is_ai_list, ai_levels)

func start_new_game(players: int = 2, names: Array = [], ai_flags: Array = [], ai_levels: Array = []):
	print("\n" + "=".repeat(60))
	print("🎲 NOVÁ HRA SPOUŠTĚNA")
	print("=".repeat(60))
	
	num_players = players
	current_player = 0
	current_state = GameState.WAITING
	
	player_scores.clear()
	player_names.clear()
	player_has_entered.clear()
	is_ai.clear()
	ai_players.clear()
	
	if not dice_manager:
		dice_manager = get_node_or_null("/root/Main/DiceManager")
	
	var ai_index = 0
	for i in range(num_players):
		player_scores.append(0)
		player_has_entered.append(false)
		
		if i < names.size():
			player_names.append(names[i])
		else:
			player_names.append("Hráč " + str(i + 1))
		
		var is_ai_player = false
		if i < ai_flags.size():
			is_ai_player = ai_flags[i]
		
		is_ai.append(is_ai_player)
		
		if is_ai_player:
			var ai_level = AIPlayer.AILevel.NORMAL
			if ai_index < ai_levels.size():
				ai_level = ai_levels[ai_index]
			
			var ai = AIPlayer.new()
			ai.init(self, dice_manager, ai_level)
			add_child(ai)
			ai_players.append(ai)
			
			print("✅ AI hráč: ", player_names[i], " (", AIPlayer.AILevel.keys()[ai_level], ")")
			ai_index += 1
		else:
			ai_players.append(null)
			print("👤 Hráč: ", player_names[i])
	
	print("=".repeat(60) + "\n")
	start_turn()

func start_turn():
	"""Začni tah aktuálního hráče"""
	print("\n" + "=".repeat(60))
	print("🎮 NOVÝ TÁH")
	print("=".repeat(60))
	
	current_round_bank = 0
	available_dice = 6
	selected_dice_indices.clear()
	last_roll_values.clear()
	last_roll_result.clear()
	current_state = GameState.WAITING
	
	# ⚠️ OPRAVA: Volej clear_all_for_new_turn() místo clear_selection()
	if dice_manager:
		print("🧹 Resetuji DiceManager pro nový tah...")
		dice_manager.clear_all_for_new_turn()
	
	var player_type = "👤 Hráč" if not is_ai[current_player] else "🤖 AI"
	print(player_type + ": ", player_names[current_player])
	print("Skóre: ", player_scores[current_player])
	print("=".repeat(60) + "\n")
	
	turn_started.emit(current_player)
	dice_reset_requested.emit()
	
	if is_ai[current_player]:
		var ai = ai_players[current_player]
		if ai:
			ai.make_decision_roll()

func roll_dice() -> bool:
	if current_state == GameState.ROLLING:
		print("❌ Nelze házet - už se hází!")
		return false
	
	if available_dice <= 0:
		print("❌ Žádné kostky k hození!")
		return false
	
	print("\n🎲 ROLL: Házím ", available_dice, " kostkami")
	print("   Zabanované indexy: ", selected_dice_indices)
	
	current_state = GameState.ROLLING
	return true

func on_dice_rolled(values: Array):
	"""Zpracuj výsledek hodu"""
	last_roll_values = values
	
	var rolled_values = []
	var rolled_indices = []
	
	print("\n" + "=".repeat(60))
	print("🎲 VÝSLEDEK HODU")
	print("=".repeat(60))
	print("Všechny kostky: ", values)
	print("Zabanované indexy: ", selected_dice_indices)
	
	for i in range(values.size()):
		if not selected_dice_indices.has(i):
			rolled_values.append(values[i])
			rolled_indices.append(i)
	
	print("\nHodnuté kostky (bez banku):")
	print("  Hodnoty: ", rolled_values)
	print("  Indexy: ", rolled_indices)
	
	last_roll_result = FarkleRules.evaluate_dice(rolled_values)
	
	var remapped_scoring = []
	for local_idx in last_roll_result.available_dice:
		if local_idx < rolled_indices.size():
			remapped_scoring.append(rolled_indices[local_idx])
	
	last_roll_result.available_dice = remapped_scoring
	
	print("\n📊 VYHODNOCENÍ:")
	
	if last_roll_result.is_farkle:
		print("❌ FARKLE! Žádné body!")
		print("=".repeat(60) + "\n")
		handle_farkle()
		return
	
	print("✅ Body: ", last_roll_result.total_score)
	print("   Kombinace: ", last_roll_result.scoring_combinations)
	print("   Bodující indexy: ", last_roll_result.available_dice)
	print("=".repeat(60) + "\n")
	
	current_state = GameState.SELECTING
	
	if is_ai[current_player]:
		var ai = ai_players[current_player]
		if ai:
			ai.make_decision_select(last_roll_result.available_dice)

func select_dice(indices: Array) -> bool:
	"""Vyber kostky které chceš započítat"""
	print("\n" + "=".repeat(60))
	print("✅ VÝBĚR KOSTEK")
	print("=".repeat(60))
	print("Hráč vybírá: ", indices)
	
	if current_state != GameState.SELECTING:
		print("❌ Chyba: Nejsi ve stavu SELECTING!")
		print("=".repeat(60) + "\n")
		return false
	
	# Ověř že vybrané kostky bodují
	var scoring_dice = last_roll_result.available_dice
	print("Bodující indexy: ", scoring_dice)
	
	for idx in indices:
		if not scoring_dice.has(idx):
			print("❌ Kostka ", idx, " NEBODUJE!")
			print("=".repeat(60) + "\n")
			return false
	
	# ⚠️ KONTROLA: Pokud hráč vybral JEN NĚKTERÉ bodující kostky
	# a zbylé kostky NEBODUJÍ → bude FARKLE při dalším hodu!
	var remaining_indices = []
	for i in range(last_roll_values.size()):
		if not selected_dice_indices.has(i) and not indices.has(i):
			remaining_indices.append(i)
	
	if remaining_indices.size() > 0:
		# Zkontroluj jestli zbylé kostky bodují
		var remaining_values = []
		for idx in remaining_indices:
			remaining_values.append(last_roll_values[idx])
		
		var remaining_result = FarkleRules.evaluate_dice(remaining_values)
		
		if remaining_result.is_farkle:
			print("⚠️ VAROVÁNÍ: Zbývající kostky NEBODUJÍ!")
			print("   Pokud házíte znovu → automaticky FARKLE!")
			print("   Doporučujeme ULOŽIT BODY!")
	
	# Přidej vybrané indexy
	for idx in indices:
		if not selected_dice_indices.has(idx):
			selected_dice_indices.append(idx)
	
	# Vypočítej body
	var selected_values = []
	for idx in indices:
		selected_values.append(last_roll_values[idx])
	
	var selected_result = FarkleRules.evaluate_dice(selected_values)
	var points = selected_result.total_score
	
	current_round_bank += points
	available_dice -= indices.size()
	
	print("✅ Zabanované kostky: ", selected_dice_indices)
	print("   Přidáno do banky: +", points)
	print("   Banka kola: ", current_round_bank)
	print("   Zbývá kostek: ", available_dice)
	
	# ⚠️ HOT HAND - všechny kostky použity!
	if available_dice == 0:
		print("\n🔥 HOT HAND! Všechny kostky zpět!")
		available_dice = 6
		selected_dice_indices.clear()
		
		# ⚠️ RESET DiceManager - vrať kostky zpět!
		if dice_manager:
			dice_manager.clear_all_for_new_turn()
	
	print("=".repeat(60) + "\n")
	
	dice_selected.emit(selected_dice_indices)
	round_scored.emit(points, current_round_bank)
	
	current_state = GameState.WAITING
	
	if is_ai[current_player]:
		var ai = ai_players[current_player]
		if ai:
			ai.make_decision_roll()
	
	return true

func bank_points() -> bool:
	print("\n" + "=".repeat(60))
	print("💾 ULOŽENÍ BODŮ")
	print("=".repeat(60))
	
	if current_round_bank <= 0:
		print("❌ Nemáš co uložit!")
		print("=".repeat(60) + "\n")
		return false
	
	if not player_has_entered[current_player]:
		if current_round_bank < MIN_SCORE_TO_ENTER:
			print("❌ Potřebuješ min. ", MIN_SCORE_TO_ENTER, " bodů pro vstup!")
			print("=".repeat(60) + "\n")
			return false
		else:
			player_has_entered[current_player] = true
			print("✅ Hráč vstoupil do hry!")
	
	player_scores[current_player] += current_round_bank
	var total = player_scores[current_player]
	
	print("Kolo: +", current_round_bank, " bodů")
	print("Celkem: ", total, " bodů")
	print("=".repeat(60) + "\n")
	
	turn_ended.emit(current_player, total)
	
	if total >= WINNING_SCORE:
		end_game()
		return true
	
	next_player()
	return true

func handle_farkle():
	print("🚫 FARKLE ZPRACOVÁNÍ")
	print("   Banka kola vynulována: ", current_round_bank, " → 0")
	
	current_round_bank = 0
	player_busted.emit(current_player)
	
	next_player()

func next_player():
	current_player = (current_player + 1) % num_players
	start_turn()

func end_game():
	current_state = GameState.GAME_OVER
	
	var winner = 0
	var max_score = player_scores[0]
	
	for i in range(1, num_players):
		if player_scores[i] > max_score:
			max_score = player_scores[i]
			winner = i
	
	print("\n" + "=".repeat(60))
	print("🏆 VÍTĚZSTVÍ!")
	print("=".repeat(60))
	print("Vítěz: ", player_names[winner])
	print("Skóre: ", max_score)
	print("=".repeat(60) + "\n")
	
	game_won.emit(winner, max_score)

# ============ GETTERS ============

func get_current_player_name() -> String:
	return player_names[current_player]

func get_player_score(player_id: int) -> int:
	if player_id < player_scores.size():
		return player_scores[player_id]
	return 0

func get_current_bank() -> int:
	return current_round_bank

func get_available_dice() -> int:
	return available_dice

func is_current_player_ai() -> bool:
	return is_ai[current_player] if current_player < is_ai.size() else false

func can_roll() -> bool:
	return current_state == GameState.WAITING and available_dice > 0

func can_bank() -> bool:
	return current_state == GameState.WAITING and current_round_bank > 0

func get_game_state() -> GameState:
	return current_state
