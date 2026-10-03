class_name Localization
extends RefCounted

const ContentTextCatalogScript = preload("res://src/content/text/content_text_catalog.gd")

const FORMAT_TOKEN := "%"

static var _english_translation: Translation
static var _source_key_by_english: Dictionary = {}
static var _source_key_index_loaded := false
static var _feedback_key_by_exact_text: Dictionary = {}
static var _feedback_key_index_loaded := false

static func text(key: String) -> String:
	if key.is_empty():
		push_error("Localization key must not be empty.")
		return "[MISSING LOCALIZATION KEY]"
	var translated := str(TranslationServer.translate(key))
	if translated == key:
		push_error("Missing English source localization key: %s" % key)
		return "[MISSING %s]" % key
	if _placeholder_count(translated) > 0 or _has_invalid_format_token(translated):
		push_error("Localization key %s requires arguments; use Localization.format()." % key)
		return "[INVALID FORMAT %s]" % key
	return translated.replace("%%", "%")


static func canonical_text(key: String) -> String:
	return ContentTextCatalogScript.canonical_text(key)


static func display_text(canonical_english: String) -> String:
	# Translate exact English source strings at presentation seams. Unknown or
	# dynamically composed text remains unchanged.
	if canonical_english.is_empty():
		return ""
	_load_source_key_index()
	var key := str(_source_key_by_english.get(canonical_english, ""))
	if key.is_empty():
		return canonical_english
	var translated := str(TranslationServer.translate(key))
	if translated == key:
		return canonical_english
	return translated.replace("%%", "%") if _placeholder_count(translated) == 0 else translated


static func retranslate_exact_text(previously_localized_text: String) -> String:
	# Restore feedback that is an exact catalog value. Formatted warnings and
	# dynamic text are intentionally returned intact when no exact key matches.
	if previously_localized_text.is_empty():
		return ""
	_load_feedback_key_index()
	var key := str(_feedback_key_by_exact_text.get(previously_localized_text, ""))
	if key.is_empty():
		return previously_localized_text
	var translated := str(TranslationServer.translate(key))
	if translated == key:
		return previously_localized_text
	return translated.replace("%%", "%") if _placeholder_count(translated) == 0 else translated


static func _load_source_key_index() -> void:
	if _source_key_index_loaded:
		return
	_source_key_index_loaded = true
	if _english_translation == null:
		_english_translation = TranslationServer.get_translation_object("en") as Translation
	if _english_translation == null:
		push_error("English source translation is unavailable.")
		return
	for raw_key in _english_translation.get_message_list():
		var key := str(raw_key)
		var source := str(_english_translation.get_message(key))
		if key.is_empty() or source.is_empty():
			continue
		var current_key := str(_source_key_by_english.get(source, ""))
		if current_key.is_empty() or _source_key_priority(key) < _source_key_priority(current_key):
			_source_key_by_english[source] = key


static func _load_feedback_key_index() -> void:
	if _feedback_key_index_loaded:
		return
	_feedback_key_index_loaded = true
	for locale in ["en", "zh_CN"]:
		var translation := TranslationServer.get_translation_object(locale) as Translation
		if translation == null:
			push_error("Feedback translation resource is unavailable: %s" % locale)
			continue
		for raw_key in translation.get_message_list():
			var key := str(raw_key)
			var value := str(translation.get_message(key))
			if key.is_empty() or value.is_empty():
				continue
			var current_key := str(_feedback_key_by_exact_text.get(value, ""))
			if current_key.is_empty() or _feedback_key_priority(key) < _feedback_key_priority(current_key):
				_feedback_key_by_exact_text[value] = key


static func _source_key_priority(key: String) -> int:
	# Domain-backed content identities win over generic words and UI phrasing.
	# This makes duplicate English source strings resolve consistently to their
	# authored content translation while keeping the reverse map deterministic.
	if key.begins_with("base.character.") or key.begins_with("base.passive."):
		return 0
	if key.begins_with("alpha.") or key.begins_with("base."):
		return 1
	if key.begins_with("CONTENT_"):
		return 2
	if key.begins_with("WORD_"):
		return 3
	if key.begins_with("UI_"):
		return 4
	return 5


