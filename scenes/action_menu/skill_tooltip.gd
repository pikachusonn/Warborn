extends CanvasLayer

var panel: PanelContainer
var title: Label
var bolt: TextureRect
var damage_label: Label
var cooldown_label: Label
var description_label: Label
var bolt_material: ShaderMaterial

func _ready() -> void:
	layer = 30
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(panel)
	var paper := StyleBoxTexture.new()
	paper.texture = assemble_paper()
	paper.texture_margin_left = 64
	paper.texture_margin_right = 64
	paper.texture_margin_top = 64
	paper.texture_margin_bottom = 64
	paper.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	paper.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	paper.content_margin_left = 30
	paper.content_margin_right = 30
	paper.content_margin_top = 34
	paper.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", paper)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	var heading := HBoxContainer.new()
	rows.add_child(heading)
	title = make_label(22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Segoe UI", "Arial"])
	bold.font_weight = 700
	title.add_theme_font_override("font", bold)
	heading.add_child(title)
	bolt = make_icon(preload("res://assets/ui/skill_tooltip/energy.png"), Vector2(24, 30))
	heading.add_child(bolt)
	bolt_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform bool inactive = false; void fragment() { vec4 c = texture(TEXTURE, UV); if (inactive) { float g = dot(c.rgb, vec3(0.299, 0.587, 0.114)); c.rgb = vec3(g); c.a *= 0.4; } COLOR = c; }"
	bolt_material.shader = shader
	bolt.material = bolt_material
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	rows.add_child(stats)
	stats.add_child(make_icon(preload("res://assets/icons/action_menu/skill_placeholder.png"), Vector2(22, 28)))
	damage_label = make_label(17)
	stats.add_child(damage_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(spacer)
	stats.add_child(make_icon(preload("res://assets/ui/skill_tooltip/cooldown.png"), Vector2(22, 28)))
	cooldown_label = make_label(17)
	stats.add_child(cooldown_label)
	description_label = make_label(17)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(description_label)
	ignore_mouse(panel)
	panel.hide()

func assemble_paper() -> Texture2D:
	# The sheet contains nine 64px cells separated by 64px gutters.
	# Join them before nine-slicing; the three middle cells then repeat
	# vertically as the description grows, without stretching the artwork.
	var source := preload("res://assets/ui/skill_tooltip/paper.png").get_image()
	var joined := Image.create(192, 192, false, Image.FORMAT_RGBA8)
	for row in range(3):
		for column in range(3):
			joined.blit_rect(source, Rect2i(column * 128, row * 128, 64, 64), Vector2i(column * 64, row * 64))
	return ImageTexture.create_from_image(joined)

func make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.16))
	label.add_theme_constant_override("outline_size", 2)
	return label

func make_icon(texture: Texture2D, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	# Atlas cropping removes transparent padding without altering the supplied art.
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = texture.get_image().get_used_rect()
	icon.texture = atlas
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

func ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)

func show_skill(skill: Skill, display_name: String, anchor: Vector2) -> void:
	title.text = skill.skill_name if not skill.skill_name.is_empty() else display_name
	bolt_material.set_shader_parameter("inactive", skill.get_action_cost() == 0)
	damage_label.text = "%d damage" % skill.get_tooltip_damage()
	cooldown_label.text = "%d turns" % skill.cooldown
	if skill.cooldown_remaining > 0:
		cooldown_label.text += " (%d left)" % skill.cooldown_remaining
	description_label.text = skill.description
	panel.reset_size()
	panel.show()
	var viewport_size := get_viewport().get_visible_rect().size
	var desired := anchor - Vector2(panel.size.x + 16, panel.size.y * 0.5)
	panel.position = Vector2(
		clampf(desired.x, 10, maxf(10, viewport_size.x - panel.size.x - 10)),
		clampf(desired.y, 10, maxf(10, viewport_size.y - panel.size.y - 10))
	)

func hide_tooltip() -> void:
	panel.hide()
