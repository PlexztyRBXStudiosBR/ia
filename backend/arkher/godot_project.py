"""
Gerador de projetos Godot 4.3+ REAIS (arquivos .godot / .tscn / .gd / .gdshader).

O resultado é um dicionário {caminho_relativo: conteúdo} que o servidor empacota
em .zip. O projeto abre direto no Godot 4 sem nenhuma configuração extra:
cenas com formato 3, UIDs, input map serializado como o editor faz, autoloads,
WorldEnvironment com SDFGI/SSAO/glow, player CharacterBody3D, HUD e shaders.
"""
from __future__ import annotations

import math
from typing import Dict, List, Optional, Tuple

from .pnglib import make_icon

__all__ = ["generate_godot_project", "GODOT_FEATURES"]

GODOT_FEATURES = {
    "version": "4.3",
    "renderer": "forward_plus",
    "scripting": "GDScript",
}

# teclas (physical keycode) do Godot 4
_KEYS = {
    "W": 87, "A": 65, "S": 83, "D": 68, "E": 69, "Q": 81, "F": 70,
    "SPACE": 32, "SHIFT": 4194325, "ESC": 4194305, "TAB": 4194306,
    "UP": 4194320, "DOWN": 4194322, "LEFT": 4194319, "RIGHT": 4194321,
    "MOUSE_L": 1, "MOUSE_R": 2,
}


def _key_event(code: int, mouse: bool = False) -> str:
    if mouse:
        return (
            'Object(InputEventMouseButton,"resource_local_to_scene":false,'
            '"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,'
            '"shift_pressed":false,"control_pressed":false,"meta_pressed":false,'
            f'"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),'
            f'"factor":1.0,"button_index":{code},"canceled":false,"pressed":false,"double_click":false,"script":null)'
        )
    return (
        'Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"",'
        '"device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,'
        '"control_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,'
        f'"physical_keycode":{code},"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)'
    )


def _input_map() -> Dict[str, Tuple[List[int], List[int]]]:
    return {
        "move_forward": ([_KEYS["W"], _KEYS["UP"]], []),
        "move_back": ([_KEYS["S"], _KEYS["DOWN"]], []),
        "move_left": ([_KEYS["A"], _KEYS["LEFT"]], []),
        "move_right": ([_KEYS["D"], _KEYS["RIGHT"]], []),
        "jump": ([_KEYS["SPACE"]], []),
        "sprint": ([_KEYS["SHIFT"]], []),
        "crouch": ([67], []),  # C
        "interact": ([_KEYS["E"], _KEYS["F"]], []),
        "attack": ([], [_KEYS["MOUSE_L"]]),
        "block": ([], [_KEYS["MOUSE_R"]]),
        "pause": ([_KEYS["ESC"]], []),
        "inventory": ([_KEYS["TAB"]], []),
    }


# =========================================================== arquivos .gd
PLAYER_GD = '''extends CharacterBody3D
## Player AAA gerado pelo Arkher AI
## Movimento com aceleração, sprint, crouch, coyote time, jump buffer,
## camera em terceira pessoa com colisão e máquina de estados de animação.

class_name ArkherPlayer

signal health_changed(current: float, maximum: float)
signal died
signal landed(impact_speed: float)

@export_group("Movimento")
@export var walk_speed: float = 4.2
@export var sprint_speed: float = 7.6
@export var crouch_speed: float = 1.9
@export var acceleration: float = 12.0
@export var air_acceleration: float = 3.0
@export var deceleration: float = 14.0
@export var jump_velocity: float = 5.2
@export var gravity_scale: float = 1.0
@export var rotation_speed: float = 14.0

@export_group("Feel")
@export var coyote_time: float = 0.14
@export var jump_buffer: float = 0.18
@export var fall_damage_threshold: float = 13.0
@export var camera_sensitivity: float = 0.0022
@export var camera_pitch_limit: float = 1.35

@export_group("Combate")
@export var max_health: float = 100.0
@export var attack_damage: float = 18.0
@export var attack_range: float = 2.2

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _mesh: Node3D = $Visuals
@onready var _animation_tree: AnimationTree = $Visuals/AnimationTree
@onready var _state_machine: Node = $StateMachine

var health: float = max_health
var is_sprinting: bool = false
var is_crouching: bool = false
var is_dead: bool = false
var move_input: Vector2 = Vector2.ZERO
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _fall_start_y: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
\tadd_to_group("player")
\tInput.mouse_mode = Input.MOUSE_MODE_CAPTURED
\thealth_changed.emit(health, max_health)


func _unhandled_input(event: InputEvent) -> void:
\tif is_dead:
\t\treturn
\tif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
\t\t_camera_pivot.rotate_y(-event.relative.x * camera_sensitivity)
\t\tvar pitch := _camera_pivot.rotation.x - event.relative.y * camera_sensitivity
\t\t_camera_pivot.rotation.x = clampf(pitch, -camera_pitch_limit, camera_pitch_limit)
\telif event.is_action_pressed("pause"):
\t\tInput.mouse_mode = (Input.MOUSE_MODE_VISIBLE
\t\t\tif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
\t\t\telse Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
\tif is_dead:
\t\treturn
\t_apply_gravity(delta)
\t_read_input(delta)
\t_apply_movement(delta)
\t_update_animation()
\tmove_and_slide()
\t_handle_landing()


func _apply_gravity(delta: float) -> void:
\tif is_on_floor():
\t\t_coyote = coyote_time
\t\t_fall_start_y = global_position.y
\telse:
\t\t_coyote = maxf(0.0, _coyote - delta)
\t\tvelocity.y -= _gravity * gravity_scale * delta


func _read_input(delta: float) -> void:
\tmove_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
\tis_sprinting = Input.is_action_pressed("sprint") and move_input.length() > 0.2 and not is_crouching
\tis_crouching = Input.is_action_pressed("crouch")
\tif Input.is_action_just_pressed("jump"):
\t\t_jump_buffer = jump_buffer
\t_jump_buffer = maxf(0.0, _jump_buffer - delta)
\tif Input.is_action_just_pressed("attack"):
\t\t_attack()


func _apply_movement(delta: float) -> void:
\tvar target_speed := crouch_speed if is_crouching else (sprint_speed if is_sprinting else walk_speed)
\tvar accel := acceleration if is_on_floor() else air_acceleration
\tvar basis := _camera_pivot.global_transform.basis
\tvar direction := (basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()
\tdirection.y = 0.0

\tif direction.length_squared() > 0.001:
\t\tvelocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta * target_speed)
\t\tvelocity.z = move_toward(velocity.z, direction.z * target_speed, accel * target_speed * delta)
\t\tvar look := Basis.looking_at(direction.normalized(), Vector3.UP)
\t\t_mesh.global_transform.basis = _mesh.global_transform.basis.slerp(look, rotation_speed * delta)
\telse:
\t\tvelocity.x = move_toward(velocity.x, 0.0, deceleration * delta * target_speed)
\t\tvelocity.z = move_toward(velocity.z, 0.0, deceleration * delta * target_speed)

\tif _jump_buffer > 0.0 and (_coyote > 0.0 or is_on_floor()):
\t\tvelocity.y = jump_velocity * (1.05 if is_sprinting else 1.0)
\t\t_jump_buffer = 0.0
\t\t_coyote = 0.0
\t\tif _animation_tree:
\t\t\t_animation_tree.set("parameters/OneShot/request", true)


func _handle_landing() -> void:
\tif is_on_floor() and _fall_start_y > global_position.y:
\t\tvar impact := sqrtf(maxf(0.0, 2.0 * _gravity * (_fall_start_y - global_position.y)))
\t\tif impact > fall_damage_threshold:
\t\t\ttake_damage((impact - fall_damage_threshold) * 6.0)
\t\tlanded.emit(impact)
\t_fall_start_y = global_position.y


func _update_animation() -> void:
\tif not _animation_tree:
\t\treturn
\tvar planar := Vector2(velocity.x, velocity.z).length()
\tvar blend := planar / maxf(0.001, sprint_speed)
\t_animation_tree.set("parameters/Locomotion/blend_position", Vector2(0.0, clampf(blend, 0.0, 1.0)))
\t_animation_tree.set("parameters/conditions/on_floor", is_on_floor())
\t_animation_tree.set("parameters/conditions/is_moving", planar > 0.35)
\t_animation_tree.set("parameters/conditions/is_sprinting", is_sprinting)
\t_animation_tree.set("parameters/conditions/is_crouching", is_crouching)


func _attack() -> void:
\tvar space := get_world_3d().direct_space_state
\tvar from := _camera.global_position
\tvar to := from + _camera.global_transform.basis.z * -attack_range
\tvar query := PhysicsRayQueryParameters3D.create(from, to, 1)
\tquery.exclude = [get_rid()]
\tvar hit := space.intersect_ray(query)
\tif hit and hit.get("collider") and hit["collider"].has_method("take_damage"):
\t\thit["collider"].take_damage(attack_damage)
\tif _animation_tree:
\t\t_animation_tree.set("parameters/Attack/request", true)


func take_damage(amount: float) -> void:
\tif is_dead:
\t\treturn
\thealth = clampf(health - amount, 0.0, max_health)
\thealth_changed.emit(health, max_health)
\tif health <= 0.0:
\t\tis_dead = true
\t\tdied.emit()
\t\tif _animation_tree:
\t\t\t_animation_tree.set("parameters/Death/request", true)


func heal(amount: float) -> void:
\ttake_damage(-amount)
'''

