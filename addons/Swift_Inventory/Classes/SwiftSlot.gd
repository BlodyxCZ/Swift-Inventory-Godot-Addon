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
		var replacement := item.copy(mini(value, item.item_data.max_stack_size))
		if value <= 0:
			swift_inventory.set_stack(address, null)
		elif value < item.amount:
			swift_inventory.try_remove(address, item.amount - value)
		else:
			swift_inventory.set_stack(address, replacement)
	get:
		return item.amount if item else 0

## Inventory resource currently bound to this slot.
var swift_inventory: SwiftInventory
## Address in [member swift_inventory] represented by this slot, or [code]-1[/code] when unbound.
var address: int = -1

## Stack currently stored at [member address], or [code]null[/code] when the address is empty.
## Runtime assignments validate and store the supplied stack in the bound inventory, then
## notify every bound container.
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
		return swift_inventory.get_stack(address)
## Texture control used to display [member item_data]'s icon.
var texture_rect: TextureRect
## Label used to display [member amount].
var amount_label: Label
## Presentation flags used by SwiftHotbar and drag target feedback.
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var selection_color: Color = Color(1.0, 0.78, 0.25)
var _drop_feedback: int = 0


## Initializes the slot to expand and fill the space assigned by its parent container.
func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Binds the slot to [param slot_address] in [param inventory] and refreshes its presentation.
func bind(inventory: SwiftInventory, slot_address: int) -> void:
	if swift_inventory and swift_inventory.on_change.is_connected(_on_inventory_change):
		swift_inventory.on_change.disconnect(_on_inventory_change)
	swift_inventory = inventory
	address = slot_address
	if swift_inventory and not get_parent() is SwiftContainer:
		swift_inventory.on_change.connect(_on_inventory_change)
	refresh()


## Updates the icon, amount label, and inspector properties from the bound inventory stack.
func refresh() -> void:
	var stack := item

	if texture_rect:
		texture_rect.texture = stack.item_data.icon if stack else null
	if amount_label:
		amount_label.text = str(stack.amount) if stack else ""

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


func _validate_property(property: Dictionary) -> void:
	if property.name in ["item_data", "amount"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE
	if property.name == "amount" and not item:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_drag_data(_at_position: Vector2) -> Variant:
	if Engine.is_editor_hint() or not item:
		return null
	var quantity := SwiftDrag.initial_quantity(
		item.amount, Input.is_key_pressed(KEY_SHIFT), Input.is_key_pressed(KEY_CTRL)
	)
	var payload := SwiftDrag.create_payload(swift_inventory, address, quantity)
	var preview := SwiftDragPreview.new()
	preview.setup(payload, size)
	set_drag_preview(preview)
	return payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if Engine.is_editor_hint():
		return data is Dictionary and data.has("files")

	var allowed := SwiftDrag.can_drop(data, swift_inventory, address)
	_drop_feedback = 1 if allowed else -1
	queue_redraw()
	return allowed


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	SwiftDrag.drop(data, swift_inventory, address)
	_drop_feedback = 0
	queue_redraw()


func _on_inventory_change(_type: SwiftInventory.CHANGES, _from: int, _to: int) -> void:
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_drop_feedback = 0
		queue_redraw()


func _draw() -> void:
	if selected:
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), selection_color, false, 2.0)
	if _drop_feedback != 0:
		var color := Color(0.3, 1.0, 0.5) if _drop_feedback > 0 else Color(1.0, 0.3, 0.3)
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), color, false, 2.0)


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
