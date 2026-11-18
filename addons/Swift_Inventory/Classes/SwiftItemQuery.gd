@tool
## Reusable filter for occupied inventory addresses. All supplied criteria must match.
class_name SwiftItemQuery
extends Resource

## Matches any listed ID. An empty list accepts all IDs.
@export var item_ids: Array[StringName] = []:
	set(value):
		item_ids = value
		emit_changed()
## Every listed tag must be present on the item definition.
@export var required_tags: Array[StringName] = []:
	set(value):
		required_tags = value
		emit_changed()
## Case-insensitive substring of the item's display name or ID.
@export var text: String = "":
	set(value):
		text = value
		emit_changed()
## Each listed key must exist and match by value. Other stack metadata is allowed.
@export var required_instance_data: Dictionary[StringName, Variant] = {}:
	set(value):
		required_instance_data = value
		emit_changed()


## Side-effect-free match against one valid stack.
func matches(stack: SwiftItemStack) -> bool:
	if stack == null or not stack.is_valid():
		return false
	var data := stack.item_data
	if not item_ids.is_empty() and data.id not in item_ids:
		return false
	var term := text.strip_edges()
	if (
		not term.is_empty()
		and data.display_name.findn(term) < 0
		and String(data.id).findn(term) < 0
	):
		return false
	for tag in required_tags:
		if tag not in data.tags:
			return false
	for key in required_instance_data:
		if (
			not stack.instance_data.has(key)
			or (
				SwiftPersistence.value_state(stack.instance_data[key])
				!= SwiftPersistence.value_state(required_instance_data[key])
			)
		):
			return false
	return true