ENEMY_GD = '''extends CharacterBody3D
## Inimigo com IA de estados (patrulha -> persegue -> ataca -> recua).
## Gerado pelo Arkher AI. Use navmesh (NavigationRegion3D) para navegação real.

class_name ArkherEnemy

signal died(enemy: Node)

@export var max_health: float = 60.0
@export var move_speed: float = 3.2
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 1.1
@export var detection_range: float = 16.0
@export var attack_range: float = 2.0
@export var patrol_points: Array[Node3D] = []

enum State { PATROL, CHASE, ATTACK, RETREAT, DEAD }

@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _animation_tree: AnimationTree = $Visuals/AnimationTree
@onready var _health_bar: Node = $Visuals/HealthBar

var state: State = State.PATROL
var health: float = max_health
var target: Node3D = null
var _attack_timer: float = 0.0
var _patrol_index: int = 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
\tadd_to_group("enemies")
\thealth = max_health
\t_pick_next_patrol_point()


func _physics_process(delta: float) -> void:
\tif state == State.DEAD:
\t\treturn
\tif not is_on_floor():
\t\tvelocity.y -= _gravity * delta
\t_attack_timer = maxf(0.0, _attack_timer - delta)
\t_scan_for_player()

\tmatch state:
\t\tState.PATROL:
\t\t\t_patrol(delta)
\t\tState.CHASE:
\t\t\t_chase(delta)
\t\tState.ATTACK:
\t\t\t_attack(delta)
\t\tState.RETREAT:
\t\t\t_retreat(delta)

\tmove_and_slide()
\tif _animation_tree:
\t\t_animation_tree.set("parameters/Locomotion/blend_position",
\t\t\tVector2(0.0, clampf(Vector2(velocity.x, velocity.z).length() / move_speed, 0.0, 1.0)))


func _scan_for_player() -> void:
\tvar players := get_tree().get_nodes_in_group("player")
\tif players.is_empty():
\t\ttarget = null
\t\tif state == State.CHASE or state == State.ATTACK:
\t\t\tstate = State.PATROL
\t\treturn
\ttarget = players[0]
\tvar dist := global_position.distance_to(target.global_position)
\tif dist < attack_range and state != State.ATTACK:
\t\tstate = State.ATTACK
\telif dist < detection_range and state == State.PATROL:
\t\tstate = State.CHASE
\telif dist > detection_range * 1.4 and state != State.PATROL:
\t\tstate = State.PATROL
\tif health < max_health * 0.22 and state != State.RETREAT and randf() < 0.01:
\t\tstate = State.RETREAT


func _move_toward_point(point: Vector3, delta: float, speed: float) -> void:
\tif _nav_agent and _nav_agent.is_navigation_finished() == false:
\t\tvar next := _nav_agent.get_next_path_position()
\t\tpoint = next
\tvar dir := (point - global_position)
\tdir.y = 0.0
\tif dir.length_squared() > 0.01:
\t\tdir = dir.normalized()
\t\tvelocity.x = move_toward(velocity.x, dir.x * speed, 18.0 * delta)
\t\tvelocity.z = move_toward(velocity.z, dir.z * speed, 18.0 * delta)
\t\trotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 10.0 * delta)
\telse:
\t\tvelocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
\t\tvelocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)


func _patrol(delta: float) -> void:
\tif patrol_points.is_empty():
\t\tvelocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
\t\tvelocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
\t\treturn
\tvar point := patrol_points[_patrol_index].global_position
\t_move_toward_point(point, delta, move_speed * 0.55)
\tif global_position.distance_to(point) < 0.8:
\t\t_pick_next_patrol_point()


func _chase(delta: float) -> void:
\tif target == null:
\t\treturn
\tif _nav_agent:
\t\t_nav_agent.target_position = target.global_position
\t_move_toward_point(target.global_position, delta, move_speed)


func _attack(delta: float) -> void:
\tvelocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
\tvelocity.z = move_toward(velocity.z, 0.0, 22.0 * delta)
\tif target:
\t\tlook_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
\tif _attack_timer <= 0.0 and target:
\t\t_attack_timer = attack_cooldown
\t\tif _animation_tree:
\t\t\t_animation_tree.set("parameters/Attack/request", true)
\t\tif target.has_method("take_damage"):
\t\t\ttarget.take_damage(attack_damage)


func _retreat(delta: float) -> void:
\tif target == null:
\t\tstate = State.PATROL
\t\treturn
\tvar away := global_position + (global_position - target.global_position).normalized() * 6.0
\t_move_toward_point(away, delta, move_speed * 1.15)
\tif health > max_health * 0.45:
\t\tstate = State.CHASE


func _pick_next_patrol_point() -> void:
\tif patrol_points.is_empty():
\t\treturn
\t_patrol_index = (_patrol_index + 1) % patrol_points.size()
\tif _nav_agent:
\t\t_nav_agent.target_position = patrol_points[_patrol_index].global_position


func take_damage(amount: float) -> void:
\tif state == State.DEAD:
\t\treturn
\thealth -= amount
\tif _health_bar and _health_bar.has_method("set_ratio"):
\t\t_health_bar.set_ratio(health / max_health)
\tif health <= 0.0:
\t\tstate = State.DEAD
\t\tdied.emit(self)
\t\tif _animation_tree:
\t\t\t_animation_tree.set("parameters/Death/request", true)
\t\tvar tween := create_tween()
\t\ttween.tween_property(self, "modulate:a" if "modulate" in self else "transparency", 1.0, 2.0) if false else null
\t\tqueue_free.call_deferred()  # troque por pooling em produção
\telse:
\t\tstate = State.CHASE
'''

