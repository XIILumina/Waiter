extends Node

signal score_changed(score: int, tips: int)
signal shift_time_changed(seconds_left: int)
signal shift_finished
signal tray_stability_changed(value: int, visible: bool)
signal notebook_requested(customer: Node)

var score: int = 0
var tips: int = 0
var shift_active: bool = false
var next_order_id: int = 1
var notebook_open: bool = false

func create_order_id() -> int:
	var new_id: int = next_order_id
	next_order_id += 1
	return new_id


func update_tray_stability(value: int, visible: bool) -> void:
	tray_stability_changed.emit(value, visible)


func request_notebook(customer: Node) -> bool:
	if notebook_open:
		return false

	notebook_open = true
	notebook_requested.emit(customer)
	return true


func close_notebook() -> void:
	notebook_open = false


func add_reward(points: int, tip_amount: int) -> void:
	if not shift_active:
		return

	score += points
	tips += tip_amount
	score_changed.emit(score, tips)


func add_penalty(points: int) -> void:
	if not shift_active:
		return

	score -= points
	score_changed.emit(score, tips)


func begin_shift() -> void:
	shift_active = true


func update_shift_time(seconds_left: int) -> void:
	shift_time_changed.emit(seconds_left)


func end_shift() -> void:
	if not shift_active:
		return

	shift_active = false
	shift_finished.emit()


func reset() -> void:
	score = 0
	tips = 0
	shift_active = false
	next_order_id = 1
	notebook_open = false
	score_changed.emit(score, tips)
