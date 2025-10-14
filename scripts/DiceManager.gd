extends Node3D
#DiceManager
@export var camera_controller: Camera3D

signal all_dice_stopped(values: Array)
signal dice_rolling_started

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
	if parent.has_node("Table"):
		var table = parent.get_node("Table")
		print("\n🪵 Stůl:")
		print("   Pozice: ", table.global_position)
		if table is StaticBody3D:
			print("   Collision layer: ", table.collision_layer)
			print("   Collision mask: ", table.collision_mask)
	else:
		print("\n⚠️ STŮL NENALEZEN! Kostky nemají kam dopadnout!")
	
	print("🔍 ==========================================\n")
	
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

	print("\n🔍 ========== DEBUG KONTROLA SCÉNY ==========")
	print("📍 DiceManager pozice: ", global_position)
	print("📍 DiceManager rotace: ", rotation_degrees)
	
	if dice_array.size() > 0:
		var test_dice = dice_array[0]
		print("\n🎲 Test kostka [0]:")
		print("   Lokální pozice: ", test_dice.position)
		print("   Globální pozice: ", test_dice.global_position)
		print("   Visible: ", test_dice.visible)
		print("   Freeze: ", test_dice.freeze)
		print("   Collision layer: ", test_dice.collision_layer)
		print("   Collision mask: ", test_dice.collision_mask)
		
	if camera_controller == null:
		camera_controller = camera

func create_dice():
	"""Vytvoř 6 kostek"""
	for i in range(NUM_DICE):
		var dice = DICE_SCENE.instantiate()
		add_child(dice)
		
		# Nastav počáteční pozici
		var row = i / 3
		var col = i % 3
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
		# ⚠️ KLÍČOVÁ ZMĚNA - rehod také používá kelímek!
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
	
	# Zatřes a hoď
	if dice_cup and dice_cup.has_method("shake_and_throw"):
		# Spusť animaci kelímku (bez await - běží paralelně)
		dice_cup.shake_and_throw()
		
		# Čekáme na signál dice_released a dostaneme pozici
		var release_position = await dice_cup.dice_released
		
		# ZOBRAZ kostky při vysypání a dej jim impulz (s pozicí z kelímku)
		show_and_throw_dice(indices, release_position)
	else:
		print("⚠️ Kelímek nemá metodu shake_and_throw!")
		# Fallback - klasické házení
		perform_simple_throw(indices)
	
	# Kamera na kostky - rychle
	await get_tree().create_timer(3.0).timeout
	if camera and camera.has_method("move_to_focused") and use_camera_animations:
		camera.move_to_focused()

func reset_all_dice_for_reroll():
	"""Resetuj všechny kostky do počátečního stavu - KROMĚ zabanovaných"""
	print("🔄 Kompletní reset kostek pro rehod (kromě zabanovaných)...")
	
	for i in range(dice_array.size()):
		# ⚠️ PŘESKOČ zabanované kostky - ty už jsou stranou!
		if banked_dice.has(i):
			print("⏭️ Kostka ", i, " je zabanovaná, ponechávám stranou")
			continue
		
		var dice = dice_array[i]
		
		# Úplný reset fyziky
		dice.freeze = true
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO
		dice.visible = false
		dice.is_rolling = false
		dice.settle_timer = 0.0
		
		# Reset pozice na původní místo (v kelímku)
		var row = i / 3
		var col = i % 3
		var offset = Vector3(
			float(col - 1) * 1.5,
			0,
			float(row) * 1.5 - 0.75
		)
		dice.position = spawn_position + offset
		dice.rotation = Vector3.ZERO
		
		# Skryj prstenec
		dice.set_selected(false)
	
	print("✅ Kostky resetovány (zabanované zůstaly stranou)")

