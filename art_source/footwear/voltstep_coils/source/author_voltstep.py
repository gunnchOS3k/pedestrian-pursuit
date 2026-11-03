"""Original Voltstep Coils mesh authoring source; Blender 4.0.2.
Hand-shaped station rings, cut lightning panels, lacing, heel springs.
No downloaded art, textures, fonts or external meshes. Candidate, not final art.
"""
import bpy, math, os, json
from mathutils import Vector
from pathlib import Path

OUT = Path(__file__).resolve().parents[1]
ASSET = OUT / 'product/assets/models/footwear/voltstep_coils'
ASSET.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, roughness=.5, metal=0, emission=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=roughness;p.inputs['Metallic'].default_value=metal
    p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
    return m

navy=material('Woven midnight upper — original',(.032,.056,.095),.68)
rubber=material('Graphite directional grip',(.012,.019,.026),.86)
gold=material('Midsole yellow anodized frame',(.96,.68,.045),.3,.4)
cyan=material('Boost cyan coil conductor',(.035,.82,.73),.28,.25,.35)
ivory=material('Warm ivory ceramic toe',(.79,.82,.75),.46)
steel=material('Brushed heel stabilizer',(.16,.23,.28),.37,.7)
orange=material('Kinetic orange lace tips',(.98,.19,.065),.4)
parts=[]

def mesh(name, verts, faces, mat, smooth=False):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
    for p in m.polygons:p.use_smooth=smooth
    parts.append(o);return o

def bevel(o, width=.003, segments=2):
    mod=o.modifiers.new('Authored soft manufacturing edges','BEVEL');mod.width=width;mod.segments=segments
    mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    return o

# Model forward is Blender -Y; glTF/Godot forward is +Z, Z-up becomes Y-up.
# Deliberate sneaker outline, with a broad toe and narrower sculpted heel.
outline=[(-.042,-.165),(.042,-.165),(.068,-.142),(.077,-.09),(.074,-.02),(.064,.07),(.054,.137),(.035,.15),(-.035,.15),(-.054,.137),(-.064,.07),(-.074,-.02),(-.077,-.09),(-.068,-.142)]

def sole(name, outline, bottom, top, mat, inset=.003):
    n=len(outline);verts=[(x,y,bottom) for x,y in outline]+[(x,y,top) for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return bevel(mesh(name,verts,faces,mat),inset,2)

sole('Continuous grounded graphite outsole',outline,-.059,-.039,rubber)
sole('Thin cyan sole seam',outline,-.039,-.031,cyan,.001)
# Forefoot only: the heel spring remains visible under the floating upper cup.
fore=[(x,y) for x,y in outline if y<.071]
fore.insert(6,(.06,.048));fore.insert(7,(-.06,.048))
sole('Sculpted split forefoot midsole',fore,-.031,.004,gold)

# Upper is a continuous custom mesh with distinct toe, instep and ankle volumes.
stations=[(-.164,.032,.025,.027),(-.145,.061,.025,.045),(-.09,.072,.026,.055),(-.025,.068,.035,.082),(.038,.061,.052,.106),(.095,.054,.057,.13),(.143,.044,.048,.117)]
segments=12;verts=[]
for y,width,low,high in stations:
    for i in range(segments):
        angle=2*math.pi*i/segments
        verts.append((width*math.cos(angle),y,low+(high-low)*(.5+.5*math.sin(angle))))
faces=[]
for s in range(len(stations)-1):
    for i in range(segments):faces.append((s*segments+i,s*segments+(i+1)%segments,(s+1)*segments+(i+1)%segments,(s+1)*segments+i))
faces.extend([tuple(reversed(range(segments))),tuple(range((len(stations)-1)*segments,len(stations)*segments))])
upper=mesh('Authored tapered woven sneaker shell',verts,faces,navy,True)
bevel(upper,.002,2)

# Ceramic toe guard follows the curved toe rather than a box placeholder.
toe=[(-.063,-.145),(-.04,-.169),(.04,-.169),(.063,-.145),(.07,-.102),(-.07,-.102)]
sole('Faceted ceramic toe cap',toe,.023,.047,ivory,.004)

def bar(name,a,b,r,mat,vertices=10):
    mid=(Vector(a)+Vector(b))/2;delta=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=delta.length,location=mid)
    o=bpy.context.object;o.name=name;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
    parts.append(o);return bevel(o,min(.001,r*.25),1)

