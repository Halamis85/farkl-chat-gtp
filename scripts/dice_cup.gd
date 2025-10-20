extends Node3D
# dice_cup.gd - KOMPLETNÍ VERZE s camera integrací

signal shake_complete()
signal dice_released(release_position: Vector3)
signal shake_started()  # ⭐ NOVÝ signál
signal dice_about_to_release()  # ⭐ NOVÝ signál

var camera: Camera3D = null

@export var shake_duration: float = 0.8
@export var shake_intensity: float = 0.2
@export var throw_duration: float = 1.2
@export var shake_sounds: Array[AudioStream] = []

var rest_position: Vector3
var is_shaking: bool = false
var audio_player: AudioStreamPlayer3D = null

func _ready():
	# Ulož výchozí pozici
	rest_position = global_position
	rotation = Vector3.ZERO
	
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	
	# ⭐ PŘIPOJ KAMERU
	if has_node("/root/Main/Camera3D"):
		camera = get_node("/root/Main/Camera3D")
		print("📷 Kelímek připojen ke kameře")
	else:
		print("⚠️ Kamera nebyla nalezena")
	
	print("🥤 Kelímek inicializován:")
	print("   Rest pozice: ", rest_position)
	print("   Scale: ", scale)

# ========================================
# HLAVNÍ FUNKCE - S CAMERA HOOKS
# ========================================

func shake_and_throw():
	"""REALISTICKÝ HOD s camera synchronizací"""
	if is_shaking:
		return
	
	is_shaking = true
	print("🎲 Realistický hod začíná...")
	
	# ⭐ 1. NOTIFIKUJ KAMERU - začíná shake
	shake_started.emit()
	if camera:
		camera.move_to_shake_view()  # Kamera sleduje kelímek
	
	play_shake_sound()
	
	# FÁZE 1: Třesení (0.8s)
	await realistic_shake()
	
	# ⭐ 2. NOTIFIKUJ KAMERU - kostky se chystají vypadnout
	dice_about_to_release.emit()
	
	# FÁZE 2: Oblouk + vysypání (1.2s)
	await realistic_arc_throw()
	
	# ⭐ 3. KAMERA SHAKE při vysypání
	if camera:
		camera.add_camera_shake(0.2, 0.3)  # ← Opraveno: add_camera_shake místo play_shake
	
	# FÁZE 3: Návrat (0.8s)
	await smooth_return()
	
	is_shaking = false
	print("✅ Hod dokončen")

# ========================================
# FÁZE 1: REALISTICKÉ TŘESENÍ
# ========================================

func realistic_shake():
	"""Lidské třesení - nepravidelné, s akcelerací"""
	print("🔄 Třesu jako člověk...")
	
	var shake_steps = 12
	var step_time = shake_duration / shake_steps
	
	for i in range(shake_steps):
		var t = float(i) / shake_steps
		
		# Postupně zrychlující třesení
		var intensity = shake_intensity * (0.3 + t * 0.7)
		var freq = 15.0 + t * 20.0
		
		# Nepravidelné offsety (simulace lidské ruky)
		var noise_x = sin(t * freq + randf_range(-0.3, 0.3))
		var noise_y = cos(t * freq * 1.3 + randf_range(-0.2, 0.2))
		var noise_z = sin(t * freq * 0.7 + randf_range(-0.4, 0.4))
		
		var offset = Vector3(
			noise_x * intensity * 0.3,
			noise_y * intensity * 0.5,
			noise_z * intensity * 0.4
		)
		
		# Rotace kelímku při třesení
		var rot = Vector3(
			sin(t * freq * 1.1) * deg_to_rad(8),
			cos(t * freq * 0.9) * deg_to_rad(5),
			sin(t * freq * 1.4) * deg_to_rad(12)
		)
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		
		tween.tween_property(self, "position", rest_position + offset, step_time)
		tween.tween_property(self, "rotation", rot, step_time)
		
		await tween.finished
	
	# Reset na výchozí
	var reset = create_tween()
	reset.set_parallel(true)
	reset.tween_property(self, "position", rest_position, 0.15)
	reset.tween_property(self, "rotation", Vector3.ZERO, 0.15)
	await reset.finished
	
	shake_complete.emit()

# ========================================
# FÁZE 2: REALISTICKÝ OBLOUK + VYSYPÁNÍ
# ========================================

