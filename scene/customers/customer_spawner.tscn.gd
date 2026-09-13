extends Node3D

@export var customer_scene: PackedScene

@onready var spawn_point_a: Marker3D = $SpawnPointA
@onready var spawn_point_b: Marker3D = $SpawnPointB
@onready var spawn_timer: Timer = $SpawnTimer

var occupied_slots: Array[bool] = [false, false]
var customers_by_slot: Dictionary = {}
var spawning_enabled: bool = true


func _ready() -> void:
	spawn_timer.timeout.connect(_fill_empty_slots)
	GameState.shift_finished.connect(_on_shift_finished)
	call_deferred("_fill_empty_slots")


func _fill_empty_slots() -> void:
	if not spawning_enabled or not GameState.shift_active:
		return

	for slot_index in range(2):
		if not occupied_slots[slot_index]:
			_spawn_customer_in_slot(slot_index)


func _spawn_customer_in_slot(slot_index: int) -> void:
	if customer_scene == null:
		push_warning("У CustomerSpawner не назначена Customer Scene")
		return

	var customer: Node3D = customer_scene.instantiate()
	get_tree().current_scene.add_child(customer)

	var spawn_point: Marker3D = spawn_point_a if slot_index == 0 else spawn_point_b
	customer.global_transform = spawn_point.global_transform

	customer.customer_finished.connect(_on_customer_finished.bind(slot_index))

	occupied_slots[slot_index] = true
	customers_by_slot[slot_index] = customer


func _on_customer_finished(slot_index: int) -> void:
	occupied_slots[slot_index] = false
	customers_by_slot.erase(slot_index)

	if spawning_enabled and GameState.shift_active:
		spawn_timer.start()


func _on_shift_finished() -> void:
	spawning_enabled = false
	spawn_timer.stop()

	for customer in customers_by_slot.values():
		if is_instance_valid(customer):
			customer.queue_free()

	customers_by_slot.clear()
	occupied_slots = [false, false]
