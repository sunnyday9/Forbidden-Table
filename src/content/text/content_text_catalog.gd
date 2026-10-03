class_name ContentTextCatalog
extends RefCounted

# This imported English Translation resource is canonical Content data.
# Preloading it keeps it in the resource dependency graph for headless and
# exported builds without registering it with Presentation's TranslationServer.
const _ENGLISH_SOURCE: Translation = preload("res://localization/en.en.translation")

static func canonical_text(key: String) -> String:
	if key.is_empty():
		push_error("Localization key must not be empty.")
		return "[MISSING LOCALIZATION KEY]"
	var source := str(_ENGLISH_SOURCE.get_message(key))
	if source.is_empty():
		push_error("Missing English source localization key: %s" % key)
		return "[MISSING %s]" % key
	return source.replace("%%", "%")
