# scripts/main_menu.gd
extends Node

# Reference na panely
@onready var main_panel = $MainPanel
@onready var register_panel = $RegisterPanel
@onready var select_player_panel = $SelectPlayerPanel
@onready var game_setup_panel = $GameSetupPanel
@onready var statistics_panel = $StatisticsPanel
@onready var settings_panel = $SettingsPanel

# PlayerManager singleton
var player_manager: PlayerManager

# Všechny panely pro snadnou správu
var all_panels: Array[Control] = []

# Audio manager
var audio_manager: Node

func _ready():
	# Inicializuj PlayerManager (jako singleton)
	if not PlayerManager.instance:
		var pm = PlayerManager.new()
		add_child(pm)
		player_manager = pm
	else:
		player_manager = PlayerManager.instance
	
	# Najdi audio manager
	if has_node("/root/AudioManager"):
		audio_manager = get_node("/root/AudioManager")
	
	# Registruj všechny panely
	all_panels = [
		main_panel,
		register_panel,
		select_player_panel,
		game_setup_panel,
		statistics_panel,
		settings_panel
	]
	
	# Inicializuj UI
	_setup_main_panel()
	_setup_register_panel()
	_setup_select_player_panel()
	_setup_game_setup_panel()
	_setup_statistics_panel()
	_setup_settings_panel()
	
	# Zobraz hlavní menu
	show_panel("main")
	
	print("✅ MainMenu inicializován")

# ===================================
# SPRÁVA PANELŮ
# ===================================

func show_panel(panel_name: String) -> void:
	"""Zobraz konkrétní panel a skryj ostatní"""
	for panel in all_panels:
		panel.visible = false
	
	match panel_name:
		"main":
			main_panel.visible = true
		"register":
			register_panel.visible = true
			_refresh_register_panel()
		"select_player":
			select_player_panel.visible = true
			_refresh_select_player_panel()
		"game_setup":
			game_setup_panel.visible = true
			_refresh_game_setup_panel()
		"statistics":
			statistics_panel.visible = true
			_refresh_statistics_panel()
		"settings":
			settings_panel.visible = true
			_refresh_settings_panel()
	
	print("📺 Panel: ", panel_name)

# ===================================
# MAIN PANEL
# ===================================

func _setup_main_panel() -> void:
	"""Nastav hlavní menu tlačítka"""
	var btn_new_game = main_panel.get_node("VBox/BtnNewGame")
	var btn_load_game = main_panel.get_node("VBox/BtnLoadGame")
	var btn_statistics = main_panel.get_node("VBox/BtnStatistics")
	var btn_settings = main_panel.get_node("VBox/BtnSettings")
	var btn_quit = main_panel.get_node("VBox/BtnQuit")
	
	btn_new_game.pressed.connect(_on_new_game)
	btn_load_game.pressed.connect(_on_load_game)
	btn_statistics.pressed.connect(_on_statistics)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)

func _on_new_game() -> void:
	"""Nová hra - přejdi na výběr hráče"""
	play_sound("button_click")
	show_panel("select_player")

func _on_load_game() -> void:
	"""Načti poslední hru"""
	play_sound("button_click")
	var current_player = player_manager.get_current_player()
	
	if current_player.is_empty():
		print("⚠️ Žádný hráč není přihlášen")
		show_panel("select_player")
		return
	
	# TODO: Implementuj načítání poslední hry
	print("📂 Načítám poslední hru pro hráče: ", current_player.display_name)
	show_panel("game_setup")

func _on_statistics() -> void:
	"""Zobraz statistiky"""
	play_sound("button_click")
	show_panel("statistics")

func _on_settings() -> void:
	"""Zobraz nastavení"""
	play_sound("button_click")
	show_panel("settings")

func _on_quit() -> void:
	"""Ukončete hru"""
	play_sound("button_click")
	get_tree().quit()

# ===================================
# REGISTER PANEL
# ===================================

func _setup_register_panel() -> void:
	"""Nastav registrační panel"""
	var txt_username = register_panel.get_node("VBox/UsernameInput")
	var txt_display_name = register_panel.get_node("VBox/DisplayNameInput")
	var btn_register = register_panel.get_node("VBox/BtnRegister")
	var btn_back = register_panel.get_node("VBox/BtnBack")
	var lbl_error = register_panel.get_node("VBox/ErrorLabel")
	
	btn_register.pressed.connect(_on_register_player.bind(txt_username, txt_display_name, lbl_error))
	btn_back.pressed.connect(func(): show_panel("select_player"))

func _refresh_register_panel() -> void:
	"""Osviež registrační panel"""
	var txt_username = register_panel.get_node("VBox/UsernameInput")
	var txt_display_name = register_panel.get_node("VBox/DisplayNameInput")
	var lbl_error = register_panel.get_node("VBox/ErrorLabel")
	
	txt_username.text = ""
	txt_display_name.text = ""
	lbl_error.text = ""

