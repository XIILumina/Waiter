extends CharacterBody3D

@export var speed := 5.0
@export var sprint_speed := 8.0
@export var gravity := 20.0
@export var mouse_sensitivity := 0.002

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var hand: Marker3D = $Hand

var carried: Node3D = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("interact"):
		if carried:
			_drop()
		else:
			_try_pick()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

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

func _try_pick() -> void:
	if not ray.is_colliding():
		return
	var hit := ray.get_collider() as Node
	if hit == null:
		return
	var target := hit as Node
	while target and not target.is_in_group("pickup"):
		target = target.get_parent()
	if target == null:
		return

	carried = target as Node3D
	if carried is CollisionObject3D:
		carried.collision_layer = 0
		carried.collision_mask = 0
	if carried is RigidBody3D:
		carried.freeze = true
	carried.reparent(hand)
	carried.position = Vector3.ZERO
	carried.rotation = Vector3.ZERO

func _drop() -> void:
	var world := get_tree().current_scene
	var forward := -camera.global_transform.basis.z
	var drop_pos := camera.global_position + forward * 1.4
	drop_pos.y = global_position.y + 0.2

	carried.reparent(world)
	carried.global_position = drop_pos
	if carried is CollisionObject3D:
		carried.collision_layer = 1
		carried.collision_mask = 1
	if carried is RigidBody3D:
		carried.freeze = false
	carried = null
