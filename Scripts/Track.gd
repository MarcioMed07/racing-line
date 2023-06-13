extends Line2D

onready var circle_scene = preload("res://Scenes/Circle.tscn")
onready var controller = $".."

export var curve_min_angle = 0.04

export var racing_line_width = 1.5
export var racing_line_color = Color.blue
export var show_center_points = true
export var show_curve_definitions = true
export var track_border_width = 1
export var track_border_color = Color.black
export var connect_dots = true

var started = false
var arranged = false
var full_solve = false
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
var point_distance = 7

var frictionCoefficient = 1.7
var gravity = 10
var race = false
var cars = [
	{
		speed=100,
		max_speed = 100,
		acceleration=14.2,
		deceleration = 39,
		position = Vector2.ZERO,
		distance = 0,
		breaking_for_index = -1,
		speed_index = -1,
		line = racingLinePoints,
		curve_speed = racingLineSpeeds,
		length = racing_line_length,
		color = Color.blue,
		will_brake = true,
		use_racing_line = true
	},
	{
		max_speed = 100,
		speed=100,
		acceleration=14.2,
		deceleration = 39,
		position = Vector2.ZERO,
		distance = 0,
		breaking_for_index = -1,
		speed_index = -1,
		line = centerPoints,
		curve_speed = racingLineSpeeds,
		length = racing_line_length,
		color = Color.black,
		will_brake = true,
		use_racing_line = false
	},
	{
		max_speed = 100,
		speed=100,
		acceleration=14.2,
		deceleration = 39,
		position = Vector2.ZERO,
		distance = 0,
		breaking_for_index = -1,
		speed_index = -1,
		line = centerPoints,
		curve_speed = racingLineSpeeds,
		length = racing_line_length,
		color = Color.red,
		will_brake = false,
		use_racing_line = true
	},
	{
		max_speed = 100,
		speed=100,
		acceleration=14.2,
		deceleration = 39,
		position = Vector2.ZERO,
		distance = 0,
		breaking_for_index = -1,
		speed_index = -1,
		line = centerPoints,
		curve_speed = racingLineSpeeds,
		length = racing_line_length,
		color = Color.yellow,
		will_brake = false,
		use_racing_line = false
	},
	{
		max_speed = 100,
		speed=100,
		acceleration = -1,
		deceleration = -1,
		position = Vector2.ZERO,
		distance = 0,
		breaking_for_index = -1,
		speed_index = -1,
		line = centerPoints,
		curve_speed = racingLineSpeeds,
		length = racing_line_length,
		color = Color.green,
		will_brake = true,
		use_racing_line = true
	},
	{
		max_speed = 100,
		speed = 100,
		acceleration = -1,
		deceleration = -1,
		position = Vector2.ZERO,
		distance = 0,
		breaking_for_index = -1,
		speed_index = -1,
		line = centerPoints,
		curve_speed = racingLineSpeeds,
		length = racing_line_length,
		color = Color.pink,
		will_brake = true,
		use_racing_line = false
	}
]

var default_font = Control.new().get_font("font")




func _ready():
	if !visible:
		return
	for car in cars:
		car.speed = 0
	reload_track()

func _process(delta):
	if !visible or !started:
		return
	if !completed:
		track_process()
		return
	if race:
		for car in cars:
			car_distance_setup(car, delta)
			var curve_results = car_curve_speed_calculation(car)
			var curve_speed = curve_results[0]
			var next_curve_speed = curve_results[1]
			var distance_to_next_curve = curve_results[2]
			if car.will_brake:
				car_speed_with_brake(car,curve_speed,next_curve_speed,distance_to_next_curve,delta)
			else:
				car.speed = car.max_speed
	update()
	pass

func start(fullSolve):
	started = true
	full_solve = fullSolve
	arrange()
	spawn_circles()
	var time_start = OS.get_ticks_msec() 
	resolve_circles()
	var time_end = OS.get_ticks_msec()
	print(time_end - time_start, 'ms')
	update()
	pass

func reload_track():
	started = false
	arranged = false
	centerPoints = normalize_track(points,point_distance)
	centerSpeeds = []
	outerPoints = []
	innerPoints = []
	racingLinePoints = []
	racingLineSpeeds = []
	segments = []
	for circle in circles:
		remove_child(circle)
		circle.queue_free()
	circles = []
	connected_dots = false
	track_length = 0
	racing_line_length = 0
	completed = false
	for car in cars:
		car.distance = 0
		car.position = Vector2.ZERO
	update()




