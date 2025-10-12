extends Node3D

signal shake_complete()
signal dice_released()

@export var shake_duration: float = 1.2
@export var shake_intensity: float = 0.4
@export var pour_duration: float = 1.0
@export var shake_sounds: Array[AudioStream] = []  # Přidej zvuky třesení
@export var dice_spawn_offset: Vector3 = Vector3(0, 1, 0)  # Pozice odkud se kostky vysypou

var is_shaking: bool = false
var original_position: Vector3
var original_rotation: Vector3
var is_hidden: bool = false

# Reference na kostky
var dice_in_cup: Array = []

# Audio player
var audio_player: AudioStreamPlayer3D = null

func _ready():
	original_position = position
	original_rotation = rotation
	
	# Vytvoř audio player pro zvuky
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)

func hide_cup():
	"""Skryj kelímek (mimo kameru)"""
	if is_hidden:
		return
	
	is_hidden = true
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Přesuň daleko mimo
	var hide_position = original_position + Vector3(-8, -2, -5)
	tween.tween_property(self, "position", hide_position, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false
	print("🥤 Kelímek schován")

func show_cup():
	"""Zobraz kelímek zpět na původní pozici"""
	if not is_hidden:
		return
	
	is_hidden = false
	visible = true
	scale = Vector3(0.1, 0.1, 0.1)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(self, "position", original_position, 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1, 1, 1), 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	print("🥤 Kelímek zobrazen")

func shake_and_pour():
	"""Zatřes kelímkem a vysyp kostky"""
	if is_shaking:
		return
	
	is_shaking = true
	print("🥤 Třesu kelímkem...")
	
	# Zvuk třesení
	play_shake_sound()
	
	# Fáze 1: Třesení
	await shake_cup()
	
	# Fáze 2: Vysypání
	await pour_dice()
	
	is_shaking = false

func shake_cup():
	"""Animace třesení kelímkem - více realistická"""
	var tween = create_tween()
	tween.set_parallel(false)
	
	var shake_time = shake_duration
	var steps = 20  # Více kroků pro plynulejší pohyb
	
	for i in range(steps):
		var t = float(i) / steps
		var progress = t * shake_time
		
		# Komplexnější třesení - více os
		var offset_y = sin(progress * 25.0) * shake_intensity * (1.0 - t * 0.3)
		var offset_x = cos(progress * 20.0) * shake_intensity * 0.6 * (1.0 - t * 0.3)
		var offset_z = sin(progress * 15.0) * shake_intensity * 0.3
		
		var rot_z = sin(progress * 30.0) * deg_to_rad(20) * (1.0 - t * 0.5)
		var rot_x = cos(progress * 25.0) * deg_to_rad(10)
		
		tween.tween_property(
			self, 
			"position", 
			original_position + Vector3(offset_x, offset_y, offset_z),
			shake_time / steps
		).set_trans(Tween.TRANS_SINE)
		
		tween.tween_property(
			self,
			"rotation",
			Vector3(original_rotation.x + rot_x, original_rotation.y, rot_z),
			shake_time / steps
		).set_trans(Tween.TRANS_SINE)
	
	await tween.finished
	shake_complete.emit()

func pour_dice():
	"""Animace vysypání kostek - VYLEPŠENÁ dramatická verze"""
	print("🎲 Vysypávám kostky...")
	
	# Fáze 1: Prudké zdvižení kelímku nahoru
	var lift_tween = create_tween()
	lift_tween.set_parallel(true)
	
	var lift_pos = original_position + Vector3(0, 1.5, 0)
	var lift_rot = original_rotation + Vector3(deg_to_rad(-10), 0, 0)
	
	lift_tween.tween_property(self, "position", lift_pos, 0.15)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift_tween.tween_property(self, "rotation", lift_rot, 0.15)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await lift_tween.finished
	
	# Krátká pauza pro napětí
	await get_tree().create_timer(0.1).timeout
	
	# Fáze 2: Rychlé naklonění a vysypání
	var pour_tween = create_tween()
	pour_tween.set_parallel(true)
	
	# Více dramatické naklonění - jako by to někdo hodil
	var pour_rotation = original_rotation + Vector3(deg_to_rad(150), deg_to_rad(20), deg_to_rad(-50))
	var pour_position = original_position + Vector3(2.0, 0.8, 1.2)
	
	# Rychlé otočení
	pour_tween.tween_property(self, "rotation", pour_rotation, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	pour_tween.tween_property(self, "position", pour_position, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Uvolni kostky brzy - ať vypadají že vylétly
	await get_tree().create_timer(0.1).timeout
	release_dice()
	
	await pour_tween.finished
	
	# Fáze 3: Mírné zatřesení (dozvuky)
	var shake_count = 3
	for i in range(shake_count):
		var shake_offset = Vector3(
			randf_range(-0.1, 0.1),
			randf_range(-0.05, 0.05),
			randf_range(-0.1, 0.1)
		)
		var shake_tween = create_tween()
		shake_tween.tween_property(
			self, 
			"position", 
			pour_position + shake_offset, 
			0.05
		)
		await shake_tween.finished
	
	# Počkej aby kostky dopadly
	await get_tree().create_timer(0.4).timeout
	
	# Fáze 4: Elegantní návrat kelímku
	var return_tween = create_tween()
	return_tween.set_parallel(true)
	
	# Nejdřív zpátky do původní rotace
	return_tween.tween_property(self, "rotation", original_rotation, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Pak pozice
	return_tween.tween_property(self, "position", original_position, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await return_tween.finished
	
	# Krátká pauza než se schová
	await get_tree().create_timer(0.3).timeout
	
	# Fáze 5: Schovej kelímek
	hide_cup()

func release_dice():
	"""Uvolni kostky z kelímku"""
	dice_released.emit()
	
	# Vizuální efekt - prach/jiskry při vysypání (volitelné)
	create_pour_particles()
	
	print("✅ Kostky uvolněny!")

func create_pour_particles():
	"""Vytvoř částicový efekt při vysypání"""
	# Jednoduchý flash efekt
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.95, 0.7)
	flash.light_energy = 2.0
	flash.omni_range = 4.0
	flash.global_position = global_position + Vector3(1, 0, 0)
	get_parent().add_child(flash)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	await tween.finished
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
