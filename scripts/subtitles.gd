extends Label
class_name SubtitleLabel

var current_text_priority := -1
var text_dict := {} # Maps subtitle text -> priority

func add_text(new_text: String, priority: int = 0) -> void:
	text_dict[new_text] = priority
	await _refresh_display()

func left_text_area(old_text: String) -> void:
	if not text_dict.has(old_text):
		return

	text_dict.erase(old_text)
	await _refresh_display()

func _refresh_display() -> void:
	if text_dict.is_empty():
		_animate_change("", -1)
		return

	var next_text := _get_highest_priority_text()
	var next_priority: int = text_dict[next_text]

	# Avoid replaying the animation if we are already showing the correct text.
	if next_text == text and next_priority == current_text_priority:
		return

	await _animate_change(next_text, next_priority)

func _get_highest_priority_text() -> String:
	var best_text := text
	var best_priority := -1_000_000_000

	for key in text_dict.keys():
		var priority: int = text_dict[key]
		var is_better: bool = priority > best_priority or (priority == best_priority and key == text)
		if is_better:
			best_priority = priority
			best_text = key

	return best_text

func _animate_change(new_text: String, priority: int) -> void:
	# Check if current text is active, else move down
	var current_still_active: bool = text_dict.has(text) and text_dict[text] == current_text_priority
	if priority < current_text_priority and current_still_active:
		return

	if %SubtitlesAnimationPlayer.is_playing():
		await %SubtitlesAnimationPlayer.animation_finished

	%TransitionSubtitles.text = text
	%SubtitlesAnimationPlayer.play("change_text_animation")
	current_text_priority = priority
	text = new_text
