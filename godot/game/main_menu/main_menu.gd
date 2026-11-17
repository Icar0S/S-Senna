class_name MainMenu
extends Control
## Placeholder title screen of the Game (Etapa 00): project name + version.

@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_title_label.text = str(ProjectSettings.get_setting("application/config/name", ""))
	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
