extends Node2D

class_name Circle

#onready var process_button = $"../../Panel/VBoxContainer/CheckButton"

export var m_position: Vector2
var growth_factor = 1
var reposition_factor:float = 1
var hit_threshold = 1
var complete_threshold = 2
export var radius = 10
export var solve_speed = 1

var cur_itt = 0
var max_itt = 300000
var last_radius = 0
var last_position = Vector2.ZERO
var start_position
var paused = false
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
	hit = -1,
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

var default_font = Control.new().get_font("font")

func _ready():
	cur_itt = 0
	pass

func _process(delta):
	if paused:
		return
	if is_running:
		for i in range(solve_speed):
			if is_complete():
				is_running = false
				update()
				return
			step()
		update()
	pass


##Calculate 1 step of the circle proccess
func step():
	if index == 13:
		pass
	if(cur_itt > max_itt):
		completed = true
		return
	if !grow_circle():
		move_circle()
	update_clipping_points()
	update_hits()
	cur_itt += 1


## Increases the circle radius if it's not touching the outer lines
func grow_circle():
	if (entry_clipping.hit or exit_clipping.hit):
		radius -= growth_factor*2
		return false
	radius += growth_factor
	return true


## Moves the circle towards the apex 
func move_circle():
	var moving_dir = Vector2.ZERO
	var condition = ((entry_clipping.hit or exit_clipping.hit) and (abs(exit_clipping.distance - entry_clipping.distance) < reposition_factor))
	if apex_clipping.distance - radius > 0:
		moving_dir -= (apex_clipping.point - m_position).normalized()
	else:
		if entry_clipping.hit:
			moving_dir += (entry_clipping.point - m_position).normalized() 
		if exit_clipping.hit:
			moving_dir += (exit_clipping.point - m_position).normalized() 
		if condition:
			moving_dir += (apex_clipping.point - m_position).normalized()
	m_position -= moving_dir.normalized() * reposition_factor


## Verifies if the circle hit the lines at the clipping points
func update_hits():
	var apex = apex_clipping.distance - radius
	var entry = entry_clipping.distance - radius
	var exit = exit_clipping.distance - radius
	entry_clipping.hit = entry < hit_threshold
	exit_clipping.hit = exit < hit_threshold
	apex_clipping.hit = apex < hit_threshold and apex > -hit_threshold


## Calculate steps until circle proccess is complete
func resolve(full = false):
	if !full:
		is_running = true
		return
	var completed = false
	while !completed:
		step()
		
		completed = is_complete()
		is_running = !completed
		


## Circle proccess is complete when the circle hits the outer lines at entry and exit and the apex on the inside line
func is_complete():
	var apex = apex_clipping.distance - radius
	var entry = entry_clipping.distance - radius
	var exit = exit_clipping.distance - radius
	var max_radius = radius > 10000
	var hits = entry < complete_threshold and exit < complete_threshold and apex < complete_threshold and apex > -complete_threshold
	return hits or completed or max_radius


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
	entry_clipping = {
		distance = INF,
		hit = false,
		point = Vector2(INF,INF),
		index = -1,
	}
	for i in range(outer_segment.size()/2):
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
	for i in range(outer_segment.size()/2, outer_segment.size()-1):
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
		hit = -1,
		point = Vector2(INF,INF),
		index = -1,
	}
	var entry = entry_clipping.index if !second_pass else exit_clipping.index/2
	for i in range(entry, exit_clipping.index):
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


func update_points(innerSegment, outerSegment, color, _direction, _index):
	if outerSegment.size() <=2 or innerSegment.size() <= 2:
		return false
	index = _index
	direction = _direction
	inner_segment = innerSegment
	outer_segment = outerSegment
	complete_color = color
	m_position = (innerSegment[1]+innerSegment[-2])/2#(innerSegment[innerSegment.size()/2] + outerSegment[outerSegment.size()/2] )/2
	radius = innerSegment[1].distance_to(innerSegment[-2]) 
	start_position = m_position
	update_clipping_points()
	return true

func start_second_pass(point, full = false):	
	completed = false
	second_pass = true
	second_pass_goal = point
	outer_segment = outer_segment.slice(1,outer_segment.size())
	outer_segment.push_front(second_pass_goal)
	radius = 1
	cur_itt = 0
	m_position = (inner_segment[1]+inner_segment[-2])/2#(inner_segment[-inner_segment.size()/3] + outer_segment[-inner_segment.size()/3] )/2#(exit_clipping.point + second_pass_goal + 18*apex_clipping.point)/20
	start_position = m_position
	update_clipping_points()
	update_hits()
	resolve(full)

func _draw():
	if is_running:
		if second_pass:
			draw_circle(second_pass_goal, 4, Color.red)
		for i in range(1,inner_segment.size()):
			draw_line(inner_segment[i-1],inner_segment[i],complete_color,1)
		for i in range(1,outer_segment.size()):
			draw_line(outer_segment[i-1],outer_segment[i],complete_color,1)
		draw_string(default_font, apex_clipping.point, str(cur_itt))
		draw_arc(m_position,radius,0,360,3600,complete_color,2)
		draw_circle(apex_clipping.point,2,Color.aqua)
		draw_circle(m_position,2,complete_color)
