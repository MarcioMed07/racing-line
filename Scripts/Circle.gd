extends Node2D

onready var process_button = $"../../Panel/VBoxContainer/CheckButton"

export var m_position: Vector2
export var growth_factor = 0.1
export var reposition_factor:float = 0.1
export var radius = 10


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

func _ready():
	pass

func _process(delta):
	var simulate = process_button.pressed
	if !simulate or outer_segment.size() <=2:
		return
	update()
	
	if is_complete():
		complete_color = Color.black
		return
#	resolve()
	if !grow_circle():
		move_circle()
	update_hits()
#	debug()
	pass


func resolve():
	while !is_complete():
		if !grow_circle():
			move_circle()
		update_hits()
	complete_color = Color.black


func is_complete():
	return entry_clipping.hit and exit_clipping.hit and apex_clipping.hit


func update_hits():
	entry_clipping.hit = entry_clipping.distance - radius <= 0.05
	exit_clipping.hit = exit_clipping.distance - radius <= 0.05
	apex_clipping.hit = abs(apex_clipping.distance - radius) <= 1


func grow_circle():
	if entry_clipping.hit or exit_clipping.hit:
		return false
	radius += growth_factor
	return true


func move_circle():
	if entry_clipping.hit:
		m_position -= (entry_clipping.point - m_position).normalized() * reposition_factor
	if exit_clipping.hit:
		m_position -= (exit_clipping.point - m_position).normalized() * reposition_factor
	update_clipping_points()


func get_closest_distances(segment,points,distances,indexes,ammount, reverse = false):
	for i in range(ammount):		
		for j in range(segment.size()-1):
			var A = segment[j]
			var B = segment[j+1]
			var C = m_position
			var point = point(A,B,C)
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
	for i in range((outer_segment.size()/2)-1):
		var A = outer_segment[i]
		var B = outer_segment[i+1]
		var C = m_position
		var point = point(A,B,C)
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
		var point = point(A,B,C)
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
		var point = point(A,B,C)
		var cur_distance = m_position.distance_to(point)
		if cur_distance > apex_clipping.distance:
			apex_clipping.distance = cur_distance
			apex_clipping.point = point
			apex_clipping.index = i
	pass


func point(A,B,C):
	var S = (C-A).dot(B-A) / (B-A).dot(B-A)
	if S <= 0:
		return A
	if S >= 1:
		return B
	return A + S*(B-A)


func update_points(innerSegment, outerSegment, color):
	if outerSegment.size() <=2 or innerSegment.size() <= 2:
		return false
	inner_segment = innerSegment
	outer_segment = outerSegment
	complete_color = color
	m_position = (inner_segment[inner_segment.size()/2] + inner_segment[inner_segment.size()/2+1])/2	
	update_clipping_points()
	return true



func _draw():
	if !is_complete():
		draw_arc(m_position,radius,0,360,3600,complete_color,2)
	else:
		draw_arc(m_position,radius,entry_clipping.point.angle_to_point(m_position),exit_clipping.point.angle_to_point(m_position),3600,Color.blue,2)
	pass
