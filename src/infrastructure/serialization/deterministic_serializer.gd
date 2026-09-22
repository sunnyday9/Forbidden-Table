class_name DeterministicSerializer
extends RefCounted

static func serialize(value) -> String:
	return JSON.stringify(_canonicalize(value))

static func hash(value) -> String:
	var hashing_context := HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(serialize(value).to_utf8_buffer())
	return hashing_context.finish().hex_encode()

static func command_dictionary(command_data: Dictionary) -> Dictionary:
	var result := {}
	var identity_fields := ["command_id", "command_type", "actor_id", "target_id", "preview"]
	for field in identity_fields:
		if command_data.has(field):
			result[field] = _canonicalize(command_data[field])

	var payload_keys: Array[String] = []
	for key in command_data.keys():
		if not identity_fields.has(str(key)):
			payload_keys.append(str(key))
	payload_keys.sort()
	for key in payload_keys:
		result[key] = _canonicalize(command_data[key])
	return result

static func serialize_command(command_data: Dictionary) -> String:
	return JSON.stringify(_canonicalize(command_dictionary(command_data)))

static func _canonicalize(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array[String] = []
			for key in value.keys():
				keys.append(str(key))
			keys.sort()
			var result := {}
			for key in keys:
				result[key] = _canonicalize(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_canonicalize(item))
			return result
		TYPE_OBJECT:
			if value != null and value.has_method("to_dictionary"):
				return _canonicalize(value.to_dictionary())
	return value
