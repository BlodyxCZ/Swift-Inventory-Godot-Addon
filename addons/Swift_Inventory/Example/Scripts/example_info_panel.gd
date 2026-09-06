extends PanelContainer


func _on_swift_info_on_info_changed(new_item: SwiftItemStack) -> void:
	if new_item == null:
		$VBoxContainer/Label.text = ""
		$VBoxContainer/Label2.text = ""
		$VBoxContainer/Label3.text = ""
		return
	$VBoxContainer/Label.text = new_item.item_data.display_name
	$VBoxContainer/Label2.text = new_item.item_data.description
	if new_item.instance_data:
		$VBoxContainer/HSeparator2.show()
		$VBoxContainer/Label3.show()
		$VBoxContainer/Label3.text = str(new_item.instance_data)
	else:
		$VBoxContainer/HSeparator2.hide()
		$VBoxContainer/Label3.hide()
