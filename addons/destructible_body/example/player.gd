extends KinematicBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var fuel = 100
var mouse_sens = 0.2
var mov_speed = 15
var run_boost = 5
var mov_accel = 6
var air_accel = 1
var nor_accel = 6
var jump = 12
var direction = Vector3()
var velocity = Vector3()
var movement = Vector3()
var gravity = 20
var gravity_vec : Vector3
var full_contact = false
var io : IO

onready var head = $Head
onready var ground_check = $GroundCheck


func _ready():
#	Engine.time_scale = 0.5
	io = get_tree().current_scene.get_node("io")
	pass # Replace with function body.


func _physics_process(delta):
	
	direction = Vector3()
	
	if (io.click):
		if ($Head/RayCast.is_colliding() && $Head/RayCast.get_collider() is DestructibleBody):
			var other : DestructibleBody = $Head/RayCast.get_collider()
			other._destruct($Head/RayCast.get_collision_point(), $Head/RayCast.get_collision_normal(), 1.0)
	
	if (ground_check.is_colliding()):
		full_contact = true
	else:
		full_contact = false
	
	if not is_on_floor() and not full_contact:
		gravity_vec += Vector3.DOWN * gravity * delta
		mov_accel = air_accel
	elif is_on_floor() and full_contact:
		gravity_vec = -get_floor_normal()*gravity
		mov_accel = nor_accel
	else:
		gravity_vec = -get_floor_normal()
		mov_accel = nor_accel
	
	if (io.jump and (is_on_floor() or full_contact)):
		gravity_vec = Vector3.UP * jump
	
	direction -= transform.basis.z * io.loco.y
	direction += transform.basis.x * io.loco.x
	
	direction = direction.normalized()
	var boost = 0
	if (io.run): boost = run_boost
	velocity = velocity.linear_interpolate(direction*(mov_speed+boost), mov_accel * delta)
	movement.z = velocity.z + gravity_vec.z
	movement.x = velocity.x + gravity_vec.x
	movement.y = gravity_vec.y
	move_and_slide(movement, Vector3.UP, false, 3, PI/4, false)

func jump():
	pass

func get_local_x():
	return transform.basis.x.normalized()

func get_local_y():
	return transform.basis.y.normalized()

func get_local_z():
	return transform.basis.z.normalized()

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg2rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg2rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg2rad(-90), deg2rad(90))
	pass



func _on_RigidBody2_body_entered(body):
	print(body.name)
	pass # Replace with function body.
