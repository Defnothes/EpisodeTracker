extends Control

var config
var entry_list = []
var folder_path = ""
var RSS
var regex_ep :RegEx
enum sort_types {TITLE, PROGRESS, REMAINING, NONE}
var sort_by = null
var sort_dir = true

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
	
	var cont_ent = preload("res://ContainerEntry.tscn").instance()
	$VBoxContainer/EntriesHeader/LabelTitle.rect_min_size =\
		 cont_ent.get_child(0).rect_min_size
	
	sort_by = config.get_value('general', 'sort_by', sort_types.NONE)
	sort_dir = config.get_value('general', 'sort_dir', true)
	#$VBoxContainer/EntriesHeader/LabelProgress.rect_min_size =\
	#	cont_ent.get_child(1).rect_min_size
	refresh()
	

	
func refresh():
	# Etry list
	for i in range(0, $VBoxContainer/ScrollContainer/ContainerEntryList.get_child_count()):
		$VBoxContainer/ScrollContainer/ContainerEntryList.get_child(i).queue_free()
	
	var files = Global.list_files_in_directory(folder_path)
	
	var entry_lines = []
	for entry in entry_list:
		var entry_line = load("res://ContainerEntry.tscn").instance()
		#entry_lines.append(entryLine)
		$VBoxContainer/ScrollContainer/ContainerEntryList.add_child(entry_line)
		entry_line.set_properties(
			entry['title'], entry['date'], int(entry['epcount']), entry['last_watched'],
			entry['quality'], entry['subber'],
			$VBoxContainer/ContainerDownloadScript/LineEditDownloadScript.text,
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
					entry_line.set_episode(
						ep_nr, 
						Global.status.DOWNLOADED, 
						[$VBoxContainer/ContainerWatchScript/LineEditWatchScript.text, filepath]
						)
		if 'watched' in entry:
			entry_line.update_watched_list(entry['watched'])
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
		for entry in entries:
			$VBoxContainer/ScrollContainer/ContainerEntryList.add_child(entry)
		
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
			return sort_dir == (Global.unix_time_from_string(a.last_watched) < 
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
				fill_details('','','')
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
	#config.set_value("RSS", 'URI', $VBoxContainer/ContainerRSS/LineEditRSS.text)
	#config.set_value("RSS", 'title', $VBoxContainer/ContainerRSS/LineEditTitleTag.text)
	#config.set_value("RSS", 'link', $VBoxContainer/ContainerRSS/LineEditLinkTag.text)
	config.set_value("download", 'quality', $VBoxContainer/ContainerRSS/LineEditQuality.text)
	config.set_value("download", 'subber', $VBoxContainer/ContainerRSS/LineEditSubber.text)

	config.set_value("entries", "list", entry_list)
	config.set_value('general', 'sort_by', sort_by)
	config.set_value('general', 'sort_dir', sort_dir)
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


func _on_ButtonUpdateRSS_pressed():
	print('starting download')
	#RSS.download($VBoxContainer/ContainerRSS/LineEditRSS.text, 'user://RSS.xml', $VBoxContainer/ContainerRSS/ButtonUpdateRSS)
	
	#RSS.download($VBoxContainer/ContainerRSS/LineEditRSS.text,"/page?id=1",80,false) #domain,url,port,useSSL
	#RSS.download("https://subsplease.org","/rss/?r=1080",80,false) #domain,url,port,useSSL
	RSS.download("http://www.mocky.io","/v2/5185415ba171ea3a00704eed",80,false) #domain,url,port,useSSL
	
func _on_RSS_loading(loaded,total):
	print(str(loaded*100/total),'%')
	
func _on_RSS_loaded(result):
	var result_string = result.get_string_from_ascii()
	print(result_string)


func _on_LabelTitle_pressed():
	if sort_by != sort_types.TITLE:
		sort_by = sort_types.TITLE
	else:
		sort_dir = !sort_dir
	refresh()

func _on_LabelProgress_pressed():
	if sort_by != sort_types.PROGRESS:
		sort_by = sort_types.PROGRESS
	else:
		sort_dir = !sort_dir
	refresh()

func _on_LabelTimeRemaining_pressed():
	if sort_by != sort_types.REMAINING:
		sort_by = sort_types.REMAINING
	else:
		sort_dir = !sort_dir
	refresh()


func _on_LineEditWatchScript_focus_exited():
	refresh()


func _on_LineEditDownloadScript_focus_exited():
	refresh()
