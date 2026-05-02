extends CharacterBody2D
class_name DummyEnemy

enum State {
	IDLE,
	HURT,
	DEAD
}

@export var max_health: int = 999
@export var friction: float = 2000.0
@export var hurt_duration: float = 0.18
@export var white_flash_time: float = 0.08

@onready var sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var blood_fx: AnimatedSprite2D = $Visual/BloodFX
@onready var hurtbox: Area2D = $Hurtbox

var health: int
var state: State = State.IDLE

var hurt_time_left: float = 0.0
var flash_time_left: float = 0.0

@export var push_distance: float = 18.0
@export var push_time: float = 0.06
@export var push_out_time: float = 0.06
@export var push_return_time: float = 0.12
@export var projectile_flash_time: float = 0.06
@export var projectile_flash_color: Color = Color(0.7, 0.2, 1.0, 1.0)




var current_flash_color: Color = Color.WHITE
var start_position: Vector2
var push_tween: Tween

func _ready() -> void:
	start_position = position
	health = max_health

	blood_fx.visible = false
	blood_fx.stop()

	if not blood_fx.animation_finished.is_connected(_on_blood_finished):
		blood_fx.animation_finished.connect(_on_blood_finished)

	play_anim("idle")


func _physics_process(delta: float) -> void:
	# Dummy parado
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	#move_and_slide()

	update_hurt(delta)
	update_white_flash(delta)


func update_hurt(delta: float) -> void:
	if state != State.HURT:
		return

	hurt_time_left -= delta

	# Mantém hurt rodando
	if sprite.animation != "hurt":
		sprite.play("hurt")

	if hurt_time_left <= 0.0:
		finish_hurt()


func take_damage(amount: int, knockback_direction: int, hit_id: int = 0) -> void:
	if state == State.DEAD:
		return

	health -= amount

	var is_light_attack := hit_id in [1, 2, 3, 4]
	var is_projectile := hit_id == 20

	# LIGHT ATTACK
	if is_light_attack:
		start_hurt()
		play_blood_fx()

		start_white_flash(
			Color(10, 10, 10, 1),
			white_flash_time
		)

	# PROJECTILE
	elif is_projectile:
		start_hurt()
		start_white_flash(
			Color(10, 10, 10, 1),
			white_flash_time
		)
		
		await  get_tree().create_timer(0.1).timeout
		start_white_flash(
			projectile_flash_color,
			projectile_flash_time
		)

	# OUTROS DANOS
	else:
		start_white_flash()

	if hit_id == 3:
		push_back(knockback_direction)

	if hit_id == 4:
		return_to_original_position()

	print("Dummy tomou dano: ", amount, " | Hit: ", hit_id, " | Vida: ", health)

	if health <= 0:
		die()


func start_hurt() -> void:
	state = State.HURT
	hurt_time_left = hurt_duration

	# Reinicia hurt instantaneamente
	sprite.stop()
	sprite.frame = 0
	sprite.play("hurt")


func finish_hurt() -> void:
	if state == State.DEAD:
		return

	state = State.IDLE
	play_anim("idle")


func play_blood_fx() -> void:
	# NÃO reinicia o sangue enquanto já está tocando.
	# Isso impede cortar no frame 4.
	if blood_fx.is_playing():
		return

	blood_fx.visible = true
	blood_fx.stop()
	blood_fx.frame = 0
	blood_fx.play("hits")


func _on_blood_finished() -> void:
	blood_fx.stop()
	blood_fx.visible = false
	blood_fx.frame = 0


func start_white_flash(color: Color = Color(10, 10, 10, 1), duration: float = white_flash_time) -> void:
	current_flash_color = color
	flash_time_left = duration

	sprite.modulate = current_flash_color


func update_white_flash(delta: float) -> void:
	if flash_time_left <= 0.0:
		sprite.modulate = Color.WHITE
		return

	flash_time_left -= delta


func die() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD

	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	sprite.stop()
	sprite.frame = 0
	sprite.play("death")


func play_anim(anim_name: String) -> void:
	if sprite.animation == anim_name and sprite.is_playing():
		return

	sprite.play(anim_name)

func push_back(knockback_direction: int) -> void:
	knockback_direction = clampi(knockback_direction, -1, 1)

	if knockback_direction == 0:
		knockback_direction = -1

	if push_tween:
		push_tween.kill()

	push_tween = create_tween()
	push_tween.set_trans(Tween.TRANS_SINE)
	push_tween.set_ease(Tween.EASE_OUT)

	push_tween.tween_property(
		self,
		"position",
		start_position + Vector2(knockback_direction * push_distance, 0.0),
		push_time
	)
	
func return_to_original_position() -> void:
	if push_tween:
		push_tween.kill()

	push_tween = create_tween()
	push_tween.set_trans(Tween.TRANS_SINE)
	push_tween.set_ease(Tween.EASE_IN_OUT)

	push_tween.tween_property(
		self,
		"position",
		start_position,
		push_time
	)
