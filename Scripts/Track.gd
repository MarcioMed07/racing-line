extends Line2D

onready var circle_scene = preload("res://Scenes/Circle.tscn")

export var curve_min_angle = 0.04
export var growth_speed = 0.7
export var reposition_speed = 0.7
export var full_solve = false

var centerPoints = []
var outerPoints = []
var innerPoints = []
var segments = []
var circles = []
var connected_dots = false;

func _ready():
	if !visible:
		return
	centerPoints = points
	arrange()
	spawn_circles()
	var time_start = OS.get_ticks_msec() 
	resolve_circles()
	var time_end = OS.get_ticks_msec()
	print(time_end - time_start, 'ms')
	pass


func _process(delta):
	if !visible:
		return
	if connected_dots:
		return
	var acc = true
	if circles.size() > 0:
		for circle in circles:
			acc = acc && circle.is_complete()
		if acc:
			if !check_final_circles_collisions():
				connected_dots = true
			update()
	pass


func angle_difference(i):
	var A = center_points_at(i)
	var B = center_points_at(i+1)
	var C = center_points_at(i+2)
	
	var a2 = B.distance_squared_to (C) 
	var b2 = A.distance_squared_to (C) 
	var c2 = A.distance_squared_to (B)  
	
	#TODO: treat in case of first/last point
	if(a2==0 || b2 ==0 || c2== 0):
		return 0
	var a = sqrt(a2)
	var b = sqrt(b2)
	var c = sqrt(c2)
	# From Cosine law 
	var alpha = acos((b2+c2-a2)/(2*b*c))
	var betta = acos((a2+c2-b2)/(2*a*c))
	var gamma = acos((a2+b2-c2)/(2*a*b))
	return alpha


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
			var A = centerPoints[segment_start]
			var B = centerPoints[segment_start+1]
			var P = centerPoints[segment_end]
			var AP = A.direction_to(P)
			var AB = A.direction_to(B)
			var curve_direction =  1 if AB.angle_to(AP) >= 0 else -1
			segments.append({start= segment_start,end=segment_end, direction = curve_direction})


func arrange():
	innerPoints.resize(centerPoints.size())
	outerPoints.resize(centerPoints.size())
	for i in range(centerPoints.size()):
		var offset = Vector2(0,width/2)
		if centerPoints.size() > 1 :#and i != 0:
			var previous = centerPoints[i-1]
			var current = centerPoints[i]
			offset = offset.rotated(previous.direction_to(current).angle())
		innerPoints[i] = centerPoints[i] + offset
		outerPoints[i] = centerPoints[i] - offset
	segment_track()
	update()
	pass

func spawn_circles():
	for i in range(0,segments.size()):
		var segment = segments[i]
		var circle = circle_scene.instance()
		circle.reposition_factor = reposition_speed
		circle.growth_factor = growth_speed
		var segment_trailling = 1
		var updated_success = false
		var start = segment.start-segment_trailling
		var end = (segment.end+segment_trailling)%innerPoints.size()
		if segment.direction > 0:
			updated_success = circle.update_points(
				innerPoints.slice(start, end),
				outerPoints.slice(start, end),
				Color.purple,
				segment.direction,
				i,
				growth_speed,
				reposition_speed
			)
		else:
			updated_success = circle.update_points(
				outerPoints.slice(start, end),
				innerPoints.slice(start, end),
				Color.yellow,
				segment.direction,
				i,
				growth_speed,
				reposition_speed
			)
		
		if(updated_success):
			circle.growth_factor = growth_speed
			circle.reposition_factor = reposition_speed
			self.add_child(circle, true)
			circles.append(circle)
		else:
			circle.free()
	pass


func resolve_circles():
	for circle in circles:
		circle.resolve(full_solve)


# if the edges of the circles touch, the distance between the centers is r1+r2;
# any greater distance and the circles don't touch or collide; and
# any less and then do collide
func circle_collision(circle_a:Vector2, circle_b:Vector2,radius_a:float, radius_b:float):
	return pow((circle_a.x-circle_b.x),2) + pow((circle_a.y-circle_b.y),2) <= pow((radius_a - radius_b),2)


func check_final_circles_collisions():
	var problem = false
	for i in range(circles.size()):
		var A = circle_at(i)
		var B = circle_at(i+1)
		var entry_point = B.entry_clipping.point
		var distance_from_circle_to_point = A.m_position.distance_to(entry_point)
		if(distance_from_circle_to_point < A.radius and !B.second_pass):
			problem = true
			B.start_second_pass(A.exit_clipping.point, full_solve)
	return problem


func connect_dots():
	for i in range(circles.size()):
		var A = circles[i].exit_clipping.point
		var B = circles[(i+1)%circles.size()].entry_clipping.point
		draw_line(A,B,Color.blue,2)
		circles[i].update()


func circle_at(i) -> Circle:
	return circles[i%circles.size()]


func center_points_at(i):
	return centerPoints[(i)%centerPoints.size()]


func print_track():
	print("[")
	for point in centerPoints:
		print("Vector2",point,",")
	print("]")


func _draw():
	var default_font = Control.new().get_font("font")
	
	for i in range(centerPoints.size()):
		draw_circle(center_points_at(i), 2, Color.black)
	for i in range(segments.size()):
		draw_string(default_font, centerPoints[segments[i].start], "s-"+str(i))
		draw_circle(centerPoints[segments[i].start], 2, Color.green)
		draw_string(default_font, centerPoints[segments[i].end], "e-"+str(i))
		draw_circle(centerPoints[segments[i].end], 2, Color.red)

	for i in range(outerPoints.size()):
		if(i < outerPoints.size()-1):
			draw_line(outerPoints[i], outerPoints[i+1],  Color.black, 2)
	for i in range(innerPoints.size()):
		if(i < innerPoints.size()-1):
			draw_line(innerPoints[i], innerPoints[i+1],  Color.black, 2)
	draw_line(innerPoints[0], outerPoints[0],  Color.black, 2)
	if connected_dots:
		connect_dots()
	pass
