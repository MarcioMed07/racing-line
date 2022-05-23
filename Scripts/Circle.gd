extends Node2D

class_name Circle

onready var process_button = $"../../Panel/VBoxContainer/CheckButton"

export var m_position: Vector2
export var growth_factor = 0.1
export var reposition_factor:float = 0.1
export var radius = 10
export var solve_speed = 10

var cur_itt = 0
var max_itt = 15000

var direction = 1
var index = -1
var entry_clipping = {
	distance = INF,
	hit = false,
	point = Vector2(INF,INF),
	index = -1,
}

var exit_clipping = {
	distance = INF,
	hit = false,
	point = Vector2(INF,INF),
	index = -1,
}

var apex_clipping = {
	distance = -INF,
	hit = false,
	point = Vector2(INF,INF),
	index = -1,
}

var outer_segment = []
var inner_segment = []

var complete_color = Color.gray
var hit_threshold_entry_exit = 0.35
var hit_threshold_apex = 0.05
var completed = false

var is_running = false
var second_pass = false
var second_pass_goal = Vector2.ZERO

func _ready():
	cur_itt = 0
	pass

func _physics_process(delta):
	update()

func _process(delta):
	if is_running:
		if second_pass == false:
			first_pass_process()
		else:
			second_pass_process()
	pass

func first_pass_process():
	if is_complete():
		is_running = false
		return
	if is_running:
		for i in range(solve_speed):
			step()

func second_pass_process():
	if is_complete():
		is_running = false
		return
	if is_running:
		for i in range(solve_speed):
			step()


##Calculate 1 step of the circle proccess
func step():
	if !grow_circle():
		move_circle()
	update_hits()
	cur_itt += 1

## Calculate steps until circle proccess is complete
func resolve(full = false):
	if !full:
		is_running = true
		return
	var completed = false
	while !completed:		
		if second_pass == false:
			first_pass_process()
		else:
			second_pass_process()
		completed = is_complete()
		is_running = !completed

## Circle proccess is complete when the circle hits the outer lines at entry and exit and the apex on the inside line
func is_complete():
	if completed:
		return true
	if (entry_clipping.hit and exit_clipping.hit and apex_clipping.hit):
		completed = true
		return true
#	if( cur_itt > max_itt ) or (second_pass and (cur_itt > 600)):
#		completed = true
#		return true
	return false

## Verifies if the circle hit the lines at the clipping points
func update_hits():
	entry_clipping.hit = entry_clipping.distance - growth_factor *2 < radius
	exit_clipping.hit = exit_clipping.distance  - growth_factor *2 < radius
	apex_clipping.hit = apex_clipping.distance - radius > hit_threshold_apex


## Increases the circle radius if it's not touching the outer lines
func grow_circle():
	if (entry_clipping.hit or exit_clipping.hit) and (second_pass or !apex_clipping.hit):
		return false
	radius += growth_factor
	return true

## Moves the circle towards the apex 
func move_circle():
	var moving_dir = Vector2.ZERO
	if entry_clipping.hit and exit_clipping.hit:
		moving_dir = (apex_clipping.point - m_position).normalized() * reposition_factor#((entry_clipping.point - m_position) + (exit_clipping.point - m_position)).normalized() * reposition_factor*200
		radius -= growth_factor
	elif entry_clipping.hit:
		moving_dir = (entry_clipping.point - m_position).normalized() * reposition_factor
	elif exit_clipping.hit:
		moving_dir = (exit_clipping.point - m_position).normalized() * reposition_factor
	m_position -= moving_dir
	radius -= growth_factor
	update_clipping_points()


func get_closest_distances(segment,points,distances,indexes,ammount, reverse = false):
	for i in range(ammount):		
		for j in range(segment.size()-1):
			var A = segment[j]
			var B = segment[j+1]
			var C = m_position
			var point = closest_point_on_line_segment(A,B,C)
			var cur_distance = point.distance_to(m_position)
			if (cur_distance < distances[i] if !reverse else cur_distance > distances[i]) and !indexes.has(j):
				distances[i] = cur_distance
				points[i] = point
				indexes[i] = j
	return

