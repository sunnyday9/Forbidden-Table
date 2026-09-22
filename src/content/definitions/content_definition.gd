class_name ContentDefinition
extends Resource

const ContentValidationReportScript = preload("res://src/content/validation/content_validation_report.gd")
const ContentValidationIssueScript = preload("res://src/content/validation/content_validation_issue.gd")

@export var content_id: String
@export var referenced_content_ids: Array[String]

const PRODUCTION_NAMESPACE := "base"
const COMPATIBILITY_NAMESPACE := "prototype"

func _init(definition_id: String = "", references: Array[String] = []) -> void:
	content_id = definition_id
	referenced_content_ids = references.duplicate()

func validate():
	var report = ContentValidationReportScript.new()
	if not _is_namespaced_id(content_id):
		report.add_issue(ContentValidationIssueScript.new(
			"invalid_id",
			content_id,
			"Content ID must use lowercase dot-separated namespaces."
		))
	elif not [PRODUCTION_NAMESPACE, COMPATIBILITY_NAMESPACE].has(content_id.get_slice(".", 0)):
		report.add_issue(ContentValidationIssueScript.new(
			"invalid_namespace",
			content_id,
			"Content ID must use the base or prototype namespace."
		))
	var expected_families := expected_id_families()
	if not expected_families.is_empty() and _content_family() not in expected_families:
		report.add_issue(ContentValidationIssueScript.new(
			"invalid_definition_type",
			content_id,
			"Content ID does not match the typed definition family."
		))
	return report

func definition_type_name() -> String:
	return "ContentDefinition"

func expected_id_families() -> Array[String]:
	return []

func reference_requirements() -> Array[Dictionary]:
	return []

func _content_family() -> String:
	var segments := content_id.split(".")
	return segments[1] if segments.size() > 1 else ""

func _issue(code: String, message: String, reference_id: String = ""):
	return ContentValidationIssueScript.new(code, content_id, message, reference_id)

func _required_string(report, value: String, code: String, field_name: String) -> void:
	if value.is_empty():
		report.add_issue(_issue(code, "%s must not be empty." % field_name))

func _reference_requirement(reference_id: String, expected_types: Array[String], field_name: String) -> Dictionary:
	return {
		"reference_id": reference_id,
		"expected_types": expected_types,
		"field_name": field_name,
	}

func _is_namespaced_id(definition_id: String) -> bool:
	if definition_id.is_empty():
		return false
	var segments := definition_id.split(".")
	if segments.size() < 2:
		return false

	for segment in segments:
		if segment.is_empty():
			return false
		for character in segment:
			var code: int = character.unicode_at(0)
			var is_lowercase_letter := code >= 97 and code <= 122
			var is_digit := code >= 48 and code <= 57
			if not (is_lowercase_letter or is_digit or character == "_" or character == "-"):
				return false
	return true
