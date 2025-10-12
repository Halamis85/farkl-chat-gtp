extends Node3D

signal all_dice_stopped(values: Array)
signal dice_rolling_started
# signal cup_animation_complete()  # Nepoužitý signál

const DICE_SCENE = preload("res://scenes/dice.tscn")
const NUM_DICE = 6

var dice_array: Array = []
var dice_stopped_count: int = 0
var is_rolling: bool = false
var selected_dice: Array = []  # Dočasný výběr (klikání myší v manuálním režimu)
var banked_dice: Array = []  # Permanentně vybrané kostky v aktuálním kole
var rolling_dice_indices: Array = []  # Indexy kostek, které se právě kutálí
var last_values: Array = [0, 0, 0, 0, 0, 0]  # Poslední hodnoty všech kostek
var first_roll: bool = true  # Je to první hod v kole?

# Reference na kelímek a kameru (nastavíš v _ready nebo z venku)
var dice_cup: Node3D = null
var camera: Camera3D = null
var audio_manager: Node = null
var effects_manager: Node3D = null
var use_cup_animation: bool = true  # Zapni/vypni animace kelímku
var use_camera_animations: bool = true  # Zapni/vypni pohyby kamery

# Pozice pro házení kostek
var spawn_position = Vector3(0, 3, 0)
var spawn_spread = 2.0

func _ready():
	create_dice()  # Kostky se vytvoří už schované
	
	# Najdi kelímek a kameru ve scéně (pokud existují)
	var parent = get_parent()
	if parent.has_node("DiceCup"):
		dice_cup = parent.get_node("DiceCup")
		print("🥤 Kelímek nalezen!")
	
	if parent.has_node("Camera3D"):
		camera = parent.get_node("Camera3D")
		print("📷 Kamera nalezena!")
	
	# Najdi audio manager (global nebo v parent)
	if has_node("/root/AudioManager"):
		audio_manager = get_node("/root/AudioManager")
		print("🔊 Audio manager nalezen!")
	elif parent.has_node("AudioManager"):
		audio_manager = parent.get_node("AudioManager")
		print("🔊 Audio manager nalezen!")
	
	# Najdi effects manager
	if parent.has_node("DiceEffects"):
		effects_manager = parent.get_node("DiceEffects")
		print("✨ Effects manager nalezen!")

func create_dice():
	"""Vytvoř 6 kostek"""
	for i in range(NUM_DICE):
		var dice = DICE_SCENE.instantiate()
		add_child(dice)
		
		# Nastav počáteční pozici
		var row = i / 3  # Řádek (0 nebo 1)
		var col = i % 3  # Sloupec (0, 1, nebo 2)
		var offset = Vector3(
			float(col - 1) * 1.5,
			0,
			float(row) * 1.5 - 0.75
		)
		dice.position = spawn_position + offset
		
		# SKRYJ kostku ihned (je v kelímku)
		dice.visible = false
		dice.freeze = true
		
		# Připoj signály
		dice.dice_stopped.connect(_on_dice_stopped)
		dice.dice_rolling.connect(_on_dice_rolling)
		dice.dice_clicked.connect(_on_dice_clicked)
		
		dice_array.append(dice)
	
	print("🎲 Vytvořeno ", NUM_DICE, " kostek (schované v kelímku)")

func roll_all_dice(banked_indices: Array = []):
	"""
	Hoď kostkami.
	banked_indices: indexy kostek, které NEMAJÍ být hozeny (už jsou zabanované)
	Pokud je prázdné, hoď všemi.
	"""
	if is_rolling:
		return
	
	is_rolling = true
	dice_stopped_count = 0
	rolling_dice_indices.clear()
	dice_rolling_started.emit()
	
	# Zjisti, kterými kostkami házet
	var dice_to_roll_indices = []
	
	print("===== HÁZENÍ KOSTEK =====")
	print("🔒 Zabanované (NEHÁZET): ", banked_indices)
	
	if banked_indices.is_empty():
		# Hoď všemi kostkami
		for i in range(dice_array.size()):
			dice_to_roll_indices.append(i)
			rolling_dice_indices.append(i)
	else:
		# Hoď jen těmi, které NEJSOU v banked_indices
		for i in range(dice_array.size()):
			if not banked_indices.has(i):
				dice_to_roll_indices.append(i)
				rolling_dice_indices.append(i)
	
	print("🎲 Házím kostkami (indexy): ", rolling_dice_indices)
	print("=========================")
	
	# Pokud používáme kelímek a házíme všemi kostkami (první hod nebo hot hand)
	if use_cup_animation and dice_cup and banked_indices.is_empty() and first_roll:
		first_roll = false  # Už to není první hod
		perform_cup_animation(dice_to_roll_indices)
	else:
		# Klasické házení bez kelímku
		perform_classic_roll(dice_to_roll_indices)

