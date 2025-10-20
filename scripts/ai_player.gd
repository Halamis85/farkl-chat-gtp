# scripts/ai_player.gd - OPRAVENÁ VERZE
extends Node

class_name AIPlayer

enum AILevel {
	EASY,
	NORMAL,
	HARD,
	EXPERT
}

var game_manager: GameManager = null
var dice_manager: DiceManager = null
var level: AILevel = AILevel.NORMAL

var thinking_delay: float = 1.5
var action_delay: float = 0.8

var decision_history: Array = []

func _ready():
	print("\n🤖 AI_PLAYER inicializován")

func init(game_mgr: GameManager, dice_mgr: DiceManager, ai_level: AILevel = AILevel.NORMAL):
	"""Inicializuj AI"""
	game_manager = game_mgr
	dice_manager = dice_mgr
	level = ai_level
	
	print("🤖 AI inicializován: ", AILevel.keys()[level])
	return self

# ============ ROZHODNUTÍ - HÁZET NEBO ULOŽIT ============

func make_decision_roll() -> void:
	"""AI se rozhoduje, zda hasovat"""
	await get_tree().create_timer(thinking_delay).timeout
	
	print("\n🤖 AI ROZHODOVÁNÍ:Hasovat?")
	print("   Banka: ", game_manager.get_current_bank())
	print("   Kostky: ", game_manager.get_available_dice())
	print("   Skóre: ", game_manager.get_player_score(game_manager.current_player))
	
	var should_roll = _evaluate_roll_decision()
	
	if should_roll:
		print("   ✅ AI: Budu HÁZET!")
		_record_decision("ROLL", "hasovat")
		await get_tree().create_timer(action_delay).timeout
		_click_roll_button()
	else:
		print("   💾 AI: Uložím BODY!")
		_record_decision("BANK", "uložit body")
		await get_tree().create_timer(action_delay).timeout
		_click_bank_button()

# ============ VÝBĚR KOSTEK ============

func make_decision_select(available_dice_indices: Array) -> void:
	"""AI vybírá kostky"""
	await get_tree().create_timer(thinking_delay).timeout
	
	print("\n🤖 AI VÝBĚR KOSTEK")
	print("   Dostupné indexy: ", available_dice_indices)
	print("   Poslední hod: ", game_manager.last_roll_values)
	
	# Najdi nejlepší výběr
	var best_selection = _find_best_selection(available_dice_indices)
	
	print("   ✅ AI vybírá: ", best_selection)
	print("   Body: ", _calculate_selection_score(best_selection))
	
	_record_decision("SELECT", str(best_selection))
	
	# ✅ OPRAVENO: Klikni na kostky
	_select_dice(best_selection)
	
	# ✅ OPRAVENO: Čekej a pak klikni na POTVRDIT
	await get_tree().create_timer(action_delay).timeout
	print("   (Klikám na BtnSelect...)")
	_click_select_button()

# ============ ROZHODOVACÍ LOGIKA ============

func _evaluate_roll_decision() -> bool:
	"""Rozhodni, zda má smysl házet znovu"""
	var current_bank = game_manager.get_current_bank()
	var total_score = game_manager.get_player_score(game_manager.current_player)
	var available_dice = game_manager.get_available_dice()
	
	if available_dice <= 0:
		print("   (Žádné kostky)")
		return false
	
	match level:
		AILevel.EASY:
			return _evaluate_roll_easy(current_bank, total_score)
		AILevel.NORMAL:
			return _evaluate_roll_normal(current_bank, total_score)
		AILevel.HARD:
			return _evaluate_roll_hard(current_bank, total_score)
		AILevel.EXPERT:
			return _evaluate_roll_expert(current_bank, total_score)
	
	return false

func _evaluate_roll_easy(bank: int, total: int) -> bool:
	"""EASY: Konzervativní"""
	if total < 500:
		return true
	
	if bank >= 200:
		print("   (Bezpečně: ", bank, " bodů)")
		return false
	
	return randf() > 0.5

func _evaluate_roll_normal(bank: int, total: int) -> bool:
	"""NORMAL: Vyvážené"""
	if total < 500:
		return true
	
	var target = 300
	if bank >= target:
		print("   (Cíl dosažen: ", bank, " >= ", target, ")")
		return randf() > 0.6
	
	print("   (Pokračuji - chci ", target, ", mám ", bank, ")")
	return true

func _evaluate_roll_hard(bank: int, total: int) -> bool:
	"""HARD: Agresivní"""
	if total < 500:
		return true
	
	var win_score = GameManager.WINNING_SCORE
	var distance_to_win = win_score - total
	
	if distance_to_win < 1500:
		print("   (Blízko cíle! Zbývá ", distance_to_win, " bodů)")
		return true
	
	var target = 500
	if bank < target:
		print("   (Agresivně: potřebuji ", target, ", mám ", bank, ")")
		return true
	
	return randf() > 0.3

func _evaluate_roll_expert(bank: int, _total: int) -> bool:
	"""EXPERT: Optimální"""
	# ✅ OPRAVENO: Přejmenován _total
	var expected_value = _calculate_expected_value(bank)
	
	print("   (Expert EVA: ", expected_value, ")")
	
	if expected_value > 50:
		return true
	
	return false

# ============ VÝBĚR KOSTEK ============

func _find_best_selection(available_indices: Array) -> Array:
	"""Najdi nejlepší výběr kostek"""
	var values = game_manager.last_roll_values
	
	match level:
		AILevel.EASY:
			return _select_easy(available_indices, values)
		AILevel.NORMAL:
			return _select_normal(available_indices, values)
		AILevel.HARD:
			return _select_hard(available_indices, values)
		AILevel.EXPERT:
			return _select_expert(available_indices, values)
	
	return available_indices

