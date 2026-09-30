class_name Localization
extends RefCounted

const FORMAT_TOKEN := "%"

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
	return translated

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
	return template % values if not values.is_empty() else template

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
		"CHARACTER_SELECT", "COMPLETE_HAND", "CONTRACT", "CONTRACT_SELECT", "CORE",
		"DEFEAT", "DISCARD", "DRAW", "DRAW_ACTION", "DUPLICATE", "ELITE", "ELITE_REWARD", "EMPTY",
		"END_TURN", "ENTER_EVENT", "ENTER_SHOP", "ENTER_WORKSHOP", "EVENT", "EVENT_OPTION",
		"HAND", "MAP", "MAP_CHOICE", "MAP_NODE", "NONE", "NORMAL", "ONGOING", "PAIR", "PASSIVE",
		"PARTIAL_SETTLEMENT", "PATTERN", "QUAD", "REACTION", "REACTION BEFORE INTENT",
		"REFINEMENT_TOKEN", "REMOVE", "REPLACE_MODIFIER", "RESERVE", "RESERVE_SWAP",
		"REWARD", "REWARD_CHOICE", "RUN_COMPLETE", "RUN_SUMMARY", "SEQUENCE", "SETTLEMENT",
		"SHOP", "SHOP_EXIT", "SHOP_OFFER", "SHOP_REFRESH", "STANDARD", "TECHNIQUE",
		"TRANSFORM", "TRIPLET", "VICTORY", "WORKSHOP", "WORKSHOP_BACK", "WORKSHOP_EXIT",
		"WORKSHOP_SELECT_SERVICE", "WORKSHOP_SELECT_TARGET", "WORKSHOP_SERVICE",
		"ACT_ONE", "ACT_TWO", "ACT TWO", "ACT ONE", "BAMBOO", "CHARACTERS", "DOTS",
		"HONORS", "EAST", "GREEN", "NORTH", "RED", "SEVEN_PAIRS", "SOUTH", "WEST", "WHITE",
		"NORMAL", "REDUCED", "ROUTE-DEPENDENT", "STEADY", "PRESSURE", "POOL_BIAS", "INSUFFICIENT_TP", "UNAVAILABLE",
		"REFINEMENT", "QUIET_CURRENT", "OPEN_LEDGER", "BRITTLE_COMPASS", "LONG_CURRENT",
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
		"ACT_1_BOSS_DEFEATED", "ACT_2_BOSS_DEFEATED", "ACT_2_REACHED", "CHARACTER_CHOSEN",
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