func perform_cup_animation(indices: Array):
	"""Animace s kelímkem - nová verze s hozením"""
	print("🥤 Spouštím animaci házení...")
	
	# Zvuk kelímku
	if audio_manager and audio_manager.has_method("play_cup_shake"):
		audio_manager.play_cup_shake()
	
	# Kamera na kelímek (stranou)
	if camera and camera.has_method("move_to_shake_view") and use_camera_animations:
		camera.move_to_shake_view()
		await get_tree().create_timer(0.3).timeout
	
	# Zatřes a hoď - OPRAVENÝ s await
	if dice_cup and dice_cup.has_method("shake_and_throw"):
		# Spusť animaci kelímku (bez await - běží paralelně)
		dice_cup.shake_and_throw()
		
		# Čekáme na signál dice_released
		await dice_cup.dice_released
		
		# ZOBRAZ kostky při vysypání a dej jim impulz
		show_and_throw_dice(indices)
	else:
		print("⚠️ Kelímek nemá metodu shake_and_throw!")
		# Fallback - klasické házení
		perform_classic_roll(indices)
	
	# Kamera na kostky - rychle
	await get_tree().create_timer(0.4).timeout
	if camera and camera.has_method("move_to_focused") and use_camera_animations:
		camera.move_to_focused()
		
	# Camera shake efekt při dopadu
	await get_tree().create_timer(0.5).timeout
	if camera and camera.has_method("add_camera_shake"):
		camera.add_camera_shake(0.2, 0.5)

func perform_classic_roll(indices: Array):
	"""Klasické házení kostkami (bez kelímku)"""
	# Zvuk házení
	if audio_manager and audio_manager.has_method("play_dice_roll"):
		audio_manager.play_dice_roll()
	
	# Házej kostky s malým časovým odstupem pro realistický efekt
	for i in range(indices.size()):
		var idx = indices[i]
		var dice = dice_array[idx]
		
		# Různá síla hodu pro každou kostku
		var strength = randf_range(4.5, 7.5)
		
		# Malé zpoždění mezi kostkami pro přirozenější efekt
		if i > 0:
			await get_tree().create_timer(randf_range(0.02, 0.08)).timeout
		
		dice.roll(strength)

func show_dice(indices: Array):
	"""Zobraz vybrané kostky (při vysypání)"""
	for idx in indices:
		if idx < dice_array.size():
			var dice = dice_array[idx]
			dice.visible = true
			dice.freeze = false
	print("👁️ Zobrazeno ", indices.size(), " kostek")

func show_and_throw_dice(indices: Array):
	"""Zobraz kostky a hoď jimi jako z kelímku - s efektem vysypání"""
	print("🎲 Vysypávám ", indices.size(), " kostek s impulzem!")
	
	# Pozice kelímku (odkud se kostky vysypou)
	var cup_position = dice_cup.global_position if dice_cup else Vector3(0, 3, 0)
	var throw_origin = cup_position + Vector3(1.0, -0.5, 0)  # Trochu před kelímkem a níž
	
	for i in range(indices.size()):
		var idx = indices[i]
		if idx < dice_array.size():
			var dice = dice_array[idx]
			
			# Zobraz a aktivuj
			dice.visible = true
			dice.freeze = false
			
			# Nastav pozici blízko kelímku (jako by vylétly)
			var spread = Vector3(
				randf_range(-0.4, 0.4),
				randf_range(-0.2, 0.2),
				randf_range(-0.4, 0.4)
			)
			dice.global_position = throw_origin + spread
			
			# Dej jim silný impulz směrem dolů a na střed stolu
			var to_center = (Vector3(0, 0, 0) - throw_origin).normalized()
			var throw_direction = (to_center + Vector3(
				randf_range(-0.3, 0.3),
				randf_range(-0.5, -0.2),  # Dolů
				randf_range(-0.3, 0.3)
			)).normalized()
			
			var throw_force = randf_range(9.0, 13.0)  # Silnější hod
			dice.linear_velocity = throw_direction * throw_force
			
			# Silná náhodná rotace
			dice.angular_velocity = Vector3(
				randf_range(-25, 25),
				randf_range(-25, 25),
				randf_range(-25, 25)
			)
			
			# Mírná prodleva mezi kostkami
			await get_tree().create_timer(0.02).timeout
	
	# Označ že kostky se kutálí
	is_rolling = true
	dice_stopped_count = 0
	dice_rolling_started.emit()

func _on_dice_rolling():
	pass  # Kostka začala kutálení