func _select_easy(available: Array, _values: Array) -> Array:
	"""EASY: Vyber co nejvíce bezpečně"""
	# ✅ OPRAVENO: Přejmenován _values
	var selected = []
	var triplet_value = _find_triplet(game_manager.last_roll_values)
	
	if triplet_value != -1:
		for i in range(game_manager.last_roll_values.size()):
			if available.has(i) and game_manager.last_roll_values[i] == triplet_value:
				if selected.size() < 3:
					selected.append(i)
		return selected
	
	for i in available:
		if game_manager.last_roll_values[i] == 1 or game_manager.last_roll_values[i] == 5:
			selected.append(i)
	
	return selected if selected.size() > 0 else available

func _select_normal(available: Array, _values: Array) -> Array:
	"""NORMAL: Vezmi všechny"""
	# ✅ OPRAVENO: Přejmenován _values
	return available

func _select_hard(available: Array, _values: Array) -> Array:
	"""HARD: Vezmi všechny"""
	# ✅ OPRAVENO: Přejmenován _values
	return available

func _select_expert(available: Array, _values: Array) -> Array:
	"""EXPERT: Optimalizuj"""
	# ✅ OPRAVENO: Přejmenován _values
	return available

# ============ POMOCNÉ FUNKCE ============

func _find_triplet(values: Array) -> int:
	"""Najdi triplet"""
	for val in range(1, 7):
		var count = 0
		for v in values:
			if v == val:
				count += 1
		if count >= 3:
			return val
	return -1

func _calculate_selection_score(indices: Array) -> int:
	"""Spočítej body"""
	var values = []
	for idx in indices:
		values.append(game_manager.last_roll_values[idx])
	
	var result = FarkleRules.evaluate_dice(values)
	return result.total_score

func _calculate_expected_value(current_bank: int) -> float:
	"""EVA pro další hod"""
	var success_prob = 0.7
	var _farkle_prob = 0.3  # ✅ OPRAVENO: Přejmenován s _
	var expected_points = 150.0
	
	var eva = (success_prob * expected_points) - (0.3 * current_bank)
	return eva

func _record_decision(decision_type: String, details: String):
	"""Zaznamenej rozhodnutí"""
	var record = {
		"time": Time.get_ticks_msec(),
		"type": decision_type,
		"details": details,
		"bank": game_manager.get_current_bank(),
		"level": AILevel.keys()[level]
	}
	decision_history.append(record)
	
	if decision_history.size() > 100:
		decision_history.pop_front()

# ============ UI INTERAKCE ============

func _click_roll_button():
	"""Klikni na HODIT"""
	var ui = get_tree().root.get_node_or_null("Main/GameUI")
	if not ui:
		print("   ❌ UI nenalezeno!")
		return
	
	var btn = ui.get_node_or_null("Actions/HBox/BtnRoll")
	if not btn:
		print("   ❌ BtnRoll nenalezen!")
		return
	
	if btn.disabled:
		print("   ⚠️ BtnRoll je zakázané!")
		return
	
	print("   ✅ BtnRoll kliknut!")
	btn.pressed.emit()

func _click_bank_button():
	"""Klikni na ULOŽIT"""
	var ui = get_tree().root.get_node_or_null("Main/GameUI")
	if not ui:
		print("   ❌ UI nenalezeno!")
		return
	
	var btn = ui.get_node_or_null("Actions/HBox/BtnBank")
	if not btn:
		print("   ❌ BtnBank nenalezen!")
		return
	
	if btn.disabled:
		print("   ⚠️ BtnBank je zakázané!")
		return
	
	print("   ✅ BtnBank kliknut!")
	btn.pressed.emit()

func _click_select_button():
	"""Klikni na POTVRDIT VÝBĚR"""
	var ui = get_tree().root.get_node_or_null("Main/GameUI")
	if not ui:
		print("   ❌ UI nenalezeno!")
		return
	
	var btn = ui.get_node_or_null("Actions/HBox/BtnSelect")
	if not btn:
		print("   ❌ BtnSelect nenalezen!")
		return
	
	if btn.disabled:
		print("   ⚠️ BtnSelect je zakázané! State: ", game_manager.current_state)
		return
	
	print("   ✅ BtnSelect kliknut!")
	btn.pressed.emit()

func _select_dice(indices: Array):
	"""Simuluj klik na kostky"""
	print("   (Vybírám kostky: ", indices, ")")
	for idx in indices:
		var dice = dice_manager.get_dice(idx)
		if dice:
			dice.dice_clicked.emit(dice)

# ============ VEŘEJNÉ ============

func get_decision_history() -> Array:
	"""Vrať historii"""
	return decision_history.duplicate()

func print_statistics():
	"""Vytiskni statistiku"""
	print("\n" + "=".repeat(60))
	print("🤖 AI STATISTIKA")
	print("=".repeat(60))
	print("Úroveň: ", AILevel.keys()[level])
	print("Rozhodnutí: ", decision_history.size())
	
	var rolls = 0
	var banks = 0
	var selects = 0
	
	for record in decision_history:
		match record.type:
			"ROLL": rolls += 1
			"BANK": banks += 1
			"SELECT": selects += 1
	
	print("- Háze: ", rolls)
	print("- Uloží: ", banks)
	print("- Vybírá: ", selects)
	print("=".repeat(60) + "\n")
