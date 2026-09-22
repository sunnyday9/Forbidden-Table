class_name CommandValidation
extends RefCounted

const VALID := "VALID"
const INVALID := "INVALID"

var valid: bool
var code: String
var message: String
var details: Dictionary

func _init(
	validation_valid: bool,
	validation_code: String = VALID,
	validation_message: String = "",
	validation_details: Dictionary = {},
) -> void:
	valid = validation_valid
	code = validation_code
	message = validation_message
	details = validation_details.duplicate(true)

func is_valid() -> bool:
	return valid

func to_dictionary() -> Dictionary:
	return {
		"valid": valid,
		"code": code,
		"message": message,
		"details": details.duplicate(true),
	}
