@tool
## Reusable insertion restrictions. All applicable inventory and slot rules must pass.
## Empty allow lists are unrestricted; block lists always take precedence.
## Rule changes never remove existing contents. Custom predicates must be side-effect free.
class_name SwiftRule
extends Resource

@export var allowed_ids: Array[StringName] = []
@export var blocked_ids: Array[StringName] = []
@export var allowed_tags: Array[StringName] = []
@export var blocked_tags: Array[StringName] = []
## Require every allowed tag instead of at least one.
@export var require_all_tags: bool = false
## Zero uses the item's limit. Positive values cap the total quantity at one address.
@export_range(0, 2147483647, 1) var max_quantity: int = 0


## Checks the proposed final stack, including its total quantity and metadata.
func accepts(stack: SwiftItemStack, inventory: SwiftInventory, address: int) -> bool:
	if stack == null or not stack.is_valid():
		return false
	var data := stack.item_data
	if data.id in blocked_ids or (not allowed_ids.is_empty() and data.id not in allowed_ids):
		return false
	for tag in blocked_tags:
		if tag in data.tags:
			return false
	if not allowed_tags.is_empty():
		var matches := 0
		for tag in allowed_tags:
			if tag in data.tags:
				matches += 1
		if matches == 0 or (require_all_tags and matches != allowed_tags.size()):
			return false
	if max_quantity > 0 and stack.amount > max_quantity:
		return false
	return _accepts(stack, inventory, address)


## Override for custom item definition or instance metadata checks.
func _accepts(_stack: SwiftItemStack, _inventory: SwiftInventory, _address: int) -> bool:
	return true
