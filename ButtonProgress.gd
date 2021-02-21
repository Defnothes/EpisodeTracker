extends Button

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var parent

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
	var _err = $HTTPRequest.connect("request_completed", self, "call_magnet")
	
func set_message_parent(mp):
	parent = mp

func set_status(new_status, ep_number):
	current_status = new_status
	set_button_icon(Global.status2icon[new_status])
	index  = ep_number

func set_watch_callback(action):
	watch_script = action[0]
	watch_params = action[1]
	
func set_download_callback(download_script, title, quality, subber):
	dl_script = download_script
	dl_params = Global.generate_api_request_URI(title, index+1, quality, subber)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func set_watched_callback(object, method):
	watched_parent = object
	watched_callback = method

#func _input(event):
#	if (event is InputEventMouseButton and event.pressed):
#		if event.button_index == BUTTON_LEFT :
#			print('left')
#		if event.button_index == BUTTON_RIGHT:
#			print('right')

func _play_file():
	parent.print_info('Opening File: ' + str(watch_params))
	var _err = OS.execute(watch_script, watch_params, false)
	
func _clip_file():
	parent.print_info('Copied path to clipboard: ' + str(watch_params[0]))
	OS.set_clipboard(str(watch_params[0]))

func _on_Button_pressed():
	var _err
	match current_status:
		Global.status.DOWNLOADED:
			set_status(Global.status.WATCHED, index)
			if not Input.is_key_pressed(KEY_CONTROL):
				watched_parent.call(watched_callback, index, Global.status.WATCHED)
				if Input.is_key_pressed(KEY_ALT):
					_clip_file()
				else:
					_play_file()
		Global.status.WATCHED:
			if Input.is_key_pressed(KEY_CONTROL):
				set_status(Global.status.WATCHING,index)
				watched_parent.call(watched_callback, index, Global.status.WATCHING, false)
			elif Input.is_key_pressed(KEY_ALT):
				_clip_file()
			else:
				_play_file()
		Global.status.WATCHING:
			if Input.is_key_pressed(KEY_CONTROL):
				set_status(Global.status.DOWNLOADED,index)
				watched_parent.call(watched_callback, index, Global.status.DOWNLOADED, false)
			else:
				set_status(Global.status.WATCHED,index)
				watched_parent.call(watched_callback, index, Global.status.WATCHED)
				if Input.is_key_pressed(KEY_ALT):
					_clip_file()
				else:
					_play_file()
		Global.status.RELEASED:
			if Input.is_key_pressed(KEY_CONTROL) and not Input.is_key_pressed(KEY_ALT):
				set_status(Global.status.DELETED, index)
				watched_parent.call(watched_callback, index, Global.status.WATCHED, false)
			elif dl_script!=null and \
			not (Input.is_key_pressed(KEY_ALT) and not Input.is_key_pressed(KEY_CONTROL)):
				if not parent.find_node('ButtonLockOn').visible:
					parent.print_info('Submitting API Req: ' + str(dl_params))
					$HTTPRequest.request(dl_params)
				else:#The status should be LOCKED
					parent.print_error("Disable Download Lock First")
				#print(dl_script, dl_params)
		Global.status.DELETED:
			if Input.is_key_pressed(KEY_CONTROL):
				set_status(Global.status.RELEASED,index)
				watched_parent.call(watched_callback, index, Global.status.DOWNLOADED, false)
		Global.status.LOCKED:
			parent.print_error("Disable Download Lock First")

func call_magnet(_result, _response_code, _headers, body):
	var magnet = Global.generate_magnet_from_RSS(body)
	if magnet.find("torrent") > -1:
		parent.print_info('Submitting Magent link: ' + str(magnet).substr(0,50) + '[...]')
		var _err = OS.execute(dl_script, [magnet], false)
	else:
		parent.print_error('Could not get magnet link from API response: '+
							body.get_string_from_utf8())
