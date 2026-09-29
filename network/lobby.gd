extends Control

var address: LineEdit
var port: SpinBox
var message: Label

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.075, 0.11)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 560
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "WARBORN"
	title.add_theme_font_size_override("font_size", 44)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Two players · Same Wi-Fi / direct IP\nHost a match, then share your address and port."
	column.add_child(hint)
	address = LineEdit.new()
	address.placeholder_text = "Host IP address (LAN or Tailscale)"
	column.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = Netplay.PORT
	port.prefix = "Port "
	column.add_child(port)
	_add_button(column, "Host match", func(): Netplay.host(int(port.value)))
	_add_button(column, "Join match", func():
		if address.text.strip_edges().is_empty():
			message.text = "Enter the host's IP address first."
		else:
			Netplay.join(address.text, int(port.value)))
	_add_button(column, "Local play", Netplay.local_play)
	_add_button(column, "Cancel connection", func():
		Netplay.close_session()
		message.text = "Connection cancelled.")
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(560, 80)
	column.add_child(message)
	Netplay.status_changed.connect(_on_status)

func _on_status(value: String) -> void:
	message.text = value

func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
