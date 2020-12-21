extends Control

var config
var entry_list = []
var folder_path = ""
var RSS
enum sort_types {TITLE, PROGRESS, REMAINING, NONE}
var sort_by = null
var sort_dir = true
var search_recursive = false
var highlight_entries = false

var message_fade_counter = 0
var message_fade_level = 0
var message_color = Color(1,1,1,0)

var files = []
# Called when the node enters the scene tree for the first time.
func _ready():
	
	config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK: # if not, something went wrong with the file loading
		if err == ERR_FILE_NOT_FOUND:
			print_info('No settings file found. Initializing with defaults. ')
		elif err!=0:
			print_error('An error occured while loading settings file. ' +
					'Loading Defaults. Code: ' + str(err))
	folder_path = config.get_value("general","folder_path","")
	$VBoxContainer/PathContainer/Path.text = folder_path
	Global.download_URI = config.get_value('general', 'download_URI', 
							"https://nyaa.net/api/search?q=%s%s+%02d%s")
	Global.DB_URI = config.get_value('general', 'DB_URI', 
							"https://myanimelist.net/anime.php?q=%s&cat=anime")
	entry_list = config.get_value("entries","list",[])
	
	#DEBUG = config.get_value("debug","debug_enabled",false)
	
	$VBoxContainer/ContainerWatchScript/LineEditWatchScript.set_text(
		config.get_value("scripts", 'watch',''))
	$VBoxContainer/ContainerDownloadScript/LineEditDownloadScript.set_text(
		config.get_value("scripts", 'download',''))
	#$VBoxContainer/ContainerRSS/LineEditRSS.set_text(
	#	config.get_value("RSS", 'URI',''))
	$VBoxContainer/ContainerRSS/LineEditQuality.set_text(
		config.get_value("download", 'quality','1080p'))
	$VBoxContainer/ContainerRSS/LineEditSubber.set_text(
		config.get_value("download", 'subber',''))
	
	#var cont_ent = preload("res://ContainerEntry.tscn").instance()
	#$VBoxContainer/EntriesHeader/LabelTitle.rect_min_size =\
	#	 cont_ent.get_child(0).rect_min_size
	
	sort_by = config.get_value('general', 'sort_by', sort_types.NONE)
	sort_dir = config.get_value('general', 'sort_dir', true)
	search_recursive = config.get_value('general', 'search_recursive', false)
	$VBoxContainer/PathContainer/ContainerPathInteract/CheckBoxRecursive.set_pressed(search_recursive)
	#$VBoxContainer/EntriesHeader/LabelProgress.rect_min_size =\
	#	cont_ent.get_child(1).rect_min_size
	
	highlight_entries = config.get_value('visuals', 'highlight_entries', true)
	
	refresh()

	
func print_info(message):
	message_color = Color(1,1,1,1)
	_message_set_text(message)
	
func print_error(message):
	message_color = Color(1,0,0,1)
	_message_set_text(message)
	
func print_log(_message):
	pass

func _message_set_text(message):
	print(message)
	message_fade_level = 0
	message_fade_counter = 0
	$VBoxContainer/LabelMessage.set_text(message)

func passes_filter(title:String):
	if $VBoxContainer/HBoxContainerFilter/LineEditFilter.text == '' or \
		$VBoxContainer/HBoxContainerFilter/LineEditFilter.text.to_upper() in title.to_upper():
		return true
	return false
	