func normalize_track(path: Array, distance: float) -> Array:
	var equidistant_points: Array = []
	var total_length: float = calculate_path_length(path)

	equidistant_points.append(path[0])  # Add the first point from the original path

	var accumulated_distance: float = 0.0
	var previous_point: Vector2 = path[0]

	for i in range(1, path.size()):
		var current_point: Vector2 = path[i]
		var segment_length: float = previous_point.distance_to(current_point)

		while accumulated_distance + segment_length >= distance:
			var remaining_distance: float = distance - accumulated_distance
			var interpolation_ratio: float = remaining_distance / segment_length
			var interpolated_point: Vector2 = interpolate_points(previous_point, current_point, interpolation_ratio)
			equidistant_points.append(interpolated_point)

			previous_point = interpolated_point
			segment_length -= remaining_distance
			accumulated_distance = 0.0

		accumulated_distance += segment_length
		previous_point = current_point

	equidistant_points.append(path[path.size() - 1])  # Add the last point from the original path

	return equidistant_points


func calculate_path_length(path: Array) -> float:
	var total_length: float = 0.0

	for i in range(1, path.size()):
		var previous_point: Vector2 = path[i - 1]
		var current_point: Vector2 = path[i]
		total_length += previous_point.distance_to(current_point)

	return total_length

func interpolate_points(point1: Vector2, point2: Vector2, ratio: float) -> Vector2:
	return point1.linear_interpolate(point2, ratio)


func track_process():
	if connected_dots:
		return
	var acc = true
	if circles.size() > 0:
		for circle in circles:
			acc = acc && circle.completed
		if acc:
			if !check_final_circles_collisions():
				completed()
				connected_dots = true
			update()


func segment_track():
	segments = []
	var is_segmenting = false
	var segment_start = null
	var segment_end = null
	var angle_tolerance = 0.999
	var min_curve_angle = 0.85
	var last_angle = 0
	for i in range(centerPoints.size() - 1):
		var prev_point = centerPoints[i - 1]
		var current_point = centerPoints[i]
		var next_point = centerPoints[i + 1]
		var direction = (next_point - current_point).normalized()
		var angle = direction.angle_to((prev_point - current_point).normalized()) / PI
		if !is_segmenting and abs(angle) < angle_tolerance and angle != 0:
			is_segmenting = true
			segment_start = i
		elif is_segmenting and (abs(angle) > angle_tolerance or sign(last_angle) != sign(angle)):
			segment_end = i
			is_segmenting = false
			var first_point = centerPoints[segment_start]
			var middle_point  = centerPoints[floor((segment_start+segment_end)/2)]
			var final_point = centerPoints[segment_end]
			var total_curve_angle = (final_point - middle_point).normalized().angle_to((first_point - middle_point).normalized()) / PI
			if total_curve_angle != 0:
				segments.append({start = segment_start, end = segment_end, direction = sign(total_curve_angle)})
		last_angle = angle
	
	var i = -1
	var max_distance_to_combine = 100/point_distance
	var always_combine_distance = 25/point_distance
	var always_combine_size = 25/point_distance
	while i < segments.size():
		i += 1
		if(i >= segments.size()):
			break
		var curr_segment = segments[i]
		var first_point = centerPoints[curr_segment.start]
		var middle_point  = centerPoints[floor((curr_segment.start+curr_segment.end)/2)]
		var final_point = centerPoints[curr_segment.end]
		var total_curve_angle = abs((final_point - middle_point).normalized().angle_to((first_point - middle_point).normalized()) / PI)
		var prev_segment = segments[i-1]
		var next_segment = segments[(i+1)%segments.size()]
		var prev_proximity = abs(curr_segment.start - prev_segment.end)
		var next_proximity = abs(curr_segment.end - next_segment.start)
		
		if(total_curve_angle > min_curve_angle):
			if prev_proximity < max_distance_to_combine and prev_proximity <= next_proximity and curr_segment.direction == prev_segment.direction:
				segments[i-1].end = curr_segment.end
				segments.remove(i)
				i-=1
				continue
			elif next_proximity < max_distance_to_combine and next_proximity < prev_proximity and curr_segment.direction == next_segment.direction:
				segments[(i+1)%segments.size()].start = curr_segment.start
				segments.remove(i)
				i-=1
				continue
		if prev_proximity <= always_combine_distance and ((curr_segment.end-curr_segment.start) < always_combine_size or curr_segment.direction == prev_segment.direction):
			segments[i-1].end = curr_segment.end
			segments.remove(i)
			i-=1
			continue
		if next_proximity <= always_combine_distance and ((curr_segment.end-curr_segment.start) < always_combine_size  or curr_segment.direction == next_segment.direction):
			segments[(i+1)%segments.size()].start = curr_segment.start
			segments.remove(i)
			i-=1
			continue