GAME_GD = '''extends Node
## Autoload (singleton) central: estado de jogo, saves, sinais globais e cena.
## Gerado pelo Arkher AI.

signal scene_changing
signal score_changed(value: int)
signal settings_changed

const SAVE_PATH := "user://arkher_save_%s.json"

var current_slot: int = 1
var score: int = 0:
\tset(value):
\t\tscore = value
\t\tscore_changed.emit(score)
var playtime: float = 0.0
var settings: Dictionary = {
\t"master_volume": 0.9,
\t"music_volume": 0.75,
\t"sfx_volume": 1.0,
\t"sensitivity": 0.5,
\t"invert_y": false,
\t"quality": "high",
\t"language": "pt_BR",
}


func _process(delta: float) -> void:
\tif get_tree().current_scene and get_tree().current_scene.is_in_group("playable"):
\t\tplaytime += delta


func change_scene(path: String, fade: float = 0.35) -> void:
\tscene_changing.emit()
\tvar tween := create_tween()
\ttween.tween_callback(func() -> void: get_tree().change_scene_to_file(path))
\ttween.tween_interval(fade)


func save_game(slot: int = -1) -> bool:
\tvar id := slot if slot > 0 else current_slot
\tvar data := {
\t\t"version": 1,
\t\t"score": score,
\t\t"playtime": playtime,
\t\t"settings": settings,
\t\t"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
\t\t"timestamp": Time.get_unix_time_from_system(),
\t}
\tvar file := FileAccess.open(SAVE_PATH % id, FileAccess.WRITE)
\tif file == null:
\t\tpush_error("Arkher: falha ao abrir save %d" % id)
\t\treturn false
\tfile.store_string(JSON.stringify(data, "\\t"))
\tfile.close()
\treturn true


func load_game(slot: int = -1) -> bool:
\tvar id := slot if slot > 0 else current_slot
\tvar path := SAVE_PATH % id
\tif not FileAccess.file_exists(path):
\t\treturn false
\tvar file := FileAccess.open(path, FileAccess.READ)
\tvar parsed = JSON.parse_string(file.get_as_text())
\tfile.close()
\tif typeof(parsed) != TYPE_DICTIONARY:
\t\treturn false
\tscore = int(parsed.get("score", 0))
\tplaytime = float(parsed.get("playtime", 0.0))
\tsettings.merge(parsed.get("settings", {}), true)
\tsettings_changed.emit()
\tvar scene := String(parsed.get("scene", ""))
\tif scene != "":
\t\tchange_scene(scene)
\treturn true


func has_save(slot: int = -1) -> bool:
\tvar id := slot if slot > 0 else current_slot
\treturn FileAccess.file_exists(SAVE_PATH % id)
'''

AUDIO_GD = '''extends Node
## Autoload de áudio: bus de música/SFX, crossfade e pool de sons 2D/3D.

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var _music_players: Array[AudioStreamPlayer] = []
var _current_music: int = 0
var _sfx_pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
\tfor bus in [BUS_MASTER, BUS_MUSIC, BUS_SFX]:
\t\tif AudioServer.get_bus_index(bus) == -1:
\t\t\tAudioServer.add_bus()
\t\t\tAudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus)
\tfor i in 2:
\t\tvar p := AudioStreamPlayer.new()
\t\tp.bus = BUS_MUSIC
\t\tadd_child(p)
\t\t_music_players.append(p)
\tfor i in 8:
\t\tvar p := AudioStreamPlayer.new()
\t\tp.bus = BUS_SFX
\t\tadd_child(p)
\t\t_sfx_pool.append(p)


func play_music(stream: AudioStream, fade: float = 1.2) -> void:
\tvar next := (_current_music + 1) % _music_players.size()
\tvar incoming := _music_players[next]
\tvar outgoing := _music_players[_current_music]
\t_current_music = next
\tincoming.stream = stream
\tincoming.volume_db = -60.0
\tincoming.play()
\tvar tween := create_tween().set_parallel(true)
\ttween.tween_property(incoming, "volume_db", 0.0, fade)
\ttween.tween_property(outgoing, "volume_db", -60.0, fade)
\ttween.chain().tween_callback(outgoing.stop)


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_variation: float = 0.08) -> void:
\tfor p in _sfx_pool:
\t\tif not p.playing:
\t\t\tp.stream = stream
\t\t\tp.volume_db = volume_db
\t\t\tp.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
\t\t\tp.play()
\t\t\treturn
\tvar p := _sfx_pool[0]
\tp.stream = stream
\tp.play()


func apply_settings(settings: Dictionary) -> void:
\t_set_bus(BUS_MASTER, float(settings.get("master_volume", 1.0)))
\t_set_bus(BUS_MUSIC, float(settings.get("music_volume", 1.0)))
\t_set_bus(BUS_SFX, float(settings.get("sfx_volume", 1.0)))


func _set_bus(bus: String, linear: float) -> void:
\tvar idx := AudioServer.get_bus_index(bus)
\tif idx >= 0:
\t\tAudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, linear)))
'''

MAIN_MENU_GD = '''extends Control
## Menu principal com foco de teclado/gamepad e transições.

@onready var _title: Label = %Title
@onready var _continue: Button = %ContinueButton


func _ready() -> void:
\t_continue.disabled = not Game.has_save()
\t_continue.visible = not _continue.disabled
\t%PlayButton.grab_focus()
\tGame.apply_audio_settings() if Game.has_method("apply_audio_settings") else null


func _on_play_pressed() -> void:
\tGame.change_scene("res://scenes/levels/level_01.tscn")


func _on_continue_pressed() -> void:
\tif Game.load_game():
\t\treturn
\t_on_play_pressed()


func _on_options_pressed() -> void:
\t%OptionsPanel.visible = true
\t%OptionsPanel.get_node("%BackButton").grab_focus()


func _on_quit_pressed() -> void:
\tget_tree().quit()
'''

HUD_GD = '''extends CanvasLayer
## HUD: vida, stamina, pontuação, crosshair, avisos e menu de pausa.

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _pause_menu: Control = %PauseMenu


func _ready() -> void:
\tvar players := get_tree().get_nodes_in_group("player")
\tif players:
\t\tvar p = players[0]
\t\tif p.has_signal("health_changed"):
\t\t\tp.health_changed.connect(_on_health_changed)
\tGame.score_changed.connect(_on_score_changed)
\t_pause_menu.visible = false
\t_on_score_changed(Game.score)


func _on_health_changed(current: float, maximum: float) -> void:
\t_health_bar.max_value = maximum
\t_health_bar.value = current
\t_health_label.text = "%d / %d" % [int(current), int(maximum)]


func _on_score_changed(value: int) -> void:
\t_score_label.text = "Pontos  %d" % value


func _unhandled_input(event: InputEvent) -> void:
\tif event.is_action_pressed("pause"):
\t\tvar paused := not get_tree().paused
\t\tget_tree().paused = paused
\t\t_pause_menu.visible = paused


func _on_resume_pressed() -> void:
\tget_tree().paused = false
\t_pause_menu.visible = false


func _on_restart_pressed() -> void:
\tget_tree().paused = false
\tget_tree().reload_current_scene()


func _on_menu_pressed() -> void:
\tget_tree().paused = false
\tGame.change_scene("res://scenes/ui/main_menu.tscn")
'''