func update_clipping_points():
	update_entry_clipping()
	update_exit_clipping()
	update_apex_clipping()
	pass


func update_entry_clipping():
	if second_pass:
		entry_clipping = {
			distance = second_pass_goal.distance_to(m_position),
			hit = false,
			point = second_pass_goal,
			index = -1,
		}
		return
	entry_clipping = {
		distance = INF,
		hit = false,
		point = Vector2(INF,INF),
		index = -1,
	}
	for i in range((outer_segment.size()/2)-1):
		var A = outer_segment[i]
		var B = outer_segment[i+1]
		var C = m_position
		var point = closest_point_on_line_segment(A,B,C)
		var cur_distance = point.distance_to(m_position)
		if cur_distance < entry_clipping.distance:
			entry_clipping.distance = cur_distance
			entry_clipping.point = point
			entry_clipping.index = i
	pass


func update_exit_clipping():
	exit_clipping = {
		distance = INF,
		hit = false,
		point = Vector2(INF,INF),
		index = -1,
	}
	for i in range((outer_segment.size()/2)-1, outer_segment.size()-1):
		var A = outer_segment[i]
		var B = outer_segment[i+1]
		var C = m_position
		var point = closest_point_on_line_segment(A,B,C)
		var cur_distance = point.distance_to(m_position)
		if cur_distance < exit_clipping.distance:
			exit_clipping.distance = cur_distance
			exit_clipping.point = point
			exit_clipping.index = i
	pass


func update_apex_clipping():
	apex_clipping = {
		distance = -INF,
		hit = false,
		point = Vector2(INF,INF),
		index = -1,
	}
	for i in range(entry_clipping.index, exit_clipping.index):
		var A = inner_segment[i]
		var B = inner_segment[i+1]
		var C = m_position
		var point = closest_point_on_line_segment(A,B,C)
		var cur_distance = m_position.distance_to(point)
		if cur_distance > apex_clipping.distance:
			apex_clipping.distance = cur_distance
			apex_clipping.point = point
			apex_clipping.index = i
	pass


func closest_point_on_line_segment(A,B,C):
	if((B-A).dot(B-A) == 0):
		return A
	var S = (C-A).dot(B-A) / (B-A).dot(B-A)
	if S <= 0:
		return A
	if S >= 1:
		return B
	return A + S*(B-A)


func update_points(innerSegment, outerSegment, color, _direction, _index, growth, reposition):
	if outerSegment.size() <=2 or innerSegment.size() <= 2:
		return false
	index = _index
	direction = _direction
	inner_segment = innerSegment
	outer_segment = outerSegment
	complete_color = color
	m_position = (innerSegment[1] + innerSegment[-2])/2
	radius = innerSegment[1].distance_to(innerSegment[-2]) 
	update_clipping_points()
	return true

func start_second_pass(point, full = false):
	solve_speed = 1
	completed = false
	second_pass = true
	second_pass_goal = point
	radius = 1
	cur_itt = 0
	m_position = (exit_clipping.point + second_pass_goal)/2
	update_clipping_points()
	update_hits()
	resolve(full)

func _draw():
	var default_font = Control.new().get_font("font")
#	if second_pass:
#		draw_circle(exit_clipping.point, 4, Color.chocolate)
#		draw_circle(entry_clipping.point, 4, Color.pink)
	if is_running:
		draw_string(default_font, apex_clipping.point, str(cur_itt))
		draw_arc(m_position,radius,0,360,3600,complete_color,2)
	if !is_complete():
		pass
	else:
		var angle_from = rad2deg(entry_clipping.point.angle_to_point(m_position))
		var angle_to = rad2deg(exit_clipping.point.angle_to_point(m_position))
		if(angle_from < 0):
			angle_from += 360
		if(angle_to < 0):
			angle_to += 360
		if(angle_to < angle_from):
			angle_to += 360
		if direction > 0:
			draw_arc(m_position,radius,deg2rad(angle_from),deg2rad(angle_to),360,Color.blue,2)
		else:
			draw_arc(m_position,radius,deg2rad(angle_to),deg2rad(angle_from+360),360,Color.blue,2)
	pass
