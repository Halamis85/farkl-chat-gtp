extends Node3D
#DiceManager
class_name DiceManager

var camera: Camera3D = null


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
var audio_manager: Node = null
var effects_manager: Node3D = null
var use_cup_animation: bool = true  # Zapni/vypni animace kelímku
var use_camera_animations: bool = true  # Zapni/vypni pohyby kamery

# Pozice pro házení kostek
var spawn_position = Vector3(0, 2, 0)
var spawn_spread = 2.0
var banked_values: Dictionary = {}  # Uchová hodnoty zabanovaných kostek

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
		
		if has_node("/root/Main/Camera3D"):
			camera = get_node("/root/Main/Camera3D")

func create_dice():
	"""Vytvoř 6 kostek"""
	for i in range(NUM_DICE):
		var dice = DICE_SCENE.instantiate()
		add_child(dice)
		
		# Nastav počáteční pozici
		var row = i / 3.0
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
	"""Animace s kelímkem"""
	print("🥤 Spouštím animaci házení...")
	
	if audio_manager and audio_manager.has_method("play_cup_shake"):
		audio_manager.play_cup_shake()
	
	if camera and camera.has_method("move_to_shake_view") and use_camera_animations:
		camera.move_to_shake_view()
		await get_tree().create_timer(0.3).timeout
	
	if dice_cup and dice_cup.has_method("shake_and_throw"):
		# ✅ OPRAVENO: Spusť animaci BEZ uložení - běží na pozadí
		dice_cup.shake_and_throw()
		
		# Čekáme na signál
		var release_position = await dice_cup.dice_released
		
		# Zobraz kostky
		show_and_throw_dice(indices, release_position)
		
		# Čekej aby se animace skončila
		await get_tree().create_timer(4.0).timeout
	else:
		print("⚠️ Kelímek nemá metodu shake_and_throw!")
		perform_simple_throw(indices)
	
	# Kamera na kostky
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
		var row = i / 3.0
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
	"""Klasické házení - synchronizace s kelímkem"""
	print("🎲 Rehod - synchronizuji s kelímkem...")
	
	reset_all_dice_for_reroll()
	await get_tree().create_timer(0.1).timeout
	
	if dice_cup and dice_cup.has_method("shake_and_throw"):
		print("   → Spouštím shake_and_throw()...")
		
		# ✅ OPRAVENO: Spusť animaci BEZ uložení - běží na pozadí
		dice_cup.shake_and_throw()
		
		print("   → Čekám na signal dice_released...")
		var release_position = await dice_cup.dice_released
		
		print("   → Signal přijat! Spawnuji kostky...")
		show_and_throw_dice(indices, release_position)
		
		# Čekej aby se animace skončila
		await get_tree().create_timer(4.0).timeout
		
		if camera and camera.has_method("move_to_focused"):
			camera.move_to_focused()
	else:
		print("⚠️ Kelímek nedostupný, fallback...")
		perform_simple_throw(indices)
	
	print("✅ Rehod hotov")

