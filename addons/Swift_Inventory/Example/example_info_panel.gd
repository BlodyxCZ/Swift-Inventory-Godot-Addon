extends PanelContainer


func _on_swift_info_on_info_changed(new_item: SwiftItemStack) -> void:
	$VBoxContainer/Label.text = new_item.item_data.display_name
	$VBoxContainer/Label2.text = new_item.item_data.description
