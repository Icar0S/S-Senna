class_name StudioMain
extends Control
## Placeholder main screen of the S-Senna Studio (Etapa 00): name + version.

const STUDIO_SUFFIX: String = "Studio"

@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	var project_name: String = str(ProjectSettings.get_setting("application/config/name", ""))
	_title_label.text = "%s %s" % [project_name, STUDIO_SUFFIX]
	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