func _on_dice_stopped(_value: int):
	dice_stopped_count += 1
	
	# Zvuk dopadu
	if audio_manager and audio_manager.has_method("play_dice_impact"):
		audio_manager.play_dice_impact()
	
	# Zkontroluj, jestli se zastavily všechny házené kostky
	if dice_stopped_count >= rolling_dice_indices.size():
		is_rolling = false
		
		# Aktualizuj hodnoty jen těch kostek, které se právě kutálely
		for idx in rolling_dice_indices:
			if idx < dice_array.size():
				var val = dice_array[idx].get_value()
				if val >= 1 and val <= 6:
					last_values[idx] = val
				else:
					print("⚠️ Kostka ", idx, " vrátila neplatnou hodnotu: ", val)
					last_values[idx] = 1  # Fallback
		
		print("Všechny kostky zastaveny. Hodnoty: ", last_values)
		all_dice_stopped.emit(last_values.duplicate())

func count_rolling_dice() -> int:
	"""Počet kostek, které se kutálí"""
	var count = 0
	for dice in dice_array:
		if dice.is_dice_rolling():
			count += 1
	return count if count > 0 else dice_stopped_count

func get_all_values() -> Array:
	"""Získej hodnoty všech kostek"""
	var values = []
	for dice in dice_array:
		values.append(dice.get_value())
	return values

func get_dice(index: int):
	"""Získej konkrétní kostku"""
	if index < dice_array.size():
		return dice_array[index]
	return null

func reset_positions():
	"""Resetuj pozice kostek"""
	for i in range(dice_array.size()):
		var dice = dice_array[i]
		var row = i / 3.0  # Řádek (0 nebo 1)
		var col = i % 3  # Sloupec (0, 1, nebo 2)
		var offset = Vector3(
			float(col - 1) * 1.5,
			0,
			float(row) * 1.5 - 0.75
		)
		dice.position = spawn_position + offset
		dice.rotation = Vector3.ZERO
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO

func _on_dice_clicked(dice: RigidBody3D):
	"""Zpracuj kliknutí na kostku (jen pro manuální režim)"""
	var dice_index = dice_array.find(dice)
	if dice_index == -1:
		return
	
	# Nelze vybrat už zabanovanou kostku
	if banked_dice.has(dice_index):
		print("⚠️ Kostka ", dice_index, " je už zabanovaná!")
		return
	
	# Zvuk výběru
	if audio_manager and audio_manager.has_method("play_dice_select"):
		audio_manager.play_dice_select()
	
	# Toggle výběr pro manuální režim
	if selected_dice.has(dice_index):
		# Odeber z výběru
		selected_dice.erase(dice_index)
		dice.set_selected(false)
		print("➖ Odebráno z výběru: ", dice_index)
	else:
		# Přidej do výběru
		selected_dice.append(dice_index)
		dice.set_selected(true)
		print("➕ Přidáno do výběru: ", dice_index)
	
	print("📋 Dočasný výběr: ", selected_dice)

func get_selected_dice() -> Array:
	"""Vrať indexy dočasně vybraných kostek (manuální režim)"""
	return selected_dice.duplicate()

func get_banked_dice() -> Array:
	"""Vrať indexy zabanovaných kostek"""
	return banked_dice.duplicate()

func clear_selection():
	"""Zruš dočasný výběr (manuální režim) a resetuj všechny kostky"""
	# Vrať zabanované kostky zpět
	for idx in banked_dice:
		if idx < dice_array.size():
			dice_array[idx].set_selected(false)
	
	# Vyčisti dočasný výběr
	for idx in selected_dice:
		if idx < dice_array.size():
			dice_array[idx].set_selected(false)
	
	selected_dice.clear()
	banked_dice.clear()
	first_roll = true  # Reset pro další kolo
	
	# Skryj všechny kostky zpět do kelímku
	hide_all_dice()
	
	# Kelímek zůstává na rest_position, není potřeba ho zobrazovat
	
	print("🔄 Reset všech kostek - schované v kelímku")

func hide_all_dice():
	"""Skryj všechny kostky (na začátku - jsou v kelímku)"""
	for dice in dice_array:
		dice.visible = false
		dice.freeze = true
	print("👻 Schováno ", dice_array.size(), " kostek")

func mark_dice_as_banked(indices: Array):
	"""Označ kostky jako zabanované (přesunou se stranou a změní barvu)"""
	for idx in indices:
		if idx < dice_array.size() and not banked_dice.has(idx):
			banked_dice.append(idx)
			var dice = dice_array[idx]
			dice.set_selected(true)  # Zobrazí prstenec
			
			# Efekt při skórování
			if effects_manager and effects_manager.has_method("play_score_effect"):
				effects_manager.play_score_effect(dice.global_position)
	
	# Zvuk skórování
	if audio_manager and audio_manager.has_method("play_score"):
		audio_manager.play_score()
	
	# Vyčisti dočasný výběr
	selected_dice.clear()
	
	print("✅ Zabanované kostky: ", banked_dice)
