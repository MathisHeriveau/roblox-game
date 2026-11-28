"""
Starling models for Comet Raiders, built procedurally in Blender (1 unit = 1 Roblox stud).

  blender -b -P tools/models/starling.py -- --out assets/models --render build/models/starlings.png

Produces assets/models/starling.fbx with separate objects so the game can colour each piece:
  Body (puffy five-pointed star), EyeL/EyeR, ShineL/ShineR, ClosedEyeL/ClosedEyeR ("^" eyes),
  Mouth, Tongue, CheekL/CheekR, Crown, CrownGem, Halo, WingL/WingR, Gem (floating crystal).
The face looks towards Blender -Y, which the FBX export turns into Roblox -Z (LookVector).
A preview render shows the six rarities side by side, coloured like the style sheet.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------- shape parameters (studs)
OUTER = 2.75  # tip radius
INNER = 1.78  # notch radius
TIP_SHARPNESS = 1.05  # higher = thinner, more pointed tips
HALF_THICKNESS = 1.15  # half thickness at the centre
# Mobile budget: about a hundred Starlings can be on screen (8 bases); Roblox caps a mesh at
# 20k triangles. 20 cuts = 2646 quads (~5.3k triangles) with smooth shading.
BODY_CUTS = 20
SPHERE_SEGMENTS = 20


def outline(theta: float) -> float:
    """Radius of the star outline at angle theta (tips at the top and every 72 degrees)."""
    wave = (math.cos(5 * (theta - math.pi / 2)) + 1) / 2
    return INNER + (OUTER - INNER) * wave**TIP_SHARPNESS


def half_thickness(x: float, z: float) -> float:
    theta = math.atan2(z, x)
    radius = outline(theta)
    rho = min(1.0, math.hypot(x, z) / radius)
    taper = 0.78 + 0.22 * (INNER / radius)
    return HALF_THICKNESS * taper * math.sqrt(max(0.0, 1 - rho**2))


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_object(name: str, mesh: bpy.types.Mesh) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def smooth(obj: bpy.types.Object, subdivisions: int = 1):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if subdivisions > 0:
        mod = obj.modifiers.new("Subdivision", "SUBSURF")
        mod.levels = subdivisions
        mod.render_levels = subdivisions


def build_body() -> bpy.types.Object:
    """Cube-sphere (no poles, so no shading pinch) inflated into the star outline: each point of
    the unit sphere at angle theta is pushed out to the star radius in X/Z and squashed in Y,
    which gives the round pillow edge."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=BODY_CUTS, use_grid_fill=True)
    for v in bm.verts:
        d = v.co.normalized()
        theta = math.atan2(d.z, d.x)
        radius = outline(theta)
        taper = 0.78 + 0.22 * (INNER / radius)
        v.co = Vector((d.x * radius, d.y * HALF_THICKNESS * taper, d.z * radius))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Body")
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object("Body", mesh)
    smooth(obj, 0)
    return obj


def surface_point(x: float, z: float, lift: float = 0.0) -> Vector:
    """Point on the front surface above (x, z), pushed out by `lift`."""
    return Vector((x, -half_thickness(x, z) - lift, z))


def ellipsoid(name: str, center: Vector, radii: Vector, segments: int = SPHERE_SEGMENTS) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=segments // 2, radius=1)
    bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object(name, mesh)
    smooth(obj, 0)
    return obj


def arc_tube(name: str, center: Vector, radius: float, thickness: float, start: float, end: float) -> bpy.types.Object:
    """A curved tube on the face plane (the closed happy eye "^" / smile)."""
    bm = bmesh.new()
    steps, sides = 24, 10
    rings = []
    for i in range(steps + 1):
        t = start + (end - start) * i / steps
        p = center + Vector((radius * math.cos(t), 0, radius * math.sin(t)))
        tangent = Vector((-math.sin(t), 0, math.cos(t)))
        normal = Vector((math.cos(t), 0, math.sin(t)))
        binormal = Vector((0, 1, 0))
        ring = []
        for k in range(sides):
            a = k / sides * 2 * math.pi
            offset = (normal * math.cos(a) + binormal * math.sin(a)) * thickness
            ring.append(bm.verts.new(p + offset))
        rings.append(ring)
    for i in range(steps):
        for k in range(sides):
            a, b = rings[i][k], rings[i][(k + 1) % sides]
            c, d = rings[i + 1][(k + 1) % sides], rings[i + 1][k]
            bm.faces.new((a, b, c, d))
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object(name, mesh)
    smooth(obj, 0)
    return obj