func perform_simple_throw(indices: Array):
	"""Jednoduchý hod bez kelímku - fallback"""
	print("🎲 Jednoduchý hod ", indices.size(), " kostek (bez kelímku)...")
	
	# Zvuk házení
	if audio_manager and audio_manager.has_method("play_dice_roll"):
		audio_manager.play_dice_roll()
	
	# Zobraz a aktivuj kostky
	for idx in indices:
		if idx < dice_array.size():
			var dice = dice_array[idx]
			
			dice.global_position = Vector3(
				randf_range(-3.0, 3.0),
				5.0,
				randf_range(-3.0, 3.0)
			)
			
			dice.rotation = Vector3(
				randf_range(0, TAU),
				randf_range(0, TAU),
				randf_range(0, TAU)
			)
			
			dice.visible = true
			dice.freeze = false
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
	
	# Počkej aby se fyzika probudila
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
	"""
	Realistické vysypání kostek z kelímku - OPRAVENÁ VERZE
	Kostky padají z vrcholu oblouku směrem dolů na stůl
	"""
	
	if cup_release_position == Vector3.ZERO:
		cup_release_position = Vector3(0, 0, 0)  # Fallback
	
	print("\n🎲 === VYSYPÁNÍ KOSTEK ===")
	print("   Release pozice kelímku: ", cup_release_position)
	print("   Počet kostek: ", indices.size())
	
	# Počkej na dokončení animace kelímku (malá pauza)
	await get_tree().create_timer(0.1).timeout
	
	# === SPAWN POINT - otvor kelímku ===
	# Kelímek je silně otočený (~70°), otvor míří dolů
	var spawn_point = cup_release_position
	
	spawn_point = cup_release_position + Vector3(0, -1.5, 4.5)

	
	# Bezpečnostní kontrola - spawn point musí být NAD stolem!
	if spawn_point.y < 2.0:
		print("⚠️ Spawn point příliš nízko! Korihuji...")
		spawn_point.y = 5.0
	
	print("   Spawn point (střed stolu): ", spawn_point)
	print("   Stůl je na: (0, 0, 0)")
	
	# === VYSYPÁNÍ KOSTEK POSTUPNĚ ===
	for i in range(indices.size()):
		var idx = indices[i]
		if idx >= dice_array.size():
			continue
		
		var dice = dice_array[idx]
		
		# 1. Aktivuj kostku
		dice.visible = true
		dice.freeze = false
		
		# 2. Spawn v TĚSNÉ skupince z otvoru (malý rozptyl!)
		var spread = Vector3(
			randf_range(-0.1, 0.1),   # ⬅️ ZMĚNĚNO: Menší rozptyl X
			randf_range(-0.05, 0.05), # ⬅️ ZMĚNĚNO: Menší rozptyl Y
			randf_range(-0.1, 0.1)    # ⬅️ ZMĚNĚNO: Menší rozptyl Z
		)
		dice.global_position = spawn_point + spread
		
		# 3. Náhodná počáteční rotace
		dice.rotation = Vector3(
			randf_range(0, TAU),
			randf_range(0, TAU),
			randf_range(0, TAU)
		)
		
		# 4. SMĚR PÁDU - PŘÍMO DOLŮ do středu stolu!
		var table_center = Vector3(0, 0, 0)
		var to_center = (table_center - spawn_point).normalized()
		
		# Směr: 60% dolů + 40% do středu = dopad blízko středu
		var throw_direction = (
			Vector3(0, -1, 0) * 0.6 +  # ⬅️ ZMĚNĚNO: Méně dolů
			to_center * 0.4            # ⬅️ ZMĚNĚNO: Více do středu
		).normalized()
		
		# Malý rozptyl aby nepadly všechny na stejné místo
		throw_direction += Vector3(
			randf_range(-0.3, 0.3),    # ⬅️ ZMĚNĚNO: Větší rozptyl
			randf_range(-0.05, 0.0),   # Mírně dolů
			randf_range(-0.3, 0.3)     # ⬅️ ZMĚNĚNO: Větší rozptyl
		)
		throw_direction = throw_direction.normalized()
		
		# 5. SÍLA HODU - mírnější aby dopadly blíž
		var throw_force = randf_range(6.0, 9.0)  # ⬅️ ZMĚNĚNO: Méně síly!
		dice.linear_velocity = throw_direction * throw_force
		
		# 6. ROTACE - realistické kutálení
		dice.angular_velocity = Vector3(
			randf_range(-20, 20),
			randf_range(-20, 20),
			randf_range(-15, 15)
		)
		
		# 7. Označ že se kutálí
		dice.start_rolling()
		
		print("   ✓ Kostka ", idx, " vysypána: pos=", dice.global_position.y)
		
		# Rychlá pauza mezi kostkami (realistické vysypávání)
		await get_tree().create_timer(0.1).timeout  # ⬅️ ZMĚNĚNO: Rychlejší
	
	# === FINALIZACE ===
	is_rolling = true
	dice_stopped_count = 0
	dice_rolling_started.emit()
	
	print("✅ Všechny kostky vysypány a padají!")
	print("=========================\n")


func _on_dice_rolling():
	pass  # Kostka začala kutálení

func _on_dice_stopped(_value: int):
	dice_stopped_count += 1
	
	# Zvuk dopadu
	if audio_manager and audio_manager.has_method("play_dice_impact"):
		audio_manager.play_dice_impact()
	
	# Zkontroluj všechny kostky
	if dice_stopped_count >= rolling_dice_indices.size():
		is_rolling = false
		
		# ⚠️ OPRAVA - Aktualizuj hodnoty JEN pro nehozené kostky
		for idx in rolling_dice_indices:
			if idx < dice_array.size():
				var dice = dice_array[idx]
				
				# Bezpečnostní kontrola pozice
				if dice.global_position.y < -2.0:
					print("⚠️ Kostka ", idx, " je mimo stůl! Teleportuji...")
					dice.global_position = Vector3(
						randf_range(-3, 3),
						0.8,
						randf_range(-3, 3)
					)
					dice.linear_velocity = Vector3.ZERO
					dice.angular_velocity = Vector3.ZERO
				
				# ✅ KLÍČ - Ulož hodnotu JEN pokud NENÍ zabanovaná!
				if not banked_dice.has(idx):
					var val = dice.get_value()
					last_values[idx] = val if val >= 1 and val <= 6 else 1
					print("🎲 Kostka ", idx, " nová hodnota: ", last_values[idx])
				else:
					# Zabanovaná kostka - použij ULOŽENOU hodnotu
					if banked_values.has(idx):
						last_values[idx] = banked_values[idx]
						print("🔒 Kostka ", idx, " ZABANOVANÁ hodnota: ", last_values[idx])
		
		print("✅ Všechny kostky zastaveny. Hodnoty: ", last_values)
		
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
		var row = i / 3.0
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
	# Vyčisti dočasný výběr myši
	for idx in selected_dice:
		if idx < dice_array.size():
			dice_array[idx].set_selected(false)
	
	selected_dice.clear()
	
	print("🔄 Vyčištěn dočasný výběr")
	print("   Zabanované kostky zůstávají: ", banked_dice)

