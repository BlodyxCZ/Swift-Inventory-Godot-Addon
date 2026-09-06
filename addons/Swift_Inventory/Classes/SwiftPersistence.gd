@tool
## Native snapshot I/O shared by inventory and UI state Resources.
## Load only trusted game save files: native Resources may reference scripts.
class_name SwiftPersistence
extends RefCounted


## Writes beside the destination, then replaces it only after a successful save.
## Snapshot callers must detach mutable resources before calling this method.
static func save_resource(snapshot: Resource, path: String) -> Error:
	if not valid_path(path): return ERR_INVALID_PARAMETER
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK: return error
	var temporary := (
		"%s.writing-%s.%s"
		% [absolute.get_basename(), Time.get_ticks_usec(), absolute.get_extension()]
	)
	error = ResourceSaver.save(snapshot, temporary)
	if error == OK: error = DirAccess.rename_absolute(temporary, absolute)
	if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	return error


static func valid_path(path: String) -> bool:
	return not path.is_empty() and path.get_extension().to_lower() in ["tres", "res"]


## Explicit recursion also handles Resource values inside Arrays and Dictionaries on 4.4.
## Scripts, textures and shared item definitions keep their authored asset references.
static func copy_value(value: Variant) -> Variant:
	var errors: Array = []
	var result: Variant = _copy_value(value, [], errors)
	return result if errors.is_empty() else null


static func _copy_value(value: Variant, copies: Array, errors: Array) -> Variant:
	for pair in copies: if is_same(pair[0], value): return pair[1]
	if value is Dictionary:
		var result: Dictionary = value.duplicate(false)
		result.clear()
		copies.append([value, result])
		for key in value:
			result[_copy_value(key, copies, errors)] = _copy_value(value[key], copies, errors)
		return result
	if value is Array:
		var result: Array = value.duplicate(false)
		copies.append([value, result])
		for index in value.size():
			result[index] = _copy_value(value[index], copies, errors)
		return result
	if value is Resource and not _is_shared_asset(value):
		if not _has_default_constructor(value):
			errors.append(ERR_INVALID_DATA)
			return null
		var result: Resource = value.duplicate(false)
		if (
			result == null
			or result.get_script() != value.get_script()
			or result.get_class() != value.get_class()
		):
			errors.append(ERR_INVALID_DATA)
			return null
		copies.append([value, result])
		result.resource_path = ""
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
				result.set(property.name, _copy_value(value.get(property.name), copies, errors))
		return result
	return value


## Rejects cycles and nonserializable runtime handles before writing a save.
static func is_storable(value: Variant, parents: Array = []) -> bool:
	if parents.size() > 64 or typeof(value) in [TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]: return false
	if value is Object and not value is Resource: return false
	if not (value is Array or value is Dictionary or value is Resource): return true
	if value is Resource and _is_shared_asset(value): return true
	if value is Resource and not _has_default_constructor(value): return false
	for parent in parents: if is_same(parent, value): return false
	var branch := parents.duplicate()
	branch.append(value)
	if value is Array:
		for element in value:
			if not is_storable(element, branch):
				return false
	elif value is Dictionary:
		for key in value:
			if not is_storable(key, branch) or not is_storable(value[key], branch):
				return false
	else:
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
				if not is_storable(value.get(property.name), branch):
					return false
	return true


static func _is_shared_asset(value: Resource) -> bool:
	return value is Script or value is Texture or value is SwiftItemData


static func _has_default_constructor(value: Resource) -> bool:
	var script: Script = value.get_script()
	while script:
		for method in script.get_script_method_list():
			if method.name == "_init":
				return method.args.size() <= method.default_args.size()
		script = script.get_base_script()
	return true


## Structural comparison state for mutable metadata. Resource properties are captured by
## value, so independent copies compare equally and later nested changes are detectable.
static func value_state(value: Variant, parents: Array = []) -> Variant:
	if not (value is Array or value is Dictionary or value is Object): return [typeof(value), value]
	for index in parents.size():
		if is_same(parents[index], value):
			return ["cycle", index]
	if parents.size() > 64: return ["depth_limit"]
	var branch := parents.duplicate()
	branch.append(value)
	if value is Array:
		var elements: Array = []
		for element in value: elements.append(value_state(element, branch))
		return [TYPE_ARRAY, elements]
	if value is Dictionary:
		var entries: Dictionary = {}
		for key in value:
			var key_state: Variant = value_state(key, branch)
			if not entries.has(key_state): entries[key_state] = []
			entries[key_state].append(value_state(value[key], branch))
		return [TYPE_DICTIONARY, entries]
	if not is_instance_valid(value): return [TYPE_NIL]
	if not value is Resource or _is_shared_asset(value): return [TYPE_OBJECT, value.get_instance_id()]
	var properties: Dictionary = {}
	for property in value.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
			properties[property.name] = value_state(value.get(property.name), branch)
	var script: Script = value.get_script()
	return [TYPE_OBJECT, value.get_class(), script.get_instance_id() if script else 0, properties]
