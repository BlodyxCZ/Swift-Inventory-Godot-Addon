@tool
## Separate native save resource for named hotbar selections and drop-area positions.
## Use each view's capture_ui_state()/restore_ui_state() methods with a stable key.
class_name SwiftUIState
extends Resource

@export_storage var format_version: int = 1
@export var views: Dictionary[StringName, Dictionary] = {}


func save_to_file(path: String) -> Error:
	if format_version != 1 or not SwiftPersistence.is_storable(views):
		return ERR_INVALID_DATA
	return SwiftPersistence.save_resource(SwiftPersistence.copy_value(self), path)


## Replaces all view entries only after validating the loaded resource.
func load_from_file(path: String) -> Error:
	if not SwiftPersistence.valid_path(path):
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SwiftUIState
	if saved == null or saved.format_version != 1 or not SwiftPersistence.is_storable(saved.views):
		return ERR_INVALID_DATA
	views = SwiftPersistence.copy_value(saved.views)
	emit_changed()
	return OK
