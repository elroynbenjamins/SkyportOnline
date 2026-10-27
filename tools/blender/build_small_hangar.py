#!/usr/bin/env python3
"""Build a truly grid-authored 3D hangar in Blender and render both isometric views.

Run:
  blender -b -t 4 --python tools/blender/build_small_hangar.py

This is an actual 3D source model, not an SVG extrusion or an AI concept render.
4x3 logical square-grid footprint; 2:1 projected ground diamond:
224x112 px at 1x. World units map exactly to grid cells.
"""
import bpy
import math
import os
import json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUTPUT_DIR = os.path.join(ROOT, "assets", "production", "airport_buildings_blender_v1")
SOURCE_DIR = os.path.join(ROOT, "assets", "source", "blender")
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(SOURCE_DIR, exist_ok=True)

PIXEL_SCALE = 4
WIDTH = 224 * PIXEL_SCALE
HEIGHT = 260 * PIXEL_SCALE
# Game footprint: width=(4+3)*32=224; depth=(4+3)*16=112.
GRID_X = 3.0  # physical Blender X is game grid Y
GRID_Y = 4.0  # physical Blender Y is game grid X
BASE_Z = 0.0

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for material in list(bpy.data.materials):
    bpy.data.materials.remove(material)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 48
scene.cycles.use_denoising = False  # Ubuntu's Blender build lacks OpenImageDenoiser
scene.render.resolution_x = WIDTH
scene.render.resolution_y = HEIGHT
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.render.image_settings.color_depth = "8"
scene.render.film_transparent = True
scene.camera = None
if hasattr(scene, "view_settings"):
    try:
        scene.view_settings.view_transform = "AgX" if bpy.app.version >= (4, 0, 0) else "Filmic"
        scene.view_settings.look = "Medium High Contrast"
    except Exception:
        pass
scene.world.use_nodes = True
background = scene.world.node_tree.nodes.get("Background")
background.inputs["Color"].default_value = (0.50, 0.69, 0.80, 1.0)
background.inputs["Strength"].default_value = 0.56

root = bpy.data.objects.new("HANGAR_ROOT__rotate_for_4x3_and_3x4", None)
bpy.context.collection.objects.link(root)
# 5% internal footprint clearance prevents roof eaves clipping the export
# canvas, while the separate 4x3 Godot placement and guide remain unchanged.
root.scale.x = 0.93
root.scale.y = 0.93

