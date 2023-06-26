extends OptionButton

onready var controller = $"../.."

onready var Custom = preload("res://Scenes/Tracks/Random.tscn")
onready var Oval = preload("res://Scenes/Tracks/Oval.tscn")
onready var Interlagos = preload("res://Scenes/Tracks/Interlagos.tscn")
onready var Nurburgring = preload("res://Scenes/Tracks/Nurburgring.tscn")
onready var Monaco = preload("res://Scenes/Tracks/Monaco.tscn")
onready var Monza = preload("res://Scenes/Tracks/Monza.tscn")
var tracks = []
func _ready():
	tracks = [Custom,Oval,Interlagos,Nurburgring,Monaco]
	add_item('Custom',0)
	add_item('Oval',1)
	add_item('Interlagos',2)
	add_item('Nurburgring',3)
	add_item('Monaco',4)
	add_item('Monza',4)
	selected = -1



func _on_track_selected(index):
	var old_track = controller.get_node('Track')
	if is_instance_valid(old_track):
		controller.remove_child(old_track)
		old_track.queue_free()
	var new_track = tracks [index]
	var new_track_instace = new_track.instance()
	new_track_instace.set_name('Track')
	controller.add_child(new_track_instace)
	
	pass # Replace with function body.
