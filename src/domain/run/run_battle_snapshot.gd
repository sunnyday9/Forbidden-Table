class_name RunBattleSnapshot
extends RefCounted

var data: Dictionary

func _init(initial_data: Dictionary = {}) -> void:
	data = initial_data.duplicate(true)

func to_dictionary() -> Dictionary:
	return data.duplicate(true)