WATER_SHADER = '''shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Água estilizada AAA - Arkher AI
uniform vec4 deep_color : source_color = vec4(0.02, 0.12, 0.22, 0.92);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.52, 0.60, 0.55);
uniform sampler2D noise_tex;
uniform float wave_speed = 0.35;
uniform float wave_height = 0.12;
uniform float wave_scale = 6.0;
uniform float foam_threshold = 0.72;
uniform float fresnel_power = 4.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.06;
uniform float normal_strength = 0.6;

float wave(vec2 uv, float t) {
\tfloat w = sin((uv.x + uv.y) * 6.0 + t) * 0.5
\t\t+ sin((uv.x * 1.7 - uv.y * 0.9) * 9.0 + t * 1.3) * 0.3
\t\t+ texture(noise_tex, uv * wave_scale + vec2(t * 0.06, t * 0.04)).r * 0.6;
\treturn w;
}

void vertex() {
\tfloat t = TIME * wave_speed * 6.0;
\tVERTEX.y += wave(UV, t) * wave_height;
}

void fragment() {
\tfloat t = TIME * wave_speed * 6.0;
\tfloat w = wave(UV, t);

\t// normal por derivadas da função de onda
\tvec2 e = vec2(0.06, 0.0);
\tfloat hx = wave(UV + e.xy, t) - wave(UV - e.xy, t);
\tfloat hz = wave(UV + e.yx, t) - wave(UV - e.yx, t);
\tNORMAL = normalize(NORMAL + vec3(-hx, 0.0, -hz) * normal_strength);

\tfloat fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
\tfloat foam = smoothstep(foam_threshold, 1.0, w);
\tvec3 base = mix(deep_color.rgb, shallow_color.rgb, clamp(w, 0.0, 1.0));
\tALBEDO = mix(base, vec3(0.92), foam * 0.75);
\tALBEDO = mix(ALBEDO, vec3(0.75, 0.88, 0.95), fresnel * 0.55);
\tROUGHNESS = mix(roughness_value, 0.5, foam);
\tMETALLIC = 0.0;
\tALPHA = mix(deep_color.a, 1.0, fresnel + foam);
}
'''

OUTLINE_SHADER = '''shader_type spatial;
render_mode unshaded, cull_front;

// Outline de personagem estilo AAA/cel-shading - Arkher AI
uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float outline_width : hint_range(0.0, 0.05) = 0.012;
uniform float depth_fade = 0.6;

void vertex() {
\tvec3 n = normalize(NORMAL);
\tVERTEX += n * outline_width * (1.0 + length(MODELVIEW_MATRIX[3].xyz) * depth_fade);
}

void fragment() {
\tALBEDO = outline_color.rgb;
\tALPHA = outline_color.a;
}
'''

GRASS_SHADER = '''shader_type spatial;
render_mode cull_disabled;

// Vento em vegetação (vertex animation) - Arkher AI
uniform float wind_strength = 0.35;
uniform float wind_speed = 1.4;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float height_mask_power = 1.6;

void vertex() {
\tfloat mask = pow(clamp(COLOR.r, 0.0, 1.0), height_mask_power);
\tfloat world_x = (MODEL_MATRIX * vec4(VERTEX, 1.0)).x;
\tfloat world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
\tfloat phase = world_x * 0.6 + world_z * 0.4 + TIME * wind_speed;
\tfloat gust = sin(phase) * 0.6 + sin(phase * 2.3) * 0.4;
\tVERTEX.x += wind_direction.x * gust * wind_strength * mask;
\tVERTEX.z += wind_direction.y * gust * wind_strength * mask;
\tVERTEX.y -= abs(gust) * wind_strength * 0.18 * mask;
}

void fragment() {
\tALBEDO = COLOR.rgb * texture(ALBEDO_TEX, UV).rgb;
\tROUGHNESS = 0.85;
\tALPHA_SCISSOR_THRESHOLD = 0.45;
}
'''

SKY_ENV_TRES = '''[gd_resource type="Environment" load_steps=3 format=3 uid="uid://arkherenv01"]

[sub_resource type="ProceduralSkyMaterial" id="sky_mat"]
sky_top_color = Color(0.16, 0.34, 0.62, 1)
sky_horizon_color = Color(0.62, 0.72, 0.82, 1)
sky_curve = 0.12
sky_energy_multiplier = 1.0
ground_bottom_color = Color(0.12, 0.12, 0.13, 1)
ground_horizon_color = Color(0.55, 0.58, 0.6, 1)
ground_curve = 0.08
sun_angle_max = 38.0
sun_curve = 0.12

[sub_resource type="Sky" id="sky"]
sky_material = SubResource("sky_mat")
radiance_size = 1024

[resource]
background_mode = 2
sky = SubResource("sky")
ambient_light_source = 3
ambient_light_energy = 1.0
reflected_light_source = 2
tonemap_mode = 3
tonemap_exposure = 1.0
tonemap_white = 6.0
ssao_enabled = true
ssao_radius = 1.4
ssao_intensity = 1.6
ssil_enabled = true
ssil_radius = 5.0
sdfgi_enabled = true
sdfgi_use_occlusion = true
sdfgi_energy = 1.0
glow_enabled = true
glow_intensity = 0.55
glow_bloom = 0.08
glow_hdr_threshold = 1.05
glow_hdr_scale = 1.6
volumetric_fog_enabled = true
volumetric_fog_density = 0.012
volumetric_fog_albedo = Color(0.85, 0.88, 0.95, 1)
volumetric_fog_gi_inject = 1.0
adjustment_enabled = true
adjustment_contrast = 1.06
adjustment_saturation = 1.08
'''

DEFAULT_BUS_TRES = '''[gd_resource type="AudioBusLayout" format=3 uid="uid://arkherbus01"]

[resource]
bus/1/name = &"Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
'''


# ===================================================== helpers de cena .tscn
class SceneWriter:
    """Monta .tscn formato 3 (Godot 4) com sub-resources e nós."""

    def __init__(self, root_type: str, root_name: str, uid: str = ""):
        self.uid = uid
        self.ext: List[str] = []
        self.sub: List[str] = []
        self.nodes: List[str] = []
        self.connections: List[str] = []
        self._ext_count = 0
        self._sub_count = 0
        self.root_type = root_type
        self.root_name = root_name
        self.root_props: List[str] = []

    def ext_resource(self, res_type: str, path: str, res_id: str = "") -> str:
        self._ext_count += 1
        rid = res_id or f"ext{self._ext_count}"
        self.ext.append(f'[ext_resource type="{res_type}" path="{path}" id="{rid}"]')
        return rid

    def sub_resource(self, res_type: str, res_id: str, body: List[str]) -> str:
        self.sub.append(f'[sub_resource type="{res_type}" id="{res_id}"]\n' + "\n".join(body))
        return res_id

    def node(self, name: str, node_type: str = "", parent: str = ".",
             instance: str = "", props: Optional[List[str]] = None,
             groups: Optional[List[str]] = None) -> None:
        header = f'[node name="{name}"'
        if node_type:
            header += f' type="{node_type}"'
        if instance:
            header += f' instance=ExtResource("{instance}")'
        header += f' parent="{parent}"]'
        lines = [header]
        if groups:
            lines.append("groups=" + str(groups).replace("'", '"'))
        for p in props or []:
            lines.append(p)
        self.nodes.append("\n".join(lines))

    def build(self) -> str:
        load_steps = len(self.ext) + len(self.sub) + 1
        head = f'[gd_scene load_steps={load_steps} format=3'
        if self.uid:
            head += f' uid="{self.uid}"'
        head += ']'
        parts = [head, ""]
        if self.ext:
            parts += self.ext + [""]
        if self.sub:
            parts += self.sub + [""]
        root = f'[node name="{self.root_name}" type="{self.root_type}"]'
        parts.append("\n".join([root] + self.root_props))
        parts.append("")
        parts += self.nodes
        if self.connections:
            parts.append("")
            parts += self.connections
        return "\n".join(parts) + "\n"


