extends RigidBody3D

signal dice_stopped(value: int)
signal dice_rolling
signal dice_clicked(dice: RigidBody3D)

var is_rolling: bool = false
var is_selected: bool = false
var current_value: int = 0
var settle_timer: float = 0.0
var settle_threshold: float = 0.5  # Sekundy bez pohybu = zastaveno

# Vizuální feedback - prstenec
var selection_ring: MeshInstance3D = null  # Reference na prstenec

# Definice stran kostky (normálové vektory v local space)
var face_normals = {
	1: Vector3.DOWN,
	2: Vector3.LEFT,
	3: Vector3.BACK,
	4: Vector3.FORWARD,
	5: Vector3.RIGHT,
	6: Vector3.UP
}

func _ready():
	# Nastavení fyziky pro realistické chování
	contact_monitor = true
	max_contacts_reported = 4
	
	# Fyzikální vlastnosti
	mass = 0.015  # Lehká kostka (15g)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.6  # Tření
	physics_material_override.bounce = 0.3  # Trochu poskakování
	
	linear_damp = 1.5  # Rychlejší zpomalení lineárního pohybu
	angular_damp = 2.0  # Rychlejší zpomalení rotace
	
	# Najdi prstenec vytvořený v editoru
	if has_node("SelectionRing"):
		selection_ring = $SelectionRing
		selection_ring.visible = false
	else:
		# Pokud neexistuje, vytvoř ho programově
		create_selection_ring()

func hide_in_cup():
	"""Skryj kostku (je v kelímku)"""
	visible = false
	freeze = true

func show_and_activate():
	"""Zobraz kostku a aktivuj fyziku"""
	visible = true
	freeze = false

func create_selection_ring():
	"""Vytvoř zlatý prstenec pod kostkou"""
	selection_ring = MeshInstance3D.new()
	selection_ring.name = "SelectionRing"
	
	# Vytvoř torus mesh (prstenec)
	var torus = TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.5
	torus.rings = 32
	torus.ring_segments = 8
	
	selection_ring.mesh = torus
	
	# Materiál - zlatý svítící
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0, 0.9)  # Zlatá
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.84, 0.0, 0.5)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	selection_ring.material_override = mat
	
	# Pozice a rotace
	selection_ring.position = Vector3(0, -0.6, 0)  # Pod kostkou
	selection_ring.rotation_degrees = Vector3(90, 0, 0)  # Horizontálně
	
	selection_ring.visible = false
	
	add_child(selection_ring)
	print("✨ Prstenec vytvořen automaticky")

func _physics_process(delta):
	if is_rolling:
		# Kontrola, zda se kostka zastavila
		var velocity = linear_velocity.length() + angular_velocity.length()
		
		if velocity < 0.1:  # Téměř žádný pohyb
			settle_timer += delta
			if settle_timer >= settle_threshold:
				stop_rolling()
		else:
			settle_timer = 0.0
	
	# Udržuj prstenec vždy horizontální (i když se kostka točí)
	if selection_ring and selection_ring.visible:
		selection_ring.global_rotation = Vector3(deg_to_rad(90), 0, 0)
	
func roll(impulse_strength: float = 3.0):
	"""Hoď kostkou s náhodným impulzem - realisticky"""
	is_rolling = true
	settle_timer = 0.0
	dice_rolling.emit()
	
	# Reset rychlostí
	angular_velocity = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	
	# Náhodná počáteční rotace pro větší variabilitu
	rotation = Vector3(
		randf_range(0, TAU),
		randf_range(0, TAU),
		randf_range(0, TAU)
	)
	
	# Realistický impulz - více nahoru, méně do stran
	var throw_direction = Vector3(
		randf_range(-0.8, 0.8),   # Trochu do stran
		randf_range(2.5, 4.0),    # Hlavně nahoru
		randf_range(-0.8, 0.8)    # Trochu dopředu/dozadu
	).normalized()
	
	var random_impulse = throw_direction * impulse_strength
	
	# Silná rotace pro realistické kutálení
	var random_torque = Vector3(
		randf_range(-15, 15),
		randf_range(-15, 15),
		randf_range(-15, 15)
	)
	
	# Přidej náhodný malý offset k pozici pro více variability
	var spawn_offset = Vector3(
		randf_range(-0.3, 0.3),
		randf_range(0, 0.5),
		randf_range(-0.3, 0.3)
	)
	position += spawn_offset
	
	apply_central_impulse(random_impulse)
	apply_torque_impulse(random_torque)

func stop_rolling():
	"""Zastav kostku a detekuj hodnotu"""
	is_rolling = false
	
	# Zastav pohyb
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Detekuj, která strana je nahoře
	current_value = get_top_face()
	
	# Ujisti se, že hodnota je 1-6
	if current_value < 1 or current_value > 6:
		current_value = 1  # Fallback
		print("⚠️ Neplatná detekce, nastavuji na 1")
	
	dice_stopped.emit(current_value)
	
	print("Kostka ukázala: ", current_value)

func get_top_face() -> int:
	"""Zjisti, která strana kostky je nahoře"""
	var up_direction = Vector3.UP
	var best_face = 1
	var best_dot = -1.0
	
	# Transform normálových vektorů do world space a najdi nejbližší k UP
	for face_value in face_normals:
		var world_normal = global_transform.basis * face_normals[face_value]
		var dot = world_normal.dot(up_direction)
		
		if dot > best_dot:
			best_dot = dot
			best_face = face_value
	
	# Debug výpis pro testování
	print("Kostka rotace: ", rotation_degrees, " -> Detekovaná hodnota: ", best_face, " (dot: ", best_dot, ")")
	
	# Pokud dot není dostatečně velký, můžeme mít problém
	if best_dot < 0.7:
		print("⚠️ Slabá detekce (dot: ", best_dot, "), možná kostka nestojí stabilně")
	
	return best_face

func get_value() -> int:
	"""Vrať aktuální hodnotu kostky"""
	return current_value

func is_dice_rolling() -> bool:
	"""Kontrola, zda se kostka ještě kutálí"""
	return is_rolling

func set_face(value: int):
	"""Nastav kostku na konkrétní hodnotu (pro testování)"""
	if value < 1 or value > 6:
		push_error("Neplatná hodnota kostky: " + str(value))
		return
	
	# Nastav rotaci podle požadované strany
	match value:
		1:
			rotation = Vector3.ZERO
		2:
			rotation = Vector3(0, 0, -PI/2)
		3:
			rotation = Vector3(PI/2, 0, 0)
		4:
			rotation = Vector3(-PI/2, 0, 0)
		5:
			rotation = Vector3(0, 0, PI/2)
		6:
			rotation = Vector3(PI, 0, 0)
	
	current_value = value

func set_selected(selected: bool) -> void:
	"""Zobraz/skryj prstenec pod kostkou"""
	is_selected = selected
	
	if selection_ring:
		selection_ring.visible = selected
		print("🔔 Prstenec ", "ZOBRAZIT" if selected else "SKRÝT")

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
	"""Detekce kliknutí na kostku"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not is_rolling:
				dice_clicked.emit(self)  # Emitujeme signál při kliknutí
