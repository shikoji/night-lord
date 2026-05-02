extends Area2D
class_name GrabHitbox

signal grabbed(target: Node)

@onready var collision: CollisionShape2D = $CollisionShape2D

var already_grabbed: Array[Node] = []
var has_grabbed: bool = false
var grabber: Node = null


func _ready() -> void:
	disable_hitbox()

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func enable_hitbox(new_grabber: Node) -> void:
	grabber = new_grabber
	has_grabbed = false
	already_grabbed.clear()
	collision.set_deferred("disabled", false)


func disable_hitbox() -> void:
	collision.set_deferred("disabled", true)
	has_grabbed = false
	already_grabbed.clear()


func _on_area_entered(area: Area2D) -> void:
	try_grab(area)


func _on_body_entered(body: Node2D) -> void:
	try_grab(body)


func try_grab(target: Node) -> void:
	if has_grabbed:
		return

	if target in already_grabbed:
		return

	if not target.is_in_group("grabbable"):
		return

	already_grabbed.append(target)
	has_grabbed = true

	grabbed.emit(target)
