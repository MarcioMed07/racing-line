extends Line2D

onready var circle_scene = preload("res://Scenes/Circle.tscn")

export var curve_min_angle = 4

var centerPoints = []
var outerPoints = []
var innerPoints = []
var segments = []


func _ready():
	centerPoints = points
	arrange()
	pass


func angle_difference(i):
	var A = centerPoints[(i-1)%centerPoints.size()]
	var B = centerPoints[i]
	var C = centerPoints[(i+1)%centerPoints.size()]
	
	
	var a2 = B.distance_squared_to (C) 
	var b2 = A.distance_squared_to (C) 
	var c2 = A.distance_squared_to (B) 
  
	# length of sides be a, b, c 
	var a = sqrt(a2); 
	var b = sqrt(b2); 
	var c = sqrt(c2); 

	if(a==0 || b ==0 || c== 0):
		return 0
	
	# From Cosine law 
	var alpha = acos((b2 + c2 - a2) / (2 * b * c)); 
	var betta = acos((a2 + c2 - b2) / (2 * a * c)); 
	var gamma = acos((a2 + b2 - c2) / (2 * a * b)); 

	# Converting to degree 
	alpha = alpha * 180 / PI; 
	betta = betta * 180 / PI; 
	gamma = gamma * 180 / PI;
	
	return gamma


func segment_track():
	var is_segmenting = false
	var segment_start = null
	var segment_end = null
	segments = []
	for i in range(centerPoints.size()):
		var angle =  angle_difference(i)
		if(!is_segmenting and angle > curve_min_angle):
			is_segmenting = true
			segment_start = i
			segment_end = null
		if(is_segmenting and angle <= curve_min_angle):
			is_segmenting = false
			segment_end = i
			var curve_direction =  1 if centerPoints[segment_start].angle_to(centerPoints[segment_end]) >0 else -1
			segments.append({start= segment_start,end=segment_end, direction = curve_direction})


func arrange():
	innerPoints.resize(centerPoints.size())
	outerPoints.resize(centerPoints.size())
	for i in range(centerPoints.size()):
		var offset = Vector2(0,width/2)
		if centerPoints.size() > 1 and i != 0:
			var previous = centerPoints[i-1]
			var current = centerPoints[i]
			offset = offset.rotated(previous.direction_to(current).angle())
		innerPoints[i] = centerPoints[i] + offset
		outerPoints[i] = centerPoints[i] - offset	
	segment_track()
	for segment in segments:
		var circle = circle_scene.instance()
		var updated_success = false
		if true:
			updated_success = circle.update_points(
				innerPoints.slice(segment.start-1, (segment.end+1)%innerPoints.size()),
				outerPoints.slice(segment.start-1, (segment.end+1)%outerPoints.size()),
				Color.purple
			)
		else:
			updated_success = circle.update_points(
				outerPoints.slice(segment.start-1, (segment.end+1)%innerPoints.size()),
				innerPoints.slice(segment.start-1, (segment.end+1)%innerPoints.size()),
				Color.yellow
			)
		
		if(updated_success):
			self.add_child(circle, true)
		else:
			circle.free()
	update()
	pass


func _input(event):
	return
	if event.is_action_pressed("undo"):
		centerPoints.pop_back()
		arrange()
	if event is InputEventMouseButton:
		if event.pressed:
			var point = event.position
			centerPoints.append(point)
			arrange()


func _draw():
	var default_font = Control.new().get_font("font")
	
	for i in range(segments.size()):
		draw_string(default_font, centerPoints[segments[i].start], str(i))

	for i in range(outerPoints.size()):
		if(i < outerPoints.size()-1):
			draw_line(outerPoints[i], outerPoints[i+1],  Color.green if angle_difference(i) <= curve_min_angle else Color.red, 1)
	for i in range(innerPoints.size()):
		if(i < innerPoints.size()-1):
			draw_line(innerPoints[i], innerPoints[i+1],  Color.green if angle_difference(i) <= curve_min_angle else Color.red, 1)
	pass