#			else:
#				segments.remove(i)
#				i-=1
		

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
	arranged = true
	update()
	pass


func calculate_circle_radius(point1: Vector2, point2: Vector2, point3: Vector2) -> float:
	var dx12 = point1.x - point2.x
	var dx13 = point1.x - point3.x
	var dy12 = point1.y - point2.y
	var dy13 = point1.y - point3.y
	var dy31 = point3.y - point1.y
	var dy21 = point2.y - point1.y
	var dx31 = point3.x - point1.x
	var dx21 = point2.x - point1.x

	var sx13 = pow(point1.x, 2) - pow(point3.x, 2)
	var sy13 = pow(point1.y, 2) - pow(point3.y, 2)
	var sx21 = pow(point2.x, 2) - pow(point1.x, 2)
	var sy21 = pow(point2.y, 2) - pow(point1.y, 2)

	var d1 = (2 * (dy31 * dx12 - dy21 * dx13)) if (2 * (dy31 * dx12 - dy21 * dx13)) != 0 else pow(10, -10)
	var d2 = (2 * (dx31 * dy12 - dx21 * dy13)) if (2 * (dx31 * dy12 - dx21 * dy13)) != 0 else pow(10, -10)

	var f = (sx13 * dx12 + sy13 * dx12 + sx21 * dx13 + sy21 * dx13) / d1
	var g = (sx13 * dy12 + sy13 * dy12 + sx21 * dy13 + sy21 * dy13) / d2

	var c = -(pow(point1.x, 2)) - pow(point1.y, 2) - 2 * g * point1.x - 2 * f * point1.y

	var h = -g
	var k = -f
	var sqr_of_r = h * h + k * k - c

	return sqrt(sqr_of_r)



func spawn_circles():
	for i in range(0,segments.size()):
		var segment = segments[i]
		var next_segment = segments[(i+1)%segments.size()]
		var prev_segment = segments[i-1]
		
		var circle = circle_scene.instance()
		
		var segment_trailling = 10
		var updated_success = false
		
		var start = prev_segment.end if i > 0 else 0 #floor((prev_segment.end + segment.start)/2) if i > 0 else 0
		var end = next_segment.start if i < segments.size()-1 else centerPoints.size() #floor((next_segment.start + segment.end)/2) if i < segments.size()-1 else centerPoints.size()
		
		var inner_bounds = (innerPoints if segment.direction > 0 else outerPoints).slice(segment.start, segment.end)
		var outer_bounds = (outerPoints if segment.direction > 0 else innerPoints).slice(start, end)
		
		var color = Color.purple if segment.direction > 0 else Color.yellow
		updated_success = circle.update_points(inner_bounds, outer_bounds, color,segment.direction, i)
		
		if(updated_success):
			self.add_child(circle, true)
			circles.append(circle)
		else:
			circle.free()
	pass


func resolve_circles():
	for circle in circles:
		circle.resolve(full_solve)


func circle_collision(circle_a:Vector2, circle_b:Vector2,radius_a:float, radius_b:float):
	return pow((circle_a.x-circle_b.x),2) + pow((circle_a.y-circle_b.y),2) <= pow((radius_a - radius_b),2)


func check_final_circles_collisions():
	var problem = false
	for i in range(circles.size()):
		var A = circle_at(i)
		var B = circle_at(i+1)
		var entry_point = B.entry_clipping.point
		var distance = A.m_position.distance_to(B.m_position)
		var sum_of_radii = A.radius + B.radius

