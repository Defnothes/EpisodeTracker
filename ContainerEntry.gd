extends HBoxContainer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var episodes = []
var watched = []
var date
var parent = null

var progress_containers = []

# Called when the node enters the scene tree for the first time.
func _ready():
	date = ''

func set_properties(title, date, epcount, 
					callback_object):
	$LabelTitle.text = title
	self.date = date
	self.watched = watched
	set_epcount(epcount)
	$LabelTitle.connect("pressed", callback_object, 'fill_details', 
						[$LabelTitle.text, date, len(episodes)])
	parent = callback_object
	set_time_remaining()
	
func set_epcount(new_epcount):
	for i in range(len(episodes),new_epcount):
		var status_button = preload("res://ButtonProgress.tscn").instance()
		get_progress_container(i, new_epcount).add_child(status_button)
		status_button.index = i
		status_button.set_watched_callback(self, 'set_watched_episode')
		episodes.append(status_button)
		check_new_releases()
		if (i+1)%4==0 and i!=new_epcount-1:
			var separator = VSeparator.new()
			get_progress_container(i, new_epcount).add_child(separator)
	#for i in range(epcount-new_epcount,epcount): -- should be manual reduction
	#	remove

func get_progress_container(index, limit):
	var container_index = 0 if limit<16 else index / 12
	while container_index >= len(progress_containers):
		var hcontainer = HBoxContainer.new()
		$ContainerSeasons.add_child(hcontainer)
		progress_containers.append(hcontainer)
	return progress_containers[container_index]

func check_new_releases():
	for ep in episodes:
		if ep.current_status == Global.status.UNRELEASED and \
				Global.is_available_by_time(date, ep.index):
			ep.set_status(Global.status.RELEASED, ep.index)

func set_episode(ep, stat, watch_action, dl_action):
	ep = ep-1
	if ep is int:
		if ep >= len(episodes):
			set_epcount(ep+1)
		episodes[ep].set_status(stat, ep)
		episodes[ep].set_watch_callback(watch_action)
		episodes[ep].set_download_callback(dl_action)
	
	
func set_watched_episode(episode, already_watched):
	if not already_watched:
		watched.erase(episode)
	else:
		watched.append(episode)
	parent.update_watched($LabelTitle.text, watched)

func update_watched_list(watched_eps):
	self.watched = watched_eps
	for ep in watched_eps:
		if ep<len(episodes):
			episodes[ep].set_status(Global.status.WATCHED,ep)
			
func set_time_remaining():
	var time_remaining = 9223372036854775807
	var time_prev = 9223372036854775807
	for ep in episodes:
		time_prev = time_remaining
		time_remaining = Global.seconds_until(date) - 7*24*3600*ep.index
		if time_prev>=0 and time_remaining<0:
				break
			
	
	$LabelTimeRemaining.set_text(Global.seconds_to_string(-time_remaining))
