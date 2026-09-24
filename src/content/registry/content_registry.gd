class_name ContentRegistry
extends RefCounted

const ContentValidationIssueScript = preload("res://src/content/validation/content_validation_issue.gd")
const ContentValidationReportScript = preload("res://src/content/validation/content_validation_report.gd")
const ContentDefinitionScript = preload("res://src/content/definitions/content_definition.gd")
const CONTENT_VERSION := "content.slice.v2"

var _definitions: Dictionary = {}

func register(definition):
	var report = ContentValidationReportScript.new()
	if definition == null or not definition is ContentDefinitionScript:
		report.add_issue(ContentValidationIssueScript.new(
			"invalid_definition",
			"",
			"Cannot register a value that is not a ContentDefinition."
		))
		return report

	if _definitions.has(definition.content_id):
		report.add_issue(ContentValidationIssueScript.new(
			"duplicate_id",
			definition.content_id,
			"Content ID is already registered."
		))
		return report
	var definition_report = definition.validate()
	if not definition_report.is_valid():
		return definition_report

	_definitions[definition.content_id] = definition
	return report

func content_version() -> String:
	return CONTENT_VERSION

func resolve(definition_id: String):
	return _definitions.get(definition_id)

func enumerate() -> Array:
	var definitions: Array = []
	var definition_ids: Array = _definitions.keys()
	definition_ids.sort()
	for definition_id in definition_ids:
		definitions.append(_definitions[definition_id])
	return definitions

func validate():
	var report = ContentValidationReportScript.new()
	var definition_ids: Array = _definitions.keys()
	definition_ids.sort()

	for definition_id in definition_ids:
		var definition = _definitions[definition_id]
		var definition_report = definition.validate()
		for issue in definition_report.issues:
			report.add_issue(issue)

		for reference_id in definition.referenced_content_ids:
			if not _definitions.has(reference_id):
				report.add_issue(ContentValidationIssueScript.new(
					"missing_reference",
					definition.content_id,
					"Definition references an unregistered Content ID.",
					reference_id
				))

		for requirement in definition.reference_requirements():
			var reference_id: String = requirement.get("reference_id", "")
			if reference_id.is_empty() or not _definitions.has(reference_id):
				continue
			var expected_types: Array = requirement.get("expected_types", [])
			if expected_types.is_empty():
				continue
			var referenced_definition = _definitions[reference_id]
			if referenced_definition.definition_type_name() not in expected_types:
				report.add_issue(ContentValidationIssueScript.new(
					"invalid_reference_type",
					definition.content_id,
					"Definition reference has the wrong typed content definition.",
					reference_id
				))

	return report
