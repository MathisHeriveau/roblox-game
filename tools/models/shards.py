"""
Star shard models for Comet Raiders, built procedurally in Blender (1 unit = 1 Roblox stud).

  blender -b -P tools/models/shards.py -- --out assets/models --render build/models/shards.png

Produces assets/models/shards.fbx with separate objects (the game colours them per rarity):
  Crystal      the main faceted shard (tall hexagonal crystal, cut tip, bevelled base)
  Satellite    a small crystal that floats around Rare / Epic / Legendary shards
  CrownSpikes  a ring of short crystals around the Legendary shard's base
  OrbitRing    the Mythic shard's orbit ring
  StarCrystal  the Cosmic shard: a four-pointed star crystal
Flat shading on purpose: facets are what makes a crystal read as a crystal.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector


def new_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def crystal_bm(height, radius, sides=6, twist=0.35, shoulder=0.62):
    """Elongated cut gem: long point at the bottom, widest at the shoulder, a second facet ring,
    shorter point at the top (the style sheet's shard silhouette)."""
    bm = bmesh.new()
    profile = ((height * shoulder, radius), (height * (shoulder + 0.16), radius * 0.72))
    rings = []
    for k, (z, r) in enumerate(profile):
        ring = []
        for i in range(sides):
            a = i / sides * 2 * math.pi + twist * k
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    top = bm.verts.new((0, 0, height))
    bottom = bm.verts.new((0, 0, 0))
    lower, upper = rings
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((lower[i], lower[j], upper[j]))
        bm.faces.new((lower[i], upper[j], upper[i]))
        bm.faces.new((upper[i], upper[j], top))
        bm.faces.new((lower[j], lower[i], bottom))
    return bm


def build_crystal():
    bm = crystal_bm(3.6, 0.95)
    bmesh.ops.translate(bm, vec=Vector((0, 0, -1.8)), verts=bm.verts)
    # A slight lean reads as "fallen from the sky", like the style sheet.
    bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(-16), 3, "Y"), verts=bm.verts)
    return new_object("Crystal", bm)


def build_satellite():
    bm = crystal_bm(1.1, 0.3)
    bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(25), 3, "Y"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector((1.15, 0, -0.2)), verts=bm.verts)
    return new_object("Satellite", bm)


def build_crown_spikes():
    bm = bmesh.new()
    count = 7
    for i in range(count):
        a = i / count * 2 * math.pi
        spike = crystal_bm(1.0 + 0.3 * (i % 2), 0.24)
        temp = bmesh.new()
        # Copy the spike into the shared mesh, tilted outwards and placed on a ring.
        mesh = bpy.data.meshes.new("tmp")
        spike.to_mesh(mesh)
        spike.free()
        temp.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        bmesh.ops.rotate(temp, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(28), 3, "Y"), verts=temp.verts)
        bmesh.ops.rotate(temp, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(a, 3, "Z"), verts=temp.verts)
        bmesh.ops.translate(temp, vec=Vector((0.62 * math.cos(a), 0.62 * math.sin(a), -1.45)), verts=temp.verts)
        mesh = bpy.data.meshes.new("tmp2")
        temp.to_mesh(mesh)
        temp.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    return new_object("CrownSpikes", bm)


def build_orbit_ring():
    bpy.ops.mesh.primitive_torus_add(major_radius=1.25, minor_radius=0.07, major_segments=40, minor_segments=8)
    ring = bpy.context.active_object
    ring.name = "OrbitRing"
    ring.rotation_euler = (math.radians(68), math.radians(18), 0)
    for poly in ring.data.polygons:
        poly.use_smooth = True
    return ring


def build_star_crystal():
    """Four long points and four short ones, faceted, thick in the middle."""
    bm = bmesh.new()
    points = 4
    depth = 0.75
    front = bm.verts.new((0, -depth, 0))
    back = bm.verts.new((0, depth, 0))
    ring = []
    for i in range(points * 2):
        a = i / (points * 2) * 2 * math.pi + math.pi / 2
        r = (2.0 if (i // 2) % 2 == 0 else 1.55) if i % 2 == 0 else 0.6
        ring.append(bm.verts.new((r * math.cos(a), 0, r * math.sin(a))))
    n = len(ring)
    for i in range(n):
        a, b = ring[i], ring[(i + 1) % n]
        bm.faces.new((a, b, front))
        bm.faces.new((b, a, back))
    return new_object("StarCrystal", bm)


RARITIES = [
    ("Common", (1.0, 0.82, 0.25), []),
    ("Rare", (0.05, 0.62, 1.0), ["Satellite"]),
    ("Epic", (0.62, 0.3, 1.0), ["Satellite"]),
    ("Legendary", (1.0, 0.6, 0.08), ["CrownSpikes", "Satellite"]),
    ("Mythic", (0.05, 0.92, 0.5), ["OrbitRing"]),
    ("Cosmic", (1.0, 0.42, 1.0), ["OrbitRing"]),
]


def glassy(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.12
    bsdf.inputs["Emission Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Strength"].default_value = 0.22
    return mat


def render_preview(path, pieces):
    scene = bpy.context.scene
    spacing = 4.4
    for index, (name, color, extras) in enumerate(RARITIES):
        offset = Vector(((index - 2.5) * spacing, 0, 0))
        mat = glassy(f"Shard{name}", color)
        main = "StarCrystal" if name == "Cosmic" else "Crystal"
        for piece in [main] + extras:
            src = pieces[piece]
            copy = src.copy()
            copy.data = src.data.copy()
            copy.location = src.location + offset
            scene.collection.objects.link(copy)
            copy.data.materials.clear()
            copy.data.materials.append(mat)
        for extra_angle in ((120,) if "Satellite" in extras and name == "Epic" else ()):
            src = pieces["Satellite"]
            copy = src.copy()
            copy.data = src.data.copy()
            copy.location = offset
            copy.rotation_euler = (0, 0, math.radians(extra_angle))
            scene.collection.objects.link(copy)
            copy.data.materials.clear()
            copy.data.materials.append(mat)
    for obj in pieces.values():
        obj.hide_render = True
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 28
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (4, -40, 8)
    cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for loc, energy in (((-12, -20, 18), 4000), ((14, -12, 6), 1600), ((0, 15, 10), 2500)):
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
    scene.render.resolution_x, scene.render.resolution_y = 1600, 460
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/models")
    parser.add_argument("--render", default="")
    args = parser.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pieces = {
        "Crystal": build_crystal(),
        "Satellite": build_satellite(),
        "CrownSpikes": build_crown_spikes(),
        "OrbitRing": build_orbit_ring(),
        "StarCrystal": build_star_crystal(),
    }
    os.makedirs(args.out, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces.values():
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(args.out, "shards.fbx"),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
    )
    total = 0
    for name, obj in sorted(pieces.items()):
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        total += tris
        print(f"  {name}: {tris} triangles")
    print("exported shards.fbx, total", total)
    if args.render:
        os.makedirs(os.path.dirname(args.render), exist_ok=True)
        render_preview(os.path.abspath(args.render), pieces)
        print("rendered", args.render)


main()
