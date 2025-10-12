extends Node3D

## Systém pro vizuální efekty při hře v kostky

# Předpřipravené částice
var dust_particles: GPUParticles3D = null
var spark_particles: GPUParticles3D = null

func _ready():
	create_particle_systems()

func create_particle_systems():
	"""Vytvoř částicové systémy pro efekty"""
	
	# Prach při dopadu kostek
	dust_particles = GPUParticles3D.new()
	dust_particles.emitting = false
	dust_particles.one_shot = true
	dust_particles.explosiveness = 0.8
	dust_particles.amount = 20
	dust_particles.lifetime = 0.5
	add_child(dust_particles)
	
	# Jiskry při skórování
	spark_particles = GPUParticles3D.new()
	spark_particles.emitting = false
	spark_particles.one_shot = true
	spark_particles.explosiveness = 1.0
	spark_particles.amount = 30
	spark_particles.lifetime = 0.8
	add_child(spark_particles)

func play_dice_impact_effect(impact_position: Vector3):
	"""Efekt při dopadu kostky na stůl"""
	if dust_particles:
		dust_particles.global_position = impact_position
		dust_particles.restart()
		dust_particles.emitting = true

func play_score_effect(score_position: Vector3):
	"""Efekt při skórování bodů"""
	if spark_particles:
		spark_particles.global_position = score_position
		spark_particles.restart()
		spark_particles.emitting = true
	
	# Můžeme přidat i flash efekt
	create_flash_effect(score_position)

func create_flash_effect(pos: Vector3):
	"""Krátký flash efekt"""
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.9, 0.3)
	flash.light_energy = 3.0
	flash.omni_range = 3.0
	flash.global_position = pos
	get_parent().add_child(flash)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.3)
	await tween.finished
	flash.queue_free()

func create_selection_highlight(dice_position: Vector3):
	"""Highlight efekt při výběru kostky"""
	# Můžeme zde přidat další vizuální feedback
	pass

func animate_score_popup(position: Vector3, score: int):
	"""Animovaný popup s body"""
	# Toto by vyžadovalo 3D text nebo sprite
	# Pro jednoduchost to přeskočíme, ale zde by byl kód
	print("💯 +", score, " bodů na pozici ", position)
