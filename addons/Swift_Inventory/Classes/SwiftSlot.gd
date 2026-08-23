@tool
@icon("res://addons/Swift_Inventory/Icons/SwiftSlot.svg")
## Interactive control bound to one address in a [SwiftInventory].
##
## Displays the bound stack's icon and amount, exposes editor-friendly stack properties, and
## supports moving, stacking, swapping, and transferring items through Godot drag and drop.
class_name SwiftSlot
extends Panel

## Emitted after the slot's visuals and inspector properties are refreshed.
signal refreshed

## Item definition stored at this slot's address.
##
## In the editor, assigning this property replaces the bound stack while preserving its current
## amount when possible.
@export var item_data: SwiftItemData:
	set(value):
		if not Engine.is_editor_hint():
			return
		if not swift_inventory:
			return
		var current_amount := item.amount if item else 1
		swift_inventory.set_stack_from_data(address, value, current_amount)
	get:
		return item.item_data if item else null
## Number of items stored at this slot's address.
##
## In the editor, assigning this property recreates the bound stack with the requested amount.
@export var amount: int:
	set(value):
		if not Engine.is_editor_hint():
			return
		if not swift_inventory or not item:
			return
		swift_inventory.set_stack_from_data(address, item.item_data, value)
	get:
		return item.amount if item else 0

## Inventory resource currently bound to this slot.
var swift_inventory: SwiftInventory
## Address in [member swift_inventory] represented by this slot, or [code]-1[/code] when unbound.
var address: int = -1

## Stack currently stored at [member address], or [code]null[/code] when the address is empty.
##
## Runtime assignments store the supplied stack in the bound inventory.
var item: SwiftItemStack:
	set(value):
		if Engine.is_editor_hint():
			return
		if not swift_inventory:
			return
		swift_inventory.set_stack(address, value)
	get:
		if not swift_inventory:
			return null
		return swift_inventory.inventory.get(address)
## Texture control used to display [member item_data]'s icon.
var texture_rect: TextureRect
## Label used to display [member amount].
var amount_label: Label


## Initializes the slot to expand and fill the space assigned by its parent container.
func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Binds the slot to [param slot_address] in [param inventory] and refreshes its presentation.
func bind(inventory: SwiftInventory, slot_address: int) -> void:
	swift_inventory = inventory
	address = slot_address
	refresh()


## Updates the icon, amount label, and inspector properties from the bound inventory stack.
func refresh() -> void:
	_refresh_texture()
	_refresh_label()
	notify_property_list_changed()
	refreshed.emit()


## Creates or reuses the child controls used to present the bound stack.
##
## Calling this method more than once reuses existing children named [code]SwiftItemIcon[/code]
## and [code]SwiftItemAmount[/code].
func setup() -> void:
	add_to_group("_swift_editor_selectable")

	texture_rect = get_node_or_null("SwiftItemIcon") as TextureRect
	if not texture_rect:
		texture_rect = TextureRect.new()
		add_child(texture_rect)
		texture_rect.name = "SwiftItemIcon"
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	amount_label = get_node_or_null("SwiftItemAmount") as Label
	if not amount_label:
		amount_label = Label.new()
		add_child(amount_label)
		amount_label.name = "SwiftItemAmount"
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		amount_label.offset_right = -2.0
		amount_label.offset_bottom = -2.0


func _refresh_texture() -> void:
	if texture_rect:
		texture_rect.texture = item_data.icon if item_data else null


func _refresh_label() -> void:
	if amount_label:
		amount_label.text = str(item.amount) if item else ""


func _validate_property(property: Dictionary) -> void:
	if property.name in ["item_data", "amount"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE
	if property.name == "amount" and not item:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item or not swift_inventory:
		return null
	set_drag_preview(_get_preview(item))
	return {
		"inventory": swift_inventory,
		"address": address,
		"quantity": item.amount,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if Engine.is_editor_hint():
		return data is Dictionary and data.has("files")

	return (
		data is Dictionary
		and data.get("inventory") is SwiftInventory
		and data.has("address")
		and data.has("quantity")
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_inventory := data["inventory"] as SwiftInventory
	var from_address: int = data["address"]
	var quantity: int = data["quantity"]

	if from_inventory == swift_inventory and from_address == address:
		return

	var from_stack: SwiftItemStack = from_inventory.inventory.get(from_address)
	var to_stack: SwiftItemStack = swift_inventory.inventory.get(address)
	if not from_stack:
		return

	# Different items -> swap.
	if to_stack and from_stack.item_data.id != to_stack.item_data.id:
		if from_inventory == swift_inventory:
			from_inventory.try_swap(from_address, address)
		else:
			from_inventory.try_swap(from_address, address, swift_inventory)
		return

	# Empty slot / same item -> move or stack.
	if from_inventory == swift_inventory:
		from_inventory.try_move(from_address, address, quantity)
	else:
		from_inventory.try_transfer(from_address, swift_inventory, address, quantity)


func _get_preview(item: SwiftItemStack) -> Control:
	var preview_texture_rect: TextureRect = TextureRect.new()
	var preview_amount_label: Label = Label.new()

	preview_texture_rect.texture = item.item_data.icon
	preview_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture_rect.size = size
	preview_texture_rect.position = -preview_texture_rect.size / 2

	preview_amount_label.add_theme_font_size_override("font_size", size.x / 3)
	preview_amount_label.text = str(item.amount) if item.amount > 1 else ""
	preview_amount_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preview_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	preview_amount_label.offset_right = -2.0
	preview_amount_label.offset_bottom = -2.0

	var preview = Control.new()
	preview.add_child(preview_texture_rect)
	preview_texture_rect.add_child(preview_amount_label)

	return preview
