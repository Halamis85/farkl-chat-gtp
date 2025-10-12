extends Node

class_name GameManager

signal turn_started(player_id: int)
signal turn_ended(player_id: int, total_score: int)
signal round_scored(points: int, bank: int)
signal player_busted(player_id: int)
signal game_won(player_id: int, final_score: int)
signal dice_selected(selected_indices: Array)
signal dice_reset_requested()  # Nový signál pro reset kostek

# Herní konstanty
const MIN_SCORE_TO_ENTER = 500  # Minimální skóre pro první vstup do hry
const WINNING_SCORE = 10000

# Herní stav
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

# Data hráčů
var player_scores: Array = []  # Celkové skóre každého hráče
var player_names: Array = []
var player_has_entered: Array = []  # Zda hráč již vstoupil do hry (dal 500+)

# Aktuální kolo
var current_round_bank: int = 0  # Body v aktuálním kole (ještě nezapsané)
var available_dice: int = 6  # Kolik kostek je k dispozici
var selected_dice_indices: Array = []  # Indexy vybraných kostek
var last_roll_values: Array = []
var last_roll_result: Dictionary = {}

func _ready():
	pass

func start_new_game(players: int = 2, names: Array = []):
	"""Začni novou hru"""
	num_players = players
	current_player = 0
	current_state = GameState.WAITING
	
	# Inicializuj hráče
	player_scores.clear()
	player_names.clear()
	player_has_entered.clear()
	
	for i in range(num_players):
		player_scores.append(0)
		player_has_entered.append(false)
		
		if i < names.size():
			player_names.append(names[i])
		else:
			player_names.append("Hráč " + str(i + 1))
	
	start_turn()

func start_turn():
	"""Začni tah aktuálního hráče"""
	current_round_bank = 0
	available_dice = 6
	selected_dice_indices.clear()
	current_state = GameState.WAITING
	
	turn_started.emit(current_player)
	print("\n=== TAH HRÁČE: ", player_names[current_player], " ===")
	print("Celkové skóre: ", player_scores[current_player])
	
	# Vrať všechny kostky na původní pozice
	emit_signal("dice_reset_requested")

func roll_dice() -> bool:
	"""Hoď dostupnými kostkami"""
	if current_state == GameState.ROLLING:
		return false
	
	if available_dice <= 0:
		print("Žádné kostky k hození!")
		return false
	
	current_state = GameState.ROLLING
	selected_dice_indices.clear()
	return true

func on_dice_rolled(values: Array):
	"""Zpracuj výsledek hodu kostkami"""
	last_roll_values = values
	
	# Vyhodnoť JEN ty kostky, které se právě házely (nejsou v selected_dice_indices)
	var rolled_values = []
	var rolled_indices = []
	
	for i in range(values.size()):
		if not selected_dice_indices.has(i):
			rolled_values.append(values[i])
			rolled_indices.append(i)
	
	print("\nHod (jen házené kostky): ", rolled_values)
	print("Indexy hozených kostek: ", rolled_indices)
	
	last_roll_result = FarkleRules.evaluate_dice(rolled_values)
	
	# Přemapuj indexy z rolled_values zpět na původní indexy
	var remapped_scoring = []
	for local_idx in last_roll_result.available_dice:
		if local_idx < rolled_indices.size():
			remapped_scoring.append(rolled_indices[local_idx])
	
	last_roll_result.available_dice = remapped_scoring
	
	# Zkontroluj FARKLE
	if last_roll_result.is_farkle:
		print("❌ FARKLE! Žádné body z kola ztraceny!")
		handle_farkle()
		return
	
	print("✓ Body z hodu: ", last_roll_result.total_score)
	print("Kombinace: ", last_roll_result.scoring_combinations)
	print("Bodující indexy: ", last_roll_result.available_dice)
	print("⚠️ MUSÍŠ vybrat alespoň některé bodující kostky!")
	
	current_state = GameState.SELECTING

func select_dice(indices: Array) -> bool:
	"""
	Vyber kostky, které chceš započítat.
	indices: pole indexů vybraných kostek (0-5)
	"""
	if current_state != GameState.SELECTING:
		return false
	
	# Ověř, že vybrané kostky skutečně bodují
	var scoring_dice = last_roll_result.available_dice
	for idx in indices:
		if not scoring_dice.has(idx):
			print("Kostka ", idx, " neboduje!")
			return false
	
	# Přidej vybrané indexy k již vybraným z předchozích hodů
	for idx in indices:
		if not selected_dice_indices.has(idx):
			selected_dice_indices.append(idx)
	
	# Vypočítej body jen z nyní vybraných kostek
	var selected_values = []
	for idx in indices:
		selected_values.append(last_roll_values[idx])
	
	var selected_result = FarkleRules.evaluate_dice(selected_values)
	var points = selected_result.total_score
	
	current_round_bank += points
	available_dice -= indices.size()
	
	# Pokud použil všechny kostky, dostane je zpět (hot hand)
	if available_dice == 0:
		available_dice = 6
		selected_dice_indices.clear()  # Reset vybraných kostek
		print("🔥 HOT HAND! Všechny kostky zpět!")
	
	print("Přidáno do banky: ", points)
	print("Banka kola: ", current_round_bank)
	print("Zbývá kostek: ", available_dice)
	print("Vybrané indexy celkem: ", selected_dice_indices)
	
	dice_selected.emit(selected_dice_indices)
	round_scored.emit(points, current_round_bank)
	
	current_state = GameState.WAITING
	return true

func bank_points():
	"""Ulož body z kola a ukonči tah"""
	if current_round_bank <= 0:
		print("Nemáš co uložit!")
		return false
	
	# Kontrola vstupu do hry
	if not player_has_entered[current_player]:
		if current_round_bank < MIN_SCORE_TO_ENTER:
			print("Potřebuješ minimálně ", MIN_SCORE_TO_ENTER, " bodů pro vstup!")
			return false
		else:
			player_has_entered[current_player] = true
			print("✓ Hráč vstoupil do hry!")
	
	# Přidej body
	player_scores[current_player] += current_round_bank
	var total = player_scores[current_player]
	
	print("\n💰 Uloženo: ", current_round_bank, " bodů")
	print("Celkem: ", total)
	
	turn_ended.emit(current_player, total)
	
	# Kontrola výhry
	if total >= WINNING_SCORE:
		end_game()
		return true
	
	# Další hráč
	next_player()
	return true

func handle_farkle():
	"""Zpracuj Farkle (ztráta všech bodů)"""
	current_round_bank = 0
	player_busted.emit(current_player)
	
	# Další hráč
	next_player()

func next_player():
	"""Přepni na dalšího hráče"""
	current_player = (current_player + 1) % num_players
	start_turn()

func end_game():
	"""Ukonči hru"""
	current_state = GameState.GAME_OVER
	
	# Najdi vítěze
	var winner = 0
	var max_score = player_scores[0]
	
	for i in range(1, num_players):
		if player_scores[i] > max_score:
			max_score = player_scores[i]
			winner = i
	
	print("\n🏆 VÝHRA! ", player_names[winner], " vyhrává s ", max_score, " body!")
	game_won.emit(winner, max_score)

# Getter funkce
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

func can_roll() -> bool:
	return current_state == GameState.WAITING and available_dice > 0

func can_bank() -> bool:
	return current_state == GameState.WAITING and current_round_bank > 0

func get_game_state() -> GameState:
	return current_state
