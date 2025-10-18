# scripts/game_persistence_manager.gd
extends Node


# Správa uložených her a jejich načítání

const GAMES_DIR = "user://games/"
const GAME_FILE_EXTENSION = ".farkle"
const MAX_SAVE_SLOTS = 10

func _ready():
	# Zajisti že složka existuje
	if not DirAccess.dir_exists_absolute(GAMES_DIR):
		DirAccess.make_dir_recursive_absolute(GAMES_DIR)

	
	print("✅ GamePersistenceManager inicializován")

# ===============================
# UKLÁDÁNÍ HRY
# ===============================

func save_game(game_state: Dictionary, slot: int = 0) -> bool:
	"""
	Ulož hru
	game_state: {
		"player_username": str,
		"game_mode": str,  # single, local, online
		"players": Array,  # [{name, score, ...}, ...]
		"current_player": int,
		"current_round": int,
		"dice_values": Array,
		"round_bank": int,
		"game_started": String,  # timestamp
		"elapsed_time": float,  # sekundy
		"bets": Array,  # [{player, amount}, ...]
		"difficulty": str,
		"custom_rules": Dictionary
	}
	"""
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		print("❌ Neplatný slot: ", slot)
		return false
	
	if game_state.is_empty():
		print("❌ Prázdný stav hry")
		return false
	
	var file_path = GAMES_DIR + "game_" + str(slot) + GAME_FILE_EXTENSION
	var save_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"slot": slot,
		"game_state": game_state
	}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		print("❌ Chyba při otevírání souboru: ", file_path)
		return false
	
	var json_string = JSON.stringify(save_data)
	file.store_string(json_string)
	print("✅ Hra uložena do slotu: ", slot)
	return true

func save_game_quick(game_state: Dictionary) -> bool:
	"""Rychlé uložení do posledního slotu"""
	return save_game(game_state, 0)

func save_game_auto(game_state: Dictionary) -> bool:
	"""Automatické uložení (pro pravidelné ukládání během hry)"""
	# Posuneme ostatní sloty a uložíme na začátek
	for i in range(MAX_SAVE_SLOTS - 1, 0, -1):
		if file_exists(i - 1):
			copy_save(i - 1, i)
	
	return save_game(game_state, 0)

# ===============================
# NAČÍTÁNÍ HRY
# ===============================

func load_game(slot: int = 0) -> Dictionary:
	"""Načti hru ze slotu"""
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		print("❌ Neplatný slot: ", slot)
		return {}
	
	var file_path = GAMES_DIR + "game_" + str(slot) + GAME_FILE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		print("❌ Slot je prázdný: ", slot)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("❌ Chyba při čtení souboru: ", file_path)
		return {}
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	
	if json.parse(json_string) != OK:
		print("❌ Chyba parsování: ", file_path)
		return {}
	
	var data = json.get_data()
	print("✅ Hra načtena ze slotu: ", slot)
	return data.get("game_state", {})

func load_quick_game() -> Dictionary:
	"""Načti poslední uloženou hru"""
	return load_game(0)

func load_game_for_player(username: String) -> Dictionary:
	"""Načti poslední hru konkrétního hráče"""
	for slot in range(MAX_SAVE_SLOTS):
		var game_state = load_game(slot)
		if not game_state.is_empty():
			if game_state.get("player_username") == username:
				return game_state
	
	print("⚠️ Žádná uložená hra pro hráče: ", username)
	return {}

# ===============================
# SPRÁVA SLOTŮ
# ===============================

func get_save_slots() -> Array:
	"""Vrať seznam všech slotů s informacemi"""
	var slots = []
	
	for slot in range(MAX_SAVE_SLOTS):
		var file_path = GAMES_DIR + "game_" + str(slot) + GAME_FILE_EXTENSION
		
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				var json_string = file.get_as_text()
				var json = JSON.new()
				
				if json.parse(json_string) == OK:
					var data = json.get_data()
					slots.append({
						"slot": slot,
						"exists": true,
						"timestamp": data.get("timestamp", ""),
						"player": data.get("game_state", {}).get("player_username", "?"),
						"round": data.get("game_state", {}).get("current_round", 0)
					})
				else:
					slots.append({
						"slot": slot,
						"exists": true,
						"timestamp": "Chyba",
						"player": "?",
						"round": 0
					})
		else:
			slots.append({
				"slot": slot,
				"exists": false,
				"timestamp": "",
				"player": "",
				"round": 0
			})
	
	return slots

