extends Node3D

signal shake_complete()
signal dice_released(release_position: Vector3)  # Posílá pozici kde vysypat

@export var shake_duration: float = 1.0
@export var shake_intensity: float = 0.3
@export var throw_duration: float = 0.8
@export var shake_sounds: Array[AudioStream] = []
@export var rest_position: Vector3 = Vector3(15, 0, 0)
@export var throw_target: Vector3 = Vector3(0, 0, 0)
@export var arc_height: float = 4.0
@export_range(0.0, 1.0) var release_timing: float = 0.3  # Kdy vysypat kostky (0-1)

var is_shaking: bool = false
var audio_player: AudioStreamPlayer3D = null

func _ready():
	position = rest_position
	rotation = Vector3.ZERO
	
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	
	print("🥤 Kelímek připraven na pozici: ", rest_position)

func shake_and_throw():
	"""Jednoduchá profesionální animace: míchání -> oblouk -> vysypání"""
	if is_shaking:
		return
	
	is_shaking = true
	print("🎲 Začínám hod...")
	
	play_shake_sound()
	
	# Fáze 1: Třesení na místě (15, 0, 0)
	await shake_on_position()
	
	# Fáze 2: Obloukový hod nad stůl
	await arc_throw()
	
	# Fáze 3: Návrat zpět
	await return_to_rest()
	
	is_shaking = false
	print("✅ Hod dokončen")

func shake_on_position():
	"""Promíchání kostek na místě (pozice 15, 0, 0)"""
	print("🔄 Míchám kostky na místě...")
	
	var steps = 15
	var step_time = shake_duration / steps
	
	for i in range(steps):
		var t = float(i) / steps
		var freq = 25.0 + t * 10.0
		
		var offset_y = sin(t * freq) * shake_intensity
		var offset_z = cos(t * freq * 0.8) * shake_intensity * 0.5
		
		var rot_x = sin(t * freq * 1.2) * deg_to_rad(15)
		var rot_z = cos(t * freq) * deg_to_rad(20)
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		
		tween.tween_property(
			self,
			"position",
			rest_position + Vector3(0, offset_y, offset_z),
			step_time
		)
		
		tween.tween_property(
			self,
			"rotation",
			Vector3(rot_x, 0, rot_z),
			step_time
		)
		
		await tween.finished
	
	# Vrať na výchozí pozici před hodem
	var reset = create_tween()
	reset.set_parallel(true)
	reset.tween_property(self, "position", rest_position, 0.1)
	reset.tween_property(self, "rotation", Vector3.ZERO, 0.1)
	await reset.finished
	
	shake_complete.emit()

func arc_throw():
	"""Obloukový hod nad stůl s vysypáním"""
	print("🌊 Házím obloukem...")
	
	var start_pos = rest_position
	var end_pos = throw_target + Vector3(0, 2.0, 0)
	var mid_pos = (start_pos + end_pos) / 2.0
	mid_pos.y += arc_height
	
	# Fáze 1: Oblouk k nejvyššímu bodu s počátkem převrácení
	var rise_tween = create_tween()
	rise_tween.set_parallel(true)
	rise_tween.set_trans(Tween.TRANS_QUAD)
	rise_tween.set_ease(Tween.EASE_OUT)
	
	rise_tween.tween_property(self, "position", mid_pos, throw_duration * 0.5)
	rise_tween.tween_property(
		self,
		"rotation",
		Vector3(deg_to_rad(60), deg_to_rad(-10), deg_to_rad(40)),
		throw_duration * 0.5
	)
	
	await rise_tween.finished
	
	# Fáze 2: Dokončení převrácení a klesání nad stůl
	var pour_tween = create_tween()
	pour_tween.set_parallel(true)
	pour_tween.set_trans(Tween.TRANS_QUAD)
	pour_tween.set_ease(Tween.EASE_IN)
	
	var pour_rotation = Vector3(deg_to_rad(140), deg_to_rad(-20), deg_to_rad(70))
	
	pour_tween.tween_property(self, "position", end_pos, throw_duration * 0.5)
	pour_tween.tween_property(self, "rotation", pour_rotation, throw_duration * 0.5)
	
	# Vysyp kostky když je kelímek dostatečně převrácený (nastavitelný timing)
	await get_tree().create_timer(throw_duration * 0.5 * release_timing).timeout
	release_dice()
	
	await pour_tween.finished
	await get_tree().create_timer(0.2).timeout

func return_to_rest():
	"""Plynulý návrat na výchozí pozici"""
	print("↩️ Vracím se...")
	
	await get_tree().create_timer(0.3).timeout
	
	var current_pos = position
	var mid_return = (current_pos + rest_position) / 2.0
	mid_return.y += 3.0
	
	# Fáze 1: Nahoru
	var up_tween = create_tween()
	up_tween.set_parallel(true)
	up_tween.set_trans(Tween.TRANS_CUBIC)
	up_tween.set_ease(Tween.EASE_OUT)
	
	up_tween.tween_property(self, "position", mid_return, 0.4)
	up_tween.tween_property(self, "rotation", Vector3.ZERO, 0.4)
	
	await up_tween.finished
	
	# Fáze 2: Dolů na místo
	var down_tween = create_tween()
	down_tween.set_parallel(true)
	down_tween.set_trans(Tween.TRANS_CUBIC)
	down_tween.set_ease(Tween.EASE_IN)
	
	down_tween.tween_property(self, "position", rest_position, 0.4)
	down_tween.tween_property(self, "rotation", Vector3.ZERO, 0.4)
	
	await down_tween.finished

func release_dice():
	"""Emituj signál pro DiceManager, aby vysypal kostky"""
	# Pošli aktuální globální pozici kelímku (kde se mají kostky spawnnout)
	dice_released.emit(global_position)
	
	if is_inside_tree():
		call_deferred("create_pour_particles")
	
	print("🎲 Signál dice_released odeslán z pozice: ", global_position)

func create_pour_particles():
	"""Flash efekt při vysypání"""
	if not is_inside_tree():
		return
	
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.95, 0.7)
	flash.light_energy = 2.5
	flash.omni_range = 5.0
	flash.position = Vector3(0, -1, 0)
	
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	await tween.finished
	
	if flash and is_instance_valid(flash):
		flash.queue_free()

func play_shake_sound():
	"""Přehraj zvuk třesení"""
	if shake_sounds.size() > 0 and audio_player:
		var random_sound = shake_sounds[randi() % shake_sounds.size()]
		audio_player.stream = random_sound
		audio_player.play()
