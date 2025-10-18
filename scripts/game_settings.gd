# scripts/game_settings.gd
extends Node


# Autoload - přidej v Project → Project Settings → Autoload

# Soubor nastavení
const SETTINGS_FILE = "user://game_settings.json"

# Výchozí nastavení
var settings: Dictionary = {
	# Audio
	"master_volume": 0.8,
	"sfx_volume": 0.8,
	"music_volume": 0.6,
	
	# Vizuální
	"brightness": 1.0,
	"language": "cs",
	"animation_speed": 1.0,
	"screen_shake": true,
	"visual_effects": true,
	
	# Herní
	"difficulty": "normal",  # easy, normal, hard
	"auto_next_player": true,
	"show_hints": true,
	"show_animations": true,
	
	# Sítě
	"default_server": "localhost:5000",
	"player_name": "",
	
	# Statistiky
	"track_statistics": true,
	"send_telemetry": false
}

# Herní konfiguraci (konstanty)
const GAME_CONFIG = {
	"min_score_to_start": 500,
	"winning_score": 10000,
	"max_players_local": 6,
	"max_players_online": 8,
	"ai_levels": ["easy", "normal", "hard", "expert"],
	"min_bet": 100,
	"max_bet": 10000,
	"round_timeout": 120,  # sekundy
	"connection_timeout": 30
}

# Dostupné jazyky
const LANGUAGES = {
	"cs": "Čeština",
	"en": "English",
	"de": "Deutsch",
	"fr": "Français"
}

func _ready():
	load_settings()
	print("✅ GameSettings inicializován")

# ===============================
# NAČÍTÁNÍ A UKLÁDÁNÍ
# ===============================

func load_settings() -> void:
	"""Načti nastavení z souboru"""
	if not FileAccess.file_exists(SETTINGS_FILE):
		print("⚠️ Soubor nastavení neexistuje, používám výchozí")
		save_settings()
		return
	
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file == null:
		print("❌ Chyba při čtení nastavení")
		return
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	
	if json.parse(json_string) == OK:
		var loaded = json.get_data()
		# Sloučit s výchozím (aby se nezapomněly nová nastavení)
		for key in settings:
			if loaded.has(key):
				settings[key] = loaded[key]
		print("✅ Nastavení načteno")
	else:
		print("❌ Chyba parsování nastavení")

func save_settings() -> void:
	"""Ulož nastavení"""
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file == null:
		print("❌ Chyba při ukládání nastavení")
		return
	
	var json_string = JSON.stringify(settings)
	file.store_string(json_string)
	print("✅ Nastavení uloženo")

# ===============================
# GETTER/SETTER
# ===============================

func get_setting(key: String, default = null):
	"""Vrať nastavení"""
	if settings.has(key):
		return settings[key]
	return default

func set_setting(key: String, value) -> void:
	"""Nastav nastavení a ulož"""
	settings[key] = value
	save_settings()

func get_all_settings() -> Dictionary:
	"""Vrať všechna nastavení"""
	return settings.duplicate()

# ===============================
# AUDIO NASTAVENÍ
# ===============================

func set_master_volume(volume: float) -> void:
	"""Nastav hlavní hlasitost (0.0 - 1.0)"""
	set_setting("master_volume", clamp(volume, 0.0, 1.0))
	apply_audio_settings()

func set_sfx_volume(volume: float) -> void:
	"""Nastav hlasitost SFX"""
	set_setting("sfx_volume", clamp(volume, 0.0, 1.0))
	apply_audio_settings()

func set_music_volume(volume: float) -> void:
	"""Nastav hlasitost hudby"""
	set_setting("music_volume", clamp(volume, 0.0, 1.0))
	apply_audio_settings()