def build_face():
    eye_x, eye_z = 0.62, 0.36
    parts = []
    for side, sx in (("L", -1), ("R", 1)):
        base = surface_point(sx * eye_x, eye_z, -0.12)
        parts.append(ellipsoid(f"Eye{side}", base, Vector((0.3, 0.2, 0.42))))
        shine = surface_point(sx * eye_x - 0.09, eye_z + 0.15, 0.06)
        parts.append(ellipsoid(f"Shine{side}", shine, Vector((0.11, 0.06, 0.13)), 16))
        closed = surface_point(sx * eye_x, eye_z - 0.08, 0.02)
        parts.append(arc_tube(f"ClosedEye{side}", closed, 0.27, 0.075, math.radians(20), math.radians(160)))
        cheek = surface_point(sx * 1.08, -0.08, -0.04)
        parts.append(ellipsoid(f"Cheek{side}", cheek, Vector((0.27, 0.07, 0.17)), 16))
    # Wide open smile: a half-ellipse (flat top) with the tongue at the bottom.
    mouth_center = surface_point(0, -0.28, -0.08)
    mouth = ellipsoid("Mouth", mouth_center, Vector((0.36, 0.12, 0.3)))
    for v in mouth.data.vertices:
        if v.co.z > mouth_center.z:
            v.co.z = mouth_center.z + (v.co.z - mouth_center.z) * 0.15
    parts.append(mouth)
    parts.append(ellipsoid("Tongue", mouth_center + Vector((0, -0.06, -0.16)), Vector((0.2, 0.08, 0.11)), 20))
    return parts


def build_crown() -> list:
    bm = bmesh.new()
    top = OUTER + 0.1
    band_r, band_h, points = 0.85, 0.42, 5
    bmesh.ops.create_cone(bm, cap_ends=True, segments=40, radius1=band_r, radius2=band_r * 1.08, depth=band_h)
    for i in range(points):
        a = i / points * 2 * math.pi
        cone = bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.24, radius2=0.0, depth=0.7)
        bmesh.ops.translate(
            bm, vec=Vector((band_r * math.cos(a), band_r * math.sin(a), band_h / 2 + 0.3)), verts=cone["verts"]
        )
    # Tilted to the side, like the style sheet's Legendary Starling.
    bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(-14), 3, "Y"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector((0.25, 0, top - 0.2)), verts=bm.verts)
    mesh = bpy.data.meshes.new("Crown")
    bm.to_mesh(mesh)
    bm.free()
    crown = new_object("Crown", mesh)
    smooth(crown, 0)
    gem = ellipsoid("CrownGem", Vector((0.2, -band_r - 0.04, top - 0.2)), Vector((0.15, 0.07, 0.17)), 16)
    return [crown, gem]


def build_halo() -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.11, major_segments=40, minor_segments=10)
    halo = bpy.context.active_object
    halo.name = "Halo"
    halo.location = (0, 0.15, OUTER + 0.45)
    halo.rotation_euler = (math.radians(18), 0, 0)
    smooth(halo, 0)
    return halo


def build_wings() -> list:
    wings = []
    for side, sx in (("L", -1), ("R", 1)):
        bm = bmesh.new()
        # Three overlapping feathers per wing.
        for k, (length, angle) in enumerate(((2.3, 38), (2.0, 12), (1.6, -14))):
            feather = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=1)
            vs = feather["verts"]
            bmesh.ops.scale(bm, vec=Vector((length / 2, 0.12, 0.42)), verts=vs)
            bmesh.ops.translate(bm, vec=Vector((length / 2, 0, 0)), verts=vs)
            bmesh.ops.rotate(
                bm, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(angle), 3, "Y"), verts=vs
            )
        bmesh.ops.scale(bm, vec=Vector((sx, 1, 1)), verts=bm.verts)
        if sx < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bmesh.ops.translate(bm, vec=Vector((sx * 1.6, 0.35, 0.45)), verts=bm.verts)
        mesh = bpy.data.meshes.new(f"Wing{side}")
        bm.to_mesh(mesh)
        bm.free()
        wing = new_object(f"Wing{side}", mesh)
        smooth(wing, 0)
        wings.append(wing)
    return wings


def build_gem() -> bpy.types.Object:
    """Faceted floating crystal (Rare / Epic / Mythic accessories)."""
    bm = bmesh.new()
    sides, radius, top, bottom = 6, 0.28, 0.6, 0.38
    ring = [bm.verts.new((radius * math.cos(i / sides * 2 * math.pi), radius * math.sin(i / sides * 2 * math.pi), 0)) for i in range(sides)]
    apex, base = bm.verts.new((0, 0, top)), bm.verts.new((0, 0, -bottom))
    for i in range(sides):
        a, b = ring[i], ring[(i + 1) % sides]
        bm.faces.new((a, b, apex))
        bm.faces.new((b, a, base))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=Vector((1.9, 0.3, 1.9)), verts=bm.verts)
    mesh = bpy.data.meshes.new("Gem")
    bm.to_mesh(mesh)
    bm.free()
    return new_object("Gem", mesh)


