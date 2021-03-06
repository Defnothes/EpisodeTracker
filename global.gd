extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
enum status{
	UNRELEASED,
	RELEASED,
	DOWNLOADING,
	DOWNLOADED,
	WATCHING,
	WATCHED,
	DELETED,
	LOCKED	
}

var status2icon = {
	status.UNRELEASED:preload("res://res/waiting.png"),
	status.RELEASED:preload("res://res/download_2.png"),
	status.DOWNLOADED:preload("res://res/View.png"),
	status.DOWNLOADING:preload("res://res/download_in_progress.png"),
	status.WATCHING:preload("res://res/Viewed_partial.png"),
	status.WATCHED:preload("res://res/Viewed.png"),
	status.DELETED:preload("res://res/Viewed_deleted.png"),
	status.LOCKED:preload("res://res/download_locked.png")
}

var video_extensions = ['.mp4', '.mkv', '.avi', '.mp3', '.mob', '.flv', '.wmv',
						'webm', '.vob', '.ogv', '.ogg', '.mov', '.amv', '.m4p',
						'.m4v', 'mpeg', '.m2v', '.svi', '.3gp', '.3g2', '.f4v',
						'.f4p', '.f4p', '.f4b', '.f4a', '.f4v']

var download_URI : String
var DB_URI : String

var regex_epnr : RegEx
var regex_time : RegEx

# Called when the node enters the scene tree for the first time.
func _ready():
	regex_epnr = RegEx.new()
	regex_time = RegEx.new()
	var _err = regex_epnr.compile('- (\\d\\d)')
	_err = regex_time.compile('(\\d+)[\\./](\\d+)[\\./](\\d+)\\.? (\\d+):(\\d+)')
	
	for key in status2icon.keys():
		var im = status2icon[key].get_data()
		im.resize(16,16)
		status2icon[key] = ImageTexture.new()
		status2icon[key].create_from_image(im)
	
func unix_time_from_string(time_string):
	time_string += (' 1:00')
	var time_res = regex_time.search(time_string)
	if time_res == null:
		return null
		
	var time_dict = {'year': time_res.get_string(1), 
					'month' : time_res.get_string(2), 
					'day' : time_res.get_string(3),
					'hour': time_res.get_string(4),
					'minute': time_res.get_string(5)}
	if int(time_dict['year']) <100:
		time_dict['year'] = '20' + time_dict['year']
	
	#now that's future-proofing :))
	if int(time_dict['year']) <1970  or int(time_dict['year']) > 3000\
	or int(time_dict['month']) <=0 or int(time_dict['month']) >12 \
	or int(time_dict['day']) <=0 or int(time_dict['day']) >31 \
	or int(time_dict['hour']) <0 or int(time_dict['hour'])>=24 \
	or int(time_dict['minute']) <0 or int(time_dict['minute']) >= 60:
		return null
		
	var attempted_date = OS.get_unix_time_from_datetime(time_dict)
	if attempted_date == 0:
		return null
		
	return attempted_date

func string_from_date_time(datetime):
	return '%d.%d.%d %02d:%02d' % [
		datetime['year'],datetime['month'],datetime['day'],
		datetime['hour'],datetime['minute']]

func is_available_by_time(release_date, weeks_passed, pt=false):
	var secs_left = seconds_until(release_date)
	if pt:
		#print(OS.get_time_zone_info()['bias'])
		print (secs_left,
		' : ',secs_left/3600.0/24.0/7.0,
		 ' ', weeks_passed)
	return secs_left/3600.0/24.0/7.0>=weeks_passed

func check_finished_filename(filename:String):
	var extension = filename.substr(len(filename)-4)
	if extension in video_extensions:
		return true
	else:
		return false

func get_episode_nr_from_filename(filename:String):
	var res = regex_epnr.search(filename)
	if res != null:
		var str_res = res.get_string(1)
		if res != null:
			var int_res = int(str_res)
			return int_res
		else:
			return -2
	else:
		return -3
	
	

func generate_api_request_URI(title:String, episode:int, quality:String = '', subber:String = ''):
	title = title.replace(' ','+')
	return download_URI % \
			['[%s]+' % subber if subber != '' else '', 
			title, 
			episode, 
			('+' + quality) if quality != '' else '' ]
	
	
func generate_magnet_from_JSON(body):
	var json = JSON.parse(body.get_string_from_utf8())
	#print(json.result['torrents'][0]['name'])
	#print(json.result['torrents'][0]['magnet'])
	if (not ('torrents' in json.result)) or (len(json.result['torrents'])==0):
		return
	return json.result['torrents'][0]['magnet']
	#return '/'+str(title)+'-'+str(episode)

func seconds_until(release_date):
	if release_date == null:
		print('The release date is invalid')
		return false
	var date_to_unix = Global.unix_time_from_string(release_date)
	if date_to_unix == null:
		print('The release date is invalid')
		return false
		
	#This compensates for GMTK and timezones.
	var current_time = OS.get_unix_time_from_datetime(OS.get_datetime())

	return current_time - date_to_unix
	
func seconds_to_string(time_seconds):
	time_seconds += 0
	var time :String
	var minutes_left = time_seconds / 60
	var hrs_left =  time_seconds/ 3600
	var days_left = hrs_left / 24
	
	if time_seconds<0:
		time = '-'
	elif days_left>0:
		time = str(time_seconds/24/3600) 
		if days_left>1:
			time += ' days'
		else:
			time += ' day'
	elif hrs_left>0:
		time += str(hrs_left)
		if hrs_left>1:
			time+= ' hrs '
		else:
			time += 'hr '
	elif minutes_left>=0:
		time += str(minutes_left)
		time += ' min'
	return time

