extends PanelContainer
class_name ItemContainer

var item_name: String = "":
	set(value):
		item_name = value
		accessibility_name = item_name
		tooltip_text = item_name