#		var distance_from_circle_to_point = A.m_position.distance_to(entry_point)
#		if(distance_from_circle_to_point < A.radius and !B.second_pass):
		var threshold = -2
		if distance-sum_of_radii <= threshold and A.direction != B.direction and B.second_pass == false:
			problem = true
			B.start_second_pass(A.exit_clipping.point, full_solve)
	return problem


func check_circles_out_collision(i,j):
	var first_curve_distance = circle_at(i).exit_clipping.point.distance_to(center_points_at(segments[i].end))
	var second_curve_distance = circle_at(j).entry_clipping.point.distance_to(center_points_at(segments[i].end))
	return second_curve_distance < first_curve_distance

func wrap_degrees(angle_from,angle_to):
	if(angle_from < 0):
		angle_from += 360
	if(angle_to < 0):
		angle_to += 360
	if(angle_to < angle_from):
		angle_to += 360
	return [angle_from,angle_to]

var t = []
func get_intersection_point(i):
	var circle = circle_at(i)
	var next_circle = circle_at(i+1)
	var circles_collided = check_circles_out_collision(i, i+1)
	var entry_minus_exit = (circle_at(i + 1).entry_clipping.point + circle_at(i).exit_clipping.point)/2
	t.append(entry_minus_exit)
	return null if !circles_collided else next_circle.m_position + (entry_minus_exit - next_circle.m_position).normalized() * next_circle.radius
##
#	var distance = next_circle.m_position.distance_to(circle.m_position)
#	var radiusSum = circle.radius + next_circle.radius
#	var radiusDiff = abs(circle.radius - next_circle.radius)
#	var threshold = 4
#	if abs(distance - radiusSum) < threshold or abs(distance - radiusDiff) <threshold:
#		var direction = (next_circle.m_position - circle.m_position).normalized()
#		t.append(circle.m_position + direction * circle.radius)
#		return null if !circles_collided else circle.m_position + direction * circle.radius
#
#	return null

func append_points_to_racing_line(entry_angle,exit_angle,r,center,direction,points_between):
	points_between = floor(max(points_between,10))
	var local_points = []
	var local_speeds = []
	var angle = entry_angle
	var angle_increment = (exit_angle - entry_angle) / float(points_between - 1)
	var curve_speed = sqrt(frictionCoefficient * gravity * r)
	for i in range(points_between):
		var x = center.x + r * cos(angle)
		var y = center.y + r * sin(angle)
		
		local_points.append(Vector2(x, y))
		local_speeds.append(curve_speed)
		angle += angle_increment
	racingLinePoints += local_points
	racingLineSpeeds += local_speeds


func convertToPositiveAngle(angle: float) -> float:
	var convertedAngle  = angle + (2*PI)
	convertedAngle = fmod(convertedAngle, (2.0*PI))
	return convertedAngle


func completed():
	controller.changePanel(2)
	find_curve_speeds()
	var new_angles = []
	var center_points = []

	for i in range(circles.size()):
		new_angles.append({angle_to= null, angle_from= null})

	for i in range(circles.size()):
		var circle = circle_at(i)
		var next_circle_index = (i + 1) % circles.size()
		var intersection_point = get_intersection_point(i) 
		if intersection_point != null:
			new_angles[i].angle_to = (intersection_point.angle_to_point(circle.m_position))
			new_angles[next_circle_index].angle_from = (intersection_point.angle_to_point(circle_at(next_circle_index).m_position))
	
	for i in range(circles.size()):
		var circle = circle_at(i)
		var angle_to = null
		var angle_from = null
		if(new_angles[i].angle_to == null):
			angle_to = (circle.exit_clipping.point.angle_to_point(circle.m_position))
		else:
			angle_to = (new_angles[i].angle_to)
			
		if(new_angles[i].angle_from == null):
			angle_from = (circle.entry_clipping.point.angle_to_point(circle.m_position))
		else:
			angle_from = (new_angles[i].angle_from)
		if (angle_to) < (angle_from) and circle.direction > 0:
			angle_to = convertToPositiveAngle(angle_to)
		if angle_from < angle_to and circle.direction < 0:
			angle_from = convertToPositiveAngle(angle_from)
		print([i,angle_from,angle_to])
		append_points_to_racing_line((angle_from), (angle_to), circle.radius, circle.m_position,circle.direction,circle.entry_clipping.point.distance_to(circle.exit_clipping.point)/10)
