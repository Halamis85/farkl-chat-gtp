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

# Všechny panely
var all_panels: Array[Control] = []

# Audio manager
var audio_manager: Node

# ✅ NOVÉ - Proměnné pro AI
var selected_game_mode: String = "single"
var selected_ai_level: int = 1  # 0=EASY, 1=NORMAL, 2=HARD, 3=EXPERT

func _ready():
	print("\n" + "=".repeat(60))
	print("📺 MAIN_MENU INICIALIZACE")
	print("=".repeat(60))
	
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
		print("✅ AudioManager nalezen")
	else:
		print("⚠️ AudioManager nenalezen")
	
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
	print("=".repeat(60) + "\n")

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
# GAME SETUP PANEL - UPRAVENÁ ČÁST
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
	
	# ✅ Vytvoř AI difficulty UI
	_create_ai_difficulty_ui()

func _create_ai_difficulty_ui():
	"""Dynamicky vytvoř UI pro výběr AI obtížnosti"""
	print("\n🤖 Vytvářím AI obtížnost UI...")
	
	var vbox = game_setup_panel.get_node("VBox")
	
	# Vytvoř panel pro AI obtížnost
	var ai_panel = Panel.new()
	ai_panel.name = "AILevelPanel"
	ai_panel.visible = false
	ai_panel.custom_minimum_size = Vector2(400, 90)
	vbox.add_child(ai_panel)
	
	# VBox uvnitř panelu
	var panel_vbox = VBoxContainer.new()
	panel_vbox.name = "VBox"
	ai_panel.add_child(panel_vbox)
	panel_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Label
	var label = Label.new()
	label.text = "🤖 Vyberte obtížnost AI:"
	label.add_theme_font_size_override("font_size", 16)
	panel_vbox.add_child(label)
	
	# HBox pro tlačítka
	var hbox = HBoxContainer.new()
	hbox.name = "ButtonContainer"
	hbox.add_theme_constant_override("separation", 8)
	panel_vbox.add_child(hbox)
	
	# Tlačítka pro obtížnosti
	var difficulties = [
		{"level": 0, "text": "😊 EASY", "color": Color.GREEN},
		{"level": 1, "text": "🎮 NORMAL", "color": Color.YELLOW},
		{"level": 2, "text": "💪 HARD", "color": Color.ORANGE},
		{"level": 3, "text": "🧠 EXPERT", "color": Color.RED}
	]
	
	for diff in difficulties:
		var btn = Button.new()
		btn.text = diff.text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_ai_level_selected.bind(diff.level))
		hbox.add_child(btn)
		print("   ✅ Tlačítko: ", diff.text)
	
	print("✅ AI obtížnost UI vytvořeno\n")

func _refresh_game_setup_panel() -> void:
	"""Osviež panel nastavení hry"""
	var current_player = player_manager.get_current_player()
	var lbl_player = game_setup_panel.get_node("VBox/LblPlayer")
	
	lbl_player.text = "👤 Hráč: " + current_player.display_name
	print("🎮 Aktuální hráč: ", current_player.display_name)

func _on_game_mode_selected(mode: String) -> void:
	"""Vybraný režim hry"""
	play_sound("button_click")
	selected_game_mode = mode
	
	print("\n🎮 VYBRANÝ REŽIM: ", mode)
	
	# Najdi AI panel
	var ai_panel = game_setup_panel.get_node_or_null("VBox/AILevelPanel")
	
	# Pokud je SINGLE, zobraz AI obtížnost
	if mode == "single":
		if ai_panel:
			ai_panel.visible = true
		selected_ai_level = 1  # Default: NORMAL
		print("🤖 Zobrazuji výběr obtížnosti AI")
	else:
		# Jinak panel skryj
		if ai_panel:
			ai_panel.visible = false
		selected_ai_level = 1  # Nerelevantní pro ostatní režimy
		print("🤖 AI obtížnost skryta (není single player)")

func _on_ai_level_selected(level: int) -> void:
	"""Hráč vybral AI obtížnost"""
	selected_ai_level = level
	
	var level_name = _get_ai_level_name(level)
	print("\n🤖 VYBRANÁ OBTÍŽNOST: ", level_name)
	
	# Zvukový feedback
	play_sound("button_click")
	
	# Vizuální feedback - zvýrazni vybrané tlačítko
	_highlight_ai_difficulty_button(level)

func _highlight_ai_difficulty_button(selected_level: int):
	"""Zvýrazni vybrané tlačítko"""
	var button_container = game_setup_panel.get_node_or_null("VBox/AILevelPanel/VBox/ButtonContainer")
	
	if not button_container:
		return
	
	var buttons = button_container.get_children()
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == selected_level:
			# Zvýrazni
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		else:
			# Normální
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_pressed_color")

func _on_start_game() -> void:
	"""Spusť hru"""
	play_sound("button_click")
	
	print("\n" + "=".repeat(60))
	print("🎲 SPUŠTĚNÍ HRY")
	print("=".repeat(60))
	print("Režim: ", selected_game_mode)
	print("AI Level: ", _get_ai_level_name(selected_ai_level))
	
	# Příprava hry
	var current_player = PlayerManager.instance.get_current_player()
	
	print("\n👤 Hráč: ", current_player.display_name)
	
	# Vytvoř konfiguraci hry
	var game_config = _create_game_config(current_player)
	
	# Ulož konfiguraci do GlobalScope
	get_tree().root.set_meta("game_config", game_config)
	
	print("\n✅ Konfigurace uložena")
	print("📺 Spouštím herní scénu...")
	print("=".repeat(60) + "\n")
	
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
	
	player_manager.delete_player(current_player.username)
	show_panel("main")

# ===================================
# UTILITY FUNKCE
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
		"ai_level": selected_ai_level,
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
			config.ai_count = 0
			config.betting_enabled = true
		
		"online":
			config.players_count = 2
			config.betting_enabled = false
	
	return config

func _get_ai_level_name(level: int) -> String:
	"""Vrať jméno AI levelu"""
	match level:
		0: return "EASY"
		1: return "NORMAL"
		2: return "HARD"
		3: return "EXPERT"
		_: return "NORMAL"
