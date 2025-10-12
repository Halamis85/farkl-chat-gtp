extends Node3D

signal shake_complete()
signal dice_released()

@export var shake_duration: float = 1.0
@export var shake_intensity: float = 0.3
@export var throw_duration: float = 0.8
@export var shake_sounds: Array[AudioStream] = []  # Přidej zvuky třesení
@export var dice_spawn_offset: Vector3 = Vector3(0, 1, 0)  # Pozice odkud se kostky vysypou
@export var rest_position: Vector3 = Vector3(15, 0, 0)  # Pozice kelímku mimo hru
@export var throw_target: Vector3 = Vector3(0, 0, 0)  # Kam se hází (střed stolu)

var is_shaking: bool = false
var original_position: Vector3
var original_rotation: Vector3
var is_hidden: bool = false

# Reference na kostky
var dice_in_cup: Array = []

# Audio player
var audio_player: AudioStreamPlayer3D = null

func _ready():
	# Nastav kelímek na odpočinkovou pozici (mimo hru)
	position = rest_position
	rotation = Vector3.ZERO
	original_position = rest_position
	original_rotation = Vector3.ZERO
	
	# Vytvoř audio player pro zvuky
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	
	print("🥤 Kelímek připraven na pozici: ", rest_position)

func hide_cup():
	"""Skryj kelímek (už není potřeba - zůstane stranou)"""
	# Kelímek už zůstane na rest_position, nemusíme ho schovávat
	pass

func show_cup():
	"""Zobraz kelímek zpět (už je viditelný)"""
	# Kelímek je stále viditelný, jen na rest_position
	pass

func shake_and_throw():
	"""Zatřes kelímkem a hoď kostky na stůl - NOVÁ VERZE"""
	if is_shaking:
		print("⚠️ Kelímek už třese!")
		return
	
	is_shaking = true
	print("🥤 Začínám házení kostek z pozice: ", position)
	print("🎯 Cíl hodu: ", throw_target)
	
	# Zvuk třesení
	play_shake_sound()
	
	# Fáze 1: Třesení na místě (mimo hru)
	print("📍 Fáze 1: Třesení na rest_position")
	await shake_cup_in_place()
	
	# Fáze 2: Hod na hrací plochu
	print("📍 Fáze 2: Hod k hrací ploše")
	await throw_to_table()
	
	# Fáze 3: Návrat zpět
	print("📍 Fáze 3: Návrat")
	await return_to_rest()
	
	is_shaking = false
	print("🥤 Animace dokončena, pozice: ", position)

func shake_cup_in_place():
	"""Zatřes kelímkem na odpočinkové pozici"""
	print("🥤 Třesu kelímkem...")
	
	var shake_time = shake_duration
	var steps = 15
	
	for i in range(steps):
		var t = float(i) / steps
		var progress = t * shake_time
		
		# Třesení nahoru/dolů a rotace
		var offset_y = sin(progress * 25.0) * shake_intensity * (1.0 - t * 0.2)
		var offset_z = cos(progress * 20.0) * shake_intensity * 0.3
		var rot_z = sin(progress * 30.0) * deg_to_rad(15) * (1.0 - t * 0.3)
		
		var tween = create_tween()
		tween.set_parallel(true)
		
		tween.tween_property(
			self, 
			"position", 
			rest_position + Vector3(0, offset_y, offset_z),
			shake_time / steps
		).set_trans(Tween.TRANS_SINE)
		
		tween.tween_property(
			self,
			"rotation",
			Vector3(0, 0, rot_z),
			shake_time / steps
		).set_trans(Tween.TRANS_SINE)
		
		await tween.finished
	
	shake_complete.emit()

func throw_to_table():
	"""Hoď kelímek k hrací ploše a vysyp kostky - DEALER STYLE"""
	print("🎲 Házím na stůl...")
	
	# Fáze 1: Rychlý švih nad stůl
	var above_table = throw_target + Vector3(-2, 4.0, 0)  # Přilétni z boku
	
	var move_tween = create_tween()
	move_tween.set_parallel(true)
	
	# Rychlý agresivní pohyb
	move_tween.tween_property(self, "position", above_table, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	move_tween.tween_property(
		self, 
		"rotation", 
		Vector3(deg_to_rad(-30), deg_to_rad(-20), deg_to_rad(15)), 
		0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await move_tween.finished
	
	# Fáze 2: PRUDKÉ převrácení a vysypání (švih přes stůl)
	var pour_tween = create_tween()
	pour_tween.set_parallel(true)
	
	# Švihni přes střed stolu
	var pour_position = throw_target + Vector3(2, 3.5, 0)
	# DRAMATICKÉ převrácení
	var pour_rotation = Vector3(deg_to_rad(140), deg_to_rad(30), deg_to_rad(-50))
	
	# RYCHLÝ prudký pohyb
	pour_tween.tween_property(self, "position", pour_position, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pour_tween.tween_property(self, "rotation", pour_rotation, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Uvolni kostky HNED na začátku švihu
	await get_tree().create_timer(0.08).timeout
	release_dice()
	
	await pour_tween.finished
	
	# Fáze 3: Rychlé narovnání a odtažení
	await get_tree().create_timer(0.15).timeout
	
	var pullback = create_tween()
	pullback.set_parallel(true)
	
	# Odskoč zpět a nahoru
	var retreat_position = throw_target + Vector3(3, 5.0, 0)
	
	pullback.tween_property(self, "position", retreat_position, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pullback.tween_property(self, "rotation", Vector3.ZERO, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await pullback.finished

func return_to_rest():
	"""Vrať kelímek zpět na odpočinkovou pozici - RYCHLE"""
	print("🥤 Vracím se zpět...")
	
	# Minimální čekání - už jsme vysoko a stranou
	await get_tree().create_timer(0.3).timeout
	
	# Rychlý návrat
	var return_tween = create_tween()
	return_tween.set_parallel(true)
	
	return_tween.tween_property(self, "position", rest_position, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(self, "rotation", Vector3.ZERO, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	await return_tween.finished

func release_dice():
	"""Uvolni kostky z kelímku"""
	dice_released.emit()
	
	# Vizuální efekt - pouze pokud jsme ve stromu a na hlavním vlákně
	if is_inside_tree():
		call_deferred("create_pour_particles")
	
	print("✅ Kostky uvolněny!")

func create_pour_particles():
	"""Vytvoř částicový efekt při vysypání"""
	# Zkontroluj že jsme stále ve stromu
	if not is_inside_tree():
		return
	
	# Jednoduchý flash efekt
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.95, 0.7)
	flash.light_energy = 2.0
	flash.omni_range = 4.0
	flash.position = Vector3(1, 0, 0)  # Lokální pozice místo global
	
	# Přidej jako child kelímku
	add_child(flash)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	await tween.finished
	
	if flash and is_instance_valid(flash):
		flash.queue_free()

func add_dice_to_cup(dice_array: Array):
	"""Přidej kostky do kelímku (skryj je)"""
	dice_in_cup = dice_array
	for dice in dice_array:
		dice.visible = false
		dice.freeze = true

func show_dice():
	"""Zobraz kostky (po vysypání)"""
	for dice in dice_in_cup:
		dice.visible = true
		dice.freeze = false

func play_shake_sound():
	"""Přehraj zvuk třesení"""
	if shake_sounds.size() > 0 and audio_player:
		var random_sound = shake_sounds[randi() % shake_sounds.size()]
		audio_player.stream = random_sound
		audio_player.play()