# ---------------------------------------------------------------- preview
RARITIES = [
    ("Common", (1.0, 0.85, 0.40)),
    ("Rare", (0.0, 0.71, 1.0)),
    ("Epic", (0.70, 0.40, 1.0)),
    ("Legendary", (0.95, 0.61, 0.07)),
    ("Mythic", (0.0, 0.90, 0.46)),
    ("Cosmic", (1.0, 0.92, 1.0)),
]


def material(name: str, color, emission: float = 0.0, roughness: float = 0.35):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def paint(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def render_preview(path: str, pieces: dict):
    scene = bpy.context.scene
    eyes = material("Eye", (0.08, 0.04, 0.12), roughness=0.15)
    white = material("Shine", (1, 1, 1), emission=2)
    mouth = material("Mouth", (0.35, 0.05, 0.12))
    tongue = material("Tongue", (1.0, 0.43, 0.55))
    cheek = material("Cheek", (1.0, 0.52, 0.67))
    gold = material("Gold", (1.0, 0.78, 0.19), roughness=0.25)
    spacing = 6.6
    for index, (name, color) in enumerate(RARITIES):
        offset = Vector(((index - 2.5) * spacing, 0, 0))
        body_mat = material(f"Body{name}", color, emission=0.25, roughness=0.22)
        wanted = ["Body", "Mouth", "Tongue", "CheekL", "CheekR"]
        wanted += ["ClosedEyeL", "ClosedEyeR"] if name == "Common" else []
        wanted += ["EyeL", "EyeR", "ShineL", "ShineR"] if name not in ("Common",) else []
        if name == "Epic":
            wanted.remove("EyeR")
            wanted.remove("ShineR")
            wanted.append("ClosedEyeR")
        wanted += ["Crown", "CrownGem"] if name == "Legendary" else []
        wanted += ["Halo", "WingL", "WingR"] if name == "Cosmic" else []
        wanted += ["Gem"] if name in ("Rare", "Epic", "Mythic") else []
        for piece in wanted:
            src = pieces[piece]
            copy = src.copy()
            copy.data = src.data.copy()
            copy.location = src.location + offset
            scene.collection.objects.link(copy)
            if piece == "Body":
                paint(copy, body_mat)
            elif piece.startswith("Eye") or piece.startswith("ClosedEye"):
                paint(copy, eyes)
            elif piece.startswith("Shine"):
                paint(copy, white)
            elif piece == "Mouth":
                paint(copy, mouth)
            elif piece == "Tongue":
                paint(copy, tongue)
            elif piece.startswith("Cheek"):
                paint(copy, cheek)
            elif piece in ("Crown", "Halo"):
                paint(copy, gold)
            elif piece == "CrownGem":
                paint(copy, material("Ruby", (1, 0.15, 0.3), emission=1))
            elif piece.startswith("Wing"):
                paint(copy, material("Wing", (1.0, 0.75, 0.97), emission=0.4))
            elif piece == "Gem":
                paint(copy, material(f"Gem{name}", color, emission=1.2))
    for obj in pieces.values():
        obj.hide_render = True

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 42
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (3, -40, 9)
    direction = Vector((0, 0, 0.6)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for loc, energy in (((-12, -20, 18), 4200), ((14, -12, 6), 1800), ((0, 15, 10), 2500)):
        light_data = bpy.data.lights.new("Light", "AREA")
        light_data.energy = energy
        light_data.size = 12
        light = bpy.data.objects.new("Light", light_data)
        light.location = loc
        light.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.09, 0.06, 0.25, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    scene.world = world
    scene.view_settings.view_transform = "Standard"
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 520
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/models")
    parser.add_argument("--render", default="")
    args = parser.parse_args(argv)

    clear_scene()
    pieces = {}
    pieces["Body"] = build_body()
    for obj in build_face():
        pieces[obj.name] = obj
    for obj in build_crown():
        pieces[obj.name] = obj
    pieces["Halo"] = build_halo()
    for obj in build_wings():
        pieces[obj.name] = obj
    pieces["Gem"] = build_gem()

    os.makedirs(args.out, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces.values():
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(args.out, "starling.fbx"),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
    )
    print("exported", os.path.join(args.out, "starling.fbx"), "objects:", sorted(pieces))
    total = 0
    for name, obj in sorted(pieces.items()):
        mesh = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        tris = sum(len(poly.vertices) - 2 for poly in mesh.polygons)
        total += tris
        print(f"  {name}: {tris} triangles")
    print("  total:", total)
    if args.render:
        os.makedirs(os.path.dirname(args.render), exist_ok=True)
        render_preview(os.path.abspath(args.render), pieces)
        print("rendered", args.render)


main()
