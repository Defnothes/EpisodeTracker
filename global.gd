extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
enum status{
	UNRELEASED,
	RELEASED,
	DOWNLOADED,
	WATCHED,
	DELETED	
}

var status2icon = {
	status.UNRELEASED:preload("res://res/waiting.png"),
	status.RELEASED:preload("res://res/download_2.png"),
	status.DOWNLOADED:preload("res://res/View.png"),
	status.WATCHED:preload("res://res/viewed.png"),
	status.DELETED:preload("res://res/deleted.png")
}

var default_epnr_regex : RegEx

# Called when the node enters the scene tree for the first time.
func _ready():
	default_epnr_regex = RegEx.new()
	var _err = default_epnr_regex.compile('- (\\d\\d)')
	for key in status2icon.keys():
		var im = status2icon[key].get_data()
		im.resize(16,16)
		status2icon[key] = ImageTexture.new()
		status2icon[key].create_from_image(im)
	

func list_files_in_directory(path):
	var file_list = []
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while (file_name != ""):
			if not dir.current_is_dir():
				file_list.append(file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return file_list

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
