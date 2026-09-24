class_name JsonIntegerCodec
extends RefCounted

const INTEGER_MARKER := "__FORBIDDEN_TABLE_JSON_INTEGER__"
const INT64_MAX_MAGNITUDE := "9223372036854775807"
const INT64_MIN_MAGNITUDE := "9223372036854775808"

static func parse(json_text: String) -> Dictionary:
	var marker := INTEGER_MARKER
	var marker_check_parser := JSON.new()
	if marker_check_parser.parse(json_text) == OK:
		while _has_string_prefix(marker_check_parser.data, marker):
			marker = "_" + marker
	while json_text.contains(marker):
		marker = "_" + marker
	var protected_text := _quote_integer_tokens(json_text, marker)
	var parser := JSON.new()
	var parse_error: Error = parser.parse(protected_text)
	if parse_error != OK:
		return {"accepted": false, "code": "PARSE_FAILED", "message": parser.get_error_message()}
	var errors: Array[String] = []
	var data = _restore_integer_tokens(parser.data, marker, errors)
	if not errors.is_empty():
		return {"accepted": false, "code": "JSON_INTEGER_OUT_OF_RANGE", "errors": errors}
	return {"accepted": true, "data": data}

static func _has_string_prefix(value, marker: String) -> bool:
	if value is String:
		return value.begins_with(marker)
	if value is Dictionary:
		for key in value:
			if _has_string_prefix(value[key], marker):
				return true
		return false
	if value is Array:
		for item in value:
			if _has_string_prefix(item, marker):
				return true
	return false
static func _quote_integer_tokens(json_text: String, marker: String) -> String:
	var output := ""
	var inside_string := false
	var escaped := false
	var index := 0
	while index < json_text.length():
		var character := json_text.substr(index, 1)
		if inside_string:
			output += character
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				inside_string = false
			index += 1
			continue
		if character == "\"":
			inside_string = true
			output += character
			index += 1
			continue
		if character == "-" or _is_digit(character):
			var start := index
			while index < json_text.length() and _is_json_number_character(json_text.substr(index, 1)):
				index += 1
			var token := json_text.substr(start, index - start)
			if _is_integer_token(token):
				output += JSON.stringify(marker + token)
			else:
				output += token
			continue
		output += character
		index += 1
	return output

static func _restore_integer_tokens(value, marker: String, errors: Array[String]):
	if value is Dictionary:
		var restored: Dictionary = {}
		for key in value.keys():
			restored[key] = _restore_integer_tokens(value[key], marker, errors)
		return restored
	if value is Array:
		var restored: Array = []
		for item in value:
			restored.append(_restore_integer_tokens(item, marker, errors))
		return restored
	if value is String and value.begins_with(marker):
		var token: String = value.substr(marker.length())
		if not _fits_int64(token):
			errors.append(token)
			return null
		return int(token)
	return value

static func _is_json_number_character(character: String) -> bool:
	return character in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "e", "E", "+", "-"]

static func _is_digit(character: String) -> bool:
	return character in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

static func _is_integer_token(token: String) -> bool:
	if token.is_empty():
		return false
	var start := 1 if token.begins_with("-") else 0
	if start == token.length():
		return false
	if token.substr(start, 1) == "0":
		return start + 1 == token.length()
	if token.substr(start, 1) not in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		return false
	for index in range(start + 1, token.length()):
		if not _is_digit(token.substr(index, 1)):
			return false
	return true

static func _fits_int64(token: String) -> bool:
	if not _is_integer_token(token):
		return false
	if token == "-0":
		return true
	var negative := token.begins_with("-")
	var magnitude := token.substr(1) if negative else token
	var limit := INT64_MIN_MAGNITUDE if negative else INT64_MAX_MAGNITUDE
	if magnitude.length() < limit.length():
		return true
	if magnitude.length() > limit.length():
		return false
	return magnitude <= limit
