class_name ContentDefinition
extends Resource

const ContentValidationReportScript = preload("res://src/content/validation/content_validation_report.gd")
const ContentValidationIssueScript = preload("res://src/content/validation/content_validation_issue.gd")

@export var content_id: String
@export var referenced_content_ids: Array[String]

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
	return report

func _is_namespaced_id(definition_id: String) -> bool:
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
