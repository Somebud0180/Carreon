extends Label
class_name SubtitleLabel

var current_text_priority = -1
var text_dict = {}

func add_text(new_text: String, priority: int = 0) -> void:
	text_dict.get_or_add(new_text, priority)
	change_text(new_text, priority)

func change_text(new_text: String, priority: int = 0) -> void:
	# If priority is lesser than current, ignore
	if priority < current_text_priority:
		return
	
	if %SubtitlesAnimationPlayer.is_playing():
		await %SubtitlesAnimationPlayer.animation_finished
	
	%TransitionSubtitles.text = text
	%SubtitlesAnimationPlayer.play("change_text_animation")
	current_text_priority = priority
	text = new_text

func left_text_area(old_text: String, priority: int = 0) -> void:
	if %TransitionSubtitles.text != old_text or text_dict.find_key(old_text) == null:
		return
	
	if %TransitionSubtitles.text == old_text:
		text_dict.erase(old_text)
		_sort_dict(text_dict)
		change_text(pairs.back())

func _sort_dict(dict: Dictionary) -> void:
	var pairs = dict.keys().map(func (key): return [key, dict[key]])
	pairs.sort()
	dict.clear()
	for p in pairs:
		dict[p[0]] = p[1]