func _on_register_player(txt_username: LineEdit, txt_display_name: LineEdit, lbl_error: Label) -> void:
	"""Zaregistruj nového hráče"""
	play_sound("button_click")
	
	var username = txt_username.text.strip_edges()
	var display_name = txt_display_name.text.strip_edges()
	
	# Validace
	if username.length() < 3:
		lbl_error.text = "❌ Uživatelské jméno musí mít min. 3 znaky"
		play_sound("error")
		return
	
	if display_name.is_empty():
		lbl_error.text = "❌ Jméno hráče nesmí být prázdné"
		play_sound("error")
		return
	
	if player_manager.player_exists(username):
		lbl_error.text = "❌ Hráč s tímto jménem už existuje"
		play_sound("error")
		return
	
	# Vytvoř hráče
	var new_player = player_manager.create_new_player(username, display_name)
	
	if not new_player.is_empty():
		player_manager.set_current_player(username)
		lbl_error.text = "✅ Hráč vytvořen! Přesunuji se..."
		play_sound("success")
		
		await get_tree().create_timer(1.0).timeout
		show_panel("game_setup")
	else:
		lbl_error.text = "❌ Chyba při vytváření hráče"
		play_sound("error")

# ===================================
# SELECT PLAYER PANEL
# ===================================

func _setup_select_player_panel() -> void:
	"""Nastav panel pro výběr hráče"""
	var btn_new_player = select_player_panel.get_node("VBox/BtnNewPlayer")
	var btn_back = select_player_panel.get_node("VBox/BtnBack")
	
	btn_new_player.pressed.connect(func(): show_panel("register"))
	btn_back.pressed.connect(func(): show_panel("main"))

func _refresh_select_player_panel() -> void:
	"""Osviež seznam hráčů"""
	# Najdi scroll container s hráči
	var player_list = select_player_panel.get_node("VBox/ScrollContainer/PlayerListContainer")
	
	# Vyčisti staré položky
	for child in player_list.get_children():
		child.queue_free()
	
	# Přidej všechny hráče
	var players = player_manager.get_all_players()
	
	for player in players:
		var btn = Button.new()
		btn.text = "👤 " + player.display_name + " (" + player.username + ")"
		btn.custom_minimum_size = Vector2(0, 50)
		btn.pressed.connect(_on_player_selected.bind(player.username))
		player_list.add_child(btn)
	
	if players.is_empty():
		var lbl = Label.new()
		lbl.text = "Žádný hráč"
		player_list.add_child(lbl)

func _on_player_selected(username: String) -> void:
	"""Vybraný hráč"""
	play_sound("button_click")
	player_manager.set_current_player(username)
	show_panel("game_setup")

# ===================================
# GAME SETUP PANEL
# ===================================

func _setup_game_setup_panel() -> void:
	"""Nastav panel pro přípravu hry"""
	var btn_single = game_setup_panel.get_node("VBox/ModeSelection/BtnSinglePlayer")
	var btn_multi = game_setup_panel.get_node("VBox/ModeSelection/BtnMultiPlayer")
	var btn_online = game_setup_panel.get_node("VBox/ModeSelection/BtnOnlineMulti")
	var btn_start = game_setup_panel.get_node("VBox/BtnStartGame")
	var btn_back = game_setup_panel.get_node("VBox/BtnBack")
	
	btn_single.pressed.connect(_on_game_mode_selected.bind("single"))
	btn_multi.pressed.connect(_on_game_mode_selected.bind("local"))
	btn_online.pressed.connect(_on_game_mode_selected.bind("online"))
	btn_start.pressed.connect(_on_start_game)
	btn_back.pressed.connect(func(): show_panel("select_player"))

func _refresh_game_setup_panel() -> void:
	"""Osviež panel nastavení hry"""
	var current_player = player_manager.get_current_player()
	var lbl_player = game_setup_panel.get_node("VBox/LblPlayer")
	
	lbl_player.text = "👤 Hráč: " + current_player.display_name

var selected_game_mode: String = "single"

func _on_game_mode_selected(mode: String) -> void:
	"""Vybraný režim hry"""
	play_sound("button_click")
	selected_game_mode = mode
	print("🎮 Vybraný režim: ", mode)
	
	# TODO: Zobraz odpovídající možnosti (počet hráčů, vsázky, atd.)