func refresh(reload_files = true):
	# Etry list
	for i in range(0, $VBoxContainer/ScrollContainer/ContainerEntryList.get_child_count()):
		var child = $VBoxContainer/ScrollContainer/ContainerEntryList.get_child(0)
		child.queue_free()
		$VBoxContainer/ScrollContainer/ContainerEntryList.remove_child(child)
		
	if reload_files:
		files = Global.list_files_in_directory(folder_path, search_recursive)
	
	var entry_lines = []
	for entry in entry_list:
		if not passes_filter(entry['title']):
			continue
		var entry_line = load("res://ContainerEntry.tscn").instance()
		#entry_lines.append(entryLine)
		$VBoxContainer/ScrollContainer/ContainerEntryList.add_child(entry_line)
		
		entry_line.set_properties(
			entry['title'], entry['date'], int(entry['epcount']), entry['last_watched'],
			entry['quality'], entry['subber'],
			$VBoxContainer/ContainerDownloadScript/LineEditDownloadScript.text,
			self)
		
		var episodes_found = []
		for file in files:
			if entry['title'].to_upper() in file[0].to_upper():
				var ep_nr = Global.get_episode_nr_from_filename(file[0])
				episodes_found.append(ep_nr)
				var is_finished = Global.check_finished_filename(file[0])
				match ep_nr:
					-3:
						print_error('Ep nr was not found in ' + file[0])
					-2:
						print_error('The regex supplied should contain one () marker')
					_:
						var filepath  =  file[1]
						if OS.get_name() in ["Windows", "UWP", "Server"]:
							filepath = filepath.replace('/','\\')
						filepath = PoolStringArray([filepath])
						entry_line.set_episode(
							ep_nr, 
							Global.status.DOWNLOADED if is_finished else Global.status.DOWNLOADING, 
							[$VBoxContainer/ContainerWatchScript/LineEditWatchScript.text, filepath]
							)
		if 'watched' in entry:
			entry_line.update_watched_list(entry['watched'], episodes_found)

	_on_TextEditTitle_text_changed($VBoxContainer/ContainerActionButtons/ContainerTitleEdit/TextEditTitle.text)
	#var date_thing = load("res://addons/calendar_button/popup.tscn").instance()
	#$VBoxContainer/ScrollContainer/ContainerEntryList.add_child(date_thing)
	#var calendar_button_node = $CalendarButton
	#calendar_button_node.connect("date_selected", self, "your_func_here")
	for entry_line in entry_lines:
		$VBoxContainer/ScrollContainer/ContainerEntryList.add_child(entry_line)
	
	sort_entries()
	
func sort_entries():
	var entries = $VBoxContainer/ScrollContainer/ContainerEntryList.get_children()
	
	if len(entries)>0 and sort_by != null:	
		for entry in entries:
			$VBoxContainer/ScrollContainer/ContainerEntryList.remove_child(entry)
		entries.sort_custom(self, "entry_comparator")
		var idx = 0
		for entry in entries:
			$VBoxContainer/ScrollContainer/ContainerEntryList.add_child(entry)
			if highlight_entries:
				if idx%2:
					entry.set_color(entry.COLORS.TRANS)
				else:
					entry.set_color(entry.COLORS.GREY)
			idx += 1 
		#	print(entry)
func entry_comparator(a : Node, b:Node):
	match sort_by:
		sort_types.TITLE:
			return sort_dir == (a.find_node('LabelTitle').text < b.find_node('LabelTitle').text)
		sort_types.REMAINING:
			var atime = -a.time_remaining_unix 
			var btime = -b.time_remaining_unix
			atime = 9223372036854775807 if atime<0 else atime
			btime = 9223372036854775807 if btime<0 else btime
			return sort_dir == (atime < btime)
		sort_types.PROGRESS:
			return sort_dir == (Global.unix_time_from_string(a.last_watched) > 
								Global.unix_time_from_string(b.last_watched))
	
func update_watched(title, array, last_watched):
	#print(title, array)
	
	for entry in entry_list:
		if entry['title'] == title:
			entry['watched'] = array
			entry['last_watched'] = last_watched
	config.set_value("entries", "list", entry_list)
	config.save("user://settings.cfg")

#%% Utils
func fill_details(title, date, epcount):
	var _err
	if Input.is_key_pressed(KEY_CONTROL):
		var link = Global.DB_URI % [title]
		link = link.replace(' ', '+')
		print_info("Opening Page: " + link)
		#OS.execute("C:/Program Files/Vivaldi/Application/vivaldi.exe", [link], true)
		
		var os_name = OS.get_name()
		if os_name in ["Windows", "UWP", "Server"]:
			_err = OS.execute("start", ['""', link], true)
		elif os_name == "X11":
			_err = OS.execute("open", [link], true)
		elif os_name == "Android":
			print_error('Android not supported')
		elif os_name in ["iOS", "OSX"]:
			_err = OS.execute("curl", [link], true)
		elif os_name in "HTML5":
			print_error('Webredirect not supported in browser')
		else:
			print_error('Unkown OS detected')
	else:
		$VBoxContainer/ContainerActionButtons/ContainerTitleEdit/TextEditTitle.set_text(title)
		$VBoxContainer/ContainerActionButtons/ContainerDateEdit/TextEditDate.set_text(date)
		$VBoxContainer/ContainerActionButtons/ContainerEpcount/TextEditEpcount.set_text(str(epcount))
		_on_TextEditTitle_text_changed(title)


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
	refresh()
	
