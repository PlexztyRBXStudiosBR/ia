"""
Biblioteca de código AAA (GDScript / Luau / HLSL-like) usada pelo site e pelo chat.
Cada entrada: id, título, engine, tags, código, explicação curta.
"""
from __future__ import annotations

from typing import Dict, List

__all__ = ["SNIPPETS", "search", "categories"]


def _s(sid: str, title: str, engine: str, tags: List[str], lang: str, code: str, note: str) -> Dict:
    return {"id": sid, "title": title, "engine": engine, "tags": tags, "lang": lang, "code": code, "note": note}


SNIPPETS: List[Dict] = [
    _s("godot_player", "Player Controller 3D (Godot 4)", "godot", ["movimento", "player", "characterbody"], "gdscript", '''extends CharacterBody3D

@export var speed := 5.0
@export var sprint_multiplier := 1.6
@export var jump_velocity := 4.8
@export var acceleration := 10.0
@export var friction := 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var target_speed := speed * (sprint_multiplier if Input.is_action_pressed("sprint") else 1.0)

	if direction:
		velocity.x = lerp(velocity.x, direction.x * target_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * target_speed, acceleration * delta)
		look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)

	move_and_slide()
''', "Base sólida com aceleração/fricção (nada de movimento 'patinando')."),

    _s("godot_state_machine", "Máquina de estados (animações) com AnimationTree", "godot", ["animação", "animationtree"], "gdscript", '''extends AnimationTree
## Uso: ligue `active = true` e chame set_state("run") etc.

@export var animation_player: AnimationPlayer

var _state_machine: AnimationNodeStateMachinePlayback

func _ready() -> void:
	_state_machine = get("parameters/playback")

func set_state(state: StringName) -> void:
	if _state_machine:
		_state_machine.travel(state)

func set_blend(value: float) -> void:
	# blend_position do BlendSpace1D "Locomotion"
	set("parameters/Locomotion/blend_position", value)
''', "Travel entre estados sem travar a animação atual."),

    _s("godot_signals", "Sinais + grupos: comunicação desacoplada", "godot", ["arquitetura", "sinais"], "gdscript", '''# Qualquer nó:
func _ready() -> void:
	add_to_group("enemies")

# Quem quer ouvir (sem referência direta):
func _on_player_damaged() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.alert(global_position)

# Sinal global via autoload:
# Em autoload/GameEvents.gd:
#   signal player_damaged(amount: float)
# Em qualquer lugar: GameEvents.player_damaged.emit(12.0)
''', "Grupos + autoload de eventos evitam acoplamento e memória vazada."),

    _s("godot_lods", "LODs por distância (VisibilityRange + LODs)", "godot", ["performance", "lod"], "gdscript", '''extends MeshInstance3D
## Troca de LOD por distância sem addon.
@export var lods: Array[Mesh] = []
@export var distances: Array[float] = [25.0, 60.0, 120.0]

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam or lods.is_empty():
		return
	var d := global_position.distance_to(cam.global_position)
	var idx := 0
	for i in range(distances.size()):
		if d > distances[i]:
			idx = i + 1
	var target: Mesh = lods[mini(idx, lods.size() - 1)]
	if mesh != target:
		mesh = target
''', "Combine com o export de LODs do Arkher (o .glb sai com LOD0/1/2)."),

    _s("godot_shader_water", "Shader de água com ondas e espuma", "godot", ["shader", "água", "vfx"], "glsl", '''shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

uniform vec4 deep : source_color = vec4(0.02, 0.12, 0.22, 0.95);
uniform vec4 shallow : source_color = vec4(0.15, 0.5, 0.58, 0.6);
uniform float wave_speed = 0.6;
uniform float wave_height = 0.1;

void vertex() {
	VERTEX.y += sin((VERTEX.x + VERTEX.z) * 4.0 + TIME * wave_speed * 8.0) * wave_height;
}

void fragment() {
	float w = sin((UV.x + UV.y) * 30.0 + TIME * wave_speed * 6.0) * 0.5 + 0.5;
	vec3 col = mix(deep.rgb, shallow.rgb, w);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(col, vec3(0.8, 0.92, 1.0), fresnel * 0.6);
	ROUGHNESS = 0.08;
	ALPHA = mix(deep.a, 1.0, fresnel);
}
''', "Fresnel + ondas no vertex = água barata e bonita."),

    _s("godot_save", "Save/Load seguro com versionamento", "godot", ["save", "dados"], "gdscript", '''const SAVE_VERSION := 2

func save(path := "user://save.json") -> void:
	var data := {
		"version": SAVE_VERSION,
		"player": {
			"pos": [global_position.x, global_position.y, global_position.z],
			"health": health,
			"level": level,
		},
		"world": {"time": world_time, "flags": quest_flags},
	}
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(data))

func load_game(path := "user://save.json") -> void:
	if not FileAccess.file_exists(path):
		return
	var raw = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var version: int = raw.get("version", 1)
	var data: Dictionary = raw
	if version < SAVE_VERSION:
		data = _migrate(data, version)
	var p: Dictionary = data.get("player", {})
	global_position = Vector3(p.get("pos", [0, 0, 0])[0], p.get("pos", [0,0,0])[1], p.get("pos", [0,0,0])[2])

func _migrate(data: Dictionary, from: int) -> Dictionary:
	# migrações encadeadas -- NUNCA quebre saves antigos
	if from == 1:
		data["player"]["level"] = 1
		data["version"] = 2
	return data
''', "Migração encadeada = save de jogador nunca vira lixo após update."),

    _s("roblox_datastore", "DataStore robusto (retries + autosave + BindToClose)", "roblox", ["dados", "datastore"], "lua", '''local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("player_v1")

local function loadProfile(userId: number): {[string]: any}?
	for attempt = 1, 4 do
		local ok, data = pcall(store.GetAsync, store, "u" .. userId)
		if ok then return data end
		task.wait(2 ^ attempt * 0.5)
	end
	return nil
end

local function saveProfile(userId: number, data: {[string]: any}): boolean
	for attempt = 1, 4 do
		local ok = pcall(store.SetAsync, store, "u" .. userId, data)
		if ok then return true end
		task.wait(2 ^ attempt * 0.5)
	end
	return false
end

game:BindToClose(function()
	for _, p in ipairs(game.Players:GetPlayers()) do
		saveProfile(p.UserId, profiles[p])
	end
	task.wait(1)
end)
''', "Exponential backoff + BindToClose = zero perda de progresso."),

    _s("roblox_anticheat", "Anti-exploit: validação server-side de dano", "roblox", ["segurança", "combate"], "lua", '''-- NUNCA confie no cliente para dano/moedas/loot.
remote.OnServerEvent:Connect(function(player, target, damageSentByClient)
	-- ignora completamente o valor enviado pelo cliente
	local distance = (player.Character.HumanoidRootPart.Position
		- target.Character.HumanoidRootPart.Position).Magnitude
	if distance > MAX_RANGE then return end          -- teleport cheat
	if tick() - (lastAttack[player] or 0) < COOLDOWN then return end  -- autoclicker
	lastAttack[player] = tick()
	target:TakeDamage(SERVER_DAMAGE)                   -- valor oficial do servidor
end)
''', "Os 3 checks que eliminam 90% dos exploits de combate."),

    _s("roblox_tween_ui", "UI polida com TweenService", "roblox", ["ui", "ux"], "lua", '''local TweenService = game:GetService("TweenService")

local function popIn(gui: GuiObject, overshoot: number?)
	gui.Size = UDim2.fromScale(0.6, 0.6)
	gui.BackgroundTransparency = 1
	gui.Visible = true
	TweenService:Create(gui, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0), {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
	}):Play()
end

local function shake(gui: GuiObject, intensity: number, duration: number)
	local original = gui.Position
	local t0 = tick()
	while tick() - t0 < duration do
		local k = 1 - (tick() - t0) / duration
		gui.Position = original + UDim2.fromOffset(
			math.random(-100, 100) / 100 * intensity * k,
			math.random(-100, 100) / 100 * intensity * k)
		task.wait()
	end
	gui.Position = original
end
''', "Back easing no pop-in dá aquela sensação 'AAA' de UI."),

    _s("roblox_streaming", "StreamingEnabled + regiões para mundo grande", "roblox", ["performance", "mundo"], "lua", '''-- Workspace.StreamingEnabled = true  (já vem no projeto do Arkher)
-- Regiões de streaming manual para pontos de interesse:
local StreamManager = {}

function StreamManager.markImportant(part: BasePart)
	part:AddTag("StreamImportant")
end

-- no servidor, priorize áreas com jogadores:
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local hrp = char:WaitForChild("HumanoidRootPart")
		game:GetService("Workspace").StreamingTarget = hrp
	end)
end)
''', "StreamingTarget no root do personagem reduz pop-in perceptível."),

    _s("shader_grass", "Vento em vegetação (vertex animation)", "godot", ["shader", "vegetação"], "glsl", '''shader_type spatial;
render_mode cull_disabled, alpha_scissor;

uniform float wind_strength = 0.4;
uniform float wind_speed = 1.6;
uniform sampler2D wind_noise;

void vertex() {
	// COLOR.r marca o quanto o vértice balança (pinta no DCC ou por height)
	float mask = pow(COLOR.r, 1.5);
	vec2 wdir = vec2(0.8, 0.35);
	float phase = dot(MODEL_MATRIX[3].xz, wdir) * 0.4 + TIME * wind_speed;
	float gust = texture(wind_noise, vec2(phase * 0.05, 0.5)).r;
	VERTEX.xz += wdir * sin(phase + gust * 6.28) * wind_strength * mask;
	VERTEX.y -= abs(sin(phase)) * wind_strength * 0.2 * mask;
}
''', "Máscara por vertex color = vento sem custo de CPU."),

    _s("ai_steering", "Steering: seek + arrive + separation (NPCs)", "godot", ["ia", "npc"], "gdscript", '''class_name Steering

static func seek(pos: Vector3, target: Vector3, vel: Vector3, max_speed: float) -> Vector3:
	var desired := (target - pos).normalized() * max_speed
	return desired - vel

static func arrive(pos: Vector3, target: Vector3, vel: Vector3, max_speed: float, radius := 3.0) -> Vector3:
	var to := target - pos
	var d := to.length()
	var speed := max_speed * clampf(d / radius, 0.0, 1.0)
	var desired := to.normalized() * speed
	return desired - vel

static func separation(pos: Vector3, neighbors: Array, vel: Vector3, radius := 1.6) -> Vector3:
	var push := Vector3.ZERO
	for n in neighbors:
		var d := pos - (n as Vector3)
		var dist := d.length()
		if dist > 0.001 and dist < radius:
			push += d.normalized() * (1.0 - dist / radius)
	return push - vel * 0.4
''', "Combinação clássica de Reynolds — multidões sem pathfinding caro."),

    _s("perf_pooling", "Object pooling (balas/VFX) sem garbage", "godot", ["performance"], "gdscript", '''class_name Pool extends Node

@export var scene: PackedScene
@export var size := 32
var _free: Array[Node3D] = []

func _ready() -> void:
	for i in size:
		var n := scene.instantiate() as Node3D
		n.set_process(false)
		n.visible = false
		add_child(n)
		_free.push_back(n)

func spawn(at: Transform3D) -> Node3D:
	var n: Node3D
	if _free.is_empty():
		n = scene.instantiate()
		add_child(n)
	else:
		n = _free.pop_back()
	n.transform = at
	n.visible = true
	n.set_process(true)
	return n

func despawn(n: Node3D) -> void:
	n.set_process(false)
	n.visible = false
	_free.push_back(n)
''', "Instanciar bala no meio do combate causa hitch; pool resolve."),

    _s("godot_multithread", "Thread para geração pesada (sem travar a UI)", "godot", ["performance", "thread"], "gdscript", '''extends Node

var _thread: Thread
var _result = null

func start_heavy_work(arg: int) -> void:
	if _thread and _thread.is_alive():
		return
	_thread = Thread.new()
	_thread.start(_work.bind(arg))

func _work(arg: int) -> Dictionary:
	# código pesado aqui (pathfinding grande, geração de mundo...)
	var out := {}
	for i in range(1000000):
		out[i % 97] = i
	return out

func _process(_delta: float) -> void:
	if _thread and _thread.is_started() and not _thread.is_alive():
		_result = _thread.wait_to_finish()
		_thread = null
		_on_done(_result)

func _on_done(result: Dictionary) -> void:
	print("pronto:", result.size())
''', "wait_to_finish SEMPRE no thread principal, nunca dentro da thread."),

    _s("roblox_r15_anim", "Carregar animação em R15 e trocar em runtime", "roblox", ["animação", "r15"], "lua", '''local Players = game:GetService("Players")

local ANIMS = {
	idle = "rbxassetid://0000000000",   -- troque pelo id publicado
	walk = "rbxassetid://0000000001",
	run  = "rbxassetid://0000000002",
}

local function setup(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local tracks = {}
	for name, id in pairs(ANIMS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		tracks[name] = animator:LoadAnimation(anim)
	end
	tracks.idle:Play(0.3)

	humanoid.Running:Connect(function(speed)
		local target = if speed > 20 then tracks.run elseif speed > 0.5 then tracks.walk else tracks.idle
		for _, t in pairs(tracks) do
			if t ~= target and t.IsPlaying then t:Stop(0.25) end
		end
		if not target.IsPlaying then target:Play(0.25) end
	end)
end

Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(setup)
end)
''', "Publique o KeyframeSequence do Arkher e cole o assetid aqui."),

    _s("vfx_hitstop", "Hitstop + screenshake (game feel)", "godot", ["gamefeel", "vfx"], "gdscript", '''extends Node
## Autoload "Juice": hitstop global e screenshake na câmera.

var _shake_time := 0.0
var _shake_amp := 0.0

func hitstop(seconds := 0.06) -> void:
	Engine.time_scale = 0.0
	get_tree().create_timer(seconds, true, false, false).timeout.connect(func(): Engine.time_scale = 1.0)

func shake(amplitude := 0.35, duration := 0.25) -> void:
	_shake_amp = amplitude
	_shake_time = duration

func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var cam := get_viewport().get_camera_3d()
		if cam:
			var k := _shake_amp * (_shake_time / 0.25)
			cam.h_offset = randf_range(-k, k)
			cam.v_offset = randf_range(-k, k)
	else:
		var cam := get_viewport().get_camera_3d()
		if cam and (cam.h_offset or cam.v_offset):
			cam.h_offset = 0.0
			cam.v_offset = 0.0
''', "60 ms de hitstop faz um golpe comum parecer pesado."),

    _s("godot_import", "Import .glb do Arkher com animações mapeadas", "godot", ["import", "glb"], "gdscript", '''# Em um EditorScript ou ferramenta de import:
# 1. Coloque character.glb em res://assets/models/
# 2. Crie character.glb.import com:
#    [params]
#    animations/enabled=true
#    meshes/force_blend_shape_normals=false
#    nodes/apply_node_scale=true
# 3. Ou via código:
var imp := EditorSceneFormatImporterGLTF.new()
# O Godot 4 importa automaticamente:
#   - malhas + materiais PBR (baseColor/normal/rough/metal)
#   - skeleton + AnimationPlayer com cada take (idle/walk/run/jump)
# No AnimationTree, referencie "idle", "walk"... exatamente com esses nomes,
# porque é assim que o Arkher nomeia os takes dentro do .glb.
''', "Nomes de take padronizados = AnimationTree monta sem renomear nada."),

    _s("roblox_module_pattern", "Padrão de ModuleScript com tipagem (Luau strict)", "roblox", ["arquitetura", "luau"], "lua", '''--!strict
-- Serviço com contrato tipado: o Luau acha bug antes de rodar.
local InventoryService = {}

export type Slot = { itemId: string, count: number }
export type Inventory = { slots: {Slot}, capacity: number }

function InventoryService.new(capacity: number): Inventory
	return { slots = {}, capacity = capacity }
end

function InventoryService.add(inv: Inventory, itemId: string, count: number): boolean
	local existing = table.find(inv.slots, function(s: Slot) return s.itemId == itemId end)
	if existing then
		(inv.slots[existing] :: Slot).count += count
		return true
	end
	if #inv.slots >= inv.capacity then
		return false
	end
	table.insert(inv.slots, { itemId = itemId, count = count })
	return true
end

return InventoryService
''', "`--!strict` no topo de todo ModuleScript = metade dos bugs some."),
]


def categories() -> List[str]:
    out = []
    for s in SNIPPETS:
        if s["engine"] not in out:
            out.append(s["engine"])
    return out


def search(query: str = "", engine: str = "") -> List[Dict]:
    q = (query or "").strip().lower()
    results = []
    for s in SNIPPETS:
        if engine and s["engine"] != engine:
            continue
        if not q:
            results.append(s)
            continue
        hay = " ".join([s["title"], s["note"], " ".join(s["tags"]), s["engine"]]).lower()
        if all(word in hay for word in q.split()):
            results.append(s)
    return results
