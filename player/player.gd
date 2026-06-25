extends CharacterBody2D
class_name Player2D

# const LAND_VFX = preload("res://player/land_vfx.tscn")


@onready var sprite_2d: Sprite2D = $Sprite2D
# @onready var diamond_2d: Polygon2D = $SpriteHouser/Sprite2D/Diamond2D

# @onready var point_light : PointLight2D = $PointLight2D
# @onready var ani_player: AnimationPlayer = $AniPlayer

# @onready var glider_trail_vfx: Trail2D = $GliderTrailVFX
# @onready var glider_trail_vfx2: Trail2D = $GliderTrailVFX2


#region export_variables
@export var ground_pound_velocity = 1000

@export_group("Effects")
@export var squashed_size:Vector2 = Vector2(1.1, 0.8) 
@export var stretched_size:Vector2 = Vector2(0.8, 1.1)

@export_group("Movement")
@export var speed : float = 600.0
@export var acceleration : float = 45
@export var deceleration : float = 50

@export_group("Jump")
@export var max_jump_count : int = 2
@export var jump_velocity : float = -600.0
@export var jump_buffer_time : float = .1
@export var super_jump_time : float = .1
@export var terminal_velocity = 3000
@export var coyote_time:float = .3
#endregion

#region variables
var jump_buffer_timer:float = 0
var coyote_timer:float = 0
var super_jump_timer:float = 0
var jump_count : int = 0

## holds previous frame info
var was_on_floor : bool 
var can_super_jump : bool
var land_velocity : float 
var wish_dir : float = 0

var is_dead : bool = false
var is_being_pulled : bool = false
var is_gliding : bool = false
var is_ground_pounding : bool = false
var can_take_input : bool = true

#endregion

func _ready():
	jump_buffer_timer = 0
	coyote_timer = 0

# uncapped
func _process(delta):
	if is_dead:
		return
	# Subtract delta(frame) every delta(frame) from these vars
	jump_buffer_timer -= delta
	coyote_timer -= delta
	super_jump_timer -= delta

# capped at 60fps
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Coyote stuff
	if is_on_floor(): # current frame on_floor
		jump_count = 0

		 	
		if not was_on_floor: # previous frame on_floor
			
			# landed with enough velocity
			if land_velocity >= ground_pound_velocity:
				super_jump_timer = super_jump_time
				# VFXManager.add_vfx(LAND_VFX, $VFXSpawnLocation)
			
			is_gliding = false
			is_ground_pounding = false
			squash()
			# SFXManager.play_FX(SFXManager.land_sfx_array.pick_random(), 3, 1, 1)
		
		if jump_buffer_timer > 0:
			jump()
			
		was_on_floor = true
	else: # is in air
		land_velocity = velocity.y # keep updating land velocity till land
		if was_on_floor:
			if !(jump_count > 0):
				coyote_timer = coyote_time
				jump_count = 1
		was_on_floor = false
		apply_gravity(delta)

	
	handle_input()
	# push_off_ledges()
	move_and_slide()

func apply_gravity(delta) -> void:
	if velocity.y >= terminal_velocity:
		velocity.y = terminal_velocity
		return
	
	
	if velocity.y > 0:  # falling
		if is_gliding:
			velocity += get_gravity() * delta * .6
		else:
			velocity += get_gravity() * delta * 1.25
	else: # not falling
		velocity += get_gravity() * delta
	
	# terminal velocity
	if is_gliding:
		if velocity.y > 350:
			velocity.y = 350
	elif !is_ground_pounding: # should not be ground pounding
		if velocity.y > 1000:
			velocity.y = 1000
			

	