func perform_classic_roll(indices: Array):
	"""Klasické házení - použij kelímek i pro rehody! Čistý start."""
	print("🎲 Rehod pomocí kelímku - kompletní reset...")
	
	# KROK 1: Kompletní reset VŠECH kostek do počátečního stavu
	reset_all_dice_for_reroll()
	
	# KROK 2: Krátké čekání aby se rendering stihl
	await get_tree().create_timer(0.1).timeout
	
	# KROK 3: Použij kelímek pro hod (bez animace zatřesení pro rychlost)
	if dice_cup and dice_cup.has_method("shake_and_throw"):
		# Použij kelímek - ideálně by měl mít metodu throw_without_shake
		# ale použijeme i s animací
		dice_cup.shake_and_throw()
		var release_position = await dice_cup.dice_released
		show_and_throw_dice(indices, release_position)
		
		# Kamera
		if camera and camera.has_method("move_to_focused") and use_camera_animations:
			await get_tree().create_timer(3.0).timeout
			camera.move_to_focused()
	else:
		# Fallback - bez kelímku
		print("⚠️ Kelímek nedostupný, použiju fallback...")
		perform_simple_throw(indices)
	
	print("✅ Rehod dokončen")

func perform_simple_throw(indices: Array):
	"""Jednoduchý hod bez kelímku - fallback když kelímek není dostupný"""
	print("🎲 Jednoduchý hod ", indices.size(), " kostek (bez kelímku)...")
	
	# Zvuk házení
	if audio_manager and audio_manager.has_method("play_dice_roll"):
		audio_manager.play_dice_roll()
	
	# Zobraz a aktivuj jen ty kostky, které házíme
	for idx in indices:
		if idx < dice_array.size():
			var dice = dice_array[idx]
			
			# Umísti kostku vysoko nad stolem s náhodným rozptylem
			dice.global_position = Vector3(
				randf_range(-3.0, 3.0),
				5.0,  # Vysoko nad stolem
				randf_range(-3.0, 3.0)
			)
			
			# Náhodná rotace
			dice.rotation = Vector3(
				randf_range(0, TAU),
				randf_range(0, TAU),
				randf_range(0, TAU)
			)
			
			dice.visible = true
			dice.freeze = false
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
	
	# Počkej frame aby se fyzika probudila
	await get_tree().process_frame
	
	# Hoď všemi najednou
	for idx in indices:
		if idx < dice_array.size():
			var dice = dice_array[idx]
			var strength = randf_range(3.0, 5.0)
			dice.roll(strength)
	
	# Označ že kostky se kutálí
	is_rolling = true
	dice_stopped_count = 0
	dice_rolling_started.emit()
	
	print("✅ Všechny kostky hozeny!")

func show_and_throw_dice(indices: Array, cup_release_position: Vector3 = Vector3.ZERO):
	"""Zobraz kostky a hoď jimi jako z kelímku"""
	print("🎲 Vysypávám ", indices.size(), " kostek z pozice: ", cup_release_position)
	
	# Pokud nebyla poskytnuta pozice, použij fallback
	if cup_release_position == Vector3.ZERO:
		cup_release_position = Vector3(0, 3, 0)
	
	# Spawn bod je mírně pod kelímkem (jako by vypadávaly z otvoru)
	var throw_origin = cup_release_position + Vector3(0, -0.8, 0)
	
	for i in range(indices.size()):
		var idx = indices[i]
		if idx < dice_array.size():
			var dice = dice_array[idx]
			
			# Zobraz a aktivuj
			dice.visible = true
			dice.freeze = false
			
			# Nastav pozici s malým spreadem (jako by vypadávaly z kelímku)
			var spread = Vector3(
				randf_range(-0.4, 0.4),
				randf_range(-0.2, 0.1),
				randf_range(-0.4, 0.4)
			)
			dice.global_position = throw_origin + spread
			
			# Směr hodu - dolů ke středu stolu s realističtějším padáním
			var to_center = (Vector3(0, 0, 0) - throw_origin).normalized()
			var throw_direction = (to_center + Vector3(
				randf_range(-0.4, 0.4),
				randf_range(-0.8, -0.4),  # Hlavně dolů!
				randf_range(-0.4, 0.4)
			)).normalized()
			
			# Síla hodu
			var throw_force = randf_range(8.0, 12.0)
			dice.linear_velocity = throw_direction * throw_force
			
			# Silnější rotace pro efektnější hod
			dice.angular_velocity = Vector3(
				randf_range(-20, 20),
				randf_range(-20, 20),
				randf_range(-20, 20)
			)
			
			# Řekni kostce že začala kutálení
			dice.start_rolling()
			
			# Mírná prodleva mezi kostkami pro efekt vysypávání
			await get_tree().create_timer(0.04).timeout
	
	# Označ že kostky se kutálí
	is_rolling = true
	dice_stopped_count = 0
	dice_rolling_started.emit()
	
	print("✅ Všechny kostky vysypány a začaly energicky kutálení!")

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
		
		# ⚠️ DŮLEŽITÉ - aktualizuj hodnoty JEN pro kostky, které se právě kutálely
		# Zabanované kostky si zachovají své původní hodnoty!
		for idx in rolling_dice_indices:
			if idx < dice_array.size():
				var val = dice_array[idx].get_value()
				if val >= 1 and val <= 6:
					last_values[idx] = val
				else:
					print("⚠️ Kostka ", idx, " vrátila neplatnou hodnotu: ", val)
					last_values[idx] = 1  # Fallback
		
		print("Všechny kostky zastaveny. Hodnoty: ", last_values)
		
		if camera_controller:
			var dice_positions = []
			for die in dice_array:
				dice_positions.append(die.global_position)
			camera_controller.move_to_focused(dice_positions, false)
				
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
	return last_values.duplicate()

