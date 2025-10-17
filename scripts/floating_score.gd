# FloatingScore.gd - 3D skóre, které se pohybuje a mizí na stole
extends Node3D

var label_3d: Label3D
var start_position: Vector3
var start_time: float = 0.0
var is_positive: bool = true
var text_color: Color = Color.YELLOW
var text_size: float = 4.0  # Větší default

var float_speed: float = 2.0
var rise_height: float = 3.0
var duration: float = 2.0

func _ready():
	print("\n🎯 FloatingScore._ready()")
	
	# Vytvoř 3D label
	label_3d = Label3D.new()
	add_child(label_3d)
	label_3d.text = "+100"
	label_3d.font_size = int(text_size * 10)
	label_3d.outline_size = 3
	label_3d.modulate = text_color
	
	# Zajistí aby byl viditelný
	label_3d.pixel_size = 0.05  # Důležité pro viditelnost!
	# Billboard mode se nastaví automaticky
	
	await get_tree().process_frame  # Počkej 1 frame
	
	print("  Text: " + label_3d.text)
	print("  Font size: " + str(label_3d.font_size))
	print("  Barva: " + str(text_color))
	print("  Pozice: " + str(global_position))
	
	start_position = global_position
	start_time = Time.get_ticks_msec() / 1000.0

func set_score_text(points: int, is_pos: bool = true, color: Color = Color.YELLOW):
	"""Nastav text skóre"""
	is_positive = is_pos
	text_color = color
	label_3d.text = ("+" if is_pos else "-") + str(points)
	label_3d.modulate = color
	print("  → Text nastaven: " + label_3d.text)

func set_text_size(size: float):
	"""Nastav velikost textu"""
	text_size = size
	if label_3d:
		label_3d.font_size = int(size * 10)
		print("  → Font size nastaven: " + str(label_3d.font_size))

func set_duration(new_duration: float):
	"""Nastav jak dlouho bude vidět (v sekundách)"""
	duration = new_duration
	print("  → Doba zobrazení: " + str(duration) + "s")

func set_rise_height(new_height: float):
	"""Nastav jak vysoko se bude zvedat"""
	rise_height = new_height
	print("  → Výška zdvihu: " + str(rise_height))

func _process(_delta):
	if not label_3d:
		return
	
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	var progress = min(elapsed / duration, 1.0)
	
	# Pohyb nahoru
	var new_y = start_position.y + (rise_height * progress)
	global_position.y = new_y
	
	# Fade out
	var alpha = 1.0 - progress
	var color = label_3d.modulate
	color.a = alpha
	label_3d.modulate = color
	
	# Scale down
	scale = Vector3.ONE * (1.0 - progress * 0.5)
	
	# Debug - prvních 5 framů
	if progress < 0.1:
		print("  🎯 FloatingScore se pohybuje: Y=" + str(global_position.y) + ", alpha=" + str(alpha))
	
	if progress >= 1.0:
		print("  → FloatingScore zničen (timeout)")
		queue_free()
