extends CharacterBody3D

@export var speed := 5.0
@export var sprint_speed := 8.0
@export var gravity := 20.0
@export var mouse_sensitivity := 0.002

@export var tray_mouse_sensitivity: float = 0.01
@export var tray_move_sway: float = 0.18
@export var tray_max_angle: float = 18.0
@export var tray_spill_limit: float = 1.2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var hand: Marker3D = $Hand

@onready var third_camera: Camera3D = $CameraPivot/CameraThird
@onready var body_mesh: MeshInstance3D = $Body
@onready var camera_pivot: Node3D = $CameraPivot

@onready var tray_pivot: Node3D = $Head/Camera3D/TrayPivot
@onready var dish_anchor: Marker3D = $Head/Camera3D/TrayPivot/DishAnchor

var third_person := false

var carried: Node3D = null
var carried_collision_layer: int = 1
var carried_collision_mask: int = 1

var tray_balance: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	third_camera.current = false
	camera.current = true
	body_mesh.visible = false
	tray_pivot.visible = false

func _process(delta: float) -> void:
	if not _is_carrying_dish():
		return

	var movement: Vector2 = Vector2(velocity.x, velocity.z)
	var sprint_multiplier: float = 1.8 if Input.is_action_pressed("sprint") else 1.0

	tray_balance.x += movement.x * tray_move_sway * sprint_multiplier * delta
	tray_balance.y += movement.y * tray_move_sway * sprint_multiplier * delta
	tray_balance = tray_balance.limit_length(tray_spill_limit * 1.1)

	var tilt_x: float = deg_to_rad(tray_balance.y * tray_max_angle)
	var tilt_z: float = deg_to_rad(-tray_balance.x * tray_max_angle)
	tray_pivot.rotation.x = tilt_x
	tray_pivot.rotation.z = tilt_z

	var balance_percent: float = tray_balance.length() / tray_spill_limit
	var stability: int = int(clampf(100.0 - balance_percent * 100.0, 0.0, 100.0))
	GameState.update_tray_stability(stability, true)

	if tray_balance.length() >= tray_spill_limit:
		_spill_dish()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _is_carrying_dish() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			tray_balance.x += event.relative.x * tray_mouse_sensitivity
			tray_balance.y += event.relative.y * tray_mouse_sensitivity
		else:
			if third_person:
				camera_pivot.rotation.y -= event.relative.x * mouse_sensitivity
				camera_pivot.rotation.x -= event.relative.y * mouse_sensitivity
				camera_pivot.rotation.x = clampf(
					camera_pivot.rotation.x,
					deg_to_rad(-70.0),
					deg_to_rad(70.0)
				)
			else:
				rotate_y(-event.relative.x * mouse_sensitivity)
				head.rotate_x(-event.relative.y * mouse_sensitivity)
				head.rotation.x = clampf(
					head.rotation.x,
					deg_to_rad(-80.0),
					deg_to_rad(80.0)
				)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if GameState.notebook_open:
		return

	if event.is_action_pressed("interact"):
		if _try_world_interaction():
			return

		if carried:
			_drop()
		else:
			_try_pick()

	if event.is_action_pressed("toggle_third_person"):
		_toggle_third_person()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if GameState.notebook_open:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		move_and_slide()
		return

	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_backward")
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()

func _is_carrying_dish() -> bool:
	return carried != null and carried.is_in_group("prepared_dish")

func _spill_dish() -> void:
	if not _is_carrying_dish():
		return

	var item: Node3D = carried
	var world: Node = get_tree().current_scene
	var fall_position: Vector3 = dish_anchor.global_position

	item.reparent(world)
	item.global_position = fall_position

	if item is CollisionObject3D:
		item.collision_layer = carried_collision_layer
		item.collision_mask = carried_collision_mask

	if item is RigidBody3D:
		item.freeze = false

	carried = null
	tray_balance = Vector2.ZERO
	tray_pivot.rotation = Vector3.ZERO
	tray_pivot.visible = false
	GameState.update_tray_stability(0, false)
	GameState.add_penalty(25)

func _try_world_interaction() -> bool:
	if not ray.is_colliding():
		return false

	var target: Node = ray.get_collider() as Node

	while target != null:
		if target.has_method("interact"):
			target.interact(self)
			return true

		target = target.get_parent()

	return false

func get_carried_item() -> Node3D:
	return carried

func consume_carried_item() -> void:
	if carried == null:
		return

	var was_dish: bool = carried.is_in_group("prepared_dish")
	carried.queue_free()
	carried = null

	if was_dish:
		tray_balance = Vector2.ZERO
		tray_pivot.rotation = Vector3.ZERO
		tray_pivot.visible = false
		GameState.update_tray_stability(0, false)

func receive_item(item: Node3D) -> bool:
	return _hold_item(item)

func _hold_item(item: Node3D) -> bool:
	if carried != null or item == null:
		return false

	carried = item

	if carried is CollisionObject3D:
		carried_collision_layer = carried.collision_layer
		carried_collision_mask = carried.collision_mask
		carried.collision_layer = 0
		carried.collision_mask = 0

	if carried is RigidBody3D:
		carried.freeze = true

	var item_parent: Node3D = hand

	if carried.is_in_group("prepared_dish"):
		item_parent = dish_anchor
		tray_balance = Vector2.ZERO
		tray_pivot.rotation = Vector3.ZERO
		tray_pivot.visible = true
		GameState.update_tray_stability(100, true)

	if carried.is_inside_tree():
		carried.reparent(item_parent)
	else:
		item_parent.add_child(carried)

	carried.position = Vector3.ZERO
	carried.rotation = Vector3.ZERO
	return true

func _try_pick() -> void:
	if not ray.is_colliding():
		return

	var target: Node = ray.get_collider() as Node

	while target != null and not target.is_in_group("pickup"):
		target = target.get_parent()

	if target == null:
		return

	_hold_item(target as Node3D)

func _drop() -> void:
	if carried == null:
		return

	var item: Node3D = carried

	var world: Node = get_tree().current_scene
	var forward: Vector3 = -camera.global_transform.basis.z
	var drop_position: Vector3 = camera.global_position + forward * 1.4
	drop_position.y = global_position.y + 0.2

	item.reparent(world)
	item.global_position = drop_position

	if item is CollisionObject3D:
		item.collision_layer = carried_collision_layer
		item.collision_mask = carried_collision_mask

	if item is RigidBody3D:
		item.freeze = false

	if item.is_in_group("prepared_dish"):
		tray_balance = Vector2.ZERO
		tray_pivot.rotation = Vector3.ZERO
		tray_pivot.visible = false
		GameState.update_tray_stability(0, false)

	carried = null

func _toggle_third_person() -> void:
	third_person = not third_person
	third_camera.current = third_person
	camera.current = not third_person
	body_mesh.visible = third_person
