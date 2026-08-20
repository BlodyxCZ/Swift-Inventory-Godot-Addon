@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftSlot.svg")
class_name SwiftSlot
extends Panel


signal refreshed


var swift_inventory: SwiftInventory
var address: int = -1

var item: SwiftItemStack:
	get:
		if not swift_inventory: return null
		return swift_inventory.inventory.get(address)
var texture_rect: TextureRect

@export var item_data: SwiftItemData:
	set(value):
		if not Engine.is_editor_hint(): return
		if not swift_inventory: return
		var current_amount := item.amount if item else 1
		swift_inventory.set_stack(address, value, current_amount)
	get: return item.item_data if item else null
@export var amount: int:
	set(value):
		if not Engine.is_editor_hint():return
		if not swift_inventory or not item: return
		swift_inventory.set_stack(address, item.item_data, value)
	get: return item.amount if item else 0
@export_tool_button("Refresh Texture", "Reload") var refresh_texture_button = _refresh_texture


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func bind(inventory: SwiftInventory, slot_address: int) -> void:
	swift_inventory = inventory
	address = slot_address
	refresh()


func refresh() -> void:
	_refresh_texture()
	notify_property_list_changed()
	refreshed.emit()


func setup() -> void:
	texture_rect = get_node_or_null("SwiftItemIcon") as TextureRect
	if texture_rect: return
	texture_rect = TextureRect.new()
	add_child(texture_rect, true)
	texture_rect.owner = owner
	texture_rect.name = "SwiftItemIcon"
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

func _refresh_texture():
	if texture_rect: texture_rect.texture = item_data.icon if item_data else null


func _validate_property(property: Dictionary) -> void:
	if property.name in ["item_data", "amount"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE
	if property.name == "amount" and not item:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_drag_data(at_position: Vector2) -> Variant:
	if not item or not swift_inventory: return null
	set_drag_preview(_get_preview(item))
	return {
		"inventory": swift_inventory,
		"address": address,
		"quantity": item.amount,
	}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and data.get("inventory") is SwiftInventory
		and data.has("address")
		and data.has("quantity")
	)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var from_inventory := data["inventory"] as SwiftInventory
	var from_address: int = data["address"]
	var quantity: int = data["quantity"]
	
	if from_inventory == swift_inventory and from_address == address: return
	
	var from_stack: SwiftItemStack = from_inventory.inventory.get(from_address)
	var to_stack: SwiftItemStack = swift_inventory.inventory.get(address)
	if not from_stack: return
	
	# Different items -> swap.
	if to_stack and from_stack.item_data.id != to_stack.item_data.id:
		if from_inventory == swift_inventory: from_inventory.try_swap(from_address, address)
		else: from_inventory.try_swap(from_address, address, swift_inventory)
		return
	
	# Empty slot / same item -> move or stack.
	if from_inventory == swift_inventory: from_inventory.try_move(from_address, address, quantity)
	else: from_inventory.try_transfer(from_address, swift_inventory, address, quantity)

func _get_preview(item: SwiftItemStack) -> Control:
	var preview_texture_rect: TextureRect = TextureRect.new()
	var preview_amount_label: Label = Label.new()
	
	preview_texture_rect.texture = item.item_data.icon
	preview_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture_rect.size = size
	preview_texture_rect.position = -preview_texture_rect.size / 2
	
	preview_amount_label.add_theme_font_size_override("font_size", item.item_data.icon.get_size().x / 2)
	preview_amount_label.text = str(item.amount) if item.amount > 1 else ""
	preview_amount_label.position = preview_texture_rect.size / 2 * Vector2(1, -1)
	
	var preview = Control.new()
	preview.add_child(preview_texture_rect)
	preview.add_child(preview_amount_label)
	
	return preview
