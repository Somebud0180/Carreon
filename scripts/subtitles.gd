extends Label
class_name SubtitleLabel

var text_dict = {} # Maps subtitle text -> priority
var is_gradient_displayed: bool = false
var is_prompt_displayed: bool = false
var current_text_priority: int = -1
var show_continue: bool = false
var show_dismiss: bool = false

## Adds a text to the subtitle dictionary [br]
## Displayed by order of priority (bigger number = higher priority) [br]
## Can show a "continue" prompt to signal to user to interact for more text
## Can replace the "continue" prompt with a "dismiss" prompt
func add_text(new_text: String, priority: int = 0, has_more_text: bool = false, prompt_dismiss: bool = false) -> void:
	show_continue = has_more_text
	show_dismiss = prompt_dismiss
	text_dict[new_text] = priority
	await _refresh_display()

## Removes a text from the subtitle dictionary [br]
## Automatically removes matching text if existing and does nothing if not found
func remove_text(old_text: String, hide_continue: bool = false) -> void:
	if not text_dict.has(old_text):
		return

	if hide_continue:
		show_continue = false
		show_dismiss = false

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

	if show_continue:
		if !is_gradient_displayed:
			%GradientAnimationPlayer.play("show_gradient")
		if !is_prompt_displayed:
			%PromptAnimationPlayer.play("show_prompt")
		if %GradientAnimationPlayer.current_animation != "idle_gradient":
			await %GradientAnimationPlayer.animation_finished
			%GradientAnimationPlayer.play("idle_gradient")
	else:
		if is_gradient_displayed:
			%GradientAnimationPlayer.play("hide_gradient")
		if is_prompt_displayed:
			%PromptAnimationPlayer.play("hide_prompt")
	
	if show_dismiss:
		%Prompt.text =  "Interact to Dismiss"
	else:
		await %PromptAnimationPlayer.animation_finished
		%Prompt.text = "Interact to Continue"
