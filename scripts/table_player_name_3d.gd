# TablePlayerName.gd - 3D jméno hráče s vlastním fontem a barvou
extends Node3D

@onready var game_manager = get_node("/root/Main/GameManager")

# NASTAVITELNÉ VLASTNOSTI - změň v inspektoru!
@export var text_color: Color = Color.WHITE
@export var text_size: int = 48
@export var outline_size: int = 3
@export var outline_color: Color = Color.BLACK
@export var custom_font: Font = null
@export var position_x: float = 0.0
@export var position_y: float = 1.5
@export var position_z: float = -3.0
@export var rotation_x_deg: float = -30.0

var text_label: Label3D

func _ready():
	# Vytvoř Label3D
	text_label = Label3D.new()
	add_child(text_label)
	text_label.text = "Hráč 1"
	text_label.font_size = text_size
	text_label.modulate = text_color
	text_label.outline_size = outline_size
	
	# Přidej vlastní font
	if custom_font:
		text_label.font = custom_font
	
	# Nastav pozici
	text_label.global_position = Vector3(position_x, position_y, position_z)
	text_label.rotation.x = deg_to_rad(rotation_x_deg)
	
	# Připoj signál
	if game_manager:
		game_manager.turn_started.connect(_on_turn_started)

func _on_turn_started(_player_id: int):
	if not text_label or not game_manager:
		return
	
	var player_name = game_manager.get_current_player_name()
	text_label.text = player_name
	animate_name_change()

func animate_name_change():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(text_label, "scale", Vector3(1.2, 1.2, 1.2), 0.2)
	tween.tween_property(text_label, "modulate", Color.YELLOW, 0.2)
	
	await tween.finished
	
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(text_label, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
	tween.tween_property(text_label, "modulate", text_color, 0.15)
