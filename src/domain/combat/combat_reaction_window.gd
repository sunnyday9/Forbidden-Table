class_name CombatReactionWindow
extends RefCounted

var window_id: String
var reaction_id: String
var legal_after_lethal: bool
var predeclared: bool

func _init(
	window_identifier: String,
	reaction_identifier: String = "",
	window_legal_after_lethal: bool = false,
	window_predeclared: bool = true,
) -> void:
	window_id = window_identifier
	reaction_id = reaction_identifier if not reaction_identifier.is_empty() else window_identifier
	legal_after_lethal = window_legal_after_lethal
	predeclared = window_predeclared

func can_open_after_lethal() -> bool:
	return legal_after_lethal and predeclared

func to_dictionary() -> Dictionary:
	return {
		"window_id": window_id,
		"reaction_id": reaction_id,
		"legal_after_lethal": legal_after_lethal,
		"predeclared": predeclared,
	}