func handle_input():
	if !can_take_input: return
	#region JUMP
	if Input.is_action_just_pressed("jump"):
		if coyote_timer > 0:
				#AudioPlayer.play_FX(jump_sound, 0, 1, 1.5)
			jump()
			
		elif jump_count < max_jump_count:
			if jump_count == 0:
				stretch()
			# AUDIO  (sound, volume, lower_limit, upper_limit)
			#AudioPlayer.play_FX(jump_sound, 0, 1, 1.5)
			jump()
			
		else:
			jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_released('jump'):
		if jump_count <= max_jump_count:
			
			if velocity.y < 0: # is negative
				velocity.y *= 0.5
	#endregion 
	
	#region Movement
	wish_dir = Input.get_axis("left", "right")
	if wish_dir:
		if super_jump_timer > 0:
			velocity.x = move_toward(velocity.x, wish_dir * speed * 2, acceleration)
		else:
			velocity.x = move_toward(velocity.x, wish_dir * speed, acceleration)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration)
	#endregion 
	
	#region GroundPound
	if Input.is_action_just_pressed("ground_pound"):
		if is_on_floor():
			return
		if is_being_pulled: return
		
		is_ground_pounding = true
		# SFXManager.play_FX(SFXManager.groundpound_sfx_array.pick_random(), 3, 1, 1)
		if self.velocity.y >= ground_pound_velocity:
			return
		self.velocity.y = ground_pound_velocity
		stretch()
	#endregion
	
	if Input.is_action_pressed("parachute"):
		if is_on_floor() or is_ground_pounding:
			is_gliding = false
			# glider_trail_vfx.can_spawn_new_points = false
			# glider_trail_vfx2.can_spawn_new_points = false
		else:
			is_gliding = true
			# glider_trail_vfx.can_spawn_new_points = true
			# glider_trail_vfx2.can_spawn_new_points = true
		
	if Input.is_action_just_released("parachute"):
		is_gliding = false
		# glider_trail_vfx.can_spawn_new_points = false
		# glider_trail_vfx2.can_spawn_new_points = false
	
	if Input.is_action_just_pressed("parachute"):
		if is_ground_pounding:
			ground_pound_cancel()
			
	
func ground_pound_cancel() -> void:
	is_ground_pounding = false
	self.velocity.y = -100
	
	var tween : Tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	# tween.tween_property(diamond_2d,"rotation_degrees", 360 + 45, 0.3)
	await tween.finished
	# diamond_2d.rotation_degrees = 45
	tween.kill()

func jump():
	# SFXManager.play_FX(SFXManager.jump_sfx_array.pick_random(), -10, 1, 1)
	jump_count = jump_count + 1
	
	if super_jump_timer > 0:
		velocity.y = jump_velocity * 1.2
	else:
		velocity.y = jump_velocity
		

	

# Squash on land for cute effects :)
func squash():
	var tween = get_tree().create_tween()
	squashed_size = squashed_size / land_velocity / 400
	squashed_size = clamp(squashed_size, Vector2(1.1, 0.7), Vector2(1.3, 0.9) )
	tween.tween_property(sprite_2d, "scale",squashed_size, .1).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(squash_and_stretch_finished)
	
# Strectch on jump for cute effects :)
func stretch():
	var tween = get_tree().create_tween()
	stretched_size = stretched_size / velocity.y / 700
	stretched_size = clamp(stretched_size, Vector2(0.7, 1.1), Vector2(0.9, 1.2) )
	tween.tween_property(sprite_2d, "scale",stretched_size, .1).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(squash_and_stretch_finished)

# Return character to original state after squas and strectch are finsihed
func squash_and_stretch_finished():
	var tween = get_tree().create_tween()
	tween.tween_property(sprite_2d, "scale",Vector2(1,1), .1).set_trans(Tween.TRANS_QUAD)
	#tween.tween_property(silhouette_sprite, "scale",Vector2(1,1), .1).set_trans(Tween.TRANS_QUAD)

func die():
	if is_dead: return
	# SFXManager.play_FX(SFXManager.player_dead_sfx_array.pick_random(), 3, 1, 1)
	is_dead = true
	# ani_player.play("die")
	# TransitionManager.transition_scene_file(get_tree().current_scene.scene_file_path)
