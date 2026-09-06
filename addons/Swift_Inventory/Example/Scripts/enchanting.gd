extends VBoxContainer


@export var enchanting_grid: SwiftGrid


func _on_button_pressed() -> void:
	var inventory := enchanting_grid.swift_inventory
	var item := inventory.get_stack(0)
	if item == null: return

	var updated := item.copy()
	if not updated.instance_data.has(&"enchants"):
		updated.instance_data[&"enchants"] = {}

	updated.instance_data[&"enchants"]["Sharpness"] = 3
	inventory.set_stack(0, updated)
