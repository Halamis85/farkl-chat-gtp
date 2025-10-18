# scripts/player_manager.gd
extends Node


# Singleton
static var instance: PlayerManager

# Cesty k souborům
const PLAYERS_DIR = "user://players/"
const PLAYER_FILE_EXTENSION = ".json"
const CURRENT_PLAYER_FILE = "user://current_player.json"

# Aktuální hráč
var current_player: Dictionary = {}
var all_players: Array[Dictionary] = []

func _ready():
	if instance == null:
		instance = self
	else:
		queue_free()
		return
	
	# Zajisti že složka pro hráče existuje
	if not DirAccess.dir_exists_absolute(PLAYERS_DIR):
		DirAccess.make_dir_recursive_absolute(PLAYERS_DIR)
	
	load_all_players()
	load_current_player()
	print("✅ PlayerManager inicializován")

# ===============================
# VYTVÁŘENÍ A REGISTRACE HRÁČE
# ===============================

func create_new_player(username: String, display_name: String) -> Dictionary:
	"""Vytvoř nového hráče"""
	if username.is_empty() or display_name.is_empty():
		print("❌ Jméno a display name nesmí být prázdné!")
		return {}
	
	# Kontrola duplikátu
	for player in all_players:
		if player.username == username:
			print("❌ Hráč s tímto jménem už existuje!")
			return {}
	
	var new_player = {
		"username": username,
		"display_name": display_name,
		"created_date": Time.get_datetime_string_from_system(),
		"last_played": "",
		
		# Statistiky
		"total_games": 0,
		"total_wins": 0,
		"total_losses": 0,
		"total_points_scored": 0,
		"best_round": 0,
		"average_score": 0.0,
		"farkle_count": 0,
		
		# Profil
		"avatar_color": Color.WHITE,
		"language": "cs",
		"difficulty": "normal"
	}
	
	all_players.append(new_player)
	save_player(new_player)
	print("✅ Nový hráč vytvořen: ", username)
	return new_player

func load_player(username: String) -> Dictionary:
	"""Načti hráče z disk"""
	var file_path = PLAYERS_DIR + username + PLAYER_FILE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		print("❌ Hráč nenalezen: ", username)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("❌ Chyba při čtení souboru: ", file_path)
		return {}
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	
	if parse_error != OK:
		print("❌ Chyba parsování JSON: ", file_path)
		return {}
	
	var player_data = json.get_data()
	print("✅ Hráč načten: ", username)
	return player_data

func save_player(player: Dictionary) -> bool:
	"""Ulož hráče na disk"""
	if player.is_empty() or not player.has("username"):
		print("❌ Neplatný hráč pro uložení!")
		return false
	
	var file_path = PLAYERS_DIR + player.username + PLAYER_FILE_EXTENSION
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		print("❌ Chyba při otevírání souboru: ", file_path)
		return false
	
	var json_string = JSON.stringify(player)
	file.store_string(json_string)
	print("✅ Hráč uložen: ", player.username)
	return true

func set_current_player(username: String) -> bool:
	"""Nastav aktuálního hráče"""
	var player = load_player(username)
	if player.is_empty():
		print("❌ Hráč nenalezen: ", username)
		return false
	
	current_player = player
	current_player.last_played = Time.get_datetime_string_from_system()
	save_player(current_player)
	
	# Ulož informaci o aktuálním hráči
	var current_file = FileAccess.open(CURRENT_PLAYER_FILE, FileAccess.WRITE)
	if current_file != null:
		current_file.store_string(JSON.stringify({"username": username}))
	
	print("✅ Aktuální hráč nastaven: ", username)
	return true

func get_current_player() -> Dictionary:
	"""Vrať aktuálního hráče"""
	return current_player.duplicate()

# ===============================
# NAČÍTÁNÍ A SPRÁVA
# ===============================

func load_all_players() -> void:
	"""Načti všechny hráče"""
	all_players.clear()
	
	var dir = DirAccess.open(PLAYERS_DIR)
	if dir == null:
		print("⚠️ Složka s hráči neexistuje")
		return
	
	dir.list_dir_begin()
	var filename = dir.get_next()
	
	while filename != "":
		if filename.ends_with(PLAYER_FILE_EXTENSION):
			var username = filename.trim_suffix(PLAYER_FILE_EXTENSION)
			var player = load_player(username)
			if not player.is_empty():
				all_players.append(player)
		filename = dir.get_next()
	
	print("✅ Načteno ", all_players.size(), " hráčů")

func load_current_player() -> void:
	"""Načti posledního přihlášeného hráče"""
	if not FileAccess.file_exists(CURRENT_PLAYER_FILE):
		print("⚠️ Žádný hráč není přihlášen")
		return
	
	var file = FileAccess.open(CURRENT_PLAYER_FILE, FileAccess.READ)
	if file == null:
		return
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	
	if parse_error == OK:
		var data = json.get_data()
		if data.has("username"):
			set_current_player(data.username)

func get_all_players() -> Array[Dictionary]:
	"""Vrať seznam všech hráčů"""
	return all_players

func player_exists(username: String) -> bool:
	"""Kontrola jestli hráč existuje"""
	for player in all_players:
		if player.username == username:
			return true
	return false

func delete_player(username: String) -> bool:
	"""Vymaž hráče"""
	var file_path = PLAYERS_DIR + username + PLAYER_FILE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		print("❌ Hráč nenalezen: ", username)
		return false
	
	var error = DirAccess.remove_absolute(file_path)
	if error == OK:
		all_players = all_players.filter(func(p): return p.username != username)
		print("✅ Hráč vymazán: ", username)
		return true
	
	print("❌ Chyba při mazání hráče")
	return false

# ===============================
# STATISTIKY A AKTUALIZACE
# ===============================

func update_player_stats(game_result: Dictionary) -> void:
	"""Aktualizuj statistiky hráče po hře
	game_result: {
		"winner": bool,
		"final_score": int,
		"best_round": int,
		"farkles": int,
		"games_count": int
	}
	"""
	if current_player.is_empty():
		print("❌ Žádný hráč není přihlášen!")
		return
	
	current_player.total_games += 1
	
	if game_result.get("winner", false):
		current_player.total_wins += 1
	else:
		current_player.total_losses += 1
	
	var score = game_result.get("final_score", 0)
	current_player.total_points_scored += score
	current_player.average_score = float(current_player.total_points_scored) / current_player.total_games
	current_player.best_round = max(current_player.best_round, game_result.get("best_round", 0))
	current_player.farkle_count += game_result.get("farkles", 0)
	
	save_player(current_player)
	print("✅ Statistiky aktualizovány")

func get_player_stats() -> Dictionary:
	"""Vrať statistiky aktuálního hráče"""
	return {
		"total_games": current_player.get("total_games", 0),
		"total_wins": current_player.get("total_wins", 0),
		"win_rate": (float(current_player.get("total_wins", 0)) / max(current_player.get("total_games", 1), 1)) * 100,
		"best_round": current_player.get("best_round", 0),
		"average_score": current_player.get("average_score", 0.0),
		"total_points": current_player.get("total_points_scored", 0),
		"farkle_count": current_player.get("farkle_count", 0)
	}