#%% Input handling
func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			#print(event.scancode)
			if event.scancode == KEY_ESCAPE:
				save_all()
				get_tree().quit()
			elif event.scancode == KEY_F5:
				fill_details('','','')
				refresh()
			elif event.scancode == KEY_H and Input.is_key_pressed(KEY_CONTROL):
				highlight_entries = !highlight_entries
				refresh()
			elif not Input.is_key_pressed(KEY_CONTROL) and\
				(event.scancode>33 and event.scancode<126):
					var proc_char = event.scancode
					if proc_char>=65 and proc_char<=90:
						proc_char += 32
					$VBoxContainer/HBoxContainerFilter/LineEditFilter.grab_focus()
					$VBoxContainer/HBoxContainerFilter/LineEditFilter.append_at_cursor(char(proc_char))
					
				
			
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
	#config.set_value("RSS", 'URI', $VBoxContainer/ContainerRSS/LineEditRSS.text)
	#config.set_value("RSS", 'title', $VBoxContainer/ContainerRSS/LineEditTitleTag.text)
	#config.set_value("RSS", 'link', $VBoxContainer/ContainerRSS/LineEditLinkTag.text)
	config.set_value("download", 'quality', $VBoxContainer/ContainerRSS/LineEditQuality.text)
	config.set_value("download", 'subber', $VBoxContainer/ContainerRSS/LineEditSubber.text)

	config.set_value("entries", "list", entry_list)
	
	config.set_value('general', 'download_URI', Global.download_URI)
	config.set_value('general', 'DB_URI', Global.DB_URI)
	config.set_value('general', 'sort_by', sort_by)
	config.set_value('general', 'sort_dir', sort_dir)
	config.set_value('general', 'search_recursive', search_recursive)
	
	config.set_value('visuals', 'highlight_entries', highlight_entries)
	
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
			'watched':[],
			'last_watched':$VBoxContainer/ContainerActionButtons/ContainerDateEdit/TextEditDate.text,
			'quality':$VBoxContainer/ContainerRSS/LineEditQuality.text,
			'subber':$VBoxContainer/ContainerRSS/LineEditSubber.text}
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

func _on_TextEditTitle_text_changed(new_text):
	var add_del = $VBoxContainer/ContainerActionButtons/ButtonAddEntry
	if find_entry(new_text):
		add_del.set_text('Delete')
	else:
		add_del.set_text('Add Title')
	check_entry_is_valid()


func check_entry_is_valid():
	if (Global.unix_time_from_string($VBoxContainer/ContainerActionButtons/ContainerDateEdit/TextEditDate.text) != null and \
		len($VBoxContainer/ContainerActionButtons/ContainerTitleEdit/TextEditTitle.text)>=1 and\
		int($VBoxContainer/ContainerActionButtons/ContainerEpcount/TextEditEpcount.text)>1) or\
		$VBoxContainer/ContainerActionButtons/ButtonAddEntry.text == 'Delete':
		$VBoxContainer/ContainerActionButtons/ButtonAddEntry.disabled = false
	else:
		$VBoxContainer/ContainerActionButtons/ButtonAddEntry.disabled = true

func _on_TextEditDate_text_changed(_new_text):
	check_entry_is_valid()

func _on_TextEditEpcount_text_changed(_new_text):
	check_entry_is_valid()

func _on_LabelTitle_pressed():
	if sort_by != sort_types.TITLE:
		sort_by = sort_types.TITLE
		sort_dir = true
	else:
		sort_dir = !sort_dir
	refresh(false)

func _on_LabelProgress_pressed():
	if sort_by != sort_types.PROGRESS:
		sort_by = sort_types.PROGRESS
		sort_dir = true
	else:
		sort_dir = !sort_dir
	refresh(false)

func _on_LabelTimeRemaining_pressed():
	if sort_by != sort_types.REMAINING:
		sort_by = sort_types.REMAINING
		sort_dir = true
	else:
		sort_dir = !sort_dir
	refresh(false)


func _on_LineEditWatchScript_focus_exited():
	refresh(false)


func _on_LineEditDownloadScript_focus_exited():
	refresh(false)


func _on_CheckBoxRecursive_toggled(button_pressed):
	search_recursive = button_pressed
	refresh()

func _process(delta):
	if message_fade_level<1:
		message_fade_counter += delta
		#if message_fade_counter>0.1:
			#message_fade_counter = 0
			#message_fade_level+=0.01
		message_fade_level = exp(message_fade_counter)/30
		message_color.a = 1-message_fade_level
		$VBoxContainer/LabelMessage.set_modulate(message_color)
	else:
		message_fade_counter = 0


func _on_LabelMessage_mouse_entered():
	message_fade_level = 0
	message_fade_counter = 0


func _on_LineEdit_text_changed(_new_text):
	refresh(false)
