@tool
extends HFlowContainer


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return

	var row_count := get_line_count()
	var extra_height := size.y - get_minimum_size().y
	if row_count == 0 or extra_height <= 0.0:
		return

	# Keep the native widths and wrapping, and share unused height between rows.
	var extra_per_row := extra_height / row_count
	var row := -1
	var row_top := -1.0
	for child in get_children():
		if not child is Control or not child.is_visible() or child.is_set_as_top_level():
			continue
		var rect: Rect2 = child.get_rect()
		if rect.position.y != row_top:
			row += 1
			row_top = rect.position.y
		rect.position.y += extra_per_row * row
		rect.size.y += extra_per_row
		fit_child_in_rect(child, rect)
