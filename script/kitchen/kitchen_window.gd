extends StaticBody3D

@export var soup_scene: PackedScene
@export var coffee_scene: PackedScene
@export var salad_scene: PackedScene

@onready var cooking_timer: Timer = $CookingTimer
@onready var status_label: Label3D = $StatusLabel
@onready var pickup_point_a: Marker3D = $PickupPointA
@onready var pickup_point_b: Marker3D = $PickupPointB

var order_queue: Array[Dictionary] = []
var active_order: Dictionary = {}
var is_cooking: bool = false
var next_output_slot: int = 0


func _ready() -> void:
	status_label.text = "Принести чек"
	cooking_timer.timeout.connect(_on_cooking_finished)


func _process(_delta: float) -> void:
	if is_cooking and not cooking_timer.is_stopped():
		var seconds_left: int = int(ceil(cooking_timer.time_left))
		status_label.text = "Готовится: %d | очередь: %d" % [seconds_left, order_queue.size()]


func interact(player: Node) -> void:
	var total_orders: int = order_queue.size()

	if is_cooking:
		total_orders += 1

	if total_orders >= 2:
		status_label.text = "Очередь заполнена"
		return

	var item: Node3D = player.get_carried_item()

	if item == null:
		status_label.text = "Принеси чек"
		return

	if not item.is_in_group("order_ticket"):
		status_label.text = "Нужен чек"
		return

	var dish_id: String = str(item.get("dish_id"))
	var order_id: int = int(item.get("order_id"))

	if _get_dish_scene(dish_id) == null:
		status_label.text = "Неизвестное блюдо"
		return

	order_queue.append({
		"dish_id": dish_id,
		"order_id": order_id
	})

	player.consume_carried_item()
	status_label.text = "Чек #%d принят" % order_id

	if not is_cooking:
		_start_next_order()


func _start_next_order() -> void:
	if order_queue.is_empty():
		is_cooking = false
		status_label.text = "Принести чек"
		return

	active_order = order_queue.pop_front()
	is_cooking = true

	var dish_id: String = str(active_order["dish_id"])
	cooking_timer.wait_time = _get_cooking_time(dish_id)
	cooking_timer.start()


func _on_cooking_finished() -> void:
	var dish_id: String = str(active_order["dish_id"])
	var order_id: int = int(active_order["order_id"])
	var dish_scene: PackedScene = _get_dish_scene(dish_id)

	if dish_scene == null:
		is_cooking = false
		active_order.clear()
		status_label.text = "Ошибка блюда"
		return

	var finished_dish: Node3D = dish_scene.instantiate()
	finished_dish.set("dish_id", dish_id)
	finished_dish.set("order_id", order_id)

	get_tree().current_scene.add_child(finished_dish)

	var output_point: Marker3D = pickup_point_a if next_output_slot == 0 else pickup_point_b
	finished_dish.global_transform = output_point.global_transform
	next_output_slot = (next_output_slot + 1) % 2

	status_label.text = "%s #%d готово!" % [_get_dish_name(dish_id), order_id]
	active_order.clear()
	is_cooking = false

	if not order_queue.is_empty():
		_start_next_order()


func _get_dish_scene(dish_id: String) -> PackedScene:
	match dish_id:
		"soup":
			return soup_scene
		"coffee":
			return coffee_scene
		"salad":
			return salad_scene
		_:
			return null


func _get_cooking_time(dish_id: String) -> float:
	match dish_id:
		"soup":
			return 8.0
		"coffee":
			return 5.0
		"salad":
			return 6.0
		_:
			return 8.0


func _get_dish_name(dish_id: String) -> String:
	match dish_id:
		"soup":
			return "Суп"
		"coffee":
			return "Кофе"
		"salad":
			return "Салат"
		_:
			return "Заказ"