func clear_all_for_new_turn():
	#Kompletní reset VŠE
	print("\n🔄 ========== NOVÝ TAH - KOMPLETNÍ RESET ==========")
	
	# 1. Vyčisti dočasný výběr
	for idx in selected_dice:
		if idx < dice_array.size():
			dice_array[idx].set_selected(false)
	selected_dice.clear()
	
	# 2. Vrať zabanované kostky zpět do kelímku
	for idx in banked_dice:
		if idx < dice_array.size():
			var dice = dice_array[idx]
			dice.set_selected(false)
			dice.visible = false
			dice.freeze = true
			
			# Reset pozice do kelímku
			var row = idx / 3
			var col = idx % 3
			var offset = Vector3(
				float(col - 1) * 1.5,
				0,
				float(row) * 1.5 - 0.75
			)
			dice.position = spawn_position + offset
			dice.rotation = Vector3.ZERO
	
	# 3. Vyčisti všechny arrays - TADY se čistí banked_dice!
	banked_dice.clear()
	first_roll = true
	rolling_dice_indices.clear()
	
	# 4. Reset hodnot
	last_values = [0, 0, 0, 0, 0, 0]
	
	# 5. Skryj všechny kostky
	hide_all_dice()
	
	print("✅ Kompletní reset dokončen")
	print("   - Všechny kostky v kelímku")
	print("   - Zabanované kostky vyčištěny")
	print("   - Připraven na nový tah")
	print("====================================================\n")

func hide_all_dice():
	"""Skryj všechny kostky (na začátku - jsou v kelímku)"""
	for dice in dice_array:
		dice.visible = false
		dice.freeze = true
		dice.set_selected(false)
	print("👻 Schováno ", dice_array.size(), " kostek")

func mark_dice_as_banked(indices: Array):
	"""Označ kostky jako zabanované a přesuň je stranou"""
	
	print("\n💾 ========== BANKOVÁNÍ KOSTEK ==========")
	print("📥 Bankuji indexy: ", indices)
	print("📦 PŘED bankováním:")
	print("   banked_dice: ", banked_dice)
	
	for idx in indices:
		if idx < dice_array.size() and not banked_dice.has(idx):
			# ⚠️ OPRAVA: Spočítej pozici PŘED přidáním do banked_dice!
			var banked_position_index = banked_dice.size()  # Aktuální počet (před přidáním)
			
			banked_dice.append(idx)  # Teprve TEĎ přidej
			var dice = dice_array[idx]
			
			# Zobraz prstenec
			dice.set_selected(true)
			
			# Spočítej pozici podle pořadí
			var banked_position = Vector3(
				8.0,
				0.6,
				0.0 + banked_position_index * 1.8
			)
			
			# Zmraz a přesuň
			dice.freeze = true
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			dice.global_position = banked_position
			dice.visible = true  # ⚠️ MUSÍ zůstat viditelná!
			
			print("   ✅ Kostka ", idx, " zabanována:")
			print("      Hodnota: ", last_values[idx])
			print("      Pozice: ", banked_position)
			print("      Visible: ", dice.visible)
			print("      Freeze: ", dice.freeze)
			print("      Selected ring: ", dice.is_selected)
	
	if audio_manager and audio_manager.has_method("play_score"):
		audio_manager.play_score()
	
	# Vyčisti dočasný výběr myší
	selected_dice.clear()
	
	print("📦 PO bankování:")
	print("   banked_dice: ", banked_dice)
	print("   Celkem zabanovaných: ", banked_dice.size(), " kostek")
	
	# Efekt
	for idx in indices:
		if effects_manager and effects_manager.has_method("play_score_effect"):
			var dice = dice_array[idx]
			effects_manager.play_score_effect(dice.global_position)
	
	print("==========================================\n")
