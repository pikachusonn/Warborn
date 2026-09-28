extends AnimatedSprite2D

const SHEET := preload("res://assets/particles/dust_01.png")
const FRAME_SIZE := Vector2i(64, 64)
const FRAME_COUNT := 8

func _ready() -> void:
	var animation := SpriteFrames.new()
	animation.add_animation("burst")
	animation.set_animation_speed("burst", 12.0)
	animation.set_animation_loop("burst", false)
	for index in range(FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = SHEET
		frame.region = Rect2i(index * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		animation.add_frame("burst", frame)
	sprite_frames = animation
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * 1.8
	z_index = 8
	animation_finished.connect(queue_free)
	play("burst")
