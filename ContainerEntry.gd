extends HBoxContainer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var episodes = []
var watched = []
var date
var parent = null

# Called when the node enters the scene tree for the first time.
func _ready():
	set_epcount(12)
	date = ''

func set_properties(title, date, epcount, 
					watched,
					callback_object):
	$LabelTitle.text = title
	self.date = date
	self.watched = watched
	$LabelTitle.connect("pressed", callback_object, 'fill_details', 
						[$LabelTitle.text, date, len(episodes)])
	parent = callback_object
func set_epcount(new_epcount):
	for i in range(len(episodes),new_epcount):
		var status_button = preload("res://ButtonProgress.tscn").instance()
		self.add_child(status_button)
		status_button.set_watched_callback(self, 'set_watched_episode')
		episodes.append(status_button)
	#for i in range(epcount-new_epcount,epcount): -- should be manual reduction
	#	remove

func set_episode(ep, stat, watch_action, dl_action):
	ep = ep-1
	if ep is int:
		if ep > len(episodes):
			set_epcount(ep)
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
