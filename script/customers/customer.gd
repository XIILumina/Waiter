extends StaticBody3D

signal customer_finished

const DISH_IDS: Array[String] = ["soup", "coffee", "salad"]
const DISH_NAMES: Dictionary = {
	"soup": "Суп",
	"coffee": "Кофе",
	"salad": "Салат"
}
const DISTORTION_SYMBOLS: Array[String] = ["?", "#", "%", "*"]

@export var order_ticket_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var speech_distortion_chance: float = 0.15
@export var speech_duration: float = 2.5

@onready var order_label: Label3D = $OrderLabel
@onready var patience_label: Label3D = $PatienceLabel
@onready var patience_timer: Timer = $PatienceTimer
@onready var leave_timer: Timer = $LeaveTimer
@onready var speech_label: Label3D = $SpeechLabel
@onready var speech_timer: Timer = $SpeechTimer

var requested_dish_id: String = ""
var order_id: int = 0
var order_taken: bool = false
var order_completed: bool = false
var order_failed: bool = false
var is_leaving: bool = false
var waiting_for_notebook: bool = false
var interacting_player: Node = null


func _ready() -> void:
	requested_dish_id = DISH_IDS.pick_random()
	order_label.text = "Нажми E"
	patience_label.text = ""
	patience_timer.timeout.connect(_on_patience_timeout)
	leave_timer.timeout.connect(_on_leave_timer_timeout)
	speech_label.visible = false
	speech_timer.wait_time = speech_duration
	speech_timer.timeout.connect(_on_speech_timer_timeout)


func _process(_delta: float) -> void:
	if order_taken and not order_completed and not order_failed:
		if not patience_timer.is_stopped():
			var seconds_left: int = int(ceil(patience_timer.time_left))
			patience_label.text = "Терпение: %d" % seconds_left


func interact(player: Node) -> void:
	if order_failed:
		order_label.text = "Клиент недоволен"
		return

	if order_completed:
		order_label.text = "Заказ выполнен!"
		return

	if not order_taken:
		_open_notebook(player)
		return

	_try_receive_dish(player)


func _open_notebook(player: Node) -> void:
	if waiting_for_notebook:
		return

	if not player.has_method("get_carried_item"):
		order_label.text = "Ошибка взаимодействия"
		return

	if player.get_carried_item() != null:
		order_label.text = "Сначала освободи руки"
		return

	interacting_player = player
	waiting_for_notebook = true
	order_label.text = "Слушай внимательно"

	var dish_name: String = _get_dish_name(requested_dish_id)
	speech_label.text = "Хочу: %s" % _distort_text(dish_name)
	speech_label.visible = true
	speech_timer.start()


func _on_speech_timer_timeout() -> void:
	speech_label.visible = false

	if not waiting_for_notebook:
		return

	if not is_instance_valid(interacting_player):
		cancel_order_choice()
		return

	if not GameState.request_notebook(self):
		order_label.text = "Блокнот занят"
		cancel_order_choice()


func confirm_order_choice(selected_dish_id: String) -> void:
	if not waiting_for_notebook or not is_instance_valid(interacting_player):
		return

	if not DISH_IDS.has(selected_dish_id):
		cancel_order_choice()
		return

	if order_ticket_scene == null:
		order_label.text = "Ошибка сцены чека"
		cancel_order_choice()
		return

	order_id = GameState.create_order_id()

	var ticket: Node3D = order_ticket_scene.instantiate()
	ticket.set("dish_id", selected_dish_id)
	ticket.set("order_id", order_id)

	if not interacting_player.receive_item(ticket):
		ticket.free()
		order_label.text = "Не удалось выдать чек"
		cancel_order_choice()
		return

	order_taken = true
	waiting_for_notebook = false
	interacting_player = null
	order_label.text = "Записано: %s" % _get_dish_name(selected_dish_id)
	patience_timer.start()


func cancel_order_choice() -> void:
	speech_timer.stop()
	speech_label.visible = false
	waiting_for_notebook = false
	interacting_player = null

	if not order_taken:
		order_label.text = "Нажми E ещё раз"


func _try_receive_dish(player: Node) -> void:
	var item: Node3D = player.get_carried_item()

	if item == null:
		order_label.text = "Жду: %s" % _get_dish_name(requested_dish_id)
		return

	if not item.is_in_group("prepared_dish"):
		order_label.text = "Это не готовое блюдо"
		return

	var delivered_order_id: int = int(item.get("order_id"))

	if delivered_order_id != order_id:
		order_label.text = "Это заказ другого клиента"
		GameState.add_penalty(25)
		return

	var delivered_dish_id: String = str(item.get("dish_id"))

	if delivered_dish_id != requested_dish_id:
		order_label.text = "Я заказывал другое!"
		GameState.add_penalty(25)
		return

	var seconds_left: int = int(ceil(patience_timer.time_left))
	var tip_amount: int = seconds_left * 2
	var reward: int = _get_dish_reward(requested_dish_id)

	patience_timer.stop()
	player.consume_carried_item()
	order_completed = true

	GameState.add_reward(reward, tip_amount)
	order_label.text = "Спасибо! +%d очков" % reward
	patience_label.text = "Чаевые: %d" % tip_amount
	_start_leaving()


func _on_patience_timeout() -> void:
	if order_completed:
		return

	order_failed = true
	order_label.text = "Слишком долго!"
	patience_label.text = "Клиент ушёл"
	GameState.add_penalty(50)
	_start_leaving()


func _start_leaving() -> void:
	if is_leaving:
		return

	is_leaving = true
	leave_timer.start()


func _on_leave_timer_timeout() -> void:
	customer_finished.emit()
	queue_free()


func _get_dish_name(dish_id: String) -> String:
	return str(DISH_NAMES.get(dish_id, "Неизвестное блюдо"))


func _get_dish_reward(dish_id: String) -> int:
	match dish_id:
		"soup":
			return 100
		"coffee":
			return 70
		"salad":
			return 80
		_:
			return 50


func _distort_text(text: String) -> String:
	if randf() > speech_distortion_chance:
		return text

	var valid_positions: Array[int] = []

	for index in range(text.length()):
		var character: String = text.substr(index, 1)

		if character != " " and character != "-":
			valid_positions.append(index)

	if valid_positions.is_empty():
		return text

	var replace_index: int = valid_positions.pick_random()
	var symbol: String = DISTORTION_SYMBOLS.pick_random()

	return (
		text.substr(0, replace_index)
		+ symbol
		+ text.substr(replace_index + 1)
	)
