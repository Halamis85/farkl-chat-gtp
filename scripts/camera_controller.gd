extends Camera3D

signal camera_movement_complete()

enum CameraState {
	OVERVIEW,      # Celkový pohled na stůl
	FOCUSED,       # Přiblížení na kostky
	SHAKING,       # Sledování kelímku
	CINEMATIC      # Speciální cinematic shot
}

var current_state: CameraState = CameraState.OVERVIEW

# Pozice kamery - upravitelné v inspectoru
@export_group("Camera Positions")
@export var overview_position = Vector3(0, 8, 8)
@export var overview_rotation = Vector3(deg_to_rad(-45), 0, 0)

@export var focused_position = Vector3(0, 4, 4)
@export var focused_rotation = Vector3(deg_to_rad(-55), 0, 0)

@export var shake_position = Vector3(-4, 3, 3)
@export var shake_rotation = Vector3(deg_to_rad(-35), deg_to_rad(-25), 0)

@export_group("Camera Settings")
@export var transition_duration: float = 1.2
@export var smooth_speed: float = 4.0
@export var fov_default: float = 75.0
@export var fov_focused: float = 60.0
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
		final_pos = Vector3(center.x, 4, center.z + 4)
		
		# Směřuj na střed
		var look_at_target = center
		# Tady bychom mohli vypočítat rotaci, ale ponecháme fixní
	
	if instant:
		position = final_pos
		rotation = final_rot
		fov = fov_focused
	else:
		move_to(final_pos, final_rot, fov_focused)

func move_to_shake_view(instant: bool = false):
	"""Sleduj kelímek při třesení"""
	print("📷 Kamera: Pohled na kelímek")
	current_state = CameraState.SHAKING
	
	if instant:
		position = shake_position
		rotation = shake_rotation
		fov = fov_default
	else:
		move_to(shake_position, shake_rotation, fov_default)

func move_to(pos: Vector3, rot: Vector3, new_fov: float = -1):
	"""Plynule přesuň kameru na cílovou pozici"""
	target_position = pos
	target_rotation = rot
	target_fov = new_fov if new_fov > 0 else fov
	is_transitioning = true

func cinematic_shake_follow(cup_node: Node3D, duration: float = 1.5):
	"""Dramatické sledování kelímku během třesení"""
	if not use_cinematic_transitions:
		return
	
	print("🎬 Cinematic: Sledování kelímku")
	current_state = CameraState.CINEMATIC
	
	# Smoothly follow cup with slight offset
	var start_time = Time.get_ticks_msec() / 1000.0
	
	while Time.get_ticks_msec() / 1000.0 - start_time < duration:
		if cup_node:
			var cup_pos = cup_node.global_position
			target_position = cup_pos + Vector3(2, 2, 2)
			# Pozor - look_at nefunguje v _process, museli bychom použít jinou metodu
		await get_tree().process_frame

func zoom_in():
	"""Přiblíž kameru"""
	target_fov = max(fov_focused - 10, 40.0)
	is_transitioning = true

func zoom_out():
	"""Oddal kameru"""
	move_to_overview()

func add_camera_shake(intensity: float = 0.1, duration: float = 0.3):
	"""Přidej shake efekt kamery (např. při pádu kostek)"""
	var original_pos = position
	var shake_tween = create_tween()
	
	for i in range(5):
		var offset = Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(self, "position", original_pos + offset, duration / 10.0)
	
	shake_tween.tween_property(self, "position", original_pos, duration / 10.0)

# Manuální ovládání kamery (pro testování/debug)
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				move_to_overview()
			KEY_2:
				move_to_focused()
			KEY_3:
				move_to_shake_view()
			KEY_KP_ADD:  # Numpad +
				zoom_in()
			KEY_KP_SUBTRACT:  # Numpad -
				zoom_out()
