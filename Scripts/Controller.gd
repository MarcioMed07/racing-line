extends Node2D

var cur_track
onready var control = $"CanvasLayer/Control"

var tracks = []
onready var Custom = preload("res://Scenes/Tracks/Random.tscn")
onready var Oval = preload("res://Scenes/Tracks/Oval.tscn")
onready var Interlagos = preload("res://Scenes/Tracks/Interlagos.tscn")
onready var Nurburgring = preload("res://Scenes/Tracks/Nurburgring.tscn")
onready var Monaco = preload("res://Scenes/Tracks/Monaco.tscn")

func _ready():
	cur_track = get_node("Track")
	tracks = [Custom,Oval,Interlagos,Nurburgring,Monaco]
	control.setTrackOptions(['Custom','Oval','Interlagos','Nurburgring','Monaco'])

func isPaused():
	if cur_track:
		return cur_track.isPaused()
	return false

func togglePaused():
	if cur_track:
		cur_track.setPaused(!isPaused())


func changePanel(state):
	if state == 0:
		cur_track.show_curve_definitions = true
		cur_track.connect_dots = false
		cur_track.show_center_points = true
	elif state == 1:
		cur_track.show_curve_definitions = true
		cur_track.connect_dots = false
		cur_track.show_center_points = true
	elif state == 2:
		cur_track.show_curve_definitions = false
		cur_track.connect_dots = false
		cur_track.show_center_points = false
	control.changePanelState(state)


func setCurveMinAngle(value):
	if cur_track:
		cur_track.curve_min_angle = value

func trackSelected(index):
	var old_track = get_node('Track')
	if is_instance_valid(old_track):
		remove_child(old_track)
		old_track.queue_free()
	var new_track = tracks[index]
	var new_track_instance = new_track.instance()
	new_track_instance.set_name('Track')
	add_child(new_track_instance)
	cur_track = new_track_instance

func ittStart():
	cur_track.start(false)
	changePanel(1)
	
func fullStart():
	cur_track.start(true)
	changePanel(1)

func recalculateCurves():
	cur_track.arrange()


func reloadScene():
	if cur_track:
		cur_track.reload_track()
	changePanel(0)


func _on_ShowPointsCheck_toggled(button_pressed):
	if cur_track:
		cur_track.show_center_points = button_pressed


func _on_ShowLinesCheck_toggled(button_pressed):
	if cur_track:
		cur_track.connect_dots = button_pressed


func _on_ShowCurvesCheck_toggled(button_pressed):
	if cur_track:
		cur_track.show_curve_definitions = button_pressed


func solveSpeedValueChanged(value):
	if cur_track:
		cur_track.setSolveSpeed(value)
