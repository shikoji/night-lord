extends CharacterBody2D
class_name GrabEnemy

enum State {
	IDLE,
	GRABBED,
	THROWED,
	DEAD
}

@export var max_health: int = 30
@export var gravity: float = 1200.0
@export var throw_force_x: float = 360.0
@export var throw_force_y: float = -220.0
@export var grabbed_offset: Vector2 = Vector2(22, -18)

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D

var health: int
var state: State = State.IDLE

var grabber: Node2D = null
var throw_dir: int = 1

func face_direction(direction: int) -> void:
	sprite.flip_h = direction > 0

func _ready() -> void:
	health = max_health
	add_to_group("grabbable")
	play_anim("idle")


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			apply_gravity(delta)

		State.GRABBED:
			velocity = Vector2.ZERO
			follow_grabber()

		State.THROWED:
			apply_gravity(delta)

			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)

				if absf(velocity.x) < 5.0:
					velocity.x = 0.0
					state = State.IDLE
					play_anim("idle")

		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()


func take_damage(amount: int, knockback_direction: int, hit_id: int = 0) -> void:
	if state == State.DEAD:
		return

	health -= amount

	print("GrabEnemy tomou dano: ", amount, " | Hit: ", hit_id, " | Vida: ", health)

	if health <= 0:
		die()
		return

	match hit_id:
		1:
			start_grabbed(knockback_direction)

		2, 3:
			start_grabbed_damage()

		4:
			start_throwed(knockback_direction)

		_:
			velocity.x = knockback_direction * 120.0


func start_grabbed(direction: int) -> void:
	state = State.GRABBED
	throw_dir = direction
	velocity = Vector2.ZERO
	play_anim("grabbed")


func start_grabbed_damage() -> void:
	if state == State.DEAD:
		return

	state = State.GRABBED
	velocity = Vector2.ZERO

	if sprite.animation != "ongrab":
		play_anim("ongrab")


func start_throwed(direction: int) -> void:
	if state == State.DEAD:
		return

	state = State.THROWED
	grabber = null

	# joga para o lado CONTRÁRIO do player
	throw_dir = -direction

	velocity.x = throw_dir * throw_force_x
	velocity.y = throw_force_y

	# inimigo olha para direção do arremesso
	face_direction(throw_dir)

	play_anim("throwed")


func set_grabber(new_grabber: Node2D) -> void:
	grabber = new_grabber


func follow_grabber() -> void:
	if grabber == null:
		return

	if not is_instance_valid(grabber):
		release_from_grab()
		return

	var dir: int = 1

	if "facing_dir" in grabber:
		dir = grabber.facing_dir

	global_position = grabber.global_position + Vector2(
		grabbed_offset.x * dir,
		grabbed_offset.y
	)

	# inimigo olha para o player
	face_direction(-dir)


func release_from_grab() -> void:
	grabber = null
	state = State.IDLE
	velocity = Vector2.ZERO
	play_anim("idle")


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func die() -> void:
	state = State.DEAD
	grabber = null
	velocity = Vector2.ZERO

	if hurtbox_shape:
		hurtbox_shape.set_deferred("disabled", true)

	queue_free()


func play_anim(anim_name: String) -> void:
	if sprite.animation == anim_name and sprite.is_playing():
		return

	sprite.play(anim_name)
