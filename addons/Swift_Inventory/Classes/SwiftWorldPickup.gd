@icon("res://addons/Swift_Inventory/Icons/SwiftItemStack.svg")
## One stack held by a world pickup. Add as a child of a game-owned 2D or 3D node.
##
## The owning scene controls interaction, position, visuals, and cleanup. An empty
## component can be filled before it enters the tree when spawning a dropped item.
class_name SwiftWorldPickup
extends Node

## Emitted after a successful pickup or drop, once both sides reflect the transfer.
signal stack_changed

## Optional authored stack. Copied when the component becomes ready or is first used.
@export var initial_stack: SwiftItemStack

var _contents: SwiftInventory
var _transfer_in_progress := false


func _ready() -> void:
	_get_contents()


## Returns an independent stack snapshot, or [code]null[/code] when empty.
func get_stack() -> SwiftItemStack:
	var stack := _get_contents().get_stack(0)
	return stack.copy() if stack != null else null


## Picks up as much of [param quantity] as fits, applying destination slot rules.
## [code]-1[/code] requests the whole stack. Returns the number of items moved.
func try_pickup(destination: SwiftInventory, quantity: int = -1) -> int:
	if _transfer_in_progress or destination == null or quantity == 0 or quantity < -1:
		return 0
	var contents := _get_contents()
	_transfer_in_progress = true
	var moved := contents.transfer_stack_to(0, destination, quantity)
	_transfer_in_progress = false
	if moved > 0:
		stack_changed.emit()
	return moved


## Drops up to [param quantity] items from [param address] into this component.
## [code]-1[/code] requests the whole source stack. Compatible existing contents
## can be topped up. Returns the number moved and leaves any overflow at the source.
func try_drop(source: SwiftInventory, address: int, quantity: int = -1) -> int:
	if _transfer_in_progress or source == null or quantity == 0 or quantity < -1:
		return 0
	var stack := source.get_stack(address)
	if stack == null:
		return 0
	var contents := _get_contents()
	if source == contents:
		return 0
	var requested := stack.amount if quantity == -1 else mini(quantity, stack.amount)
	_transfer_in_progress = true
	var moved := requested - source.try_transfer(address, contents, 0, requested)
	_transfer_in_progress = false
	if moved > 0:
		stack_changed.emit()
	return moved


func _get_contents() -> SwiftInventory:
	if _contents == null:
		_contents = SwiftInventory.new()
		_contents.size = 1
		if initial_stack != null and initial_stack.is_valid():
			var stack := initial_stack.copy()
			if stack != null:
				_contents.set_stack(0, stack)
	return _contents
