"""
U11: Blender 自制简模 → 正交透明底 PNG 帧（you）。
布局与 U9 一致：4 列 × 6 行，逻辑帧 32×48（本脚本以 2×=64×96 渲染，再由 pack 做 nearest）。
  rows 0–2: idle down / side / up
  rows 3–5: walk down / side / up
禁商用素材；纯程序化几何建模。
"""
import bpy
import math
import os
from mathutils import Euler

OUT_DIR = os.environ.get(
    "U11_OUT",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "u11"),
)
os.makedirs(OUT_DIR, exist_ok=True)
FRAMES_DIR = os.path.join(OUT_DIR, "_frames")
os.makedirs(FRAMES_DIR, exist_ok=True)

FRAME_W, FRAME_H = 32, 48
COLS = 4
RENDER_SCALE = 2
RW, RH = FRAME_W * RENDER_SCALE, FRAME_H * RENDER_SCALE

FACES = ["down", "side", "up"]
FACE_YAW = {"down": 0.0, "side": math.radians(90), "up": math.radians(180)}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        bpy.data.materials.remove(block)
    for block in list(bpy.data.cameras):
        bpy.data.cameras.remove(block)
    for block in list(bpy.data.lights):
        bpy.data.lights.remove(block)
    for block in list(bpy.data.worlds):
        bpy.data.worlds.remove(block)


def mat(name, rgba, roughness=0.55):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Roughness"].default_value = roughness
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.3
    return m


BOX_FACES = [
    (0, 1, 2, 3),
    (4, 7, 6, 5),
    (0, 4, 5, 1),
    (1, 5, 6, 2),
    (2, 6, 7, 3),
    (3, 7, 4, 0),
]


def box_verts(sx, sy, sz):
    return [
        (-sx, -sy, -sz),
        (sx, -sy, -sz),
        (sx, sy, -sz),
        (-sx, sy, -sz),
        (-sx, -sy, sz),
        (sx, -sy, sz),
        (sx, sy, sz),
        (-sx, sy, sz),
    ]


def add_mesh(name, sx, sy, sz, material, loc, parent):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(box_verts(sx, sy, sz), [], BOX_FACES)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.data.materials.append(material)
    obj.parent = parent
    return obj


def build_character():
    root = bpy.data.objects.new("you_root", None)
    bpy.context.collection.objects.link(root)

    m_skin = mat("skin", (1.0, 0.84, 0.68, 1.0), 0.7)
    m_hair = mat("hair", (0.22, 0.14, 0.08, 1.0), 0.85)
    m_tunic = mat("tunic", (0.18, 0.44, 0.30, 1.0), 0.55)
    m_pants = mat("pants", (0.18, 0.18, 0.16, 1.0), 0.75)
    m_shoe = mat("shoe", (0.10, 0.10, 0.09, 1.0), 0.9)
    m_eye = mat("eye", (0.08, 0.07, 0.06, 1.0), 0.4)
    m_belt = mat("belt", (0.35, 0.28, 0.15, 1.0), 0.6)

    parts = {
        "root": root,
        "head": add_mesh("head", 0.28, 0.26, 0.30, m_skin, (0, 0, 1.95), root),
        "hair": add_mesh("hair", 0.30, 0.28, 0.14, m_hair, (0, 0.02, 2.18), root),
        "bang": add_mesh("bang", 0.28, 0.10, 0.08, m_hair, (0, -0.22, 2.05), root),
        "eye_l": add_mesh("eye_l", 0.05, 0.03, 0.05, m_eye, (-0.10, -0.26, 1.95), root),
        "eye_r": add_mesh("eye_r", 0.05, 0.03, 0.05, m_eye, (0.10, -0.26, 1.95), root),
        "torso": add_mesh("torso", 0.34, 0.20, 0.42, m_tunic, (0, 0, 1.35), root),
        "belt": add_mesh("belt", 0.36, 0.22, 0.06, m_belt, (0, 0, 0.95), root),
        "arm_l": add_mesh("arm_l", 0.10, 0.10, 0.32, m_skin, (-0.46, 0, 1.30), root),
        "arm_r": add_mesh("arm_r", 0.10, 0.10, 0.32, m_skin, (0.46, 0, 1.30), root),
        "leg_l": add_mesh("leg_l", 0.12, 0.12, 0.36, m_pants, (-0.16, 0, 0.55), root),
        "leg_r": add_mesh("leg_r", 0.12, 0.12, 0.36, m_pants, (0.16, 0, 0.55), root),
        "shoe_l": add_mesh("shoe_l", 0.13, 0.16, 0.08, m_shoe, (-0.16, -0.04, 0.10), root),
        "shoe_r": add_mesh("shoe_r", 0.13, 0.16, 0.08, m_shoe, (0.16, -0.04, 0.10), root),
    }
    return parts