func apply_audio_settings() -> void:
	"""Aplikuj audio nastavení"""
	if AudioServer.get_bus_count() == 0:
		return
	
	var master_idx = AudioServer.get_bus_index("Master")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	var music_idx = AudioServer.get_bus_index("Music")
	
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(
			master_idx,
			linear_to_db(settings.master_volume)
		)
	
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(
			sfx_idx,
			linear_to_db(settings.sfx_volume)
		)
	
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(
			music_idx,
			linear_to_db(settings.music_volume)
		)

# ===============================
# VIZUÁLNÍ NASTAVENÍ
# ===============================

func set_language(lang: String) -> void:
	"""Nastav jazyk"""
	if LANGUAGES.has(lang):
		set_setting("language", lang)
		print("🌐 Jazyk nastaven na: ", lang)
	else:
		print("❌ Jazyk není podporován: ", lang)

func set_brightness(brightness: float) -> void:
	"""Nastav jas (0.0 - 2.0)"""
	set_setting("brightness", clamp(brightness, 0.1, 2.0))

func set_animation_speed(speed: float) -> void:
	"""Nastav rychlost animací (0.5 - 2.0)"""
	set_setting("animation_speed", clamp(speed, 0.5, 2.0))

func set_screen_shake(enabled: bool) -> void:
	"""Povoluj/zakázuj třesy obrazovky"""
	set_setting("screen_shake", enabled)

# ===============================
# HERNÍ NASTAVENÍ
# ===============================

func set_difficulty(difficulty: String) -> void:
	"""Nastav obtížnost"""
	if ["easy", "normal", "hard"].has(difficulty):
		set_setting("difficulty", difficulty)
		print("⚙️ Obtížnost: ", difficulty)
	else:
		print("❌ Neznámá obtížnost: ", difficulty)

func get_game_config(key: String):
	"""Vrať herní konfiguraci"""
	if GAME_CONFIG.has(key):
		return GAME_CONFIG[key]
	return null

# ===============================
# STATISTIKY
# ===============================

func is_tracking_stats() -> bool:
	"""Jsou statistiky sledovány?"""
	return get_setting("track_statistics", true)

func is_telemetry_enabled() -> bool:
	"""Je telemetrie povolena?"""
	return get_setting("send_telemetry", false)

func get_language_name(lang_code: String) -> String:
	"""Vrať jméno jazyka"""
	return LANGUAGES.get(lang_code, lang_code)

func get_supported_languages() -> Array:
	"""Vrať seznam podporovaných jazyků"""
	return LANGUAGES.keys()

# ===============================
# RESET
# ===============================

func reset_to_defaults() -> void:
	"""Resetuj všechna nastavení na výchozí"""
	settings = {
		"master_volume": 0.8,
		"sfx_volume": 0.8,
		"music_volume": 0.6,
		"brightness": 1.0,
		"language": "cs",
		"animation_speed": 1.0,
		"screen_shake": true,
		"visual_effects": true,
		"difficulty": "normal",
		"auto_next_player": true,
		"show_hints": true,
		"show_animations": true,
		"default_server": "localhost:5000",
		"player_name": "",
		"track_statistics": true,
		"send_telemetry": false
	}
	save_settings()
	apply_audio_settings()
	print("✅ Nastavení resetováno na výchozí")

# ===============================
# EXPORT/IMPORT
# ===============================

func export_settings(file_path: String) -> bool:
	"""Exportuj nastavení do souboru"""
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	var json_string = JSON.stringify(settings)
	file.store_string(json_string)
	print("✅ Nastavení exportováno: ", file_path)
	return true

func import_settings(file_path: String) -> bool:
	"""Importuj nastavení ze souboru"""
	if not FileAccess.file_exists(file_path):
		print("❌ Soubor nenalezen: ", file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	
	if json.parse(json_string) == OK:
		var loaded = json.get_data()
		for key in loaded:
			if settings.has(key):
				settings[key] = loaded[key]
		save_settings()
		apply_audio_settings()
		print("✅ Nastavení importováno: ", file_path)
		return true
	
	print("❌ Chyba parsování nastavení")
	return false
