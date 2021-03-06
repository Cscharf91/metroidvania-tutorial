extends KinematicBody2D

const DustEffect = preload("res://Effects/DustEffect.tscn")
const PlayerBullet = preload("res://Player/PlayerBullet.tscn")
const JumpEffect = preload("res://Effects/JumpEffect.tscn")

var PlayerStats = ResourceLoader.PlayerStats

export (int) var ACCELERATION = 512
export (int) var MAX_SPEED = 64
export (float) var FRICTION = 0.25
export (int) var GRAVITY = 200
export (int) var JUMP_FORCE = 128
export (int) var MAX_SLOPE_ANGLE = 46
export (int) var BULLET_SPEED = 250

onready var animator = $SpriteAnimator
onready var sprite = $Sprite
onready var coyote_jump_timer = $CoyoteJumpTimer
onready var fire_bullet_timer = $FireBulletTimer
onready var gun = $Sprite/PlayerGun
onready var muzzle = $Sprite/PlayerGun/Sprite/Muzzle
onready var blink_animator = $BlinkAnimator

var invincible = false setget set_invincible
var motion = Vector2.ZERO
var snap_vector = Vector2.ZERO
var just_jumped = false

func _ready():
	PlayerStats.connect("player_died", self, "_on_died")
	sprite.visible = true

func set_invincible(value):
	invincible = value

func _physics_process(delta):
	just_jumped = false
	var input_vector = get_input_vector()
	apply_horizontal_force(input_vector, delta)
	apply_friction(input_vector)
	update_snap_vector()
	jump_check()
	fire_check()
	apply_gravity(delta)
	update_animations(input_vector)
	
	move()

func fire_check():
	if Input.is_action_pressed("fire") and fire_bullet_timer.time_left == 0:
		fire_bullet()

func fire_bullet():
	var bullet = Utils.instance_scene_on_main(PlayerBullet, muzzle.global_position)
	bullet.velocity = Vector2.RIGHT.rotated(gun.rotation) * BULLET_SPEED
	bullet.velocity.x *= sprite.scale.x
	bullet.rotation = bullet.velocity.angle()
	fire_bullet_timer.start()

func create_dust_effect():
	var dust_position = global_position
	dust_position.x += rand_range(-4, 4)
	Utils.instance_scene_on_main(DustEffect, dust_position)

func get_input_vector():
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	return input_vector
	
func apply_horizontal_force(input_vector, delta):
	if input_vector.x != 0:
		motion.x += input_vector.x * ACCELERATION * delta
		motion.x = clamp(motion.x, -MAX_SPEED, MAX_SPEED)

func apply_friction(input_vector):
	if input_vector.x == 0 and is_on_floor():
		motion.x = lerp(motion.x, 0, FRICTION)

func update_snap_vector():
	if is_on_floor():
		snap_vector = Vector2.DOWN

func jump_check():
	if is_on_floor() or coyote_jump_timer.time_left > 0:
		if Input.is_action_just_pressed("jump"):
			just_jumped = true
			Utils.instance_scene_on_main(JumpEffect, global_position)
			motion.y = -JUMP_FORCE
			snap_vector = Vector2.ZERO
	else:
		if Input.is_action_just_released("jump") and motion.y < -JUMP_FORCE / 2:
			motion.y = -JUMP_FORCE / 2;

func apply_gravity(delta):
	if !is_on_floor():
		motion.y += GRAVITY * delta
		motion.y = min(motion.y, JUMP_FORCE)
	
func update_animations(input_vector):
	sprite.scale.x = sign(get_local_mouse_position().x)
	if input_vector.x != 0:
		animator.play("Run")
		animator.playback_speed = input_vector.x * sprite.scale.x
	else:
		animator.playback_speed = 1
		animator.play("Idle")
	if !is_on_floor():
		animator.play("Jump")

func move():
	var was_on_floor = is_on_floor()
	var was_in_air = !is_on_floor()
	var last_motion = motion
	
	motion = move_and_slide_with_snap(motion, snap_vector * 4, Vector2.UP, true, 4, deg2rad(MAX_SLOPE_ANGLE))
	
	if was_in_air and is_on_floor():
		motion.x = last_motion.x
		Utils.instance_scene_on_main(JumpEffect, global_position)
	
	if was_on_floor and !is_on_floor() and !just_jumped:
		motion.y = 0
		coyote_jump_timer.start()


func _on_Hurtbox_hit(damage):
	if !invincible:
		PlayerStats.health -= damage
		blink_animator.play("Blink")

func _on_died():
	queue_free()
