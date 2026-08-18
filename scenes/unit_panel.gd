extends Panel
class_name UnitPanel

@onready var portrait: TextureRect = $HBoxContainer/PotraitContainer/Portrait
@onready var hp_bar: ProgressBar = $HBoxContainer/VBoxContainer/HPBar
@onready var move_button: Button = $HBoxContainer/VBoxContainer/Actions/Move
@onready var skill1_button: Button = $HBoxContainer/VBoxContainer/Actions/Skill1
@onready var skill2_button: Button = $HBoxContainer/VBoxContainer/Actions/Skill2
@onready var skill3_button: Button = $HBoxContainer/VBoxContainer/Actions/Skill3
@onready var skill4_button: Button = $HBoxContainer/VBoxContainer/Actions/Skill4
@onready var end_turn_button: Button = $HBoxContainer/VBoxContainer/Actions/EndTurn
@onready var energy_label: Label = $HBoxContainer/PotraitContainer/Energy/Label

signal move_pressed
signal skill1_pressed
signal skill2_pressed
signal skill3_pressed
signal skill4_pressed
signal end_turn_pressed

var active_skill_button: Button = null

func _ready() -> void:
	hide()
	
	move_button.pressed.connect(_on_move_pressed)
	skill1_button.pressed.connect(_on_skill1_pressed)
	skill2_button.pressed.connect(_on_skill2_pressed)
	skill3_button.pressed.connect(_on_skill3_pressed)
	skill4_button.pressed.connect(_on_skill4_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
func _on_move_pressed():
	set_skill_active(move_button)
	move_pressed.emit()

func _on_skill1_pressed():
	set_skill_active(skill1_button)
	skill1_pressed.emit()

func _on_skill2_pressed():
	set_skill_active(skill2_button)
	skill2_pressed.emit()
	
func _on_skill3_pressed():
	set_skill_active(skill3_button)
	skill3_pressed.emit()

func _on_skill4_pressed():
	set_skill_active(skill4_button)
	skill4_pressed.emit()

func _on_end_turn_pressed():
	clear_skill_active()
	end_turn_pressed.emit()
	
func show_unit(unit: Unit):
	show()
	portrait.texture = unit.data.texture
	hp_bar.max_value = unit.data.health
	hp_bar.value = unit.current_health
	skill1_button.text = unit.data.skill1_name
	skill2_button.text = unit.data.skill2_name
	skill3_button.text = unit.data.skill3_name
	skill4_button.text = unit.data.skill4_name
	
func set_skill_active(button: Button):
	if active_skill_button:
		active_skill_button.remove_theme_stylebox_override("normal")
		active_skill_button.remove_theme_stylebox_override("hover")
	active_skill_button = button
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.8, 1.0, 0.35)
	style.border_color = Color(0.4, 0.85, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)

func clear_skill_active():
	if not active_skill_button:
		return
	active_skill_button.remove_theme_stylebox_override("normal")
	active_skill_button.remove_theme_stylebox_override("hover")
	active_skill_button = null
	
func update_energy(current_energy: int):
	energy_label.text = str(current_energy)
