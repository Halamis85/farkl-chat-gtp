extends Node3D
#dice_efekt
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

func play_score_effect(world_position: Vector3):
	"""Vizuální efekt při zabanování kostek"""
	if not is_inside_tree():
		print("⚠️ Effects manager není ve stromu!")
		return
	
	# Vytvoř flash efekt
	create_flash_effect(world_position)
	
	# Můžeš přidat další efekty (částice, atd.)
	print("✨ Score efekt na pozici: ", world_position)

func create_flash_effect(world_position: Vector3):
	"""Vytvoř flash světlo na dané pozici - OPRAVENÁ VERZE"""
	if not is_inside_tree():
		print("⚠️ Nelze vytvořit flash - node není ve stromu")
		return
	
	# Vytvoř světlo
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.3)  # Zlatá barva
	flash.light_energy = 3.0
	flash.omni_range = 3.0
	
	# ⚠️ KLÍČOVÁ OPRAVA - NEJDŘÍV přidej do stromu
	add_child(flash)
	
	# ⚠️ TEĎ TEPRVE nastav globální pozici (node je ve stromu)
	flash.global_position = world_position
	
	# Fade out efekt
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.5)
	await tween.finished
	
	# Cleanup
	if flash and is_instance_valid(flash):
		flash.queue_free()
	
	print("💡 Flash efekt vytvořen na ", world_position)

func create_selection_highlight(_dice_position: Vector3):
	"""Highlight efekt při výběru kostky"""
	# Můžeme zde přidat další vizuální feedback
	pass

func animate_score_popup(popup_position: Vector3, score: int):
	"""Animovaný popup s body"""
	# Toto by vyžadovalo 3D text nebo sprite
	# Pro jednoduchost to přeskočíme, ale zde by byl kód
	print("💯 +", score, " bodů na pozici ", popup_position)