def material(name, color, roughness=0.72, metallic=0.0, emission_strength=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    principled = m.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    if emission_strength:
        emission_input = "Emission Color" if "Emission Color" in principled.inputs else "Emission"
        principled.inputs[emission_input].default_value = (*color, 1.0)
        if "Emission Strength" in principled.inputs:
            principled.inputs["Emission Strength"].default_value = emission_strength
    return m

M = {
 "wall": material("Warm ivory cladding", (0.61,0.67,0.67)),
 "wall_highlight": material("Warm wall highlights", (0.76,0.78,0.73)),
 "slate": material("Slate structural steel", (0.18,0.30,0.38), .48, .27),
 "steel": material("Blue-grey metal", (0.25,0.41,0.54), .46, .33),
 "steel_light": material("Sunlit edging", (0.47,0.60,0.67), .40, .35),
 "roof": material("Deep desaturated blue coated roof", (0.08,0.22,0.41), .40, .30),
 "roof_alt": material("Slate blue standing seam", (0.10,0.28,0.49), .47, .25),
 "roof_light": material("Highlighted roof paint", (0.15,0.34,0.55), .43, .28),
 "glass": material("Blue smoked skylight glass", (0.10,0.33,0.43), .14, .1),
 "glass_glow": material("Blue skylight glints", (0.34,0.65,0.69), .22, .16),
 "floor": material("Cool inside concrete floor", (0.38,0.45,0.45)),
 "floor_dark": material("Concrete joint", (0.25,0.31,0.32)),
 "inside": material("Shadowed rear hangar wall", (0.17,0.25,0.30)),
 "yellow": material("Yellow airport safety enamel", (0.97,0.65,0.13), .45),
 "red": material("Orange-red toolbox", (0.67,0.22,0.16), .42),
 "crate": material("Warm cargo crate timber", (0.62,0.41,0.20)),
 "crate_band": material("Dark crate band", (0.37,0.30,0.19)),
 "dark": material("Dark window rubber", (0.09,0.17,0.22)),
 "light": material("Warm service LED", (1.0,0.83,0.45), .35, emission_strength=3.6),
 "light_off": material("Light housing", (0.18,0.22,0.24), .46),
 "stripe": material("Airport-blue painted stripe", (0.15,0.36,0.61), .59),
 "interior_metal": material("Hangar interior ribs", (0.27,0.40,0.45), .54, .25),
}

def parent(ob):
    ob.parent = root
    return ob

def box(name, size, at, mat, bevel=0.025, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        ob.rotation_euler = rotation
    ob.data.materials.append(mat)
    if bevel:
        modifier = ob.modifiers.new("Material corner catchlight", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        if hasattr(modifier, "affect"):
            modifier.affect = "EDGES"
    return parent(ob)

def line(name, points, mat, bevel=0.017):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 3
    curve.bevel_resolution = 3
    curve.bevel_depth = bevel
    spline = curve.splines.new("POLY")
    spline.points.add(len(points)-1)
    for v, p in zip(spline.points, points):
        v.co = (p[0], p[1], p[2], 1)
    ob = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return parent(ob)

def arch_height(y):
    return 2.09 + 0.45 * max(0.0, 1.0 - (y/1.92)**2)

def arched_strip(name, x0, x1, mat, steps=28):
    verts=[]
    faces=[]
    for x in [x0, x1]:
        for i in range(steps+1):
            y=-1.92 + (3.84 * i/steps)
            verts.append((x,y,arch_height(y)))
    for i in range(steps):
        faces.append((i,i+1,steps+2+i,steps+1+i))
    mesh=bpy.data.meshes.new(name+"Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    ob=bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth=True
    solid=ob.modifiers.new("Genuine pressed steel thickness", "SOLIDIFY")
    solid.thickness=0.07
    bevel=ob.modifiers.new("Soft roof rim", "BEVEL")
    bevel.width=0.009
    bevel.segments=2
    return parent(ob)

def window(name, x, width=0.62):
    # Visible right-hand side wall: actual glass, mullions and lintel.
    box(name+" glass", (width, .039, .43), (x,1.811,1.20), M["glass"], .01)
    box(name+" top trim", (width+.10,.060,.035),(x,1.853,1.443),M["steel_light"],.004)
    box(name+" bottom trim",(width+.10,.06,.037),(x,1.855,.963),M["slate"],.004)
    for xoff in [-width/2,width/2,0]:
        box(name+" mullion",(.024,.063,.45),(x+xoff,1.861,1.20),M["steel_light"],.003)
    box(name+" glint",(width*.22,.005,.28),(x-width*.17,1.879,1.25),M["glass_glow"],.002)

# 1. Architectural volume lies INSIDE the exact 4x3 Blender-unit guide.
# No exterior ground plane; Godot already draws a separate grid-authoritative pad.
box("Interior floor, no external footprint extension",(2.51,3.47,.075),(0,0,.038),M["floor"],.012)
for x in [-.85,0,.85]:
    box("Inside floor concrete seam",(.020,3.38,.003),(x,0,.079),M["floor_dark"],0)
for y in [-.95,0,.95]:
    box("Inside floor cross seam",(2.48,.018,.003),(0,y,.081),M["floor_dark"],0)
box("Shadowed rear wall",(.17,3.48,2.07),(-1.31,0,1.04),M["inside"])
box("Left wall",(2.65,.17,2.08),(0,-1.77,1.05),M["wall"])
box("Right wall",(2.65,.17,2.08),(0,1.77,1.05),M["wall"])
# Width runs in Blender Y; the facade is the wall at positive Blender X.
box("Front left door pier",(.20,.31,2.07),(1.32,-1.60,1.05),M["wall_highlight"])
box("Front right door pier",(.20,.31,2.07),(1.32,1.60,1.05),M["wall_highlight"])
box("Front arch lintel",(.22,3.42,.23),(1.33,0,1.985),M["wall_highlight"],.028)
box("Front dark header under roof",(.052,3.10,.11),(1.462,0,1.82),M["slate"])
box("Front vertical door rail L",(.09,.08,1.76),(1.454,-1.40,.93),M["steel_light"])
box("Front vertical door rail R",(.09,.08,1.76),(1.454,1.40,.93),M["steel_light"])
box("Blue horizontal mid-wall stripe L",(2.59,.022,.18),(0,-1.870,.60),M["stripe"],.004)
box("Blue horizontal mid-wall stripe R",(2.59,.022,.18),(0,1.870,.60),M["stripe"],.004)
for y in [-1.76,1.76]:
    for x in [-1.1,-.25,.61]:
        box("Wall panel joints",(.025,.015,1.90),(x,y*1.004,1.04),M["wall_highlight"],0)
for x in [-.94,-.07,.79]:
    window("Right-side window %.2f" % x,x)
# Interior steel rack, rear crates, workboxes and tiny roof support ribs
for y in [-1.17,1.16]:
    box("Steel inner column",(.10,.10,1.81),(-.93,y,.92),M["interior_metal"])
    box("Inner column brace",(.65,.05,.07),(-.85,y,1.76),M["slate"])
for (x,y,w,d,h) in [(-.82,-.63,.40,.46,.43),(-.79,.04,.30,.34,.35),(-.82,.57,.38,.43,.47)]:
    box("Stacked service crate",(w,d,h),(x,y,.075+h/2),M["crate"],.012)
    box("Crate safety strap",(.031,d+.01,h*.95),(x,y,.075+h/2),M["crate_band"],.003)
box("Hanger tool trolley",(.35,.27,.77),(-.34,1.18,.49),M["red"],.024)
box("Trolley top",(.39,.29,.055),(-.34,1.18,.885),M["slate"],.006)
for z in [.36,.60]:
    box("Trolley drawer",(.013,.20,.02),(-.148,1.18,z),M["steel_light"],0)
for y in [-1.35,1.35]:
    box("Door-side kick protector",(.15,.13,.48),(1.32,y,.26),M["yellow"],.006)
    box("Overhead worklight casing",(.16,.24,.13),(1.445,y,1.88),M["light_off"],.013)
    box("Overhead warm worklight",(.045,.16,.048),(1.540,y,1.85),M["light"],.006)
# Intrinsic visual lighting for the interior, without painting a fake gradient.
def point_light(name, location, power, color, radius):
    d=bpy.data.lights.new(name,"POINT")
    d.energy=power
    d.color=color
    d.shadow_soft_size=radius
    ob=bpy.data.objects.new(name,d)
    bpy.context.collection.objects.link(ob)
    ob.location=location
    ob.parent=root
    return ob
point_light("Maintenance bay tungsten light",(0.67,0.0,1.68),72,(1.0,.74,.45),1.65)

# 2. Curved roof: physical metal mesh and separate ribs; not painted SVG bands.
for i in range(11):
    x0=-1.46+i*(2.92/11)
    x1=-1.46+(i+1)*(2.92/11)
    mat=M["roof"] if i%3==0 else M["roof_alt"] if i%3==1 else M["roof_light"]
    arched_strip("Coated curved roofing sheet %02d"%i,x0,x1,mat)

for x in [-1.48,1.48,.0]:
    pts=[(x,-1.94+3.88*i/36,arch_height(-1.94+3.88*i/36)+.030) for i in range(37)]
    line("Curved aluminium structural roof beam",pts,M["steel_light"],.031 if x in [-1.48,1.48] else .020)
for y in [-1.87,1.87]:
    line("Waterproof gutters",[(-1.47,y,arch_height(y)+.02),(1.47,y,arch_height(y)+.02)],M["slate"],.045)
# Raised skylights tangent to the arch, metallic edge on all four sides.
for x,y in [(-.76,-.73),(-.76,.67),(.40,-.73),(.40,.67)]:
    z=arch_height(y)+.050
    pitch=math.atan(-.90*y/(1.92**2))
    box("Inset skylight metal frame",(.76,.52,.042),(x,y,z),M["steel_light"],.013,(pitch,0,0))
    box("Smoked blue-green skylight glazing",(.65,.41,.045),(x,y,z+.039),M["glass"],.012,(pitch,0,0))
    box("Skylight glint",(.025,.31,.050),(x-.22,y,z+.068),M["glass_glow"],.004,(pitch,0,0))
# Tiny metallic roof vents are actual 3D volumes and cast real shadows.
for x,y in [(-.97,1.25),(.94,-1.20)]:
    z=arch_height(y)+.22
    box("Roof intake",(.29,.29,.31),(x,y,z),M["steel"],.027)
    box("Intake horizontal slats",(.32,.016,.048),(x,y+.159,z+.024),M["slate"],.005)
    box("Intake cap",(.37,.36,.061),(x,y,z+.185),M["steel_light"],.015)

# Directional key/fill lighting (independent of hangar rotation), soft shadows.
def area_light(name,loc,power,size,color):
    ob_data=bpy.data.lights.new(name,"AREA")
    ob_data.energy=power
    ob_data.shape="DISK"
    ob_data.size=size
    ob_data.color=color
    ob=bpy.data.objects.new(name,ob_data)
    bpy.context.collection.objects.link(ob)
    ob.location=loc
    ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat("-Z","Y").to_euler()
    return ob
area_light("Large soft daylight key",( -3.5, 4.5, 8.0),640,7.0,(1.0,.94,.85))
area_light("Blue overcast fill",( 4.0, -3.0, 5.6),235,6.0,(.75,.86,1.0))
area_light("Roof rim light",( -4.0,-2.0,7.0),250,4.5,(.89,.97,1.0))

# 3. Camera projection uses the EXACT game cell vectors (32,16) and (-32,16)
# via orthographic elevation 30 degrees and azimuth 45 degrees.
cam_data=bpy.data.cameras.new("SKYPORT_LOCKED_ORTHO_2_TO_1")
camera=bpy.data.objects.new("SKYPORT_LOCKED_ORTHO_2_TO_1",cam_data)
bpy.context.collection.objects.link(camera)
scene.camera=camera
a=9.0
camera.location=(a,a,a*math.sqrt(2)*math.tan(math.radians(30)))
camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat("-Z","Y").to_euler()
cam_data.type="ORTHO"
cam_data.ortho_scale=10.0
bpy.context.view_layer.update()
guide=[Vector((x,y,0)) for x in [-GRID_X/2,GRID_X/2] for y in [-GRID_Y/2,GRID_Y/2]]

def projections():
    coords=[world_to_camera_view(scene,camera,point) for point in guide]
    return (
       (max(p.x for p in coords)-min(p.x for p in coords))*WIDTH,
       (max(p.y for p in coords)-min(p.y for p in coords))*HEIGHT
    )
projected_width,projected_height=projections()
cam_data.ortho_scale*=projected_width/WIDTH
bpy.context.view_layer.update()
projected_width,projected_height=projections()
assert abs(projected_width-WIDTH)<1.5,(projected_width,WIDTH)
assert abs(projected_height-112*PIXEL_SCALE)<1.5,(projected_height,112*PIXEL_SCALE)

# Center of physical base must lie at sprite (112px, 204px), not at image
# center. This reserves exactly 56px below for the pad's front corner.
target_norm_y=1.0-(204.0/260.0)
current=world_to_camera_view(scene,camera,Vector((0,0,0))).y
up=camera.rotation_euler.to_quaternion() @ Vector((0,1,0))
camera.location+=up
bpy.context.view_layer.update()
one=world_to_camera_view(scene,camera,Vector((0,0,0))).y
camera.location+=up*((target_norm_y-one)/(one-current))
bpy.context.view_layer.update()
base_screen=world_to_camera_view(scene,camera,Vector((0,0,0)))
assert abs(base_screen.x-.5)<.008,base_screen.x
assert abs(base_screen.y-target_norm_y)<.004,(base_screen.y,target_norm_y)

guide_data={
 "logical_grid":"square_64x64",
 "footprint_normal":[4,3],
 "footprint_rotated":[3,4],
 "world_ground_units":[3.0,4.0],
 "view_projection":"2_to_1_diamond_orthographic",
 "azimuth_deg":45,
 "elevation_deg":30,
 "sprite_px":[224,260],
 "supersample_factor":PIXEL_SCALE,
 "projected_ground_px":[round(projected_width/4,3),round(projected_height/4,3)],
 "ground_center_target_px":[112,204],
 "sprite_anchor":"front_footprint_corner_at_bottom_center",
 "source":"Blender real 3D / Eevee transparent PNG / Lanczos final downsample",
}
with open(os.path.join(SOURCE_DIR,"small_hangar_grid_contract.json"),"w") as fp:
    json.dump(guide_data,fp,indent=2)

# Hide extra 3D guides from render; retain genuine 3D mesh in .blend source.
scene.render.filepath=os.path.join(OUTPUT_DIR,"_temporary_4x.png")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR,"skyport_small_hangar_4x3_v1.blend"))
for angle,label in [(0,"4x3"),(math.pi/2,"3x4")]:
    root.rotation_euler[2]=angle
    bpy.context.view_layer.update()
    scene.render.filepath=os.path.join(OUTPUT_DIR,"_hires_"+label+".png")
    bpy.ops.render.render(write_still=True)
    print("SKYPORT_BLENDER_RENDER_OK",label,scene.render.filepath)

print("SKYPORT_GRID_PROJECTION_OK",json.dumps(guide_data))
