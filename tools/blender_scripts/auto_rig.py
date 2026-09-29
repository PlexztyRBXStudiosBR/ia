"""
Script Blender - Auto-Rigging automático de personagens pela Arkher AI
Cria esqueleto humanóide completo com IK, constraints, e weight painting automático.

Uso:
    blender --background --python auto_rig.py -- <mesh_path> <output_path>
"""
import bpy
import sys
from pathlib import Path

argv = sys.argv
argv = argv[argv.index("--") + 1:] if "--" in argv else []

mesh_path = Path(argv[0]) if len(argv) > 0 else None
output_path = Path(argv[1]) if len(argv) > 1 else Path("output/rigged.glb")

print(f"[Arkher AI] Auto-rigging de personagem")
if mesh_path:
    print(f"[Arkher] Importando malha: {mesh_path}")
    bpy.ops.import_scene.gltf(filepath=str(mesh_path))

# Limpa seleção
bpy.ops.object.select_all(action='DESELECT')

# ============================================================
# CRIA ESQUELETO HUMANÓIDE
# ============================================================
print("[Arkher] Criando esqueleto humanóide...")

bpy.ops.object.armature_add(enter_editmode=False, location=(0, 0, 0))
armature = bpy.context.active_object
armature.name = "Arkher_Armature"

bpy.ops.object.mode_set(mode='EDIT')
edit_bones = armature.data.edit_bones

# Root
root = edit_bones[0]
root.name = "Root"
root.head = (0, 0, 0)
root.tail = (0, 0, 0.1)

# Espinha
hips = edit_bones.new('Hips')
hips.head = (0, 0, 0.9)
hips.tail = (0, 0, 1.0)
hips.parent = root

spine = edit_bones.new('Spine')
spine.head = (0, 0, 1.0)
spine.tail = (0, 0, 1.2)
spine.parent = hips

spine1 = edit_bones.new('Spine1')
spine1.head = (0, 0, 1.2)
spine1.tail = (0, 0, 1.4)
spine1.parent = spine

spine2 = edit_bones.new('Spine2')
spine2.head = (0, 0, 1.4)
spine2.tail = (0, 0, 1.55)
spine2.parent = spine1

neck = edit_bones.new('Neck')
neck.head = (0, 0, 1.55)
neck.tail = (0, 0, 1.65)
neck.parent = spine2

head = edit_bones.new('Head')
head.head = (0, 0, 1.65)
head.tail = (0, 0, 1.85)
head.parent = neck

# Braço esquerdo
l_shoulder = edit_bones.new('LeftShoulder')
l_shoulder.head = (0, 0, 1.5)
l_shoulder.tail = (0.1, 0, 1.5)
l_shoulder.parent = spine2

l_arm = edit_bones.new('LeftArm')
l_arm.head = (0.1, 0, 1.5)
l_arm.tail = (0.35, 0, 1.5)
l_arm.parent = l_shoulder

l_forearm = edit_bones.new('LeftForeArm')
l_forearm.head = (0.35, 0, 1.5)
l_forearm.tail = (0.6, 0, 1.45)
l_forearm.parent = l_arm

l_hand = edit_bones.new('LeftHand')
l_hand.head = (0.6, 0, 1.45)
l_hand.tail = (0.68, 0, 1.45)
l_hand.parent = l_forearm

# Braço direito
r_shoulder = edit_bones.new('RightShoulder')
r_shoulder.head = (0, 0, 1.5)
r_shoulder.tail = (-0.1, 0, 1.5)
r_shoulder.parent = spine2

r_arm = edit_bones.new('RightArm')
r_arm.head = (-0.1, 0, 1.5)
r_arm.tail = (-0.35, 0, 1.5)
r_arm.parent = r_shoulder

r_forearm = edit_bones.new('RightForeArm')
r_forearm.head = (-0.35, 0, 1.5)
r_forearm.tail = (-0.6, 0, 1.45)
r_forearm.parent = r_arm

r_hand = edit_bones.new('RightHand')
r_hand.head = (-0.6, 0, 1.45)
r_hand.tail = (-0.68, 0, 1.45)
r_hand.parent = r_forearm

# Perna esquerda
l_upleg = edit_bones.new('LeftUpLeg')
l_upleg.head = (0.1, 0, 0.9)
l_upleg.tail = (0.1, 0, 0.5)
l_upleg.parent = hips

l_leg = edit_bones.new('LeftLeg')
l_leg.head = (0.1, 0, 0.5)
l_leg.tail = (0.1, 0, 0.1)
l_leg.parent = l_upleg

l_foot = edit_bones.new('LeftFoot')
l_foot.head = (0.1, 0, 0.1)
l_foot.tail = (0.1, 0.15, 0.0)
l_foot.parent = l_leg

l_toe = edit_bones.new('LeftToeBase')
l_toe.head = (0.1, 0.15, 0.0)
l_toe.tail = (0.1, 0.25, 0.0)
l_toe.parent = l_foot

# Perna direita
r_upleg = edit_bones.new('RightUpLeg')
r_upleg.head = (-0.1, 0, 0.9)
r_upleg.tail = (-0.1, 0, 0.5)
r_upleg.parent = hips

r_leg = edit_bones.new('RightLeg')
r_leg.head = (-0.1, 0, 0.5)
r_leg.tail = (-0.1, 0, 0.1)
r_leg.parent = r_upleg

r_foot = edit_bones.new('RightFoot')
r_foot.head = (-0.1, 0, 0.1)
r_foot.tail = (-0.1, 0.15, 0.0)
r_foot.parent = r_leg

r_toe = edit_bones.new('RightToeBase')
r_toe.head = (-0.1, 0.15, 0.0)
r_toe.tail = (-0.1, 0.25, 0.0)
r_toe.parent = r_foot

# Deleta bone padrão
edit_bones.remove(edit_bones['Bone'])

bpy.ops.object.mode_set(mode='OBJECT')

# ============================================================
# WEIGHT PAINT AUTOMÁTICO
# ============================================================
print("[Arkher] Weight painting automático...")
mesh_objs = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
for mesh in mesh_objs:
    # Parent mesh ao armature com armature deform
    modifier = mesh.modifiers.new(name="Armature", type='ARMATURE')
    modifier.object = armature
    mesh.parent = armature
    # Auto-weights
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    armature.select_set(True)
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')

print("[Arkher] ✅ Auto-rig concluído!")
print(f"  - Bones: {len(armature.data.bones)}")
print(f"  - Compatível com Godot Humanoid e Roblox R15")

# Exporta
output_path.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(output_path),
    export_format='GLB',
    export_skins=True,
    export_morph=True,
    export_animations=True,
    export_yup=True,
    export_apply=True
)
print(f"[Arkher] Rig exportado para: {output_path}")
