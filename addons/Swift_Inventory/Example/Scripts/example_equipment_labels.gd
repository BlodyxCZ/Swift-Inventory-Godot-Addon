@tool
extends HBoxContainer

@export var grid: SwiftGrid


func _ready() -> void:
	if grid:
		grid.sort_children.connect(_match_grid_layout)
		_match_grid_layout()


func _match_grid_layout() -> void:
	var flags := SIZE_EXPAND_FILL if grid.scale_slots_to_width else SIZE_FILL
	for label: Label in get_children():
		label.size_flags_horizontal = flags
