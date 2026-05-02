extends Area2D
class_name Projectile

@export var speed: float = 700.0
@export var damage: int = 10
@export var hit_id: int = 20
@export var life_time: float = 2.0

@onready var hit_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dissipate_sprite: AnimatedSprite2D = $DissipateSprite

var direction: int = 1
var can_move: bool = false
var hit_done: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	hit_sprite.animation_finished.connect(_on_hit_animation_finished)

	dissipate_sprite.visible = false

	can_move = true
	play_hit_anim("casted")

	await get_tree().create_timer(life_time).timeout

	if is_instance_valid(self) and not hit_done:
		queue_free()


func _physics_process(delta: float) -> void:
	if not can_move:
		return

	if hit_done:
		return

	global_position.x += direction * speed * delta


func setup(dir: int, new_damage: int) -> void:
	direction = dir
	damage = new_damage

	scale.x = direction


func set_direction(dir: int) -> void:
	direction = dir
	scale.x = direction


func _on_area_entered(area: Area2D) -> void:
	hit_target(area)


func _on_body_entered(body: Node2D) -> void:
	hit_target(body)


func hit_target(target: Node) -> void:
	if hit_done:
		return

	var real_target := get_damage_target(target)

	if real_target == null:
		return

	hit_done = true
	can_move = false

	real_target.take_damage(damage, direction, hit_id)

	# HIT PRIMEIRO
	play_hit_anim("hit")
	await  get_tree().create_timer(0.1).timeout
	# 1 frame depois começa dissipate
	start_dissipate_delayed()


func start_dissipate_delayed() -> void:
	await get_tree().process_frame

	dissipate_sprite.visible = true
	dissipate_sprite.frame = 0
	dissipate_sprite.play("dissipate")


func get_damage_target(target: Node) -> Node:
	if target.has_method("take_damage"):
		return target

	if target.get_parent() and target.get_parent().has_method("take_damage"):
		return target.get_parent()

	if target.owner and target.owner.has_method("take_damage"):
		return target.owner

	return null


func _on_hit_animation_finished() -> void:
	if hit_sprite.animation == "hit":
		queue_free()


func play_hit_anim(anim_name: String) -> void:
	if hit_sprite.animation == anim_name and hit_sprite.is_playing():
		return

	hit_sprite.play(anim_name)