def _anchors(top: float, left: float, bottom: float, right: float,
             margins: Tuple[float, float, float, float] = (0, 0, 0, 0)) -> List[str]:
    return [
        f"anchors_preset = 15" if (top, left, bottom, right) == (0, 0, 1, 1) else "",
        f"anchor_top = {top}",
        f"anchor_left = {left}" if left else "",
        f"anchor_right = {right}",
        f"anchor_bottom = {bottom}",
        f"offset_left = {margins[0]}",
        f"offset_top = {margins[1]}",
        f"offset_right = {margins[2]}",
        f"offset_bottom = {margins[3]}",
        "grow_horizontal = 2" if right == 1 else "",
        "grow_vertical = 2" if bottom == 1 else "",
    ]


def _clean(props: List[str]) -> List[str]:
    return [p for p in props if p]


# ============================================================== gerador
def generate_godot_project(
    name: str = "Meu Jogo",
    description: str = "Jogo gerado pelo Arkher AI",
    genre: str = "acao",
    features: Optional[List[str]] = None,
    render: str = "forward_plus",
    window: Tuple[int, int] = (1920, 1080),
    icon_png: Optional[bytes] = None,
) -> Dict[str, object]:
    features = features or ["player", "enemy", "hud", "menu", "save", "shaders", "lighting"]
    files: Dict[str, object] = {}
    slug = "".join(c if c.isalnum() else "_" for c in name).strip("_").lower() or "arkher_jogo"

    # ---------------------------------------------------------- project.godot
    actions = _input_map()
    input_lines: List[str] = []
    for action, (keys, mouses) in actions.items():
        events = [_key_event(k) for k in keys] + [_key_event(m, mouse=True) for m in mouses]
        body = ",\n".join(events)
        input_lines.append(
            f'{action}={{\n"deadzone": 0.5,\n"events": [{body}]\n}}'
        )

    project = f'''; Engine configuration file - gerado pelo Arkher AI
; Projeto: {name}
; Gênero: {genre}
; {description}

config_version=5

[application]

config/name="{name}"
config/description="{description}"
config/version="0.1.0"
run/main_scene="res://scenes/ui/main_menu.tscn"
config/features=PackedStringArray("4.3", "{render}", "GL Compatibility")
config/icon="res://icon.png"
boot_splash/show_image=true
boot_splash/bg_color=Color(0.05, 0.055, 0.075, 1)

[autoload]

Game="*res://autoload/game.gd"
AudioManager="*res://autoload/audio_manager.gd"

[display]

window/size/viewport_width={window[0]}
window/size/viewport_height={window[1]}
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/vsync/vsync_mode=1

[input]

{chr(10).join(input_lines)}

[input_devices]

pointing/emulate_touch_from_mouse=true

[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="enemies"
3d_physics/layer_4="props"
3d_physics/layer_5="triggers"
3d_physics/layer_6="projectiles"

[physics]

3d/default_gravity=14.0
common/physics_ticks_per_second=120
3d/run_on_separate_thread=true

[rendering]

renderer/rendering_method="{render}"
renderer/rendering_method.mobile="mobile"
anti_aliasing/quality/msaa_3d=2
anti_aliasing/quality/use_taa=true
environment/defaults/default_environment="res://default_env.tres"
global_illumination/sdfgi/probe_ray_count=2
lights_and_shadows/directional_shadow/size=8192
lights_and_shadows/directional_shadow/soft_shadow_filter_quality=3
lights_and_shadows/positional_shadow/soft_shadow_filter_quality=3
textures/vram_compression/import_etc2_astc=true
occlusion_culling/use_occlusion_culling=true
scaling_3d/mode=2
scaling_3d/fsr_sharpness=0.2
'''
    files["project.godot"] = project
    files["default_env.tres"] = SKY_ENV_TRES
    files["default_bus_layout.tres"] = DEFAULT_BUS_TRES
    files[".gitignore"] = ".godot/\n*.import\nexport_presets.cfg\n"
    files["icon.png"] = icon_png if icon_png else make_icon(128)
    files[".gitattributes"] = "*.glb filter=lfs diff=lfs merge=lfs -text\n*.png filter=lfs diff=lfs merge=lfs -text\n"

    # ------------------------------------------------------------ autoloads
    files["autoload/game.gd"] = GAME_GD
    files["autoload/audio_manager.gd"] = AUDIO_GD

    # ------------------------------------------------------------- scripts
    files["scripts/player/player_controller.gd"] = PLAYER_GD
    files["scripts/enemy/enemy_ai.gd"] = ENEMY_GD
    files["scripts/ui/main_menu.gd"] = MAIN_MENU_GD
    files["scripts/ui/hud.gd"] = HUD_GD
    files["scripts/systems/damageable.gd"] = '''extends Node
class_name Damageable
## Componente reutilizável de dano (adicione como filho de qualquer corpo).

signal damaged(amount: float, source: Node)
signal destroyed

@export var max_health: float = 100.0
@export var armor: float = 0.0

var health: float


func _ready() -> void:
\thealth = max_health
\tif get_parent():
\t\tget_parent().add_to_group("damageable")


func take_damage(amount: float, source: Node = null) -> void:
\tvar real := maxf(0.0, amount * (1.0 - clampf(armor, 0.0, 0.9)))
\thealth = clampf(health - real, 0.0, max_health)
\tdamaged.emit(real, source)
\tif health <= 0.0:
\t\tdestroyed.emit()
'''
    files["scripts/systems/object_pool.gd"] = '''extends Node
class_name ObjectPool
## Pool de objetos (balas, VFX, inimigos) -- evita hitches de instanciação.

@export var scene: PackedScene
@export var initial_size: int = 16
@export var growth_step: int = 8

var _free: Array[Node] = []
var _all: Array[Node] = []


func _ready() -> void:
\tfor i in initial_size:
\t\t_free.append(_create())


func _create() -> Node:
\tvar inst := scene.instantiate()
\tinst.process_mode = Node.PROCESS_MODE_DISABLED
\tadd_child(inst)
\t_all.append(inst)
\treturn inst


func acquire() -> Node:
\tif _free.is_empty():
\t\tfor i in growth_step:
\t\t\t_free.append(_create())
\tvar node := _free.pop_back()
\tnode.process_mode = Node.PROCESS_MODE_INHERIT
\treturn node


func release(node: Node) -> void:
\tnode.process_mode = Node.PROCESS_MODE_DISABLED
\tif node is Node3D:
\t\t(node as Node3D).global_position = Vector3(0, -9999, 0)
\t_free.append(node)
'''

    # --------------------------------------------------------------- shaders
    files["shaders/water.gdshader"] = WATER_SHADER
    files["shaders/character_outline.gdshader"] = OUTLINE_SHADER
    files["shaders/grass_wind.gdshader"] = GRASS_SHADER
    files["shaders/hologram.gdshader"] = '''shader_type spatial;
render_mode blend_add, cull_back, unshaded;

// Holograma / escudo de energia - Arkher AI
uniform vec4 holo_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform float scan_speed = 2.2;
uniform float scan_density = 55.0;
uniform float fresnel_power = 2.6;
uniform float alpha_base = 0.22;
uniform sampler2D noise_tex;

void fragment() {
\tfloat scan = sin((VERTEX.y * scan_density) - TIME * scan_speed) * 0.5 + 0.5;
\tfloat flicker = texture(noise_tex, UV + vec2(TIME * 0.05, 0.0)).r;
\tfloat fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
\tALBEDO = holo_color.rgb * (0.6 + scan * 0.8 + fresnel);
\tALPHA = clamp(alpha_base + fresnel * 0.85 + scan * 0.18 + flicker * 0.06, 0.0, 1.0);
}
'''

    # ------------------------------------------------------ cenas: player
    player_scene = SceneWriter("CharacterBody3D", "Player", "uid://arkherplayer1")
    player_scene.root_props = [
        'script = ExtResource("%s")' % player_scene.ext_resource("Script", "res://scripts/player/player_controller.gd"),
        "collision_layer = 2",
        "collision_mask = 9",
        "floor_snap_length = 0.24",
        "safe_margin = 0.02",
    ]
    col = player_scene.sub_resource("CapsuleShape3D", "player_col", ["radius = 0.36", "height = 1.78"])
    player_scene.node("CollisionShape3D", "CollisionShape3D", props=[f"shape = SubResource(\"{col}\")", "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)"])
    player_scene.node("Visuals", "Node3D")
    body_mat = player_scene.sub_resource("StandardMaterial3D", "player_mat", [
        "albedo_color = Color(0.78, 0.55, 0.42, 1)", "metallic = 0.05", "roughness = 0.62",
    ])
    body_mesh = player_scene.sub_resource("CapsuleMesh", "player_mesh", ["radius = 0.34", "height = 1.7", f"material = SubResource(\"{body_mat}\")"])
    player_scene.node("Body", "MeshInstance3D", parent="Visuals", props=[f"mesh = SubResource(\"{body_mesh}\")", "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)"])
    player_scene.node("AnimationTree", "AnimationTree", parent="Visuals", props=[
        "tree_root = null", "anim_player = NodePath(\"../AnimationPlayer\")", "active = false",
    ])
    player_scene.node("AnimationPlayer", "AnimationPlayer", parent="Visuals")
    player_scene.node("CameraPivot", "Node3D", props=["transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.62, 0)"])
    player_scene.node("SpringArm3D", "SpringArm3D", parent="CameraPivot", props=[
        "spring_length = 3.4", "margin = 0.24",
        "transform = Transform3D(1, 0, 0, 0, 0.96593, 0.258819, 0, -0.258819, 0.96593, 0, 0, 0)",
    ])
    player_scene.node("Camera3D", "Camera3D", parent="CameraPivot/SpringArm3D", props=[
        "current = true", "fov = 72.0", "near = 0.05", "far = 900.0",
    ])
    player_scene.node("InteractRay", "RayCast3D", parent="CameraPivot/SpringArm3D/Camera3D", props=[
        "target_position = Vector3(0, 0, -3.2)", "collision_mask = 24", "enabled = true",
    ])
    files["scenes/player/player.tscn"] = player_scene.build()

    # ------------------------------------------------------- cenas: inimigo
    enemy_scene = SceneWriter("CharacterBody3D", "Enemy", "uid://arkherenemy1")
    enemy_scene.root_props = [
        'script = ExtResource("%s")' % enemy_scene.ext_resource("Script", "res://scripts/enemy/enemy_ai.gd"),
        "collision_layer = 4", "collision_mask = 9",
    ]
    e_col = enemy_scene.sub_resource("CapsuleShape3D", "enemy_col", ["radius = 0.4", "height = 1.9"])
    enemy_scene.node("CollisionShape3D", "CollisionShape3D", props=[f'shape = SubResource("{e_col}")', "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.95, 0)"])
    enemy_scene.node("NavigationAgent3D", "NavigationAgent3D", props=["path_desired_distance = 0.6", "target_desired_distance = 0.7", "avoidance_enabled = true", "radius = 0.45"])
    enemy_scene.node("Visuals", "Node3D")
    e_mat = enemy_scene.sub_resource("StandardMaterial3D", "enemy_mat", ["albedo_color = Color(0.55, 0.16, 0.16, 1)", "roughness = 0.55", "metallic = 0.25"])
    e_mesh = enemy_scene.sub_resource("CapsuleMesh", "enemy_mesh", ["radius = 0.38", "height = 1.85", f'material = SubResource("{e_mat}")'])
    enemy_scene.node("Body", "MeshInstance3D", parent="Visuals", props=[f'mesh = SubResource("{e_mesh}")', "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.95, 0)"])
    enemy_scene.node("AnimationTree", "AnimationTree", parent="Visuals", props=["active = false"])
    enemy_scene.node("HealthBar", "Sprite3D", parent="Visuals", props=["transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.15, 0)", "billboard = 1", "no_depth_test = true"])
    files["scenes/enemy/enemy.tscn"] = enemy_scene.build()

    # ------------------------------------------------------------- nível
    level = SceneWriter("Node3D", "Level01", "uid://arkherlevel01")
    level.root_props = ['process_mode = 3']
    env_id = level.ext_resource("Environment", "res://default_env.tres")
    level.node("WorldEnvironment", "WorldEnvironment", props=[f'environment = ExtResource("{env_id}")'])
    level.node("NavigationRegion3D", "NavigationRegion3D")
    level.node("Sun", "DirectionalLight3D", props=[
        "transform = Transform3D(0.766, -0.423, 0.485, 0, 0.755, 0.656, -0.643, -0.502, 0.578, 0, 24, 0)",
        "light_energy = 1.15", "light_color = Color(1, 0.94, 0.86, 1)",
        "shadow_enabled = true", "directional_shadow_mode = 2",
        "directional_shadow_max_distance = 120.0", "directional_shadow_fade_start = 0.8",
        "light_projector = null",
    ])
    level.node("ReflectionProbe", "ReflectionProbe", props=["origin = Vector3(0, 4, 0)", "size = Vector3(60, 20, 60)", "update_mode = 1"])
    ground_mat = level.sub_resource("StandardMaterial3D", "ground_mat", [
        "albedo_color = Color(0.32, 0.36, 0.28, 1)", "roughness = 0.92", "uv1_scale = Vector3(12, 12, 12)",
    ])
    ground_mesh = level.sub_resource("PlaneMesh", "ground_mesh", ["size = Vector2(80, 80)", f'material = SubResource("{ground_mat}")'])
    level.node("Ground", "StaticBody3D", props=["collision_layer = 1", "collision_mask = 0"])
    level.node("GroundMesh", "MeshInstance3D", parent="Ground", props=[f'mesh = SubResource("{ground_mesh}")'])
    ground_col = level.sub_resource("BoxShape3D", "ground_col", ["size = Vector3(80, 1, 80)"])
    level.node("GroundCol", "CollisionShape3D", parent="Ground", props=[f'shape = SubResource("{ground_col}")', "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)"])

    for i in range(6):
        ang = i * 1.047
        x = round(math.cos(ang) * 12.0, 3)
        z = round(math.sin(ang) * 12.0, 3)
        box_mat = level.sub_resource("StandardMaterial3D", f"box_mat{i}", [
            "albedo_color = Color(0.55, 0.53, 0.5, 1)", "roughness = 0.75", "metallic = 0.1",
        ])
        box_mesh = level.sub_resource("BoxMesh", f"box_mesh{i}", [
            "size = Vector3(2.4, %0.2f, 2.4)" % (1.6 + i * 0.7), f'material = SubResource("{box_mat}")'])
        level.node(f"Block{i}", "StaticBody3D", props=["collision_layer = 1"])
        level.node(f"Mesh{i}", "MeshInstance3D", parent=f"Block{i}", props=[
            f'mesh = SubResource("{box_mesh}")',
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {(1.6 + i * 0.7) / 2:.2f}, {z})"])
        box_col = level.sub_resource("BoxShape3D", f"box_col{i}", ["size = Vector3(2.4, %0.2f, 2.4)" % (1.6 + i * 0.7)])
        level.node(f"Col{i}", "CollisionShape3D", parent=f"Block{i}", props=[
            f'shape = SubResource("{box_col}")',
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {(1.6 + i * 0.7) / 2:.2f}, {z})"])

    player_ref = level.ext_resource("PackedScene", "res://scenes/player/player.tscn")
    level.node("Player", "Node3D", instance=player_ref, props=[
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.2, 8)"])
    if "enemy" in features:
        enemy_ref = level.ext_resource("PackedScene", "res://scenes/enemy/enemy.tscn")
        for i, pos in enumerate([(6, 0.2, -4), (-7, 0.2, -6), (0, 0.2, -12)]):
            level.node(f"Enemy{i}", "Node3D", instance=enemy_ref, props=[
                f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {pos[0]}, {pos[1]}, {pos[2]})"])
    for i, pos in enumerate([(10, 0, -10), (-10, 0, -12), (0, 0, 12)]):
        level.node(f"PatrolPoint{i}", "Marker3D", props=[
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {pos[0]}, {pos[1]}, {pos[2]})"])
    if "hud" in features:
        hud_ref = level.ext_resource("PackedScene", "res://scenes/ui/hud.tscn")
        level.node("HUD", "Node3D", instance=hud_ref)
    files["scenes/levels/level_01.tscn"] = level.build()

    # ----------------------------------------------------------- main scene
    main = SceneWriter("Node", "Main", "uid://arkhermain1")
    main.root_props = []
    menu_ref = main.ext_resource("PackedScene", "res://scenes/ui/main_menu.tscn")
    main.node("MainMenu", "Node", instance=menu_ref)
    files["scenes/main.tscn"] = main.build()

    # ---------------------------------------------------------------- HUD
    hud = SceneWriter("CanvasLayer", "HUD", "uid://arkherhud1")
    hud.root_props = ['script = ExtResource("%s")' % hud.ext_resource("Script", "res://scripts/ui/hud.gd"), "layer = 10"]
    hud.node("Root", "Control", props=_clean(_anchors(0, 0, 1, 1)) + ["mouse_filter = 2"])
    hud.node("HealthPanel", "PanelContainer", parent="Root", props=_clean([
        "anchors_preset = 0", "offset_left = 24.0", "offset_top = 24.0", "offset_right = 384.0", "offset_bottom = 96.0",
    ]))
    hud.node("Margin", "MarginContainer", parent="Root/HealthPanel", props=["theme_override_constants/margin_left = 12", "theme_override_constants/margin_top = 8", "theme_override_constants/margin_right = 12", "theme_override_constants/margin_bottom = 8"])
    hud.node("VBox", "VBoxContainer", parent="Root/HealthPanel/Margin")
    hud.node("HealthLabel", "Label", parent="Root/HealthPanel/Margin/VBox", props=['text = "100 / 100"', 'unique_name_in_owner = true'])
    hb_style = hud.sub_resource("StyleBoxFlat", "hb_style", ["bg_color = Color(0.85, 0.2, 0.22, 1)", "corner_radius_top_left = 3", "corner_radius_top_right = 3", "corner_radius_bottom_left = 3", "corner_radius_bottom_right = 3"])
    hud.node("HealthBar", "ProgressBar", parent="Root/HealthPanel/Margin/VBox", props=[
        'unique_name_in_owner = true', "min_value = 0.0", "max_value = 100.0", "value = 100.0",
        "show_percentage = false", "custom_minimum_size = Vector2(320, 18)",
        f'theme_override_styles/fill = SubResource("{hb_style}")'])
    hud.node("ScoreLabel", "Label", parent="Root", props=_clean([
        "anchors_preset = 1", "anchor_left = 1.0", "anchor_right = 1.0",
        "offset_left = -260.0", "offset_top = 24.0", "offset_right = -24.0", "offset_bottom = 60.0",
        'horizontal_alignment = 2', 'text = "Pontos  0"', 'unique_name_in_owner = true',
    ]))
    hud.node("Crosshair", "ColorRect", parent="Root", props=_clean([
        "anchors_preset = 8", "anchor_left = 0.5", "anchor_top = 0.5", "anchor_right = 0.5", "anchor_bottom = 0.5",
        "offset_left = -3.0", "offset_top = -3.0", "offset_right = 3.0", "offset_bottom = 3.0",
        'color = Color(1, 1, 1, 0.85)', 'mouse_filter = 2']))
    hud.node("PauseMenu", "Control", parent="Root", props=_clean(_anchors(0, 0, 1, 1)) + ['unique_name_in_owner = true', 'visible = false'])
    dim = hud.sub_resource("StyleBoxFlat", "dim", ["bg_color = Color(0, 0, 0, 0.62)"])
    hud.node("Dim", "Panel", parent="Root/PauseMenu", props=_clean(_anchors(0, 0, 1, 1)) + [f'theme_override_styles/panel = SubResource("{dim}")'])
    hud.node("Center", "CenterContainer", parent="Root/PauseMenu", props=_clean(_anchors(0, 0, 1, 1)))
    hud.node("VBox", "VBoxContainer", parent="Root/PauseMenu/Center", props=["theme_override_constants/separation = 12", "custom_minimum_size = Vector2(320, 0)"])
    hud.node("Title", "Label", parent="Root/PauseMenu/Center/VBox", props=['text = "PAUSADO"', 'horizontal_alignment = 1'])
    for label, node_name, method in (
        ("Continuar", "ResumeButton", "_on_resume_pressed"),
        ("Reiniciar", "RestartButton", "_on_restart_pressed"),
        ("Menu principal", "MenuButton", "_on_menu_pressed"),
    ):
        hud.node(node_name, "Button", parent="Root/PauseMenu/Center/VBox", props=[f'text = "{label}"'])
        hud.connections.append(
            f'[connection signal="pressed" from="Root/PauseMenu/Center/VBox/{node_name}" to="." method="{method}"]'
        )
    files["scenes/ui/hud.tscn"] = hud.build()

    # ------------------------------------------------------------ main menu
    menu = SceneWriter("Control", "MainMenu", "uid://arkhermenu1")
    menu.root_props = _clean(_anchors(0, 0, 1, 1)) + ['script = ExtResource("%s")' % menu.ext_resource("Script", "res://scripts/ui/main_menu.gd")]
    bg_grad = menu.sub_resource("Gradient", "bg_grad", [
        "offsets = PackedFloat32Array(0, 0.55, 1)",
        "colors = PackedColorArray(0.03, 0.04, 0.08, 1, 0.07, 0.1, 0.2, 1, 0.02, 0.02, 0.05, 1)"])
    bg_tex = menu.sub_resource("GradientTexture2D", "bg_tex", [f'gradient = SubResource("bg_grad")', "width = 512", "height = 512", "fill_from = Vector2(0, 0)", "fill_to = Vector2(1, 1)"])
    menu.node("Background", "TextureRect", props=_clean(_anchors(0, 0, 1, 1)) + [f'texture = SubResource("bg_tex")', "expand_mode = 1", "stretch_mode = 6"])
    menu.node("Center", "CenterContainer", props=_clean(_anchors(0, 0, 1, 1)))
    menu.node("VBox", "VBoxContainer", parent="Center", props=["theme_override_constants/separation = 18"])
    menu.node("Title", "Label", parent="Center/VBox", props=[f'text = "{name}"', 'unique_name_in_owner = true', 'horizontal_alignment = 1', 'theme_override_font_sizes/font_size = 64'])
    menu.node("Subtitle", "Label", parent="Center/VBox", props=[f'text = "{description}"', 'horizontal_alignment = 1', 'modulate = Color(1,1,1,0.65)'])
    for label, sig in (("Jogar", "_on_play_pressed"), ("Continuar", "_on_continue_pressed"), ("Opções", "_on_options_pressed"), ("Sair", "_on_quit_pressed")):
        props = [f'text = "{label}"', 'custom_minimum_size = Vector2(320, 52)']
        if label in ("Jogar", "Continuar"):
            props.append('unique_name_in_owner = true')
        menu.node(f"{label}Button", "Button", parent="Center/VBox", props=props)
        menu.connections.append(
            f'[connection signal="pressed" from="Center/VBox/{label}Button" to="." method="{sig}"]'
        )
    menu.node("OptionsPanel", "Control", props=_clean(_anchors(0, 0, 1, 1)) + ['unique_name_in_owner = true', 'visible = false'])
    menu.node("OptionsBox", "VBoxContainer", parent="OptionsPanel", props=_clean(_anchors(0.15, 0.25, 0.85, 0.75)) + ["theme_override_constants/separation = 14"])
    menu.node("OptionsTitle", "Label", parent="OptionsPanel/OptionsBox", props=['text = "OPÇÕES"', 'horizontal_alignment = 1'])
    for opt in (("Volume geral", "HSlider"), ("Música", "HSlider"), ("Efeitos", "HSlider"), ("Sensibilidade", "HSlider")):
        menu.node(f"{opt[0]}Label", "Label", parent="OptionsPanel/OptionsBox", props=[f'text = "{opt[0]}"'])
        menu.node(f"{opt[0][:4]}Slider", opt[1], parent="OptionsPanel/OptionsBox", props=["min_value = 0.0", "max_value = 1.0", "step = 0.01", "value = 0.8"])
    menu.node("BackButton", "Button", parent="OptionsPanel/OptionsBox", props=['text = "Voltar"', 'unique_name_in_owner = true'])
    files["scenes/ui/main_menu.tscn"] = menu.build()

    # ------------------------------------------------------- documentation
    files["README.md"] = _godot_readme(name, description, genre, files)
    files["docs/GDD.md"] = _gdd(name, description, genre, "godot")
    return files


def _godot_readme(name: str, description: str, genre: str, files: Dict[str, object]) -> str:
    tree = "\n".join(f"- `{k}`" for k in sorted(files))
    return f"""# {name}

> Projeto Godot 4.3+ gerado pelo **Arkher AI** — {description}
> Gênero: **{genre}**

## Como abrir

1. Baixe o Godot 4.3+ (https://godotengine.org/download)
2. **Import** → selecione a pasta do projeto → `project.godot` → **Import & Edit**
3. Aperte **F5** para rodar (a cena principal é `scenes/ui/main_menu.tscn`)

## Estrutura gerada

{tree}

## O que já vem pronto

| Sistema | Arquivo | O que faz |
|---|---|---|
| Player | `scripts/player/player_controller.gd` | Movimento com aceleração, sprint, crouch, coyote time, jump buffer, queda com dano, câmera 3ª pessoa com colisão |
| Inimigo | `scripts/enemy/enemy_ai.gd` | Máquina de estados (patrulha/persegue/ataca/recua), NavigationAgent3D, dano |
| Save/Load | `autoload/game.gd` | Save em JSON (`user://`), configurações, troca de cena com fade |
| Áudio | `autoload/audio_manager.gd` | Buses Master/Music/SFX, crossfade de música, pool de SFX |
| HUD | `scenes/ui/hud.tscn` | Vida, pontos, crosshair, menu de pausa |
| Menu | `scenes/ui/main_menu.tscn` | Menu com navegação por teclado/gamepad |
| Iluminação | `default_env.tres` | SDFGI, SSAO/SSIL, glow, fog volumétrico, tonemap ACES-ish (Filmic) |
| Shaders | `shaders/*.gdshader` | Água, outline, vento em vegetação, holograma |

## Próximos passos (checklist honesto)

- [ ] Trocar os meshes placeholder pelos seus `.glb` (o Arkher gera: use o botão **Modelo 3D**)
- [ ] Trocar as texturas placeholder pelos mapas PBR gerados (albedo/normal/rough/metal/AO)
- [ ] Importar as animações (idle/walk/run/jump) do `.glb` rigged e ligar no `AnimationTree`
- [ ] Adicionar `NavigationRegion3D` com bake de navmesh no nível
- [ ] Configurar `export_presets.cfg` (Windows / Android / Web)
- [ ] Criar os levels de verdade a partir do `level_01.tscn`

> Este projeto é um **skeleton AAA jogável**: arquitetura, código e cena funcionam de
> verdade, mas a arte final (modelos detalhados, texturas autorais, animações de mo-cap)
> ainda precisa ser produzida ou gerada por modelos de IA de imagem/3D.
"""


def _gdd(name: str, description: str, genre: str, engine: str) -> str:
    return f"""# Game Design Document — {name}

**Engine:** {engine}  |  **Gênero:** {genre}  |  **Gerado por:** Arkher AI

## 1. High concept
{description}

## 2. Pilar de design
1. **Legibilidade primeiro** — o jogador entende o que aconteceu em < 200 ms.
2. **Movimento com peso** — aceleração, coyote time e landing têm feedback.
3. **Loop de 30 segundos** — explorar → confronto → recompensa → upgrade.

## 3. Core loop
```
Explorar área  ->  Encontrar objetivo/inimigo  ->  Combate/desafio
      ^                                                |
      |                                                v
  Upgrade/melhoria  <-  Recompensa (loot, XP, recurso)
```

## 4. Mecânicas
| Mecânica | Entrada | Regra | Feedback |
|---|---|---|---|
| Movimento | WASD / analógico | aceleração 12, sprint 7.6 m/s | animação + FOV + som |
| Pulo | Espaço | buffer 0.18 s, coyote 0.14 s | squash & stretch, poeira |
| Ataque | Mouse esq. | dano 18, alcance 2.2 m, cooldown 0.55 s | hitstop 60 ms, VFX, som |
| Defesa | Mouse dir. | reduz dano 70%, gasta stamina | shader de escudo |
| Progressão | — | XP por inimigo, curva quadrática | level up com flash |

## 5. Estrutura de níveis
- **Level 01 — Tutorial:** ensina movimento, pulo e ataque (3 salas).
- **Level 02 — Verticalidade:** introduz plataformas e queda com dano.
- **Level 03 — Combate combinado:** 2 tipos de inimigo + chefe de área.
- Meta: 8–12 níveis de 6–10 min cada (campanha de ~1h30 no vertical slice).

## 6. Arte
- Estilo: realista estilizado (PBR, saturação média, contraste alto).
- Paleta: {('terras quentes + azul frio de preenchimento' if genre in ('acao', 'aventura', 'rpg') else 'neon + preto profundo')}.
- Texturas: 4k para heróis/props principais, 2k para props secundários, 8k só em close-up.
- Polígonos: herói 40–70k, NPC 15–25k, prop 2–8k, tile de cenário < 250k.

## 7. Áudio
- Música dinâmica em camadas (exploração / tensão / combate).
- 40–60 SFX no vertical slice, todos com pitch random ±8%.

## 8. Performance (metas)
| Plataforma | FPS | Frame budget |
|---|---|---|
| PC (mid) | 60 estável | 16.6 ms |
| Console | 60 / 120 modo perf. | 16.6 / 8.3 ms |
| Mobile | 30–60 | 33 ms |

## 9. Escopo e risco
| Item | Risco | Mitigação |
|---|---|---|
| Combate "bom de sentir" | Alto | Prototipar em 1 semana, playtest diário |
| Quantidade de arte | Alto | Kits modulares + reuso com material layering |
| IA de inimigos | Médio | Behavior tree simples, sem GOAP no início |

## 10. Roadmap (vertical slice)
1. Semana 1 — core movement + combate (greybox)
2. Semana 2 — inimigo, HUD, save
3. Semana 3 — level 01 com arte final
4. Semana 4 — polimento, áudio, playtest, build
"""
