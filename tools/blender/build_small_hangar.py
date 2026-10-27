"""SkyportOnline small hangar v1: actual editable Blender scene.
Run: blender -b -t 2 --python tools/blender/build_small_hangar.py -- --out /tmp/skyport_hangar
The geometry uses W=4, D=3 logical square tiles; it never changes game occupancy.
"""
import bpy
import math
import os
import sys
from mathutils import Vector

OUT = "/tmp/skyport_hangar"
if "--" in sys.argv:
    args = sys.argv[sys.argv.index("--")+1:]
    if "--out" in args:
        OUT = args[args.index("--out")+1]
os.makedirs(OUT, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def mat(name, color, rough=0.75, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    return m

white=mat("Warm offwhite ceramic cladding", (.78,.79,.74))
blue=mat("Slate blue painted metal", (.12,.28,.45), .49, .18)
roof=mat("Roof steel blue matte", (.17,.35,.55), .53, .19)
trim=mat("Pale aluminum frame", (.65,.71,.70), .36, .42)
interior=mat("Recessed unlit maintenance bay", (.065,.095,.125))
concrete=mat("Foundation concrete", (.48,.51,.50))
dark=mat("Navy seam / rubber", (.085,.13,.19))
glass=mat("Skylight glass", (.19,.43,.55), .18, .25)
amber=mat("Warm safety amber", (.96,.61,.19))
gold=mat("Painted ground guide lines", (.95,.62,.16))

def cube(name, pos, scale, material, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        mod=obj.modifiers.new("Soft manufactured edges", "BEVEL")
        mod.width=bevel
        mod.segments=3
        obj.modifiers.new("Weighted normals","WEIGHTED_NORMAL")
    return obj

def mesh(name, vertices, faces, material):
    me=bpy.data.meshes.new(name)
    me.from_pydata(vertices, [], faces)
    me.update()
    obj=bpy.data.objects.new(name,me)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj

# Y=-1.5 is the front/service door. Objects must stay within 4x3.
cube("4x3_footprint_ground_guide", (0,0,-.05),(4,3,.09), concrete, .025)
cube("Main body / supporting steel shell",(0,0,.72),(3.78,2.82,1.42),white,.035)
cube("Recessed service bay inner void",(0,-1.433,.70),(2.93,.085,1.22),interior)
cube("Bay floor",(0,-1.33,.08),(2.89,.30,.035), concrete)
# Door recessed frame — broad enough to clearly read at real gameplay zoom.
cube("Hangar lintel",(0,-1.49,1.37),(3.15,.13,.16),trim,.035)
for x in [-1.57,1.57]:
    cube("Entrance vertical beam",(x,-1.49,.68),(.125,.14,1.33),trim,.022)
cube("Lower safety door sill",(0,-1.49,.085),(3.1,.12,.035),gold)
for x in [-1.48,1.48]:
    cube("Hazard bollard",(x,-1.56,.18),(.08,.08,.36), amber,.022)
for x in [-1.17,-.68,.68,1.17]:
    cube("Rear service wall shutter rib",(x,-1.497,.65),(.035,.035,.97),dark)
# Side annex: entirely within footprint. Details scaled in actual world units.
cube("Ground staff workshop annex",(-1.53,.68,.43),(.65,1.33,.83),white,.045)
cube("Workshop roof",(-1.53,.68,.87),(.77,1.46,.10),blue,.045)
cube("Annex door",(-1.91,.53,.39),(.025,.44,.58),blue)
for y in [-.73,-.23,.28,.79]:
    cube("Glass side service window",(1.902,y,1.02),(.035,.31,.24),glass,.013)
    cube("Thin window frame",(1.928,y,1.15),(.045,.36,.038),trim)
# Roof profile: precisely centered above building rectangle.
# A shallow pitched gable roof with a raised ridge and material-thickness.
# Roof edges have very limited overhang: max +/-1.99, +/-1.49.
verts=[
 (-1.99,-1.49,1.43),(1.99,-1.49,1.43),(0,-1.49,2.07),
 (-1.99,1.49,1.43),(1.99,1.49,1.43),(0,1.49,2.07)]
mesh("Left sloped roof", [verts[k] for k in [0,2,5,3]],[(0,1,2,3)],roof)
mesh("Right sloped roof", [verts[k] for k in [2,1,4,5]],[(0,1,2,3)],roof)
for x in [-1.99,1.99]:
    cube("Drain/roof gutter",(x,0,1.45),(.065,2.96,.065),trim,.02)
cube("Roof ridge", (0,0,2.079),(.10,2.96,.055),trim,.016)
# Longitudinal seam strips sit over the roof as subtle details.
for y in [-1.10,-.54,.02,.58,1.14]:
    for sign in [-1,1]:
        # tracks following pitched roof material
        section=mesh("Manufactured roof seam",[(0,y-.014,2.092),
            (sign*1.91,y-.014,1.485),(sign*1.91,y+.014,1.485),
            (0,y+.014,2.092)],[(0,1,2,3)],trim)
# Right side two raised skylights follow roof plane.
for y in [-.58,.37]:
    obj=cube("Raised glazed skylight",(0.78,y,1.81),(.68,.48,.045),glass,.025)
    obj.rotation_euler[1]=math.radians(-17)
    obj=cube("Skylight rim",(0.78,y,1.81),(.80,.60,.025),trim,.008)
    obj.rotation_euler[1]=math.radians(-17)
# Rooftop box ventilation (fully inside volume)
cube("Roof ventilation housing",(-.95,.67,1.78),(.37,.42,.27),trim,.027)
cube("Vent opening",(-.95,.448,1.79),(.26,.018,.12),dark)
cube("Front amber warning lamp",(-1.74,-1.495,1.35),(.11,.065,.12),amber,.012)
cube("Front amber warning lamp",(1.74,-1.495,1.35),(.11,.065,.12),amber,.012)

# Stable fixed orthographic camera; both orientations use exactly one rig.
def aim(obj, pt):
    direction=Vector(pt)-obj.location
    obj.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
bpy.ops.object.camera_add(location=(8,-8,9.8))
cam=bpy.context.object
cam.name="SKYPORT_GAME_CAMERA_DO_NOT_CHANGE"
aim(cam,(0,0,.90))
cam.data.type="ORTHO"
cam.data.ortho_scale=5.9
bpy.context.scene.camera=cam
bpy.ops.object.light_add(type="AREA", location=(-3,-4,8))
key=bpy.context.object
key.name="Shared sunny softbox"
key.data.energy=900
key.data.shape="DISK"
key.data.size=7
aim(key,(0,0,0))
bpy.ops.object.light_add(type="AREA", location=(4,2,5))
fill=bpy.context.object
fill.name="Shared reflected fill"
fill.data.energy=350
fill.data.size=6
aim(fill,(0,0,0))
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.samples=32
scene.render.resolution_x=896
scene.render.resolution_y=1040
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.view_settings.view_transform="Standard"
scene.view_settings.look="Medium High Contrast"
scene.render.image_settings.color_depth="8"
scene.camera.data.lens=35
scene.world.color=(.72,.78,.86)
# Source .blend is editable and shared; preview renders at 4x sprite dimensions.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"skyport_small_hangar_4x3.blend"))
scene.render.filepath=os.path.join(OUT,"small_hangar_4x3_render_4x.png")
bpy.ops.render.render(write_still=True)
print("SKYPORT_HANGAR_RENDER_OK",scene.render.filepath)