def tube(name, points, radius, mat, sides=7):
    v=[];f=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        tangent.normalize();u=tangent.cross(Vector((0,0,1)))
        if u.length<.001:u=tangent.cross(Vector((0,1,0)))
        u.normalize();w=tangent.cross(u).normalized()
        for k in range(sides):v.append(tuple(Vector(p)+radius*(math.cos(k*2*math.pi/sides)*u+math.sin(k*2*math.pi/sides)*w)))
    for i in range(len(points)-1):
        for k in range(sides):f.append((i*sides+k,i*sides+(k+1)%sides,(i+1)*sides+(k+1)%sides,(i+1)*sides+k))
    return mesh(name,v,f,mat,True)

# Twin exposed helical heel springs; physical collision is still the normal shoe collider.
for x in [-.031,.031]:
    pts=[]
    for i in range(81):
        t=i/80;angle=t*math.pi*8
        pts.append((x+.018*math.cos(angle),.101+.018*math.sin(angle),-.028+t*.061))
    tube('Visible four-turn cyan heel coil',pts,.0038,cyan)
    bar('Heel suspension axle',(x,.101,-.028),(x,.101,.033),.005,steel)
    for z in [-.029,.033]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.026,depth=.007,location=(x,.101,z))
        o=bpy.context.object;o.name='Gold heel spring retaining cup';o.data.materials.append(gold);parts.append(o)

# Lightning side overlay: custom polygon, present on both sides for chase-camera readability.
lightning=[(-.115,.046),(-.031,.086),(-.04,.061),(.074,.1),(.011,.048),(.019,.069)]
for side in [-1,1]:
    verts=[(side*(.071 if y<0 else .059),y,z) for y,z in lightning]
    panel=mesh('Cut gold lightning side support',verts,[tuple(range(len(verts)))],gold)
    solid=panel.modifiers.new('Manufactured overlay thickness','SOLIDIFY');solid.thickness=.003
    bevel(panel,.001,2)
    bar('Cyan heel stabilizing fork',(side*.055,.044,.018),(side*.046,.128,.075),.004,cyan)

# Six independent laces and ceramic eyelets, with intentional diagonal rhythm.
for row in range(5):
    y=-.047+row*.021;z=.078+row*.009
    bar('Ivory diagonal lace',(-.029,y,z),(.029,y+.01,z+.005),.0028,ivory,8)
    for x in [-.033,.033]:bar('Gold lace eyelet',(x,y-.001,z-.003),(x,y+.006,z-.003),.005,gold,10)
bar('Orange lace-lock',(-.009,.049,.123),(.009,.049,.123),.005,orange)
bar('Heel pull loop left',(-.018,.145,.094),(-.018,.16,.142),.004,orange)
bar('Heel pull loop top',(-.018,.16,.142),(.018,.16,.142),.004,orange)
bar('Heel pull loop right',(.018,.16,.142),(.018,.145,.094),.004,orange)

# Ground grip is geometric, with directional chevrons instead of a colored plane.
for row in range(6):
    y=-.13+row*.045
    for side in [-1,1]:
        bar('Directional outsole tread',(0,y,-.061),(side*.055,y+.015,-.061),.004,rubber,6)

for o in parts:
    o['asset_status']='production_candidate';o['authored_for']='Pedestrian Pursuit / Voltstep Coils';o['third_party_source']='none'
    o.data.use_auto_smooth=True
bpy.context.scene['asset_status']='production_candidate — awaits distinct visual review and human acceptance'
bpy.context.scene['unit_contract']='meters; +X width; Blender -Y toe; Blender Z up. Export glTF +Y up.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/VoltstepCoils.blend'))

# Runtime export merges by material: source stays separated and editable in the .blend.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
for o in list(parts):
    bpy.context.view_layer.objects.active=o
    for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
joined=bpy.context.object;joined.name='VoltstepCoils_AuthoredFootwear'
bpy.ops.export_scene.gltf(filepath=str(ASSET/'VoltstepCoils.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_extras=True)
triangles=sum(len(p.vertices)-2 for p in joined.data.polygons)
(OUT/'source/BLENDER_EXPORT.json').write_text(json.dumps({'blender':bpy.app.version_string,'triangles_per_foot':triangles,'materials':len(joined.data.materials),'mesh_objects_exported':1,'status':'production_candidate','source':'original custom ring/panel topology, lacing and helical suspension; no third-party assets','export':{'format':'GLB','y_up':True,'modifiers_applied':True,'textures':'none; PBR materials only','selection_only':True}},indent=2)+'\n')
print('VOLTSTEP_AUTHORED_EXPORT',triangles,'triangles',len(joined.data.materials),'materials')
