extends Line2D

onready var circle_scene = preload("res://Scenes/Circle.tscn")

export var curve_min_angle = 0.04
export var max_radius = 300
export var use_radius = true
export var growth_speed = 0.7
export var reposition_speed = 0.7
export var full_solve = false

export var racing_line_width = 1
export var racing_line_color = Color.blue
export var show_center_points = true
export var show_curve_definitions = true
export var track_border_width = 1
export var track_border_color = Color.black
export var connect_dots = false

var centerPoints = []
var centerSpeeds = []
var outerPoints = []
var innerPoints = []
var racingLinePoints = []
var racingLineSpeeds = []
var segments = []
var circles = []
var connected_dots = false;
var solve_speed = 1;
var track_length = 0
var racing_line_length = 0;
var completed = false

var frictionCoefficient = 1.7
var gravity = 10
var cars = [
	{
		speed=100,
		max_speed = 100,
		acceleration=0,
		position = Vector2.ZERO,
		distance = 0,
		line = racingLinePoints,
		curve_speed = racingLineSpeeds,
		length = racing_line_length,
		color = racing_line_color
	},
	{
		max_speed = 100,
		speed=100,
		acceleration=0,
		position = Vector2.ZERO,
		distance = 0,
		line = centerPoints,
		curve_speed = racingLineSpeeds,
		length = racing_line_length,
		color = track_border_color
	}
]
var car_speed = 100
var car_1_distance = 0
var car_2_position = Vector2.ZERO

var default_font = Control.new().get_font("font")

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
	if !completed:
		track_process()
		return
	for car in cars:
		car.distance += car.speed * delta
		if car.distance >= car.length:
			car.distance = 0
		var result = get_point_at_distance(car.distance, car.line)
		car.position = result[0]
		var curve_speed = car.curve_speed[result[1]]
		car.speed = curve_speed if curve_speed != - 1 or curve_speed > car.max_speed else car.max_speed
		
	update()
	pass


func track_process():
	if connected_dots:
		return
	if solve_speed != $"../Control/Panel/VBoxContainer/HBoxContainer/SpinBox".value :
		solve_speed = $"../Control/Panel/VBoxContainer/HBoxContainer/SpinBox".value
		for circle in circles:
			circle.solve_speed = solve_speed
		pass
	var acc = true
	if circles.size() > 0:
		for circle in circles:
			acc = acc && circle.is_complete()
		if acc:
			if !check_final_circles_collisions():
				completed()
				connected_dots = true
			update()


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
		var a = center_points_at(i)
		var b = center_points_at(i+1)
		var c = center_points_at(i+2)
		var radius = find_radius(a.x,a.y,b.x,b.y,c.x,c.y)
		print (radius)
		if !is_segmenting and (angle > curve_min_angle if !use_radius else radius < max_radius):
			is_segmenting = true
			segment_start = i
			segment_end = null
		if is_segmenting and (angle > curve_min_angle if !use_radius else radius < max_radius):
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

func find_curve_speeds():
	for i in range(centerPoints.size()):
		centerSpeeds.append(-1)
	for segment in segments:
		var p1 = centerPoints[segment.start]
		var p2 = centerPoints[floor((segment.start+segment.end)/2)]
		var p3 = centerPoints[segment.end]
		var r = find_radius(p1.x,p1.y,p2.x,p2.y,p3.x,p3.y)
		var segment_speed = sqrt(frictionCoefficient * gravity * r)
		for i in range(segment.start+1,segment.end):
			centerSpeeds[i] = segment_speed
		
		pass
	pass


func find_radius(x1, y1, x2, y2, x3, y3) :
	var x12 = (x1 - x2);
	var x13 = (x1 - x3);

	var y12 =( y1 - y2);
	var y13 = (y1 - y3);

	var y31 = (y3 - y1);
	var y21 = (y2 - y1);

	var x31 = (x3 - x1);
	var x21 = (x2 - x1);

#	//x1^2 - x3^2
	var sx13 = pow(x1, 2) - pow(x3, 2);

#	// y1^2 - y3^2
	var sy13 = pow(y1, 2) - pow(y3, 2);

	var sx21 = pow(x2, 2) - pow(x1, 2);
	var sy21 = pow(y2, 2) - pow(y1, 2);

	var f = ((sx13) * (x12)
			+ (sy13) * (x12)
			+ (sx21) * (x13)
			+ (sy21) * (x13))/ (2 * ((y31) * (x12) - (y21) * (x13)));
	var g = ((sx13) * (y12)
			+ (sy13) * (y12)
			+ (sx21) * (y13)
			+ (sy21) * (y13))/ (2 * ((x31) * (y12) - (x21) * (y13)));

	var c = -(pow(x1, 2)) - pow(y1, 2) - 2 * g * x1 - 2 * f * y1;

#	// eqn of circle be
#	// x^2 + y^2 + 2*g*x + 2*f*y + c = 0
#	// where centre is (h = -g, k = -f) and radius r
#	// as r^2 = h^2 + k^2 - c
	var h = -g;
	var k = -f;
	var sqr_of_r = h * h + k * k - c;

#	// r is the radius
	return sqrt(sqr_of_r);


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


func check_circles_out_collision(i,j):
	var first_curve_distance = circle_at(i).exit_clipping.point.distance_to(center_points_at(segments[i].end))
	var second_curve_distance = circle_at(j).entry_clipping.point.distance_to(center_points_at(segments[i].end))
	return second_curve_distance < first_curve_distance