func list_files_in_directory(path, recursive = false):
	var file_list = []
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while (file_name != ""):
			if not dir.current_is_dir():
				file_list.append([file_name, path+'/'+file_name])
			elif recursive and file_name != '.' and file_name!='..':
				file_list += list_files_in_directory(path + '/' +file_name, true)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return file_list

func save_buffer(file_name, content):
	var file = File.new()
	file.open(file_name, File.WRITE)
	file.store_buffer(content)
	file.close()

func load_from_file(file_name):
	var file = File.new()
	file.open(file_name, File.READ)
	var content = file.get_as_text()
	file.close()
	return content

func generate_magnet_from_RSS(body):
	var parser = XMLParser.new();
	var magnet = null;
	var error = parser.open_buffer(body);
	if error != 0:
			return "Error with URL";
	var finished_reading = false;
	while (!finished_reading):
		error = parser.read();
		if error == 18:
			return "No results for query";
		if error != 0:
			return "Error parsing XML";
		if parser.get_node_type() != 3:
			var node_name = parser.get_node_name();
			if node_name == "link":
				error = parser.read();
				var node_data = parser.get_node_data();
				if node_data != "https://nyaa.si/":
					finished_reading = true;
					magnet = node_data;
				error = parser.read();
				error = parser.read();
	return magnet;

var help_text = """	[center][u][b]General Tips and Guide[/b][/u][/center]
	[center]Press any key or click on [u]Help[/u] to close this window[/center]
		Red Light:
				While red shows cannot be downloaded (accidentally)
				It can be toggled by clicking on it, or disabled by pressing ctrl-alt
	
		Header:
				Enabling [u]Recursive[/u] next to the folder selector will enable searching sub-folders as well
				Press F5 to refresh/search the directories again

		Column Titles:
				Click on [u]Next Ep[/u] or [u]Title[/u] to sort by those values respectively, clicking [u]Progress[/u] sorts by the date the show was last watched.
				Clicking the column title again reverses the search
		
		Titles:
				Clicking on titles fills their information into the fields at the bottom.
				[u]Ctrl-Click:[/u] Opens MAL link with the anime title searched
				If the Edit button is disabled, the date or episode count is invalid, or none of the fields have been changed
				If the Add button is disabled, the date or episode count is invalid. If the name already matches an existing title, it is replaced with 'Delete'
			
				Status Button Legend:
						[b]Hourglass[/b]: Unreleased ― Release dates are calculated based on the 'Date' field below
						[b]Green Arrow[/b]: Downloadable ― Click to fetch magnet link
						[b]Green Arrow with red dots[/b]: Downloading ― unfinished download, download is probably in progress
						[b]Eye[/b]: Ready ― Click to watch -> sets status to watched
								Alt-Click to copy the path to the clipboard. Specially for Syncplay -> sets status as watched
						[b]Ticked Eye[/b]: Watched ― Click to watch
						[b]Eye with Blue Triangle[/b]: Half-Watched ― Click to watch → sets status to watched
						[b]Grey Ticked Eye[/b]: Deleted ― watched, but file not found
						[b]Lock over Arrow[/b]: Prevents accidental downloads. ctrl-alt or click the red light in the top left corner
						[u]Ctrl-Click[/u]: toggles between statuses without performing any action (last watched timestamp is not updated either)
								Downloadable ↔ Deleted
								Ready → Watched → Half-Watched → Ready → ...
						[u]These statuses are not updated automatically if the file is modified outside of the program. Press F5 to refresh[/u]
					
		Show Details:
				[u][b]Date:[/b][/u] The air date of the first episode ― [u]Release dates are calculated based on this [/u]
					[u][b]Format[/b][/u]: y[./]m[./]d.? h:m , hour and minute optional
						e.g. [b]20.12.30[/b] OR [b]20/12/30[/b] OR [b]2020.12.30[/b] OR [b]20.12.30.[/b] OR [b]20.12.30 22:30[/b] etc.
				The anime will be searched for in the following form [<Subber>]<Title>+<episode>+<quality>. Subber and quality are optional. 
				The first matching result is returned as the download link, any others are discarded.
				If the Title field was empty, the date will be autocompleted to the current date and episode count will be filled with 12, 
				provided they are empty and autocomplete is enabled (Ctrl-T to toggle)
		
		Watch and download details:
				[u]Watch Script:[/u] The path to your video player's executable (e.g. C:/[...]/vlc.exe). The filename is given as an argument. Tested player: VLC
				[u]Download Script:[/u] The Path to the bittorrent application executable. The magnet is given as a parameter, should work on most clients
			
		Pseudo-toast:
				The latest message will pop up for a short period of time at the bottom of the window. Hover to see the last message
			
		[b]Hotkeys[/b]:
			F5: to refresh/search the directories again
			Ctrl-H: Enable/Disable highlighting of alterate rows
			Ctrl-T: Enable/Disable Autocomplete
			Cltr-Alt: Temprorarily disable download lock
			Any alpha-numeric key: filter
	[center]Press any key or click on [u]Help[/u] to close this window[/center]
	
	"""
#func get_link_from_RSS_depr(title, episode):
#	var file_name = 'user://RSS.xml'
#	var components = []
#
#	var xml = XMLParser.new()
#	xml.open(file_name)
#	while xml.read() == OK:
#		if xml.get_node_type() == XMLParser.NODE_TEXT:
#			print(xml.get_node_data())
#			#var r_title = xml.get_named_attribute_value('d')
#			#print(r_title)
#
#	return null
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
