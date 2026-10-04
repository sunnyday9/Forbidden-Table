extends RefCounted


static func format(display_tokens: Variant, stage: String) -> String:
	if stage == "COMPLETE":
		return "✓"
	if display_tokens is Array and not display_tokens.is_empty():
		var value := str(display_tokens.back())
		if value.contains("/"):
			return value
	return "0"
