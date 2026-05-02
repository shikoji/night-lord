extends Area2D
class_name BatProjectile

enum State {
	GOING_TO_ENEMY,
	BITING,
	TURNING_BLOOD,
	MOVING_BACK
}

@export var speed: float = 260.0
@export var return_speed: float = 360.0
@export var damage: int = 5
@export var hit_id: int = 30
@export var target_offset: Vector2 = Vector2(0, -22)
@export var spawn_offset: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.GOING_TO_ENEMY
var target: Node2D = null
var owner_player: Node2D = null
var direction: int = 1
var damage_done: bool = false


func setup(player: Node2D, enemy: Node2D, dir: int) -> void:
	owner_player = player
	target = enemy
	direction = dir
	scale.x = direction
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	match state:
		State.GOING_TO_ENEMY:
			move_to_enemy(delta)

		State.MOVING_BACK:
			move_back_to_player(delta)

func get_target_position() -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position

	if target.has_node("NeckPoint"):
		return target.get_node("NeckPoint").global_position

	return target.global_position + target_offset

func move_to_enemy(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		start_moveback()
		return

	var target_pos := get_target_position()
	var dir := global_position.direction_to(target_pos)

	global_position += dir * speed * delta

	if global_position.distance_to(target_pos) <= 10.0:
		start_bite()


func start_bite() -> void:
	if state == State.BITING:
		return

	state = State.BITING
	sprite.play("bite")

	if target and is_instance_valid(target) and not damage_done:
		damage_done = true

		if target.has_method("take_damage"):
			target.take_damage(damage, direction, hit_id)


func start_turninblood() -> void:
	state = State.TURNING_BLOOD
	sprite.play("turninblood")


func start_moveback() -> void:
	state = State.MOVING_BACK
	sprite.play("moveback")


func move_back_to_player(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return

	var return_pos := owner_player.global_position

	if owner_player.has_node("Visual/BatReturnPoint"):
		return_pos = owner_player.get_node("Visual/BatReturnPoint").global_position

	var dir := global_position.direction_to(return_pos)
	global_position += dir * return_speed * delta

	if global_position.distance_to(return_pos) <= 16.0:
		queue_free()

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	if sprite.animation == "bite":
		start_turninblood()
		return

	if sprite.animation == "turninblood":
		start_moveback()
		return