#		if circle.direction > 0:
#			append_points_to_racing_line((angle_from), (angle_to), circle.radius, circle.m_position,circle.direction,circle.entry_clipping.point.distance_to(circle.exit_clipping.point)/10)
#		else:
#			append_points_to_racing_line((angle_to), (angle_from), circle.radius, circle.m_position,circle.direction,circle.entry_clipping.point.distance_to(circle.exit_clipping.point)/10)
	for j in range(1):
		for i in racingLinePoints.size():
			var curr_point = racingLinePoints[i]
			var prev_point = racingLinePoints[i-1]
			var next_point = racingLinePoints[(i+1)%racingLinePoints.size()]
		
			racingLinePoints[i] = (2*curr_point+prev_point+next_point)/4
#	for i in range(circles.size()):
#		var circle = circle_at(i)
#		var angle_from = rad2deg(circle.entry_clipping.point.angle_to_point(circle.m_position))
#		var angle_to = rad2deg(circle.exit_clipping.point.angle_to_point(circle.m_position))
#		if(new_angles[i].angle_to != null):
#			angle_to = new_angles[i].angle_to
#		if(new_angles[i].angle_from != null):
#			angle_from = new_angles[i].angle_from 
#
#		[angle_from,angle_to] = wrap_degrees(angle_from,angle_to)
#
#		if circle.direction > 0:
#			append_points_to_racing_line(deg2rad(angle_from), deg2rad(angle_to), circle.radius, circle.m_position,circle.direction,circle.entry_clipping.point.distance_to(circle.exit_clipping.point)/10)
#		else:
#			append_points_to_racing_line(deg2rad(angle_to), deg2rad(angle_from+360), circle.radius, circle.m_position,circle.direction,circle.entry_clipping.point.distance_to(circle.exit_clipping.point)/10)

#	racingLinePoints.push_front(center_points_at(0))
#	racingLineSpeeds.push_front(-1)
	print({'racing line length':get_line_length(racingLinePoints), 'track center length':get_line_length(centerPoints)})
	
	for car in cars:
		if car.use_racing_line:
			car.line = racingLinePoints
			car.curve_speed = racingLineSpeeds
		else:
			car.line = centerPoints
			car.curve_speed = centerSpeeds
		car.length = get_line_length(car.line)
		
	completed = true


func get_line_length(line):
	var length = 0
	for i in range(line.size()):
		length += line[i-1].distance_to(line[i])
	return length


func get_point_at_distance(distance, line):
	if distance >= get_line_length(line):
		distance = 0
	var curr_distance = 0
	var last_distance = 0
	var curr_segment = -1
	var segment_distance = 0
	var segment_ran_distance = 0
	for i in range(line.size()):
		segment_distance = line[i].distance_to(line[(i+1)%line.size()])
		curr_distance += segment_distance
		if curr_distance >= distance:
			segment_ran_distance = distance-last_distance
			curr_segment = (i+1)%line.size()
			break
		pass
		last_distance = curr_distance
	var direction = line[curr_segment-1].direction_to(line[curr_segment])
	var n_position = line[curr_segment-1] + direction * segment_ran_distance
	var distance_to_next_segment = segment_distance - segment_ran_distance
	return [n_position , curr_segment, distance, distance_to_next_segment]


func distance_between_line_indexes(line,distance,target):
	var acc = 0
	for i in range(target):
		acc += array_at(line,i).distance_to(array_at(line,i+1))
	return acc - distance if acc - distance > 0 else acc - distance + get_line_length(line)







func car_distance_setup(car, delta):
	car.distance += car.speed * delta
	var result = get_point_at_distance(car.distance, car.line)
	car.position = result[0]
	car.speed_index = result[1]
	car.distance = result[2]


func find_curve_speeds():
	for i in range(centerPoints.size()):
		centerSpeeds.append(-1)
	for segment in segments:
		var p1 = centerPoints[segment.start]
		var p2 = centerPoints[floor((segment.start+segment.end)/2)]
		var p3 = centerPoints[segment.end]
		var r = calculate_circle_radius(p1,p2,p3)
		var segment_speed = sqrt(frictionCoefficient * gravity * r)
		for i in range(segment.start+1,segment.end):
			centerSpeeds[i] = segment_speed
		pass
	pass

