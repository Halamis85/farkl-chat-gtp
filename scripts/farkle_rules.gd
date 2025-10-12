extends Node

class_name FarkleRules

# Bodování v Farkle
const SCORING = {
	"single_1": 100,
	"single_5": 50,
	"three_of_kind_1": 1000,
	"three_of_kind": 100,  # × hodnota (např. 3× dvojky = 200)
	"four_of_kind": 1000,
	"five_of_kind": 2000,
	"six_of_kind": 3000,
	"straight": 1500,  # 1,2,3,4,5,6
	"three_pairs": 1500,
	"four_and_pair": 1500,
	"two_triplets": 2500
}

static func evaluate_dice(values: Array) -> Dictionary:
	"""
	Vyhodnoť hod kostek a vrať informace o bodech.
	Vrací: {
		"total_score": int,
		"scoring_combinations": Array,
		"is_farkle": bool,
		"available_dice": Array (indexy kostek, které bodují)
	}
	"""
	var result = {
		"total_score": 0,
		"scoring_combinations": [],
		"is_farkle": true,
		"available_dice": []
	}
	
	if values.is_empty():
		return result
	
	# Spočítej výskyty každé hodnoty
	var counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}
	
	for val in values:
		if val >= 1 and val <= 6:
			counts[val] += 1
	
	# Kontrola speciálních kombinací
	
	# 1. Straight (1,2,3,4,5,6)
	if is_straight(counts):
		result.total_score = SCORING.straight
		result.scoring_combinations.append("Postupka (1-6)")
		result.is_farkle = false
		result.available_dice = range(values.size())
		return result
	
	# 2. Three pairs
	var pairs = count_pairs(counts)
	if pairs == 3:
		result.total_score = SCORING.three_pairs
		result.scoring_combinations.append("Tři páry")
		result.is_farkle = false
		result.available_dice = range(values.size())
		return result
	
	# 3. Two triplets
	var triplets = count_triplets(counts)
	if triplets == 2:
		result.total_score = SCORING.two_triplets
		result.scoring_combinations.append("Dva triplety")
		result.is_farkle = false
		result.available_dice = range(values.size())
		return result
	
	# 4. Four of a kind + pair
	if has_four_and_pair(counts):
		result.total_score = SCORING.four_and_pair
		result.scoring_combinations.append("Čtyřka + pár")
		result.is_farkle = false
		result.available_dice = range(values.size())
		return result
	
	# Standardní bodování
	var used_dice = []
	
	for value in counts:
		var count = counts[value]
		
		# Six of a kind
		if count == 6:
			result.total_score += SCORING.six_of_kind
			result.scoring_combinations.append("6× " + str(value))
			used_dice.append_array(get_indices_of_value(values, value))
			result.is_farkle = false
		
		# Five of a kind
		elif count == 5:
			result.total_score += SCORING.five_of_kind
			result.scoring_combinations.append("5× " + str(value))
			used_dice.append_array(get_indices_of_value(values, value))
			result.is_farkle = false
		
		# Four of a kind
		elif count == 4:
			result.total_score += SCORING.four_of_kind
			result.scoring_combinations.append("4× " + str(value))
			used_dice.append_array(get_indices_of_value(values, value))
			result.is_farkle = false
		
		# Three of a kind
		elif count >= 3:
			if value == 1:
				result.total_score += SCORING.three_of_kind_1
			else:
				result.total_score += value * SCORING.three_of_kind
			result.scoring_combinations.append("3× " + str(value))
			
			# Přidej jen 3 kostky
			var indices = get_indices_of_value(values, value)
			for i in range(min(3, indices.size())):
				used_dice.append(indices[i])
			result.is_farkle = false
			
			# Zbylé 1 nebo 5 se počítají samostatně
			var remaining = count - 3
			if value == 1 and remaining > 0:
				result.total_score += remaining * SCORING.single_1
				for i in range(3, min(count, indices.size())):
					used_dice.append(indices[i])
			elif value == 5 and remaining > 0:
				result.total_score += remaining * SCORING.single_5
				for i in range(3, min(count, indices.size())):
					used_dice.append(indices[i])
		
		# Single 1s
		elif value == 1 and count > 0:
			result.total_score += count * SCORING.single_1
			result.scoring_combinations.append(str(count) + "× jednička")
			used_dice.append_array(get_indices_of_value(values, value))
			result.is_farkle = false
		
		# Single 5s
		elif value == 5 and count > 0:
			result.total_score += count * SCORING.single_5
			result.scoring_combinations.append(str(count) + "× pětka")
			used_dice.append_array(get_indices_of_value(values, value))
			result.is_farkle = false
	
	result.available_dice = used_dice
	return result

static func is_straight(counts: Dictionary) -> bool:
	for i in range(1, 7):
		if counts[i] != 1:
			return false
	return true

static func count_pairs(counts: Dictionary) -> int:
	var pairs = 0
	for value in counts:
		if counts[value] == 2:
			pairs += 1
	return pairs

static func count_triplets(counts: Dictionary) -> int:
	var triplets = 0
	for value in counts:
		if counts[value] == 3:
			triplets += 1
	return triplets

static func has_four_and_pair(counts: Dictionary) -> bool:
	var has_four = false
	var has_pair = false
	
	for value in counts:
		if counts[value] == 4:
			has_four = true
		elif counts[value] == 2:
			has_pair = true
	
	return has_four and has_pair

static func get_indices_of_value(values: Array, target: int) -> Array:
	var indices = []
	for i in range(values.size()):
		if values[i] == target:
			indices.append(i)
	return indices
