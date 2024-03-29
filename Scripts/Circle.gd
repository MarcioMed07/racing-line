extends Node2D

class_name Circle

export var m_position: Vector2
var growth_factor = 0.1
var hit_threshold = 1
var complete_threshold = 1
export var radius = 10
export var solve_speed = 1

var cur_itt = 0
var checking_interval = 100
var last_position = m_position
var last_radius = radius
var max_itt = 300000
var max_radius = 15000
var paused = false
var direction = 1
var index = -1
var entry_clipping
var exit_clipping
var apex_clipping
var apex_opposite = Vector2.ZERO
var middle_point_index = 0
var outer_segment = []
var inner_segment = []

var complete_color = Color.gray
var completed = false

var is_running = false
var second_pass = 0
var second_pass_goal = Vector2.ZERO

var default_font = Control.new().get_font("font")

func _ready():
	cur_itt = 0
	update_clipping_points()
	update_hits()
	pass

func _process(delta):
	if paused:
		return
	if is_running:
		for i in range(solve_speed):
			if completed:
				is_running = false
				update()
				return
			step()
		update()
	pass


##Calculate 1 step of the circle proccess
func step():
	if !grow_circle():
		move_circle()
	update_clipping_points()
	update_hits()
	completed = is_complete()


func grow_circle():
	if (entry_clipping.hit or exit_clipping.hit):
		radius -= growth_factor
		return false
	radius += growth_factor
	return true


func move_circle():
	var moving_dir = Vector2.ZERO
	if apex_clipping.distance > hit_threshold and apex_clipping.distance > radius:
		moving_dir += (apex_clipping.point - m_position)
	else:
		if entry_clipping.hit:
			moving_dir -= (entry_clipping.point - m_position) 
		if exit_clipping.hit:
			moving_dir -= (exit_clipping.point - m_position)
		moving_dir -= (apex_opposite - m_position)

	m_position += moving_dir.normalized()*growth_factor


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
	completed = false
	while !completed:
		step()
		update()
		is_running = !completed


## Circle proccess is complete when the circle hits the outer lines at entry and exit and the apex on the inside line
func is_complete():
	cur_itt += 1
	if(cur_itt > max_itt):
		completed = true
	if cur_itt % checking_interval == 0:
		if(m_position.distance_to(last_position) < complete_threshold and abs(radius-last_radius) < complete_threshold):
			completed = true
		last_position = m_position
		last_radius = radius
	if radius > max_radius:
		completed =  true
	if entry_clipping.hit and exit_clipping.hit and apex_clipping.hit:
		completed =  true
	return completed


func update_clipping_points():
	reinicialize_clips()
	update_entry_clipping()
	update_exit_clipping()
	update_apex_clipping()
	pass


func reinicialize_clips():
	entry_clipping = {
		distance = INF,
		hit = false,
		point = Vector2(INF,INF),
		index = -1,
	}

	exit_clipping = {
		distance = INF,
		hit = false,
		point = Vector2(INF,INF),
		index = -1,
	}

	apex_clipping = {
		distance = -INF,
		hit = -1,
		point = Vector2(INF,INF),
		index = -1,
	}


func update_entry_clipping():
	for i in range(0,middle_point_index):
		var A = outer_segment[i]
		var B = outer_segment[i+1]
		var C = m_position
		var point = closest_point_on_line_segment(A,B,C)
		var cur_distance = point.distance_to(m_position)
		if cur_distance < entry_clipping.distance:
			entry_clipping.distance = cur_distance
			entry_clipping.point = point
			entry_clipping.index = i


func update_exit_clipping():
	for i in range(middle_point_index, outer_segment.size()-1):
		var A = outer_segment[i]
		var B = outer_segment[i+1]
		var C = m_position
		var point = closest_point_on_line_segment(A,B,C)
		var cur_distance = point.distance_to(m_position)
		if cur_distance < exit_clipping.distance:
			exit_clipping.distance = cur_distance
			exit_clipping.point = point
			exit_clipping.index = i


func update_apex_clipping():
	if second_pass == 0:
		middle_point_index = (entry_clipping.index+exit_clipping.index)/2
	apex_opposite = outer_segment[middle_point_index]
	var min_distance = INF
	var apex_candidte_index = 0
	for i in range(inner_segment.size()):
		var distance = inner_segment[i].distance_to(apex_opposite)
		if distance < min_distance:
			apex_candidte_index = i
			min_distance = distance

	apex_clipping.distance = inner_segment[apex_candidte_index].distance_to(m_position)
	apex_clipping.point = inner_segment[apex_candidte_index]
	apex_clipping.index = apex_candidte_index
#	for i in range(inner_segment.size()-1):
#		var A = inner_segment[i]
#		var B = inner_segment[i+1]
#		var C = m_position
#		var point = closest_point_on_line_segment(A,B,C)
#		var cur_distance = m_position.distance_to(point)
#		if cur_distance > apex_clipping.distance:
#			apex_clipping.distance = cur_distance
#			apex_clipping.point = point
#			apex_clipping.index = i
#	if second_pass == 0:
#		middle_point_index = apex_clipping.index
#	apex_opposite = outer_segment[middle_point_index]


func closest_point_on_line_segment(A,B,C):
	var AB = B - A
	if(AB == Vector2.ZERO):
		return A
	var AC = C - A
	var t = AC.dot(AB) / AB.dot(AB)
	
	t = clamp(t, 0, 1)  # Garante que o ponto projetado esteja dentro do segmento AB
	
	var closest_point = A + AB * t
	return closest_point


func update_points(innerSegment, outerSegment, color, _direction, _index):
	if outerSegment.size() <=2 or innerSegment.size() <= 2:
		return false
	index = _index
	direction = _direction
	inner_segment = innerSegment
	outer_segment = outerSegment
	complete_color = color
	m_position = innerSegment[innerSegment.size()/2]
	radius = 10 
	
	var min_distance = INF
	for i in range(outerSegment.size()):
		var distance = outerSegment[i].distance_to(innerSegment[innerSegment.size()/2])
		if(distance < min_distance):
			min_distance = distance
			middle_point_index = i
		
	update_clipping_points()
	return true

func start_second_pass(point, full = false):
	last_position = Vector2.ZERO
	last_radius = 0
	completed = false
	second_pass += 1
	second_pass_goal = point
	for i in range(middle_point_index*0.9):
		outer_segment[i] = second_pass_goal
	radius = 0
	cur_itt = 0
	m_position = inner_segment[-1]
	update_clipping_points()
	update_hits()
	resolve(full)

func _draw():
	if is_running:
#		if second_pass:
#			draw_circle(second_pass_goal, 4, Color.red)
#		for i in range(1,inner_segment.size()):
#			draw_line(inner_segment[i-1],inner_segment[i],complete_color,1)
		for i in range(1,inner_segment.size()):
			draw_line(inner_segment[i-1],inner_segment[i],Color.green,2)
		for i in range(1,middle_point_index):
			draw_line(outer_segment[i-1],outer_segment[i],Color.red,2)
		for i in range(middle_point_index+1, outer_segment.size()):
			draw_line(outer_segment[i-1],outer_segment[i],Color.blue,2)
		
#		draw_string(default_font, apex_clipping.point, str(cur_itt))
#		draw_circle(apex_clipping.point,3,Color.red)
#		draw_circle(apex_opposite,2,Color.blue)
#		draw_circle(m_position,2,complete_color)
		draw_arc(m_position,radius,0,360,7920,complete_color,2)