func realistic_arc_throw():
	"""Plynulý lidský hod - oblouk s vysypáním NAD STŘEDEM stolu"""
	print("🌊 Házím obloukem...")
	
	# var _start = rest_position  # ← Přejmenováno kvůli warningu
	var peak = Vector3(0, 5.5, 0)  # Vrchol NAD STŘEDEM stolu
	var end = Vector3(0, 5, 0.2)
	
	# === ČÁST A: Zdvih + otočení nahoru (0.6s) ===
	var rise_tween = create_tween()
	rise_tween.set_parallel(true)
	rise_tween.set_trans(Tween.TRANS_CUBIC)
	rise_tween.set_ease(Tween.EASE_OUT)
	rise_tween.tween_property(self, "global_position", peak, 0.6)
	rise_tween.tween_property(
		self,
		"rotation",
		Vector3(deg_to_rad(120), deg_to_rad(-10), deg_to_rad(25)),
		0.6
	)
	
	await rise_tween.finished
	
	# ⏰ KRITICKÉ: Počkej než se kelímek PLNĚ otočí
	await get_tree().create_timer(0.15).timeout
	
	# === VYSYPÁNÍ NA VRCHOLU ===
	var cup_opening_offset = Vector3(0,-0.5,0)
	var release_pos = global_position + cup_opening_offset
	
	print("   Release pozice: ", release_pos)
	
	# ⭐ EMITUJ pozici pro DiceManager
	dice_released.emit(release_pos)
	
	# ⭐ CAMERA FOV PUNCH při vysypání
	if camera:
		camera.punch_zoom(10.0, 0.2)
	
	# Flash efekt
	if is_inside_tree():
		call_deferred("create_pour_particles")
	
	# Pauza aby kostky vypadly
	await get_tree().create_timer(0.45).timeout
	
	# === ČÁST B: Dohoz dolů (0.5s) ===
	var pour_tween = create_tween()
	pour_tween.set_parallel(true)
	pour_tween.set_trans(Tween.TRANS_QUAD)
	pour_tween.set_ease(Tween.EASE_IN)
	
	pour_tween.tween_property(self, "global_position", end, 1.0)
	pour_tween.tween_property(
		self,
		"rotation",
		Vector3(deg_to_rad(80), deg_to_rad(-10), deg_to_rad(20)),
		0.5
	)
	
	await pour_tween.finished

# ========================================
# FÁZE 3: PLYNULÝ NÁVRAT
# ========================================

func smooth_return():
	"""Návrat na výchozí pozici"""
	print("↩️ Vracím se na místo...")
	
	await get_tree().create_timer(0.3).timeout
	
	var current = global_position
	var mid_return = (current + rest_position) / 2.0
	mid_return.y += 2.5
	
	# Oblouk nahoru
	var up = create_tween()
	up.set_parallel(true)
	up.set_trans(Tween.TRANS_CUBIC)
	up.set_ease(Tween.EASE_OUT)
	
	up.tween_property(self, "global_position", mid_return, 0.4)
	up.tween_property(self, "rotation", Vector3.ZERO, 0.4)
	
	await up.finished
	
	# Dopad dolů
	var down = create_tween()
	down.set_parallel(true)
	down.set_trans(Tween.TRANS_CUBIC)
	down.set_ease(Tween.EASE_IN)
	
	down.tween_property(self, "global_position", rest_position, 0.35)
	down.tween_property(self, "rotation", Vector3.ZERO, 0.35)
	
	await down.finished
	
	# ⭐ KAMERA zpět na overview po dokončení
	if camera:
		await get_tree().create_timer(0.5).timeout
		camera.move_to_overview()

# ========================================
# POMOCNÉ FUNKCE
# ========================================

func create_pour_particles():
	"""Flash při vysypání"""
	if not is_inside_tree():
		return
	
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.95, 0.7)
	flash.light_energy = 2.0
	flash.omni_range = 4.0
	flash.position = Vector3(0, -0.5, 0)
	
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	await tween.finished
	
	if flash and is_instance_valid(flash):
		flash.queue_free()

func play_shake_sound():
	"""Zvuk třesení"""
	if shake_sounds.size() > 0 and audio_player:
		var sound = shake_sounds[randi() % shake_sounds.size()]
		audio_player.stream = sound
		audio_player.play()

# ========================================
# DEBUG (volitelné)
# ========================================

func debug_throw():
	"""Test hodu bez DiceManageru"""
	print("🧪 DEBUG: Test throw")
	await shake_and_throw()
	
