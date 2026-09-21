class_name CompleteHandInterpretation
extends RefCounted

const STANDARD := "Standard"
const SEVEN_PAIRS := "Seven Pairs"

var hand_type: String
var _groups: Array
var _pair
var _tile_instances: Array

var groups: Array:
	get:
		return _groups.duplicate()

var pair:
	get:
		return _pair

var tile_instances: Array:
	get:
		return _tile_instances.duplicate()

func _init(
	interpretation_hand_type: String,
	interpretation_groups: Array,
	interpretation_pair,
	interpretation_tile_instances: Array,
) -> void:
	hand_type = interpretation_hand_type
	_groups = interpretation_groups.duplicate()
	_pair = interpretation_pair
	_tile_instances = interpretation_tile_instances.duplicate()
