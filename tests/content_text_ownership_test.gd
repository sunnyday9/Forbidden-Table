class_name ContentTextOwnershipTest
extends RefCounted

const Localization = preload("res://src/presentation/localization/localization.gd")
const ContentTextCatalogScript = preload("res://src/content/text/content_text_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var original_locale := TranslationServer.get_locale()
	var registered_translations: Array = TranslationServer.get_translations().duplicate()
	for translation in registered_translations:
		TranslationServer.remove_translation(translation)

	_assert(
		TranslationServer.get_translations().is_empty(),
		"the no-translation case removes all registered translations",
		failures,
	)
	_assert(
		ContentTextCatalogScript.canonical_text("CONTENT_TECHNIQUE_0005") == "enemy Contamination is added",
		"canonical Content text remains available without TranslationServer resources",
		failures,
	)
	_assert(
		ContentTextCatalogScript.canonical_text("UI_PREFS_SCALE_125") == "125%",
		"canonical Content lookup preserves escaped-percent fidelity",
		failures,
	)
	_assert(
		Localization.canonical_text("CONTENT_TECHNIQUE_0005") == "enemy Contamination is added",
		"Presentation canonical_text delegates to the Content source lookup",
		failures,
	)
	var invalid_technique := TechniqueDefinitionScript.new("base.technique.invalid_kind", "UNSUPPORTED")
	var invalid_report = invalid_technique.validate()
	_assert(
		invalid_report.issues.size() == 1
			and invalid_report.issues[0].message == "TechniqueDefinition must declare a supported kind.",
		"Technique validation diagnostics use stable English source text without TranslationServer resources",
		failures,
	)
	_assert(
		TechniqueDefinitionScript.reaction_trigger_label(TechniqueDefinitionScript.REACTION_ENEMY_CONTAMINATION_ADDED)
			== "enemy Contamination is added",
		"Technique reaction labels remain stable without TranslationServer resources",
		failures,
	)

	var registry = ContentRegistryScript.new()
	var phase2_registration = Phase2CatalogScript.register_all(registry)
	var act_two_registration = AlphaActTwoCatalogScript.register_all(registry)
	var scale_registration = AlphaScaleCatalogScript.register_all(registry)
	_assert(
		phase2_registration.is_valid() and act_two_registration.is_valid() and scale_registration.is_valid(),
		"Phase 2, Act 2, and Scale catalogs register without TranslationServer resources",
		failures,
	)
	_assert(
		registry.validate().is_valid(),
		"the combined content catalogs validate without TranslationServer resources",
		failures,
	)
	var prototype_yaku = registry.resolve("prototype.yaku.sequence_path")
	_assert(
		prototype_yaku != null
			and prototype_yaku.display_name == ContentTextCatalogScript.canonical_text("CONTENT_YAKU_0001"),
		"YakuCatalog definitions use canonical Content-owned source text",
		failures,
	)
	var phase2_yaku = registry.resolve("base.yaku.pair_foundation")
	_assert(
		phase2_yaku != null
			and phase2_yaku.display_name == ContentTextCatalogScript.canonical_text("CONTENT_PHASE2_0001"),
		"Phase 2 catalog labels use canonical Content-owned source text",
		failures,
	)
	var scale_yaku = registry.resolve(AlphaScaleCatalogScript.YAKU_IDS[0])
	_assert(
		scale_yaku != null
			and scale_yaku.display_name == ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0047"),
		"Scale catalog labels use canonical Content-owned source text",
		failures,
	)
	var act_two_enemy = registry.resolve(AlphaActTwoCatalogScript.ACT_TWO_NORMAL_ENEMY_IDS[0])
	var act_two_intent = act_two_enemy.intent_graph.intent("act_two.tollkeeper.count") if act_two_enemy != null else null
	_assert(
		act_two_intent != null
			and act_two_intent.display_name == ContentTextCatalogScript.canonical_text("CONTENT_ACT_TWO_0001"),
		"Act 2 catalog labels use canonical Content-owned source text",
		failures,
	)

	for translation in registered_translations:
		TranslationServer.add_translation(translation)
	_assert(
		TranslationServer.get_translations() == registered_translations,
		"the test restores the exact registered Translation resources",
		failures,
	)
	TranslationServer.set_locale("en")
	_assert(
		Localization.canonical_text("CONTENT_TECHNIQUE_0005") == "enemy Contamination is added",
		"canonical Technique text matches its English golden in English locale",
		failures,
	)
	_assert(
		Localization.text("CONTENT_TECHNIQUE_0005") == "enemy Contamination is added",
		"Presentation still resolves active English display copy",
		failures,
	)
	TranslationServer.set_locale("zh_CN")
	_assert(
		Localization.canonical_text("CONTENT_TECHNIQUE_0005") == "enemy Contamination is added",
		"canonical Technique text matches its English golden in Simplified Chinese locale",
		failures,
	)
	_assert(
		Localization.text("CONTENT_TECHNIQUE_0005") == "敌方污染已增加",
		"Presentation still resolves active Simplified Chinese display copy",
		failures,
	)
	_assert(
		Localization.display_text("enemy Contamination is added") == "敌方污染已增加",
		"Presentation translates canonical Content text for active-locale display",
		failures,
	)
	var chinese_validation_report = invalid_technique.validate()
	_assert(
		chinese_validation_report.issues.size() == 1
			and chinese_validation_report.issues[0].message == "TechniqueDefinition must declare a supported kind.",
		"Technique validation diagnostics remain canonical English under Simplified Chinese",
		failures,
	)
	TranslationServer.set_locale(original_locale)
	_assert(
		TranslationServer.get_locale() == original_locale,
		"the test restores the active locale",
		failures,
	)
	return failures

func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
