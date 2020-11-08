extends Control

var config
var entry_list = []
var folder_path = ""

var regex_ep :RegEx
# Called when the node enters the scene tree for the first time.
func _ready():
	regex_ep = Global.default_epnr_regex
	 
	config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK: # if not, something went wrong with the file loading
				
		
		folder_path = config.get_value("general","folder_path","")
		$VBoxContainer/PathContainer/Path.text = folder_path
		
		entry_list = config.get_value("entries","list",[])
		
		#DEBUG = config.get_value("debug","debug_enabled",false)
	var watch_script = config.get_value("scripts", 'watch','')
	$VBoxContainer/ContainerWatchScript/LineEditWatchScript.set_text(watch_script)
	print('ws3',$VBoxContainer/ContainerWatchScript/LineEditWatchScript.text)
	var download_script = config.get_value("scripts", 'download','')
	$VBoxContainer/ContainerDownloadScript/LineEditDownloadScript.set_text(download_script)
	refresh()
	
func refresh():
	# Etry list
	for i in range(0, $VBoxContainer/ScrollContainer/ContainerEntryList.get_child_count()):
		$VBoxContainer/ScrollContainer/ContainerEntryList.get_child(i).queue_free()
	
	var files = Global.list_files_in_directory(folder_path)
	print(entry_list)
	
	for entry in entry_list:
		var entryLine = load("res://ContainerEntry.tscn").instance()
		$VBoxContainer/ScrollContainer/ContainerEntryList.add_child(entryLine)
		entryLine.set_properties(
			entry['title'], entry['date'], entry['epcount'],
			[],
			self)
		
		for file in files:
			if entry['title'].to_upper() in file.to_upper():
				var ep_nr = get_episode_nr_from_filename(file)
				if ep_nr == -1:
					print('Something unexpected went wrong with the regex')
				else:
					var filepath  =  folder_path + '/' + file
					filepath = filepath.replace('/','\\')
					filepath = PoolStringArray([filepath])
					entryLine.set_episode(ep_nr, Global.status.DOWNLOADED, 
						[$VBoxContainer/ContainerWatchScript/LineEditWatchScript.text, filepath],
						[$VBoxContainer/ContainerDownloadScript/LineEditDownloadScript.text, entry['title'], ep_nr])
		if 'watched' in entry:
			entryLine.update_watched_list(entry['watched'])
	_on_TextEditTitle_text_changed($VBoxContainer/ContainerActionButtons/ContainerTitleEdit/TextEditTitle.text)
	#var date_thing = load("res://addons/calendar_button/popup.tscn").instance()
	#$VBoxContainer/ScrollContainer/ContainerEntryList.add_child(date_thing)
	#var calendar_button_node = $CalendarButton
	#calendar_button_node.connect("date_selected", self, "your_func_here")
	print('ws4',$VBoxContainer/ContainerWatchScript/LineEditWatchScript.text)
	
func update_watched(title, array):
	#print(title, array)
	
	for entry in entry_list:
		if entry['title'] == title:
			entry['watched'] = array
	config.set_value("entries", "list", entry_list)
	config.save("user://settings.cfg")

#%% Utils
func fill_details(title, date, epcount):
	$VBoxContainer/ContainerActionButtons/ContainerTitleEdit/TextEditTitle.set_text(title)
	$VBoxContainer/ContainerActionButtons/ContainerDateEdit/TextEditDate.set_text(date)
	$VBoxContainer/ContainerActionButtons/ContainerEpcount/TextEditEpcount.set_text(str(epcount))
	_on_TextEditTitle_text_changed(title)

func get_episode_nr_from_filename(filename:String):
	var res = regex_ep.search(filename)
	if res != null:
		var str_res = res.get_string(1)
		if res != null:
			var int_res = int(str_res)
			return int_res
		else:
			print('The regex supplied should contain one () marker')
	else:
		print('The regex was not found ')
	return -1
	

func create_file_dialog(viewport_rect : Rect2, parent: Node, 
						access_mode, filters):
	var fd = FileDialog.new()
	var vps = viewport_rect.size 
	fd.rect_size = vps * 0.8
	fd.rect_position = vps *0.1
	fd.set_mode_overrides_title(true)
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.mode = access_mode
	fd.set_filters(PoolStringArray(filters))
	if folder_path == "":
		var _err = fd.set_current_dir(OS.get_system_dir(2))
	else:
		var _err = fd.set_current_dir(folder_path)
	parent.add_child(fd)
	fd.show()
	fd.invalidate()#AKA Refresh
	return fd
	
func set_new_folder(path):
	folder_path = path
	config.set_value("general", "folder_path", path)
	config.save("user://settings.cfg")
	$VBoxContainer/PathContainer/Path.text = path
	
	
#%% Input handling
func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_ESCAPE:
				save_all()
				get_tree().quit()
			elif event.scancode == KEY_F5:
				refresh()
			
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		# For Windows
		save_all()  
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST: 
		# For android
		save_all()
		get_tree().quit()

func save_all():
	config.set_value("scripts", 'watch', $VBoxContainer/ContainerWatchScript/LineEditWatchScript.text)
	config.set_value("scripts", 'download', $VBoxContainer/ContainerDownloadScript/LineEditDownloadScript.text)
	config.set_value("entries", "list", entry_list)
	config.save("user://settings.cfg")

func _on_ChangePath_pressed():
	var fd = create_file_dialog(get_viewport_rect(),get_node('.'),FileDialog.MODE_OPEN_DIR,[])
	fd.connect("dir_selected",self,"set_new_folder")


func _on_ButtonAddEntry_pressed():
	var add_del = $VBoxContainer/ContainerActionButtons/ButtonAddEntry
	if add_del.text == 'Add Title':
		entry_list.append(
			{'title':$VBoxContainer/ContainerActionButtons/ContainerTitleEdit/TextEditTitle.text,
			'date':$VBoxContainer/ContainerActionButtons/ContainerDateEdit/TextEditDate.text,
			'epcount':$VBoxContainer/ContainerActionButtons/ContainerEpcount/TextEditEpcount.text,
			'watched':[]}
			)
	elif add_del.text == 'Delete':
		var entry = find_entry($VBoxContainer/ContainerActionButtons/ContainerTitleEdit/TextEditTitle.text)
		entry_list.erase(entry)
		
	config.set_value("entries", "list", entry_list)
	config.save("user://settings.cfg")
	refresh()

func find_entry(title):
	for entry in entry_list:
		if title == entry['title']:
			return entry
	return null

func your_func_here(date_obj):
	print(date_obj.date()) # Use the date_obj wisely :)


func _on_CalendarButton_date_selected(date_obj):
	print(date_obj)


func _on_TextEditTitle_text_changed(new_text):
	var add_del = $VBoxContainer/ContainerActionButtons/ButtonAddEntry
	if find_entry(new_text):
		add_del.set_text('Delete')
	else:
		add_del.set_text('Add Title')


