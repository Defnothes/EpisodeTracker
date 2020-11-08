extends Button

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var watch_script = null;
var watch_params = null;
var dl_script = null;
var dl_params = null
var index = -1
var current_status

var watched_parent
var watched_callback

# Called when the node enters the scene tree for the first time.
func _ready():
	set_status(Global.status.UNRELEASED, -1)

func set_status(new_status, ep_number):
	current_status = new_status
	set_button_icon(Global.status2icon[new_status])
	index  = ep_number

func set_watch_callback(action):
	watch_script = action[0]
	watch_params = action[1]
	
func set_download_callback(action):
	dl_script = action[0]
	dl_params = action[1]
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func set_watched_callback(parent, method):
	watched_parent = parent
	watched_callback = method

#func _input(event):
#	if (event is InputEventMouseButton and event.pressed):
#		if event.button_index == BUTTON_LEFT :
#			print('left')
#		if event.button_index == BUTTON_RIGHT:
#			print('right')

func _on_Button_pressed():
	match current_status:
		Global.status.DOWNLOADED:
			set_status(Global.status.WATCHED, index)
			watched_parent.call(watched_callback, index, true)
		Global.status.WATCHED:
			if Input.is_key_pressed(KEY_CONTROL):
				set_status(Global.status.DOWNLOADED,index)
				watched_parent.call(watched_callback, index, false)
	if watch_script!=null and not Input.is_key_pressed(KEY_CONTROL):
		#print(watch_script, ' : ', watch_params)
		OS.execute(watch_script, watch_params, false)