func file_exists(slot: int) -> bool:
	"""Kontrola zda slot existuje"""
	var file_path = GAMES_DIR + "game_" + str(slot) + GAME_FILE_EXTENSION
	return FileAccess.file_exists(file_path)

func delete_save(slot: int) -> bool:
	"""Smaž uloženou hru"""
	var file_path = GAMES_DIR + "game_" + str(slot) + GAME_FILE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		print("❌ Slot neexistuje: ", slot)
		return false
	
	var error = DirAccess.remove_absolute(file_path)
	if error == OK:
		print("✅ Slot smazán: ", slot)
		return true
	
	print("❌ Chyba při mazání slotu: ", slot)
	return false

func copy_save(from_slot: int, to_slot: int) -> bool:
	"""Zkopíruj hru z jednoho slotu do druhého"""
	if not file_exists(from_slot):
		return false
	
	var game = load_game(from_slot)
	return save_game(game, to_slot)

func clear_all_saves() -> void:
	"""Smaž všechny uložené hry"""
	for slot in range(MAX_SAVE_SLOTS):
		delete_save(slot)
	print("✅ Všechny uložené hry smazány")

# ===============================
# EXPORT/IMPORT
# ===============================

func export_save(slot: int, export_path: String) -> bool:
	"""Exportuj hru do externího souboru"""
	if not file_exists(slot):
		return false
	
	var game = load_game(slot)
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	
	if file == null:
		return false
	
	var json_string = JSON.stringify(game)
	file.store_string(json_string)
	print("✅ Hra exportována: ", export_path)
	return true

func import_save(import_path: String, to_slot: int) -> bool:
	"""Importuj hru z externího souboru"""
	if not FileAccess.file_exists(import_path):
		return false
	
	var file = FileAccess.open(import_path, FileAccess.READ)
	if file == null:
		return false
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	
	if json.parse(json_string) != OK:
		return false
	
	var game_state = json.get_data()
	return save_game(game_state, to_slot)

# ===============================
# STATISTIKY SLOTŮ
# ===============================

func get_slot_info(slot: int) -> Dictionary:
	"""Vrať detailní info o slotu"""
	var file_path = GAMES_DIR + "game_" + str(slot) + GAME_FILE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		return {
			"exists": false,
			"empty": true
		}
	
	var game_state = load_game(slot)
	
	return {
		"exists": true,
		"empty": game_state.is_empty(),
		"player": game_state.get("player_username", "?"),
		"mode": game_state.get("game_mode", "?"),
		"round": game_state.get("current_round", 0),
		"elapsed_time": game_state.get("elapsed_time", 0),
		"players_count": game_state.get("players", []).size(),
		"file_path": file_path
	}

func get_total_playtime() -> float:
	"""Vrať celkový čas ve všech uložených hrách"""
	var total = 0.0
	
	for slot in range(MAX_SAVE_SLOTS):
		var game = load_game(slot)
		if not game.is_empty():
			total += game.get("elapsed_time", 0)
	
	return total

func get_most_recent_slot() -> int:
	"""Vrať slot s nejnovější hrou"""
	var newest_slot = -1
	var newest_time = ""
	
	for slot in range(MAX_SAVE_SLOTS):
		var file_path = GAMES_DIR + "game_" + str(slot) + GAME_FILE_EXTENSION
		
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				var json_string = file.get_as_text()
				var json = JSON.new()
				
				if json.parse(json_string) == OK:
					var data = json.get_data()
					var timestamp = data.get("timestamp", "")
					
					if timestamp > newest_time:
						newest_time = timestamp
						newest_slot = slot
	
	return newest_slot
