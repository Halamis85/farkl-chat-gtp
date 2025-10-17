# DebugGameUIStructure.gd - Přidej na Main node
extends Node3D

func _ready():
	print("\n" + "=".repeat(60))
	print("🔍 DEBUG: STRUKTURA GAMEUI")
	print("=".repeat(60))
	
	var game_ui = get_node("GameUI")
	print_node_tree(game_ui, 0)
	
	print("\n" + "=".repeat(60) + "\n")

func print_node_tree(node: Node, depth: int):
	"""Rekurzivně vytiskni celý strom s jmény a typy"""
	var indent = "  ".repeat(depth)
	var node_type = node.get_class()
	
	print(indent + "📍 " + node.name + " (" + node_type + ")")
	
	# Pro Control/Label/Button vypíš více info
	if node is Label:
		print(indent + "   └─ Text: " + node.text)
	if node is Button:
		print(indent + "   └─ Text: " + node.text)
	if node is ProgressBar:
		print(indent + "   └─ Value: " + str(node.value))
	
	# Rekurze pro children
	for child in node.get_children():
		print_node_tree(child, depth + 1)