static func _feedback_key_priority(key: String) -> int:
	if key.begins_with("UI_RUN_CONTROLLER_"):
		return 0
	if key.begins_with("UI_"):
		return 1
	if key.begins_with("CONTENT_"):
		return 2
	if key.begins_with("WORD_"):
		return 3
	return 4

static func format(key: String, values: Array) -> String:
	if key.is_empty():
		push_error("Localization key must not be empty.")
		return "[MISSING LOCALIZATION KEY]"
	var template := str(TranslationServer.translate(key))
	if template == key:
		push_error("Missing English source localization key: %s" % key)
		return "[MISSING %s]" % key
	if _has_invalid_format_token(template):
		push_error("Invalid format token in localization key: %s" % key)
		return "[INVALID FORMAT %s]" % key
	if _placeholder_count(template) != values.size():
		push_error("Localization key %s has unresolved interpolation values." % key)
		return "[UNRESOLVED %s]" % key
	return template % values if not values.is_empty() else template.replace("%%", "%")

static func template(key: String) -> String:
	if key.is_empty():
		push_error("Localization key must not be empty.")
		return "[MISSING LOCALIZATION KEY]"
	var translated := str(TranslationServer.translate(key))
	if translated == key:
		push_error("Missing English source localization key: %s" % key)
		return "[MISSING %s]" % key
	if _has_invalid_format_token(translated):
		push_error("Invalid format token in localization key: %s" % key)
		return "[INVALID FORMAT %s]" % key
	return translated

static func content_text(content_id: String) -> String:
	return text(content_id)

static func word_text(word_key: String) -> String:
	if word_key.strip_edges().is_empty():
		return ""
	var normalized := word_key.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	return text("WORD_" + normalized)

static func reaction_reason_text(reason_code: String) -> String:
	if reason_code == "INSUFFICIENT_TP":
		return word_text(reason_code)
	return word_text("UNAVAILABLE")