def setup_camera_light():
    cam_data = bpy.data.cameras.new("bake_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.75
    cam = bpy.data.objects.new("bake_cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (0, -4.5, 1.15)
    cam.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")
    bpy.context.scene.camera = cam

    def area(name, energy, size, loc, rot):
        d = bpy.data.lights.new(name, type="AREA")
        d.energy = energy
        d.size = size
        o = bpy.data.objects.new(name, d)
        bpy.context.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = Euler(rot, "XYZ")
        return o

    area("key", 90, 3.0, (-1.5, -2.5, 3.5), (math.radians(50), 0, math.radians(-25)))
    area("fill", 28, 4.0, (2.0, -1.5, 2.0), (math.radians(60), 0, math.radians(40)))
    area("rim", 40, 2.0, (0.5, 2.0, 2.5), (math.radians(70), 0, math.radians(160)))
    return cam


def setup_render():
    scene = bpy.context.scene
    # Prefer EEVEE_NEXT (4.2), fallback EEVEE
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = eng
            break
        except Exception:
            continue

    scene.render.resolution_x = RW
    scene.render.resolution_y = RH
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 15

    eevee = getattr(scene, "eevee", None)
    if eevee and hasattr(eevee, "taa_render_samples"):
        eevee.taa_render_samples = 24
    if eevee and hasattr(eevee, "use_gtao"):
        eevee.use_gtao = True

    world = bpy.data.worlds.new("bake_world")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.50, 0.54, 0.58, 1.0)
        bg.inputs[1].default_value = 0.30


def reset_pose(parts):
    for name in parts:
        if name == "root":
            continue
        parts[name].rotation_euler = (0, 0, 0)
        parts[name].hide_render = False
    parts["arm_l"].location = (-0.46, 0, 1.30)
    parts["arm_r"].location = (0.46, 0, 1.30)
    parts["leg_l"].location = (-0.16, 0, 0.55)
    parts["leg_r"].location = (0.16, 0, 0.55)
    parts["shoe_l"].location = (-0.16, -0.04, 0.10)
    parts["shoe_r"].location = (0.16, -0.04, 0.10)
    parts["head"].location = (0, 0, 1.95)
    parts["hair"].location = (0, 0.02, 2.18)
    parts["bang"].location = (0, -0.22, 2.05)
    parts["eye_l"].location = (-0.10, -0.26, 1.95)
    parts["eye_r"].location = (0.10, -0.26, 1.95)
    parts["torso"].location = (0, 0, 1.35)
    parts["belt"].location = (0, 0, 0.95)
    parts["root"].location = (0, 0, 0)
    parts["root"].rotation_euler = (0, 0, 0)


def apply_idle(parts, frame_i):
    bob = [0.0, 0.045, 0.0, -0.03][frame_i % 4]
    sway = [0.0, 0.10, 0.0, -0.10][frame_i % 4]
    parts["root"].location.z = bob
    parts["arm_l"].rotation_euler = (sway * 0.35, 0, math.radians(10))
    parts["arm_r"].rotation_euler = (-sway * 0.35, 0, math.radians(-10))


def apply_walk(parts, frame_i):
    phase = frame_i % 4
    swings = [(0.40, -0.40), (0.05, -0.05), (-0.40, 0.40), (-0.05, 0.05)]
    la, ra = swings[phase]
    parts["leg_l"].rotation_euler = (la, 0, 0)
    parts["leg_r"].rotation_euler = (ra, 0, 0)
    parts["shoe_l"].location = (
        -0.16,
        -0.04 + math.sin(la) * 0.28,
        0.10 + max(0.0, -math.sin(la)) * 0.10,
    )
    parts["shoe_r"].location = (
        0.16,
        -0.04 + math.sin(ra) * 0.28,
        0.10 + max(0.0, -math.sin(ra)) * 0.10,
    )
    parts["arm_l"].rotation_euler = (ra * 0.95, 0, math.radians(6))
    parts["arm_r"].rotation_euler = (la * 0.95, 0, math.radians(-6))
    parts["root"].location.z = [0.025, 0.0, 0.025, 0.0][phase]
    parts["torso"].rotation_euler = (0, 0, [0.04, 0, -0.04, 0][phase])


def apply_face(parts, face):
    parts["root"].rotation_euler = (0, 0, FACE_YAW[face])
    show_front = face != "up"
    parts["eye_l"].hide_render = not show_front
    parts["eye_r"].hide_render = not show_front
    parts["bang"].hide_render = face == "up"


def pose(parts, mode, face, frame_i):
    reset_pose(parts)
    if mode == "idle":
        apply_idle(parts, frame_i)
    else:
        apply_walk(parts, frame_i)
    apply_face(parts, face)


def render_frame(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    clear_scene()
    parts = build_character()
    setup_camera_light()
    setup_render()

    frame_paths = []
    for mode in ("idle", "walk"):
        for face in FACES:
            for fi in range(COLS):
                pose(parts, mode, face, fi)
                fname = f"{mode}_{face}_{fi}.png"
                fpath = os.path.abspath(os.path.join(FRAMES_DIR, fname))
                print(f"RENDER {fname}")
                render_frame(fpath)
                frame_paths.append(fpath)

    manifest = os.path.abspath(os.path.join(OUT_DIR, "frames_manifest.txt"))
    with open(manifest, "w") as f:
        for p in frame_paths:
            f.write(p + "\n")
    print("DONE frames:", len(frame_paths))
    print("MANIFEST", manifest)


if __name__ == "__main__":
    main()
