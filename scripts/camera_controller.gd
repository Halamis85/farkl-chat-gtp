extends Camera3D

signal camera_movement_complete()

enum CameraState {
	OVERVIEW,      # Celkový pohled na stůl
	FOCUSED,       # Přiblížení na kostky
	SHAKING,       # Sledování kelímku
	CINEMATIC      # Speciální cinematic shot
}

var current_state: CameraState = CameraState.OVERVIEW

# ========================================
# OPRAVENÉ POZICE KAMERY
# ========================================
# Stůl je na y=0, kelímek na pravé straně (x=7, z=-6)

@export_group("Camera Positions")
# Celkový pohled - vidíš celý stůl
@export var overview_position = Vector3(0, 12, 12)
@export var overview_rotation = Vector3(deg_to_rad(-50), 0, 0)

# Přiblížení na kostky - střed stolu
@export var focused_position = Vector3(0, 8, 6)
@export var focused_rotation = Vector3(deg_to_rad(-55), 0, 0)

# Pohled na kelímek - PRAVÝ ROH
@export var shake_position = Vector3(7, 5, -2)  # Naproti kelímku
@export var shake_rotation = Vector3(deg_to_rad(-40), deg_to_rad(180), 0)  # Otočeno k rohu

@export_group("Camera Settings")
@export var transition_duration: float = 1.0
@export var smooth_speed: float = 5.0
@export var fov_default: float = 75.0
@export var fov_focused: float = 65.0
@export var use_cinematic_transitions: bool = true

var target_position: Vector3
var target_rotation: Vector3
var target_fov: float
var is_transitioning: bool = false

func _ready():
	# Nastav počáteční pozici
	position = overview_position
	rotation = overview_rotation
	fov = fov_default
	target_position = overview_position
	target_rotation = overview_rotation
	target_fov = fov_default
	
	print("📷 Kamera inicializována:")
	print("   Overview: ", overview_position)
	print("   Focused: ", focused_position)
	print("   Shake: ", shake_position)

func _process(delta):
	# Plynulé přesuny kamery
	if is_transitioning:
		position = position.lerp(target_position, smooth_speed * delta)
		rotation = rotation.lerp(target_rotation, smooth_speed * delta)
		fov = lerp(fov, target_fov, smooth_speed * delta)
		
		# Kontrola, zda jsme dorazili
		if position.distance_to(target_position) < 0.1 and abs(fov - target_fov) < 0.5:
			is_transitioning = false
			position = target_position
			rotation = target_rotation
			fov = target_fov
			camera_movement_complete.emit()

func move_to_overview(instant: bool = false):
	"""Přesuň kameru na celkový pohled"""
	print("📷 Kamera: Celkový pohled")
	current_state = CameraState.OVERVIEW
	
	if instant:
		position = overview_position
		rotation = overview_rotation
		fov = fov_default
	else:
		move_to(overview_position, overview_rotation, fov_default)

func move_to_focused(dice_positions: Array = [], instant: bool = false):
	"""Přiblíž kameru na hozené kostky"""
	print("📷 Kamera: Přiblížení na kostky")
	current_state = CameraState.FOCUSED
	
	var final_pos = focused_position
	var final_rot = focused_rotation
	
	# Pokud máme pozice kostek, vypočítej střed
	if dice_positions.size() > 0:
		var center = Vector3.ZERO
		for pos in dice_positions:
			center += pos
		center /= dice_positions.size()
		
		# Přizpůsob pozici kamery podle středu kostek
		final_pos = Vector3(center.x, 6, center.z)
	
	if instant:
		position = final_pos
		rotation = final_rot
		fov = fov_focused
	else:
		move_to(final_pos, final_rot, fov_focused)

func move_to_shake_view(instant: bool = false):
	"""Přesuň kameru na pohled na kelímek (pravý roh)"""
	print("📷 Kamera: Sledování kelímku")
	current_state = CameraState.SHAKING
	
	if instant:
		position = shake_position
		rotation = shake_rotation
		fov = fov_default
	else:
		move_to(shake_position, shake_rotation, fov_default)

func move_to(pos: Vector3, rot: Vector3, new_fov: float):
	"""Generická funkce pro pohyb kamery"""
	target_position = pos
	target_rotation = rot
	target_fov = new_fov
	is_transitioning = true

# Camera shake efekt při dopadu kostek
func add_camera_shake(intensity: float = 0.2, duration: float = 0.3):
	"""Třes kamerou při dopadu"""
	var original_pos = position
	var shake_steps = 8
	var step_duration = duration / shake_steps
	
	for i in range(shake_steps):
		var t = float(i) / shake_steps
		var shake_amount = intensity * (1.0 - t)  # Postupně slábne
		
		var offset = Vector3(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		
		var tween = create_tween()
		tween.tween_property(
			self,
			"position",
			original_pos + offset,
			step_duration
		).set_trans(Tween.TRANS_SINE)
		
		await tween.finished
	
	# Vrať se na původní pozici
	position = original_pos
# Manuální ovládání kamery (pro testování/debug)
