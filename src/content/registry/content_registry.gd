class_name ContentRegistry
extends RefCounted

const ContentValidationIssueScript = preload("res://src/content/validation/content_validation_issue.gd")
const ContentValidationReportScript = preload("res://src/content/validation/content_validation_report.gd")

var _definitions: Dictionary = {}

func register(definition):
	var report = ContentValidationReportScript.new()
	if definition == null:
		report.add_issue(ContentValidationIssueScript.new(
			"invalid_definition",
			"",
			"Cannot register a null ContentDefinition."
		))
		return report

	if _definitions.has(definition.content_id):
		report.add_issue(ContentValidationIssueScript.new(
			"duplicate_id",
			definition.content_id,
			"Content ID is already registered."
		))
		return report

	_definitions[definition.content_id] = definition
	return report

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

	return report