func car_curve_speed_calculation(car):
	var curve_speed = array_at(car.curve_speed,car.speed_index)
	if car.speed_index > car.breaking_for_index or car.speed_index == 0:
		car.breaking_for_index = -1
	var next_curve_index = car.speed_index
	var next_curve_speed = array_at(car.curve_speed,next_curve_index)
	while curve_speed == next_curve_speed:
		next_curve_index += 1
		next_curve_speed = array_at(car.curve_speed,next_curve_index)
	var distance_to_next_curve = distance_between_line_indexes(car.line,car.distance,next_curve_index)
	return [curve_speed,next_curve_speed, distance_to_next_curve]


func car_speed_with_brake(car,curve_speed,next_curve_speed, distance_to_next_curve, delta):
	var brake = car.breaking_for_index == car.speed_index
	var brake_distance = ((pow(next_curve_speed,2) - pow(car.speed ,2)) / ( 2*-car.deceleration)) + ((car.speed+car.acceleration) * delta)
	if brake_distance > 0 and car.deceleration != -1:
		if brake_distance  > distance_to_next_curve:
			car.breaking_for_index = car.speed_index
			brake = true
	var curr_max_speed = curve_speed if curve_speed != - 1 and curve_speed < car.max_speed else car.max_speed
	if brake:
		car.speed = car.speed - car.deceleration*delta
	elif car.acceleration != -1:
		car.speed = car.speed + car.acceleration*delta if car.speed + car.acceleration*delta <= curr_max_speed else curr_max_speed
	if car.acceleration == -1:
		car.speed = curr_max_speed
		pass





func draw_track_line(line,speeds, color, width):
	for i in range(line.size()):
		if connect_dots:
			draw_line(line[i-1],line[i],color,width)
		if show_center_points:
			draw_circle(line[i],width*2,color)


func circle_at(i) -> Circle:
	return circles[i%circles.size()]

func array_at(array,i):
	return array[i%array.size()]


func center_points_at(i):
	return centerPoints[(i)%centerPoints.size()]


func print_track():
	print("[")
	for point in centerPoints:
		print("Vector2",point,",")
	print("]")


func isPaused():
	var paused = true
	for circle in circles:
		paused = circle.paused and paused
	return paused


func setPaused(value):
	for circle in circles:
		circle.paused = value


func setSolveSpeed(speed):
	for circle in circles:
		circle.solve_speed = speed


var redraw_track = true
func first_draw():
	redraw_track = false
		
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



func draw_race():
	for car in cars:
			draw_circle(car.position, 7, Color.white)
			draw_circle(car.position, 6.5, car.color)
			
			var curve_speed = array_at(car.curve_speed,car.speed_index)
			var next_curve_speed = array_at(car.curve_speed,car.speed_index+1)
			var i = car.speed_index+1
			while curve_speed == next_curve_speed or next_curve_speed == -1:
				i = i + 1
				next_curve_speed = array_at(car.curve_speed,i)
			draw_string(default_font, car.position+Vector2(5,5), str(floor(car.speed)))

func _draw():
	if !arranged:
		return
	first_draw()
	
	if show_center_points:
		for i in range(centerPoints.size()):
			draw_circle(centerPoints[i],racing_line_width*0.8,track_border_color)
#			draw_string(default_font, centerPoints[i], str(i))
		for i in range(circles.size()):
			var circle = circle_at(i)
			if circle.completed:
				draw_arc(circle.m_position,circle.radius,0,360,7920,circle.complete_color,2)
				draw_circle(circle.apex_clipping.point,2,Color(i/circles.size(),0,0))
				draw_circle(circle.entry_clipping.point,2,Color(i/circles.size(),0,0))
				draw_circle(circle.exit_clipping.point,2,Color(i/circles.size(),0,0))
				draw_circle(circle.outer_segment[circle.middle_point_index],2,Color.blue)
		for a in t:
			draw_circle(a,3,Color.green)
	if connected_dots:
		draw_track_line(racingLinePoints, racingLineSpeeds,racing_line_color, racing_line_width)
		draw_track_line(centerPoints,[], track_border_color, racing_line_width)

	if completed:
		draw_race()

	pass
