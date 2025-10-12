extends Node3D

@onready var dice_manager = $DiceManager

func _ready():
	# Připoj signály
	dice_manager.all_dice_stopped.connect(_on_all_dice_stopped)
	dice_manager.dice_rolling_started.connect(_on_dice_rolling_started)
	
	print("=== FARKLE TESTOVÁNÍ ===")
	print("MEZERNÍK - Hoď všemi kostkami")
	print("R - Reset pozic")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Mezerník
		if not dice_manager.is_rolling:
			print("\n--- NOVÝ HOD ---")
			dice_manager.roll_all_dice()
	
	elif event.is_action_pressed("ui_cancel"):  # ESC
		get_tree().quit()
	
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		dice_manager.reset_positions()
		print("Pozice resetovány")

func _on_dice_rolling_started():
	print("Házím kostkami...")

func _on_all_dice_stopped(values: Array):
	print("\n=== VÝSLEDEK ===")
	print("Hodnoty kostek: ", values)
	
	# Vyhodnoť pomocí Farkle pravidel
	var result = FarkleRules.evaluate_dice(values)
	
	print("\n--- BODOVÁNÍ ---")
	if result.is_farkle:
		print("❌ FARKLE! Žádné body!")
	else:
		print("✓ Celkové body: ", result.total_score)
		print("Kombinace:")
		for combo in result.scoring_combinations:
			print("  - ", combo)
		print("Bodující kostky (indexy): ", result.available_dice)
	print("==================\n")
