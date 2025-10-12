extends Node
class_name ScoringRules

# Bodování pro jednotlivé kostky
const SINGLE_ONE = 100
const SINGLE_FIVE = 50

# Funkce pro výpočet skóre z pole kostek
static func calculate_score(dice_values: Array) -> Dictionary:
	var result = {
		"score": 0,
		"scoring_dice": [],  # Indexy kostek které bodují
		"is_farkle": false
	}
	
	if dice_values.is_empty():
		return result
	
	# Spočítej frekvenci každého čísla
	var counts = {}
	for i in range(1, 7):
		counts[i] = 0
	
	for value in dice_values:
		counts[value] += 1
	
	var temp_scoring_dice = []
	var score = 0
	
	# Kontrola speciálních kombinací
	
	# 6 stejných čísel = 3000 bodů
	for num in counts:
		if counts[num] == 6:
			score += 3000
			for i in range(dice_values.size()):
				if dice_values[i] == num:
					temp_scoring_dice.append(i)
			result["score"] = score
			result["scoring_dice"] = temp_scoring_dice
			return result
	
	# 3 páry = 1500 bodů
	var pairs = 0
	for num in counts:
		if counts[num] == 2:
			pairs += 1
	
	if pairs == 3:
		score += 1500
		for i in range(dice_values.size()):
			temp_scoring_dice.append(i)
		result["score"] = score
		result["scoring_dice"] = temp_scoring_dice
		return result
	
	# Postupka 1-6 = 1500 bodů
	var has_straight = true
	for num in range(1, 7):
		if counts[num] != 1:
			has_straight = false
			break
	
	if has_straight:
		score += 1500
		for i in range(dice_values.size()):
			temp_scoring_dice.append(i)
		result["score"] = score
		result["scoring_dice"] = temp_scoring_dice
		return result
	
	# Normální bodování
	for num in counts:
		var count = counts[num]
		
		# Trojice a více
		if count >= 3:
			if num == 1:
				score += 1000 * (count - 2)  # 1000, 2000, 3000
			else:
				score += num * 100 * (count - 2)  # např. trojice 4 = 400, čtyřice = 800
			
			# Označ tyto kostky jako bodující
			var marked = 0
			for i in range(dice_values.size()):
				if dice_values[i] == num and marked < count:
					temp_scoring_dice.append(i)
					marked += 1
		
		# Jednotlivé 1 a 5 (ale ne pokud jsou v trojici)
		elif count < 3:
			if num == 1:
				score += SINGLE_ONE * count
				for i in range(dice_values.size()):
					if dice_values[i] == 1:
						temp_scoring_dice.append(i)
			elif num == 5:
				score += SINGLE_FIVE * count
				for i in range(dice_values.size()):
					if dice_values[i] == 5:
						temp_scoring_dice.append(i)
	
	result["score"] = score
	result["scoring_dice"] = temp_scoring_dice
	result["is_farkle"] = (score == 0)
	
	return result

# Pomocná funkce pro kontrolu platnosti výběru
static func is_valid_selection(dice_values: Array, selected_indices: Array) -> bool:
	if selected_indices.is_empty():
		return false
	
	var selected_values = []
	for idx in selected_indices:
		if idx >= 0 and idx < dice_values.size():
			selected_values.append(dice_values[idx])
	
	var result = calculate_score(selected_values)
	return result["score"] > 0
