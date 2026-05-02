extends Area2D
class_name AttackHitbox

var damage: int = 10

var already_hit: Array = []

@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	disable_hitbox()

func enable_hitbox(new_damage: int) -> void:

	damage = new_damage

	collision.disabled = false

func disable_hitbox() -> void:

	collision.disabled = true

	already_hit.clear()

func _on_area_entered(area: Area2D) -> void:

	if area in already_hit:
		return

	already_hit.append(area)

	if area.has_method("take_damage"):

		area.take_damage(
			damage,
			sign(global_position.x - area.global_position.x)
		)
