extends "res://src/content/registry/content_registry.gd"

const EnemyDefinitionScript = preload("res://src/content/definitions/enemy_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")

# Test-only overrides shorten encounters and let the UI script resolve them through Core Technique buttons; the production RunDomain and map stay unchanged.
func register_bundle(bundle_id: String, bundle_version: String, definitions: Array):
	for definition in definitions:
		if definition is EnemyDefinitionScript:
			definition.max_hp = 1
			definition.battle_values["pressure_limit"] = 1000
			for phase in definition.boss_phases:
				if phase is Dictionary:
					phase["max_hp"] = 1
					phase["pressure_limit"] = 1000
		elif definition is TechniqueDefinitionScript and definition.technique_kind == TechniqueDefinitionScript.CORE:
			definition.effects = [Phase2CatalogScript.typed_effect("test.stage4.%s" % definition.content_id, "DealDamage", 1)]
	return super.register_bundle(bundle_id, bundle_version, definitions)
