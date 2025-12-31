extends Label
class_name SubtitleLabel

func change_text(new_text: String) -> void:
	if %SubtitlesAnimationPlayer.is_playing():
		await %SubtitlesAnimationPlayer.animation_finished
	
	%TransitionSubtitles.text = text
	%SubtitlesAnimationPlayer.play("change_text_animation")
	text = new_text
