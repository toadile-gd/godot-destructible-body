extends Node

class_name IO
# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var loco : Vector2
var throttle : int
var jump : bool
var run : bool
var thrust : bool
var rot_x : float
var rot_y : float
var click : bool

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass # Replace with function body.

func _physics_process(delta):
	
	var mov = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		mov.y = 1
	elif Input.is_key_pressed(KEY_S):
		mov.y = -1
	else:
		mov.y = 0
	
	if Input.is_key_pressed(KEY_D):
		mov.x = 1
	elif Input.is_key_pressed(KEY_A):
		mov.x = -1
	else:
		mov.x = 0
	
	run = Input.is_key_pressed(KEY_SHIFT)
	
	if Input.is_key_pressed(KEY_SPACE):
		if (!thrust):
			jump = true
		else:
			jump = false
		thrust = true
	else:
		thrust = false
		
	if Input.is_action_just_pressed("click"):
		click = true
	else:
		click = false
	
	loco = mov
	
	if (loco.length() > 1):
		loco /= loco.length()

func _input(event):
	if event.is_action_pressed("quit"):
		get_tree().quit()