func _on_start_game() -> void:
	"""Spusť hru"""
	play_sound("button_click")
	print("🎲 Spouštím hru v režimu: ", selected_game_mode)
		# Příprav hru
	var current_player = PlayerManager.instance.get_current_player()
	
	print("\n🎮 PŘÍPRAVA HRY:")
	print("   Režim: ", selected_game_mode)
	print("   Hráč: ", current_player.display_name)
	
	# Vytvoř konfiguraci hry
	var game_config = _create_game_config(current_player)
	
	# Ulož konfiguraci do GlobalScope (přístupné v main.tscn)
	get_tree().root.set_meta("game_config", game_config)
	
	# Ulož konfiguraci i do GameTransitionManager pokud existuje

	
	print("✅ Konfigurace uložena")
	print("📺 Spouštím hru...")
	
	# Přejdi na herní scénu
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ===================================
# STATISTICS PANEL
# ===================================

func _setup_statistics_panel() -> void:
	"""Nastav panel statistik"""
	var btn_back = statistics_panel.get_node("VBox/BtnBack")
	btn_back.pressed.connect(func(): show_panel("main"))

func _refresh_statistics_panel() -> void:
	"""Osviež statistiky"""
	var current_player = player_manager.get_current_player()
	var stats = player_manager.get_player_stats()
	
	var lbl_player = statistics_panel.get_node("VBox/LblPlayer")
	var stats_list = statistics_panel.get_node("VBox/ScrollContainer/StatsList")
	
	lbl_player.text = "📊 Statistiky: " + current_player.display_name
	
	# Vyčisti staré
	for child in stats_list.get_children():
		child.queue_free()
	
	# Přidej statistiky
	var stat_items = [
		"🎮 Celkově her: " + str(stats.total_games),
		"🏆 Výhry: " + str(stats.total_wins) + " (" + str(int(stats.win_rate)) + "%)",
		"📊 Průměrné skóre: " + str(int(stats.average_score)),
		"⭐ Nejlepší kolo: " + str(stats.best_round),
		"❌ Farkles: " + str(stats.farkle_count),
		"💰 Celkově bodů: " + str(stats.total_points)
	]
	
	for stat in stat_items:
		var lbl = Label.new()
		lbl.text = stat
		lbl.custom_minimum_size = Vector2(0, 40)
		stats_list.add_child(lbl)

# ===================================
# SETTINGS PANEL
# ===================================

func _setup_settings_panel() -> void:
	"""Nastav panel nastavení"""
	var btn_back = settings_panel.get_node("VBox/BtnBack")
	var slider_volume = settings_panel.get_node("VBox/VolumeSlider")
	var btn_delete_player = settings_panel.get_node("VBox/BtnDeletePlayer")
	
	btn_back.pressed.connect(func(): show_panel("main"))
	slider_volume.value_changed.connect(_on_volume_changed)
	btn_delete_player.pressed.connect(_on_delete_player)

func _refresh_settings_panel() -> void:
	"""Osviež nastavení"""
	var current_player = player_manager.get_current_player()
	var lbl_player = settings_panel.get_node("VBox/LblPlayer")
	
	lbl_player.text = "⚙️ Nastavení: " + current_player.display_name

func _on_volume_changed(value: float) -> void:
	"""Změna hlasitosti"""
	if audio_manager and audio_manager.has_method("set_master_volume"):
		audio_manager.set_master_volume(value / 100.0)

func _on_delete_player() -> void:
	"""Vymaž hráče"""
	play_sound("button_click")
	var current_player = player_manager.get_current_player()
	
	# TODO: Zobraz potvrzovací dialog
	player_manager.delete_player(current_player.username)
	show_panel("main")

# ===================================
# UTILITY
# ===================================

func play_sound(sound_type: String) -> void:
	"""Přehraj zvuk"""
	if audio_manager == null:
		return
	
	match sound_type:
		"button_click":
			if audio_manager.has_method("play_button_click"):
				audio_manager.play_button_click()
		"success":
			if audio_manager.has_method("play_score"):
				audio_manager.play_score()
		"error":
			if audio_manager.has_method("play_farkle"):
				audio_manager.play_farkle()
# ===============================
# HELPER FUNKCE
# ===============================

func _create_game_config(current_player: Dictionary) -> Dictionary:
	"""Vytvoř konfiguraci hry pro main.tscn"""
	var config = {
		"mode": selected_game_mode,
		"current_player": current_player.username,
		"current_player_display": current_player.display_name,
		"difficulty": "normal",
		"players_count": 1,
		"other_players": [],
		"ai_count": 0,
		"betting_enabled": false
	}
	
	# Podle režimu nastav parametry
	match selected_game_mode:
		"single":
			config.ai_count = 1
			config.difficulty = "normal"
			config.betting_enabled = true
		
		"local":
			config.players_count = 2
			config.ai_count = 0  # Ostatní jsou humani
			config.betting_enabled = true
		
		"online":
			config.players_count = 2
			config.betting_enabled = false
	
	print("\n📋 Konfigurace hry:")
	print("   Režim: ", config.mode)
	print("   Hráč: ", config.current_player_display)
	print("   Počet hráčů: ", config.players_count)
	print("   AI: ", config.ai_count)
	
	return config