func completed():
	
	find_curve_speeds()
	var new_angles = []
	for i in range(circles.size()):
		new_angles.append({angle_to=null, angle_from=null})
	for i in range(circles.size()):
		var circle = circle_at(i)
		var circles_collided = check_circles_out_collision(i,i+1)
		if circles_collided:
				var center_point = (circle_at(i+1).entry_clipping.point + circle_at(i).exit_clipping.point)/2
				var magic = circle_at(i).m_position + (center_point - circle_at(i).m_position).normalized()*circle_at(i).radius
				new_angles[i].angle_to = rad2deg(magic.angle_to_point(circle.m_position))
				new_angles[(i+1)%centerPoints.size()].angle_from = rad2deg(magic.angle_to_point(circle_at(i+1).m_position))
	
	for i in range(circles.size()):
		var circle = circle_at(i)
		var angle_from = rad2deg(circle.entry_clipping.point.angle_to_point(circle.m_position))
		var angle_to = rad2deg(circle.exit_clipping.point.angle_to_point(circle.m_position))
		if(new_angles[i].angle_to != null):
			angle_to = new_angles[i].angle_to
		if(new_angles[i].angle_from != null):
			angle_from = new_angles[i].angle_from 
		if(angle_from < 0):
			angle_from += 360
		if(angle_to < 0):
			angle_to += 360
		if(angle_to < angle_from):
			angle_to += 360
		if circle.direction > 0:
			append_points_to_racing_line(deg2rad(angle_from), deg2rad(angle_to), circle.radius, circle.m_position,circle.direction,circle.entry_clipping.point.distance_to(circle.exit_clipping.point)/10)
		else:
			append_points_to_racing_line(deg2rad(angle_to), deg2rad(angle_from+360), circle.radius, circle.m_position,circle.direction,circle.entry_clipping.point.distance_to(circle.exit_clipping.point)/10)
	racingLinePoints.push_front(center_points_at(0))
	racingLineSpeeds.push_front(-1)
	print({'racing line length':get_line_length(racingLinePoints), 'track center length':get_line_length(centerPoints)})
	cars[0].line = racingLinePoints
	cars[0].curve_speed = racingLineSpeeds
	cars[1].line = centerPoints
	cars[1].curve_speed = centerSpeeds
	for car in cars:
		car.length = get_line_length(car.line)
	completed = true


func get_line_length(line):
	var length = 0
	for i in range(centerPoints.size()):
		length += centerPoints[i-1].distance_to(centerPoints[i])
	return length



func get_point_at_distance(distance, line):
	var curr_distance = 0
	var last_distance = 0
	var curr_segment = -1
	var segment_distance = 0
	for i in range(line.size()):
		segment_distance = line[i].distance_to(line[(i+1)%line.size()])
		curr_distance += segment_distance
		if curr_distance >= distance:
			segment_distance = distance-last_distance
			curr_segment = (i+1)%line.size()
			break
		pass
		last_distance = curr_distance
	var direction = line[curr_segment-1].direction_to(line[curr_segment])
	return [line[curr_segment-1] + direction * segment_distance, curr_segment]


func append_points_to_racing_line(entry_angle,exit_angle,r,center,direction,points_between):
	points_between = floor(points_between)
	points_between = max(points_between,10)
	var curve_speed = sqrt(frictionCoefficient * gravity * r)
	var local_points = []
	var local_speeds = []
	for j in range(1,points_between):
		var anglePoint = entry_angle + j*(exit_angle-entry_angle)/points_between
		var curr_point = Vector2(cos(anglePoint),sin(anglePoint)) * r + center
		local_points.append(curr_point)
		local_speeds.append(curve_speed)
	if direction > 0:
		racingLinePoints += local_points
	else:
		var local_points_inv = local_points.duplicate()
		local_points_inv.invert()
		racingLinePoints += local_points_inv
	local_speeds[0] = -1
	racingLineSpeeds += local_speeds

	

func draw_track_line(line,speeds, color, width):
	for i in range(line.size()):
		if connect_dots:
			draw_line(line[i-1],line[i],color,width)
		draw_circle(line[i],width*0.8,color)
		if cars[1].curve_speed.size() > i:
			draw_string(default_font,line[i], str(cars[1].curve_speed[i]))


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
	
	if show_curve_definitions:
		for i in range(segments.size()):
			draw_string(default_font, centerPoints[segments[i].start], "s-"+str(i))
			draw_circle(centerPoints[segments[i].start], 2, Color.green)
			draw_string(default_font, centerPoints[segments[i].end], "e-"+str(i))
			draw_circle(centerPoints[segments[i].end], 2, Color.red)

	for i in range(outerPoints.size()):
		if(i < outerPoints.size()-1):
			draw_line(outerPoints[i], outerPoints[i+1],  track_border_color, track_border_width)
	for i in range(innerPoints.size()):
		if(i < innerPoints.size()-1):
			draw_line(innerPoints[i], innerPoints[i+1],  track_border_color, track_border_width)
	draw_line(innerPoints[0], outerPoints[0],  Color.black, 2)
	
	
	
	if connected_dots:
		draw_track_line(racingLinePoints, racingLineSpeeds,racing_line_color, racing_line_width)
		draw_track_line(centerPoints,[], track_border_color, track_border_width)
#		draw_curves()
#		connect_dots()
	if completed:
		for car in cars:
			draw_circle(car.position, 7, Color.white)
			draw_circle(car.position, 6.5, car.color)
			draw_string(default_font, car.position+Vector2(5,5), str(floor(car.speed)))
	pass
