extends CharacterBody2D
class_name Player

enum State {
	EMERGE,
	NORMAL,
	AIR,
	LAND,
	ATTACK,
	PROJECTILE_ATTACK,
	BAT_ATTACK,
	DASH,
	HURT,
	STUN,
	DEAD,
	SUBMERGE
}
@export var start_with_emerge: bool = false

@export_category("Movement")
@export var walk_speed: float = 120.0
@export var run_speed: float = 260.0
@export var walk_anim_min_speed: float = 20.0
@export var run_anim_min_speed: float = 160.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var air_acceleration: float = 900.0
@export var gravity: float = 1800.0
@export var jump_force: float = -520.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var land_lock_time: float = 0.08
@export var hold_jump_buffer: bool = true

@export_category("Dash")
@export var dash_speed: float = 620.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 0.45
@export var air_dash_gravity_multiplier: float = 1.0
@export var air_dash_speed: float = 420.0

@export_category("Attack")
@export var attack_cooldown: float = 0.10
@export var attack_lunge: float = 110.0
@export var combo_buffer_time: float = 0.22
@export var dash_cancel_frame: int = 16

@export_category("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_damage: int = 10
@export var projectile_spawn_frame: int = 4

@export_category("Bat Summon")
@export var bat_scene: PackedScene
@export var bat_damage: int = 4
@export var bat_count: int = 5
@export var bat_spawn_delay: float = 0.001
@export var bat_summon_frame: int = 4

@export_category("Health")
@export var max_health: int = 100
@export var hurt_time: float = 0.20
@export var stun_time: float = 1.0
@export var knockback_force: float = 260.0

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var effects: AnimatedSprite2D = $Visual/effects

@onready var attack_hitbox: Area2D = $Visual/AttackHitbox
@onready var attack_shape: CollisionShape2D = $Visual/AttackHitbox/CollisionShape2D
@onready var projectile_spawn_point: Marker2D = $Visual/ProjectileSpawnPoint
@onready var effects2: AnimatedSprite2D = $Visual/effects2
@onready var bat_spawn_point: Marker2D = $Visual/BatSpawnPoint

var state: State = State.NORMAL
var health: int = 100

var facing_dir: int = 1
var locked_dir: int = 1
var input_dir: float = 0.0
var wants_run: bool = false

var coyote_left: float = 0.0
var jump_buffer_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_left: float = 0.0
var attack_cooldown_left: float = 0.0
var land_left: float = 0.0
var hurt_left: float = 0.0
var stun_left: float = 0.0
var combo_buffer_left: float = 0.0

var combo_requested: bool = false
var attack_damage: int = 0
var current_hit_id: int = 0
var projectile_spawned: bool = false
var effects_tocharge_started: bool = false
var cast_started_from_effect: bool = false
var bats_summoned: bool = false

var was_on_floor: bool = false
var dead_started: bool = false
var dash_started_in_air: bool = false


func _ready() -> void:
	health = max_health

	effects.visible = false
	effects.stop()
	
	effects2.visible = false
	effects2.stop()

	disable_attack_hitbox()
	connect_signals()
	
	if start_with_emerge:
		change_state(State.EMERGE)
	else:
		change_state(State.NORMAL)


func connect_signals() -> void:
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	if not sprite.frame_changed.is_connected(_on_frame_changed):
		sprite.frame_changed.connect(_on_frame_changed)

	if not attack_hitbox.area_entered.is_connected(_on_attack_area_entered):
		attack_hitbox.area_entered.connect(_on_attack_area_entered)

	if not attack_hitbox.body_entered.is_connected(_on_attack_body_entered):
		attack_hitbox.body_entered.connect(_on_attack_body_entered)

	if not effects.animation_finished.is_connected(_on_effects_animation_finished):
		effects.animation_finished.connect(_on_effects_animation_finished)
		
	if not effects2.animation_finished.is_connected(_on_effects2_animation_finished):
		effects2.animation_finished.connect(_on_effects2_animation_finished)

	if not effects2.frame_changed.is_connected(_on_effects2_frame_changed):
		effects2.frame_changed.connect(_on_effects2_frame_changed)


func _physics_process(delta: float) -> void:
	was_on_floor = is_on_floor()

	update_timers(delta)
	read_input()
	update_coyote()
	update_state(delta)

	if state != State.DASH:
		apply_gravity(delta)

	move_and_slide()

	if state in [State.NORMAL, State.AIR, State.LAND]:
		update_facing_from_input()

	update_visual_direction()

	if not was_on_floor and is_on_floor() and state == State.AIR:
		change_state(State.LAND)


func update_timers(delta: float) -> void:
	coyote_left = maxf(coyote_left - delta, 0.0)
	jump_buffer_left = maxf(jump_buffer_left - delta, 0.0)
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	dash_left = maxf(dash_left - delta, 0.0)
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	land_left = maxf(land_left - delta, 0.0)
	hurt_left = maxf(hurt_left - delta, 0.0)
	stun_left = maxf(stun_left - delta, 0.0)
	combo_buffer_left = maxf(combo_buffer_left - delta, 0.0)



func read_input() -> void:
	input_dir = Input.get_axis("move_left", "move_right")

	if Input.is_action_just_pressed("replacement"):
		wants_run = not wants_run

	if Input.is_action_just_pressed("jump"):
		jump_buffer_left = jump_buffer_time

	if hold_jump_buffer and Input.is_action_pressed("jump") and not is_on_floor():
		jump_buffer_left = jump_buffer_time

	if Input.is_action_just_pressed("attack"):
		combo_buffer_left = combo_buffer_time
		combo_requested = true
		
	if Input.is_action_just_pressed("spell"):
		change_state(State.PROJECTILE_ATTACK)
		
	if Input.is_action_just_pressed("heavy_spell"):
		change_state(State.BAT_ATTACK)
		
	if Input.is_action_just_pressed("dash") and can_dash():
		change_state(State.DASH)
		
		
	if Input.is_action_pressed("ui_page_up"):
		stun_left = 2
		change_state(State.STUN)
		
	if Input.is_action_pressed("ui_page_down"):
		hurt_left = 2
		change_state(State.HURT)
		
	if Input.is_action_pressed("ui_home"):
		change_state(State.SUBMERGE)
		
	if Input.is_action_pressed("ui_end"):
		change_state(State.DEAD)


func update_coyote() -> void:
	if is_on_floor():
		coyote_left = coyote_time


func update_state(delta: float) -> void:
	match state:
		State.EMERGE:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

		State.NORMAL:
			update_normal(delta)

		State.AIR:
			update_air(delta)

		State.LAND:
			update_land(delta)

		State.ATTACK:
			update_attack(delta)

		State.DASH:
			update_dash()

		State.HURT:
			update_hurt(delta)

		State.STUN:
			update_stun(delta)

		State.DEAD:
			velocity = Vector2.ZERO


func update_normal(delta: float) -> void:
	move_ground(delta)

	if jump_buffer_left > 0.0:
		jump()
		return

	if combo_buffer_left > 0.0 and can_attack():
		change_state(State.ATTACK)
		return

	if not is_on_floor():
		change_state(State.AIR)
		return

	update_ground_animation()


func update_air(delta: float) -> void:
	move_air(delta)

	if jump_buffer_left > 0.0 and coyote_left > 0.0:
		jump()
		return

	if combo_buffer_left > 0.0 and can_attack():
		change_state(State.ATTACK)
		return

	if velocity.y < 0.0:
		play_anim("jumping")
	else:
		play_anim("falling")


func update_land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if jump_buffer_left > 0.0:
		jump()
		return

	if land_left <= 0.0:
		change_state(State.NORMAL)
		return

	if absf(input_dir) > 0.0 or combo_buffer_left > 0.0 or Input.is_action_just_pressed("dash"):
		change_state(State.NORMAL)


func update_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if Input.is_action_just_pressed("dash") and sprite.frame >= dash_cancel_frame and can_dash():
		change_state(State.DASH)


func update_dash() -> void:
	if dash_started_in_air:
		velocity.x = locked_dir * air_dash_speed
		velocity.y += gravity * air_dash_gravity_multiplier * get_physics_process_delta_time()

		if dash_left <= 0.0:
			dash_started_in_air = false
			change_state(State.AIR)
	else:
		velocity.x = locked_dir * dash_speed
		velocity.y = 0.0

func update_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if hurt_left <= 0.0:
		change_state(State.NORMAL if is_on_floor() else State.AIR)


func update_stun(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if stun_left <= 0.0 and sprite.animation != "outstun":
		play_anim("outstun")


func move_ground(delta: float) -> void:
	var target_speed: float = walk_speed

	if wants_run:
		target_speed = run_speed

	if absf(input_dir) > 0.0:
		velocity.x = move_toward(velocity.x, input_dir * target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func move_air(delta: float) -> void:
	var target_speed: float = walk_speed

	if wants_run:
		target_speed = run_speed

	if absf(input_dir) > 0.0:
		velocity.x = move_toward(velocity.x, input_dir * target_speed, air_acceleration * delta)


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func jump() -> void:
	jump_buffer_left = 0.0
	coyote_left = 0.0
	velocity.y = jump_force
	change_state(State.AIR)
	play_anim("tojump")


func can_attack() -> bool:
	if state in [State.DEAD, State.HURT, State.STUN, State.DASH, State.EMERGE, State.SUBMERGE]:
		return false

	return attack_cooldown_left <= 0.0


func can_dash() -> bool:
	if state in [State.DEAD, State.HURT, State.STUN, State.EMERGE, State.SUBMERGE]:
		return false

	if state == State.ATTACK and sprite.frame < dash_cancel_frame:
		return false

	return dash_cooldown_left <= 0.0


func change_state(new_state: State) -> void:
	if state == State.DEAD:
		return

	if state == new_state:
		return

	exit_state(state)
	state = new_state
	enter_state(state)


func enter_state(new_state: State) -> void:
	match new_state:
		State.EMERGE:
			play_anim("emerge")

		State.NORMAL:
			combo_requested = false
			disable_attack_hitbox()

		State.AIR:
			pass

		State.LAND:
			land_left = land_lock_time
			play_anim("land")

		State.ATTACK:
			start_attack()

		State.DASH:
			start_dash()

		State.PROJECTILE_ATTACK:
			start_projectile_attack()
			
		State.BAT_ATTACK:
			start_bat_attack()

		State.HURT:
			play_anim("hited")

		State.STUN:
			play_anim("tostun")

		State.DEAD:
			start_death()

		State.SUBMERGE:
			play_anim("submerge")


func exit_state(old_state: State) -> void:
	match old_state:
		State.ATTACK:
			disable_attack_hitbox()

		State.DASH:
			pass


func start_attack() -> void:
	attack_cooldown_left = attack_cooldown
	combo_buffer_left = 0.0
	combo_requested = false

	locked_dir = facing_dir
	velocity.x = locked_dir * attack_lunge

	attack_damage = 15
	play_anim("lightatkcombo")

func start_projectile_attack() -> void:
	velocity.x = 0.0
	locked_dir = facing_dir

	projectile_spawned = false
	effects_tocharge_started = false
	cast_started_from_effect = false

	effects2.visible = false
	effects2.stop()

	play_anim("tolightcharge")

func start_dash() -> void:
	dash_left = dash_time
	dash_cooldown_left = dash_cooldown

	locked_dir = facing_dir
	dash_started_in_air = not is_on_floor()

	disable_attack_hitbox()

	if dash_started_in_air:
		velocity.x = locked_dir * air_dash_speed
	else:
		velocity.x = locked_dir * dash_speed
		velocity.y = 0.0

	if dash_started_in_air:
		play_anim("dashing")
	else:
		play_anim("todash")


func start_death() -> void:
	if dead_started:
		return

	dead_started = true

	disable_attack_hitbox()

	velocity = Vector2.ZERO
	play_anim("death")


func take_damage(amount: int, knockback_direction: int, stun_amount: float = 0.0) -> void:
	if state == State.DEAD:
		return

	health -= amount

	disable_attack_hitbox()

	velocity.x = knockback_direction * knockback_force
	velocity.y = -120.0

	if health <= 0:
		change_state(State.DEAD)
		return

	if stun_amount > 0.0:
		stun_left = stun_amount
		change_state(State.STUN)
	else:
		hurt_left = hurt_time
		change_state(State.HURT)


func update_facing_from_input() -> void:
	if absf(input_dir) > 0.0:
		facing_dir = int(signf(input_dir))


func update_visual_direction() -> void:
	visual.scale.x = float(facing_dir)


func update_ground_animation() -> void:
	var speed: float = absf(velocity.x)

	if speed < walk_anim_min_speed:
		play_anim("idle")
		return

	if not wants_run:
		play_anim("walking")
		return

	if speed < run_anim_min_speed:
		play_anim("torun")
	else:
		play_anim("running")


func play_anim(anim_name: String) -> void:
	if sprite.animation == anim_name and sprite.is_playing():
		return

	sprite.play(anim_name)


func enable_attack_hitbox(damage: int) -> void:
	attack_damage = damage
	attack_shape.set_deferred("disabled", false)


func disable_attack_hitbox() -> void:
	attack_shape.set_deferred("disabled", true)

func _on_frame_changed() -> void:
	disable_attack_hitbox()

	if state == State.ATTACK:
		match sprite.animation:
			"lightatkcombo":
				if sprite.frame == 5:
					play_slash_effect()
					current_hit_id = 1
					enable_attack_hitbox(5)

				elif sprite.frame == 10:
					current_hit_id = 2
					enable_attack_hitbox(5)

				elif sprite.frame == 16:
					current_hit_id = 3
					enable_attack_hitbox(5)

				elif sprite.frame == 19:
					current_hit_id = 4
					enable_attack_hitbox(5)

	if state == State.PROJECTILE_ATTACK:
		if sprite.animation == "tolightcharge":
			var total_frames := sprite.sprite_frames.get_frame_count("tolightcharge")

			if sprite.frame >= total_frames - 2 and not effects_tocharge_started:
				effects_tocharge_started = true
				effects2.visible = true
				effects2.frame = 0
				effects2.play("tocharge")

		if sprite.animation == "cast":
			var total_frames := sprite.sprite_frames.get_frame_count("cast")

			if sprite.frame >= total_frames - 9 and not projectile_spawned:
				spawn_projectile()
				
	if state == State.BAT_ATTACK:
		if sprite.animation == "heavycasting":
			if sprite.frame == bat_summon_frame and not bats_summoned:
				bats_summoned = true
				summon_bats()
				
func _on_animation_finished() -> void:
	match state:
		State.DEAD:
			queue_free()
		
		State.EMERGE:
			change_state(State.NORMAL)

		State.SUBMERGE:
			change_state(State.NORMAL)

		State.LAND:
			change_state(State.NORMAL)

		State.ATTACK:
			if combo_requested:
				start_attack()
				return

			change_state(State.NORMAL if is_on_floor() else State.AIR)

		State.PROJECTILE_ATTACK:
			if sprite.animation == "tolightcharge":
				play_anim("charging")

				effects2.visible = true
				effects2.frame = 0
				effects2.play("charging")
				return

			if sprite.animation == "charging":
				# espera o effects2 terminar charging/tocast
				return

			if sprite.animation == "cast":
				effects2.visible = false
				effects2.stop()
				change_state(State.NORMAL if is_on_floor() else State.AIR)
				return
				
		State.BAT_ATTACK:
			if sprite.animation == "toheavycharge":
				play_anim("heavycharging")
				return

			if sprite.animation == "heavycharging":
				play_anim("toheavycast")
				return

			if sprite.animation == "toheavycast":
				play_anim("heavycasting")
				return

			if sprite.animation == "heavycasting":
				play_anim("heavycast")
				return

			if sprite.animation == "heavycast":
				change_state(State.NORMAL if is_on_floor() else State.AIR)
				return

		State.DASH:
			if dash_started_in_air:
				return

			if sprite.animation == "todash":
				play_anim("dashing")
				return

			if sprite.animation == "dashing":
				play_anim("breakdash")
				return

			if sprite.animation == "breakdash":
				change_state(State.NORMAL if is_on_floor() else State.AIR)
				return

		State.HURT:
			if hurt_left <= 0.0:
				change_state(State.NORMAL if is_on_floor() else State.AIR)

		State.STUN:
			if sprite.animation == "tostun":
				play_anim("stuned")
			elif sprite.animation == "outstun":
				change_state(State.NORMAL if is_on_floor() else State.AIR)


func _on_attack_area_entered(area: Area2D) -> void:
	hit_target(area)


func _on_attack_body_entered(body: Node2D) -> void:
	hit_target(body)


func hit_target(target: Node) -> void:
	if not target.has_method("take_damage"):
		return

	var knock_dir: int = int(signf(target.global_position.x - global_position.x))

	if knock_dir == 0:
		knock_dir = facing_dir

	target.take_damage(attack_damage, knock_dir, current_hit_id)

func get_damage_target(target: Node) -> Node:
	if target.has_method("take_damage"):
		return target

	if target.get_parent() and target.get_parent().has_method("take_damage"):
		return target.get_parent()

	if target.owner and target.owner.has_method("take_damage"):
		return target.owner

	return null

func play_submerge() -> void:
	change_state(State.SUBMERGE)


func play_slash_effect() -> void:
	effects.visible = true
	effects.frame = 0
	effects.play("slashs")


func _on_effects_animation_finished() -> void:
	effects.visible = false
	effects.stop()

func spawn_projectile() -> void:
	if projectile_spawned:
		return

	projectile_spawned = true

	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	projectile.global_position = projectile_spawn_point.global_position
	projectile.damage = projectile_damage
	projectile.set_direction(locked_dir)

func _on_effects2_animation_finished() -> void:
	if state != State.PROJECTILE_ATTACK:
		return

	if effects2.animation == "charging":
		effects2.frame = 0
		effects2.play("tocast")
		return

	if effects2.animation == "tocast":
		effects2.visible = false
		effects2.stop()
	
func _on_effects2_frame_changed() -> void:
	if state != State.PROJECTILE_ATTACK:
		return

	if effects2.animation == "tocast":
		var total_frames := effects2.sprite_frames.get_frame_count("tocast")

		if effects2.frame >= total_frames - 2 and not cast_started_from_effect:
			cast_started_from_effect = true
			play_anim("cast")


func get_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemy")

	var nearest: Node2D = null
	var nearest_distance := INF

	for enemy in enemies:
		if not enemy is Node2D:
			continue

		var distance := global_position.distance_to(enemy.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy

	return nearest



func summon_bats() -> void:
	var enemy := get_nearest_enemy()

	if enemy == null:
		return

	var offsets := [
		Vector2(-4, -4),
		Vector2(4, -4),
		Vector2(0, 0),
		Vector2(-4, 4),
		Vector2(4, 4)
	]

	for i in bat_count:
		var bat = bat_scene.instantiate()
		get_tree().current_scene.add_child(bat)

		var offset: Vector2 = offsets[i % offsets.size()]
		bat.global_position = bat_spawn_point.global_position + offset

		bat.setup(self, enemy, locked_dir)
		bat.damage = bat_damage

		await get_tree().create_timer(bat_spawn_delay).timeout
	

func start_bat_attack() -> void:
	velocity.x = 0.0
	locked_dir = facing_dir
	bats_summoned = false
	play_anim("toheavycharge")
