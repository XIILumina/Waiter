extends CanvasLayer

@onready var crosshair_container: CenterContainer = $CenterContainer
@onready var score_label: Label = $ScorePanel/ScoreLabel
@onready var tips_label: Label = $ScorePanel/TipsLabel
@onready var shift_label: Label = $ScorePanel/ShiftLabel
@onready var stability_label: Label = $ScorePanel/StabilityLabel

@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBoxContainer/ResultLabel
@onready var restart_button: Button = $ResultPanel/VBoxContainer/RestartButton

@onready var order_notebook: PanelContainer = $OrderNotebook
@onready var soup_button: Button = $OrderNotebook/VBoxContainer/SoupButton
@onready var coffee_button: Button = $OrderNotebook/VBoxContainer/CoffeeButton
@onready var salad_button: Button = $OrderNotebook/VBoxContainer/SaladButton
@onready var cancel_button: Button = $OrderNotebook/VBoxContainer/CancelButton

var active_customer: Node = null


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.shift_time_changed.connect(_on_shift_time_changed)
	GameState.shift_finished.connect(_on_shift_finished)
	GameState.tray_stability_changed.connect(_on_tray_stability_changed)
	GameState.notebook_requested.connect(_on_notebook_requested)

	restart_button.pressed.connect(_on_restart_pressed)
	soup_button.pressed.connect(_on_dish_chosen.bind("soup"))
	coffee_button.pressed.connect(_on_dish_chosen.bind("coffee"))
	salad_button.pressed.connect(_on_dish_chosen.bind("salad"))
	cancel_button.pressed.connect(_on_notebook_cancelled)

	result_panel.visible = false
	order_notebook.visible = false
	stability_label.visible = false
	_on_score_changed(GameState.score, GameState.tips)


func _on_score_changed(score: int, tips: int) -> void:
	score_label.text = "Очки: %d" % score
	tips_label.text = "Чаевые: %d" % tips


func _on_shift_time_changed(seconds_left: int) -> void:
	var minutes: int = int(seconds_left / 60.0)
	var seconds: int = seconds_left % 60
	shift_label.text = "Смена: %d:%02d" % [minutes, seconds]


func _on_tray_stability_changed(value: int, visible: bool) -> void:
	stability_label.visible = visible
	stability_label.text = "Устойчивость: %d" % value

	if value > 60:
		stability_label.modulate = Color.GREEN
	elif value > 30:
		stability_label.modulate = Color.YELLOW
	else:
		stability_label.modulate = Color.RED


func _on_notebook_requested(customer: Node) -> void:
	active_customer = customer
	order_notebook.visible = true
	crosshair_container.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_dish_chosen(dish_id: String) -> void:
	if is_instance_valid(active_customer):
		active_customer.confirm_order_choice(dish_id)

	_close_notebook()


func _on_notebook_cancelled() -> void:
	if is_instance_valid(active_customer):
		active_customer.cancel_order_choice()

	_close_notebook()


func _close_notebook(capture_mouse: bool = true) -> void:
	order_notebook.visible = false
	crosshair_container.visible = true
	active_customer = null
	GameState.close_notebook()

	if capture_mouse and GameState.shift_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_shift_finished() -> void:
	_close_notebook(false)
	result_panel.visible = true
	result_label.text = "Смена окончена\nОчки: %d\nЧаевые: %d" % [GameState.score, GameState.tips]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_restart_pressed() -> void:
	GameState.reset()
	get_tree().reload_current_scene()