static func required_word_values() -> PackedStringArray:
	# These are the finite identifier values that Stage 4 presents as labels.
	# Keep this inventory beside the keyed source so adding a new enum/data value
	# without an English source key fails localization validation.
	return PackedStringArray([
		"ACTION", "ACTIVE", "ADD_MODIFIER", "BATTLE", "BATTLE_ACTION", "BATTLE_DEFEAT", "BOSS", "BOSS_DEFEATED", "BOSS_REWARD", "CHARACTER",
		"CHARACTER_SELECT", "COMPLETE_HAND", "CONTRACT", "CONTRACT_SELECT", "COPY_LICENSE", "CORE",
		"DEFEAT", "DISCARD", "DRAW", "DRAW_ACTION", "DUPLICATE", "ELITE", "ELITE_REWARD", "EMPTY",
		"END_TURN", "ENTER_EVENT", "ENTER_SHOP", "ENTER_WORKSHOP", "EVENT", "EVENT_OPTION",
		"GOLD_CACHE", "HAND", "MAP", "MAP_CHOICE", "MAP_NODE", "NONE", "NORMAL", "ONGOING", "PAIR", "PASSIVE",
		"PARTIAL_SETTLEMENT", "PATTERN", "QUAD", "REACTION", "REACTION BEFORE INTENT",
		"REFINEMENT_TOKEN", "REMOVE", "REPLACE_MODIFIER", "RESERVE", "RESERVE_SWAP",
		"REWARD", "REWARD_CHOICE", "RUN_COMPLETE", "RUN_SUMMARY", "SEQUENCE", "SETTLEMENT", "SKIP",
		"SHOP", "SHOP_EXIT", "SHOP_OFFER", "SHOP_REFRESH", "STANDARD", "TECHNIQUE",
		"TRANSFORM", "TRIPLET", "VICTORY", "WORKSHOP", "WORKSHOP_BACK", "WORKSHOP_EXIT",
		"WORKSHOP_SELECT_SERVICE", "WORKSHOP_SELECT_TARGET", "WORKSHOP_SERVICE",
		"ACT_ONE", "ACT_TWO", "ACT TWO", "ACT ONE", "BAMBOO", "CHARACTERS", "DOTS",
		"HONORS", "EAST", "GREEN", "NORTH", "RED", "SEVEN_PAIRS", "SOUTH", "WEST", "WHITE",
		"NORMAL", "REDUCED", "ROUTE-DEPENDENT", "STEADY", "PRESSURE", "POOL_BIAS", "INSUFFICIENT_TP", "UNAVAILABLE",
		"REFINEMENT", "RITUAL_SALVE", "QUIET_CURRENT", "OPEN_LEDGER", "BRITTLE_COMPASS", "LONG_CURRENT",
		"HOUSE_TITHE", "YAKU_SIGNAL", "YAKU", "VISIBLE", "TRUE", "FALSE",
		"RUN MODIFIER", "RISK", "REWARD", "BUILD BIAS", "PRESSURE_PER_BATTLE",
		"INITIAL_PRESSURE_PER_BATTLE", "NORMAL_REWARD_OFF_SUIT_CHOICE_CAP", "ELITE_SKIP_GOLD_PENALTY",
		"WORKSHOP_REFINEMENT_GOLD_SURCHARGE", "OFF_SUIT_POOL_WEIGHT", "COMPOSITION_COST",
		"GOLD", "ROUTE_COST", "STARTING_TP_PER_BATTLE", "REFINEMENT_TOKENS_ON_ELITE_SKIP",
		"REWARD_TILE_SUIT_BIAS", "TP", "TEMPO", "STARTING_BIAS", "REFINEMENT_TOKENS",
		"MAP_OPPORTUNITY", "REFINEMENT_TOKENS_ON_CONTRACT_SELECTION", "EXTRA_MODIFIED_TILE_CHOICE",
		"PATH", "FLEXIBILITY", "PREFERRED_TILE_IDS", "YAKU_SIGNAL_SUMMARY",
		"TILE_SURGERY", "RISK_BARGAIN", "GOLD_EXCHANGE", "MAP_REVEAL", "CONTRACT_CLAUSE",
		"RULE_MEMORY", "TILE_SURGERY_SEALED_ENTRY", "SHADOW_ACCOUNT", "LONG_MARGIN",
		"FINAL_ANNOTATION", "AMENDED_CLAUSE", "CROSS_REFERENCE",
		"ACCEPT", "CARRY_CLAUSE", "EXCHANGE", "FAVORABLE_ENTRY", "LEAVE", "MISREAD_ENTRY",
		"MISSED_PAYMENT", "PAID_ON_TIME", "REMEMBER", "REMEMBER_RULE", "REPAIR_WITH_TOKEN",
		"REVEAL", "REVEAL_ROUTE", "SPEND_TOKEN", "STAKE_HIDDEN_ACCOUNT", "STUDY_YAKU",
		"TAKE_ADVANCE", "TAKE_WAGER", "TRADE_GOLD", "TRADE_MARGIN",
		"ACT_1_BOSS_DEFEATED", "ACT_2_BOSS_DEFEATED", "ACT_2_REACHED", "CHARACTER_CHOSEN", "WORKSHOP_COUPON",
		"CONTRACT_CHOSEN", "FIRST_COMPLETE_HAND", "FIRST_RULE_BREAKER_ACQUIRED",
	])

static func _format_tokens(value: String) -> Array[String]:
	var pattern := RegEx.new()
	pattern.compile("%(?:[0-9]+\\$)?[sdif]")
	var tokens: Array[String] = []
	for matched in pattern.search_all(value.replace("%%", "")):
		tokens.append(matched.get_string())
	return tokens

static func _placeholder_count(value: String) -> int:
	return _format_tokens(value).size()

static func _has_invalid_format_token(value: String) -> bool:
	var remaining := value.replace("%%", "")
	var pattern := RegEx.new()
	pattern.compile("%(?:[0-9]+\\$)?[sdif]")
	remaining = pattern.sub(remaining, "", true)
	return FORMAT_TOKEN in remaining
