@tool
extends Node2D

# --- Configuration ---
const TILE_SIZE = 20
const GRID_SIZE = 20
const WINDOW_SIZE = TILE_SIZE * GRID_SIZE

# --- Game State ---
var snake_body = [Vector2(5, 5), Vector2(4, 5), Vector2(3, 5)]
var direction = Vector2.RIGHT
var next_direction = Vector2.RIGHT
var score = 0
var game_over_flag = false
var growth_pending = 0

# --- UI/Nodes (Created Programmatically) ---
var background_container: Node2D
var snake_container: Node2D
var food: ColorRect
var move_timer: Timer
var score_label: Label
var golden_apple_node: TextureRect

func _ready():
	if not Engine.is_editor_hint():
		setup_window()
	setup_nodes()
	if not Engine.is_editor_hint():
		spawn_food()

func setup_window():
	# Adjusts the window size to match the grid
	# On Web, we usually want to let the browser handle the outer window
	if OS.get_name() != "Web":
		DisplayServer.window_set_size(Vector2i(WINDOW_SIZE, WINDOW_SIZE + 40))
	get_tree().root.content_scale_size = Vector2i(WINDOW_SIZE, WINDOW_SIZE + 40)

func setup_nodes():
	# 0. Handle Background (Find existing or create)
	if has_node("Board"):
		background_container = $Board
		# Clear preview placeholders
		for child in background_container.get_children():
			if child.name == "Background":
				child.queue_free()
	
	golden_apple_node = get_node_or_null("GoldenApple")
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var rect = ColorRect.new()
			rect.size = Vector2(TILE_SIZE, TILE_SIZE)
			rect.position = Vector2(x, y) * TILE_SIZE
			
			# Alternate colors for checkerboard effect
			if (x + y) % 2 == 0:
				rect.color = Color(0.12, 0.12, 0.12) # Darker
			else:
				rect.color = Color(0.15, 0.15, 0.15) # Lighter
			background_container.add_child(rect)
			# Hide from scene tree so it doesn't clutter your editor view
			rect.owner = null 

	if Engine.is_editor_hint(): return # Don't run game logic in editor

	# 1. Snake Container
	snake_container = Node2D.new()
	add_child(snake_container)
	
	# 2. Food Rect
	food = ColorRect.new()
	food.size = Vector2(TILE_SIZE, TILE_SIZE)
	food.color = Color.RED
	add_child(food)
	
	# 3. Timer logic
	move_timer = Timer.new()
	move_timer.wait_time = 0.15
	move_timer.autostart = true
	move_timer.timeout.connect(_on_move_timer_timeout)
	add_child(move_timer)
	
	# 4. Simple Score Label
	score_label = Label.new()
	score_label.position = Vector2(10, WINDOW_SIZE + 5)
	score_label.text = "Score: 0"
	add_child(score_label)

func _input(_event):
	if Input.is_action_just_pressed("ui_up") and direction != Vector2.DOWN:
		next_direction = Vector2.UP
	elif Input.is_action_just_pressed("ui_down") and direction != Vector2.UP:
		next_direction = Vector2.DOWN
	elif Input.is_action_just_pressed("ui_left") and direction != Vector2.RIGHT:
		next_direction = Vector2.LEFT
	elif Input.is_action_just_pressed("ui_right") and direction != Vector2.LEFT:
		next_direction = Vector2.RIGHT

func _on_move_timer_timeout():
	if game_over_flag:
		return
	move_snake()

func move_snake():
	direction = next_direction
	var new_head = snake_body[0] + direction
	
	# Wall Collision
	if new_head.x < 0 or new_head.x >= GRID_SIZE or \
	   new_head.y < 0 or new_head.y >= GRID_SIZE:
		trigger_game_over()
		return

	# Self Collision
	if new_head in snake_body:
		trigger_game_over()
		return

	snake_body.insert(0, new_head)
	
	var head_rect = Rect2(new_head * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
	var ate_food = (new_head == Vector2(food.position / TILE_SIZE))
	var ate_golden = false
	
	if golden_apple_node and golden_apple_node.visible:
		if golden_apple_node.get_rect().intersects(head_rect):
			ate_golden = true

	# Check Food Collision
	if ate_food:
		score += 1
		score_label.text = "Score: " + str(score)
		spawn_food()
		# Slightly increase speed
		move_timer.wait_time = max(0.05, move_timer.wait_time - 0.002)
	elif ate_golden:
		score += 5
		score_label.text = "Score: " + str(score)
		golden_apple_node.visible = false
		growth_pending += 4 # This move adds 1, plus 4 more pending = 5 total
		move_timer.wait_time = max(0.05, move_timer.wait_time - 0.01)
	else:
		if growth_pending > 0:
			growth_pending -= 1
		else:
			snake_body.pop_back()
	
	draw_snake()

func draw_snake():
	# Clear and rebuild snake visuals
	for child in snake_container.get_children():
		child.queue_free()
	
	for i in range(snake_body.size()):
		var rect = ColorRect.new()
		rect.size = Vector2(TILE_SIZE - 1, TILE_SIZE - 1)
		rect.position = snake_body[i] * TILE_SIZE
		# Head is a different color
		rect.color = Color.GREEN if i == 0 else Color.DARK_GREEN
		snake_container.add_child(rect)

func spawn_food():
	var valid_pos = false
	while not valid_pos:
		var x = randi() % GRID_SIZE
		var y = randi() % GRID_SIZE
		var new_pos = Vector2(x, y)
		if not new_pos in snake_body:
			food.position = new_pos * TILE_SIZE
			valid_pos = true

func trigger_game_over():
	game_over_flag = true
	score_label.text = "GAME OVER - Final Score: " + str(score) + " (Press R to restart)"

func _process(_delta):
	if game_over_flag and Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
