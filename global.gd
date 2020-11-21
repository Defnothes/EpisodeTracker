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
	DELETED	
}

var status2icon = {
	status.UNRELEASED:preload("res://res/waiting.png"),
	status.RELEASED:preload("res://res/download_2.png"),
	status.DOWNLOADED:preload("res://res/View.png"),
	status.DOWNLOADING:preload("res://res/download_in_progress.png"),
	status.WATCHING:preload("res://res/Viewed_partial.png"),
	status.WATCHED:preload("res://res/Viewed.png"),
	status.DELETED:preload("res://res/Viewed_deleted.png")
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
	_err = regex_time.compile('(\\d+)[\\./](\\d+)[\\./](\\d+) (\\d+):(\\d+)')
	
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
	
	return OS.get_unix_time_from_datetime(time_dict)

func string_from_date_time(datetime):
	return '%d.%d.%d %d:%d' % [
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

#func get_link_from_RSS(title, episode):
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