func get_dice(index: int):
	"""Získej konkrétní kostku"""
	if index < dice_array.size():
		return dice_array[index]
	return null

func reset_positions():
	"""Resetuj pozice kostek"""
	for i in range(dice_array.size()):
		var dice = dice_array[i]
		var row = i / 3
		var col = i % 3
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
	# Vyčisti dočasný výběr
	for idx in selected_dice:
		if idx < dice_array.size():
			dice_array[idx].set_selected(false)
	
	# ⚠️ Vrať zabanované kostky zpět (resetuj jejich pozice)
	for idx in banked_dice:
		if idx < dice_array.size():
			var dice = dice_array[idx]
			dice.set_selected(false)
			
			# Vrať kostku zpět do kelímku
			var row = idx / 3
			var col = idx % 3
			var offset = Vector3(
				float(col - 1) * 1.5,
				0,
				float(row) * 1.5 - 0.75
			)
			dice.position = spawn_position + offset
	
	selected_dice.clear()
	banked_dice.clear()
	first_roll = true  # Reset pro další kolo
	
	# Skryj všechny kostky zpět do kelímku
	hide_all_dice()
	
	# Reset hodnot
	last_values = [0, 0, 0, 0, 0, 0]
	
	print("🔄 Reset všech kostek - schované v kelímku")

func hide_all_dice():
	"""Skryj všechny kostky (na začátku - jsou v kelímku)"""
	for dice in dice_array:
		dice.visible = false
		dice.freeze = true
		dice.set_selected(false)
	print("👻 Schováno ", dice_array.size(), " kostek")

func mark_dice_as_banked(indices: Array):
	"""Označ kostky jako zabanované a přesuň je stranou"""
	for idx in indices:
		if idx < dice_array.size() and not banked_dice.has(idx):
			banked_dice.append(idx)
			var dice = dice_array[idx]
			
			# Zobraz prstenec
			dice.set_selected(true)
			
			# ⚠️ PŘESUŇ kostku na kraj stolu (vpravo)
			# Každá zabanovaná kostka dostane své místo v řadě
			var banked_position_index = banked_dice.size() - 1
			var banked_position = Vector3(
				8.0, #+ banked_position_index * 1.2,  # Pozice na stole start
				0.6,  # Výška nad stolem
				0.0 + banked_position_index * 1.8 #řada horizontální x.x ke rozestup
			)
			
			# Zmraz a přesuň
			dice.freeze = true
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			dice.global_position = banked_position
			dice.visible = true  # Zůstane viditelná!
			
			print("💾 Zabanovaná kostka ", idx, " má hodnotu: ", last_values[idx])
			print("📦 Přesunuta na pozici: ", banked_position)
			
			# Efekt při skórování
			if effects_manager and effects_manager.has_method("play_score_effect"):
				effects_manager.play_score_effect(dice.global_position)
	
	if audio_manager and audio_manager.has_method("play_score"):
		audio_manager.play_score()
	
	selected_dice.clear()
	
	print("✅ Zabanované kostky: ", banked_dice)
