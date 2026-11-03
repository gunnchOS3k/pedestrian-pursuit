"""Eight original Kinetic Sole art candidates; editable Blender 4.0 source.

Run Python with --plan to inspect the source/registry contract without Blender.
Run Blender 4.0.2 --background --python this_file -- --ids all to produce assets.
Only this wave's new directories are written. No downloaded geometry or textures.
Sources are saved before runtime mesh consolidation. Human acceptance is pending.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parents[2]
RUNTIME = PROJECT / "assets/models/footwear/wave1"
BASE_SHA = "91514ef61f80d960703362eeb73eedf84f438a89"
DESIGNS = {
    "reedline_circlers": ("ReedlineCirclers", "street_legends", "street_balanced",
        "Low street sneaker; circular stitched quarter, layered orange toe, segmented rubber tread and offset lace cage."),
    "slipstream_inlines": ("SlipstreamInlines", "roller_revolution", "roller_inline",
        "Four single-file urethane wheels, long open fork, aerodynamic cyan boot, double buckle and vented ankle cuff."),
    "heelspin_quads": ("HeelspinQuads", "roller_revolution", "roller_quad",
        "Four wide-set pink wheels, two truck axles, raised magenta boot, scalloped cream panel and toe brake."),
    "cloudsole_striders": ("CloudsoleStriders", "hover_couture", "hover_glide",
        "Separated cloud bladder pods and an open luminous air gap, white-blue wrap upper and floating side arcs."),
    "tidefin_runners": ("TidefinRunners", "elemental_amphibious", "elemental_wet",
        "Low aquatic membrane runner, flexible scalloped side fins, gill ribs and wave-cut gripping keel."),
    "snowglobe_galoshes": ("SnowglobeGaloshes", "elemental_amphibious", "elemental_frost",
        "Tall ribbed frost-rubber galosh, folded insulated cuff, snowglobe-like heel dome, inset flakes and deep cross tread."),
    "beatlink_tapstep_oxfords": ("BeatLinkTapstepOxfords", "gunnchos_crossover", "crossover_tap",
        "Almond-toe two-tone Oxford, closed lacing, wingtip seam and brogue insets, separate metal toe/heel tap plates."),
    "sofa_surfers": ("SofaSurfers", "beautifully_ridiculous", "ridiculous_drift",
        "Miniature upholstered sofa slipper: rounded armrests, piped seat, button-tufted back and curved wooden glide rails."),
}

bpy = None
Vector = None
parts = []
moving = []
wheel_nodes = []
M = {}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_references():
    registry = json.loads((PROJECT / "data/vehicles/vehicle_registry.json").read_text())
    vehicles = {v["id"]: v for v in registry["vehicles"]}
    assert len(vehicles) == 50, "Full established 50-item registry required"
    references = {}
    for ident, (_, family, archetype, _) in DESIGNS.items():
        shoe_path = PROJECT / f"data/shoes/{ident}.json"
        shoe = json.loads(shoe_path.read_text())
        for record in [vehicles[ident], shoe]:
            assert record["family_id"] == family, ident
            assert record["movement_archetype"] == archetype, ident
        references[ident] = {"registry_record": vehicles[ident], "shoe_sha256": digest(shoe_path)}
    references["brand_sha256"] = digest(PROJECT / "docs/vxp3/VXP3_BRAND_SYSTEM.md")
    references["registry_sha256"] = digest(PROJECT / "data/vehicles/vehicle_registry.json")
    references["voltstep_preserved"] = {
        "glb_sha256": digest(PROJECT / "assets/models/footwear/voltstep_coils/VoltstepCoils.glb"),
        "blend_sha256": digest(PROJECT / "art_source/footwear/voltstep_coils/source/VoltstepCoils.blend"),
    }
    assert references["voltstep_preserved"]["glb_sha256"] == "d5961bd64ad01a8fb3df814cc814c7669cb923ae58cfd07b0135de8940f8511e"
    assert references["voltstep_preserved"]["blend_sha256"] == "c79b4dc74a801a3b9a7492aebea3373e211ec9885498e1c496b16093e34aec7f"
    return references


def material(name, color, rough=.5, metal=0, glow=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    p.inputs["Emission Color"].default_value = (*color, 1)
    p.inputs["Emission Strength"].default_value = glow
    return m


def palette():
    return {
        "rubber": material("Graphite grippy rubber", (.024, .035, .050), .88),
        "steel": material("Brushed structural alloy", (.22, .28, .34), .32, .72),
        "ivory": material("Warm ivory stitched panel", (.88, .86, .75), .63),
        "orange": material("Kinetic orange textile", (1.0, .24, .085), .74),
        "navy": material("Night track woven lining", (.035, .063, .12), .82),
        "cyan": material("Boost cyan conductor", (.025, .72, .65), .3, .2, .25),
        "blue": material("Slipstream cyan shell", (.16, .72, .93), .36, .15),
        "pink": material("Heelspin magenta leather", (.91, .19, .42), .43),
        "violet": material("Berry plum binding", (.26, .055, .24), .54),
        "wheel": material("Amber translucent-look urethane opaque", (.96, .56, .12), .28),
        "cloud": material("Cloud ceramic white blue", (.72, .84, .96), .3, .12),
        "aqua": material("Tide membrane aqua rubber", (.07, .63, .75), .55),
        "teal": material("Deep sea fin edging", (.025, .20, .28), .72),
        "frost": material("Frost galosh glazed rubber", (.65, .85, .93), .27),
        "snow": material("Insulated snow felt", (.91, .95, .94), .94),
        "glass": material("Opaque blue snowglobe glaze", (.18, .43, .66), .2, .3),
        "leather": material("Charcoal polished Oxford leather", (.075, .085, .11), .22),
        "tap": material("Brushed tap plate", (.50, .57, .63), .25, .87),
        "denim": material("Cozy blue upholstery", (.24, .36, .61), .92),
        "piping": material("Cream woven cushion piping", (.82, .77, .62), .87),
        "wood": material("Warm bentwood glide rails", (.28, .13, .065), .61),
    }


def mesh(name, vertices, faces, mat, smooth=False, record=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for face in data.polygons:
        face.use_smooth = smooth
    if record:
        parts.append(obj)
    return obj


def bevel(obj, amount=.002, segments=2):
    mod = obj.modifiers.new("Soft manufactured edge", "BEVEL")
    mod.width, mod.segments = amount, segments
    mod = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    return obj


def prism(name, outline, bottom, top, mat, edge=.002):
    n = len(outline)
    verts = [(x, y, bottom) for x, y in outline] + [(x, y, top) for x, y in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1) % n, (i+1) % n+n, i+n) for i in range(n)]
    return bevel(mesh(name, verts, faces, mat), edge)


def outline(width=.075, front=-.16, back=.145):
    return [(-width*.55, front), (width*.55, front), (width*.87, front+.022),
            (width, front+.07), (width*.97, -.025), (width*.82, .07),
            (width*.68, back-.014), (width*.44, back), (-width*.44, back),
            (-width*.68, back-.014), (-width*.82, .07), (-width*.97, -.025),
            (-width, front+.07), (-width*.87, front+.022)]


def shell(name, stations, mat, sides=14):
    """Authored longitudinal cross-sections; each (y, halfwidth, base, height)."""
    verts = []
    for y, width, low, high in stations:
        for k in range(sides):
            a = 2*math.pi*k/sides
            verts.append((width*math.cos(a), y, low+(high-low)*(.5+.5*math.sin(a))))
    faces = []
    for j in range(len(stations)-1):
        for k in range(sides):
            a = j*sides+k
            faces.append((a, j*sides+(k+1) % sides, (j+1)*sides+(k+1) % sides, a+sides))
    faces += [tuple(reversed(range(sides))), tuple(range((len(stations)-1)*sides, len(stations)*sides))]
    # Ring order is counterclockwise in X/Z while stations advance in +Y.
    # Reverse this winding so the opaque runtime shell faces outward.
    faces = [tuple(reversed(face)) for face in faces]
    return bevel(mesh(name, verts, faces, mat, True), .001, 1)


def box(name, center, scale, mat, edge=.003):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name, obj.scale = name, scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    parts.append(obj)
    return bevel(obj, edge)


def tube(name, points, radius, mat, sides=7, record=True):
    verts, faces = [], []
    for i, point in enumerate(points):
        tangent = Vector(points[min(i+1, len(points)-1)])-Vector(points[max(i-1, 0)])
        tangent.normalize()
        u = tangent.cross(Vector((0, 0, 1)))
        if u.length < .001:
            u = tangent.cross(Vector((0, 1, 0)))
        u.normalize()
        w = tangent.cross(u).normalized()
        for k in range(sides):
            a = k*2*math.pi/sides
            verts.append(tuple(Vector(point)+radius*(math.cos(a)*u+math.sin(a)*w)))
    for j in range(len(points)-1):
        for k in range(sides):
            faces.append((j*sides+k, j*sides+(k+1) % sides, (j+1)*sides+(k+1) % sides, (j+1)*sides+k))
    faces += [tuple(reversed(range(sides))), tuple(range((len(points)-1)*sides, len(points)*sides))]
    return mesh(name, verts, faces, mat, True, record)


def bar(name, start, end, radius, mat, sides=8):
    return tube(name, [start, end], radius, mat, sides)


def loop(name, center, rx, ry, radius, mat, plane="XY", count=28):
    points = []
    for i in range(count+1):
        a = i*math.pi*2/count
        if plane == "YZ":
            points.append((center[0], center[1]+rx*math.cos(a), center[2]+ry*math.sin(a)))
        else:
            points.append((center[0]+rx*math.cos(a), center[1]+ry*math.sin(a), center[2]))
    return tube(name, points, radius, mat)


def ellipsoid(name, center, radii, mat, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=center)
    obj = bpy.context.object
    obj.name, obj.scale = name, radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.use_smooth = True
    parts.append(obj)
    return obj


def laces(start_y, step, height, rows, mat, width=.032):
    for n in range(rows):
        y, z = start_y+n*step, height+n*.006
        bar("Lace crossing", (-width, y, z), (width, y+step*.7, z+.003), .0023, mat)
        for side in [-1, 1]:
            bar("Inset lace eyelet", (side*width, y-.002, z-.003), (side*width, y+.003, z-.003), .0035, M["steel"])


def tread(width=.06, rows=6, mat=None):
    for n in range(rows):
        y = -.13+n*.045
        for side in [-1, 1]:
            bar("Grounded chevron tread", (0, y, -.057), (side*width, y+.014, -.057), .003, mat or M["rubber"], 6)


def round_cuff(y, z, height, rx, ry, mat):
    verts, faces = [], []
    n = 20
    for zz, inset in [(z, 0), (z+height, 0), (z+height, .009), (z+.007, .009)]:
        for i in range(n):
            a = 2*math.pi*i/n
            verts.append(((rx-inset)*math.cos(a), y+(ry-inset)*math.sin(a), zz))
    for ring in range(4):
        for i in range(n):
            faces.append((ring*n+i, ring*n+(i+1) % n, ((ring+1) % 4)*n+(i+1) % n, ((ring+1) % 4)*n+i))
    return bevel(mesh("Open ankle cuff with visible lining", verts, faces, mat, True), .001, 1)


def cylinder_local(name, radius, width, mat, parent):
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius, depth=width)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler[1] = math.pi/2
    obj.data.materials.append(mat)
    obj.parent = parent
    for p in obj.data.polygons:
        p.use_smooth = True
    moving.append(obj)
    return bevel(obj, .001, 1)


def wheel(name, x, y, radius, width, mat):
    node = bpy.data.objects.new("WheelSpin_"+name, None)
    bpy.context.collection.objects.link(node)
    node.location = (x, y, -.06+radius)
    node["spin_axis_blender"] = "local X; remains local X after Y-up export"
    node["radius_m"] = radius
    node["runtime_speed_binding"] = "not implemented in asset; caller may use speed/radius"
    cylinder_local("Urethane tire", radius, width, mat, node)
    for side in [-1, 1]:
        hub = cylinder_local("Recessed wheel hub", radius*.57, .002, M["steel"], node)
        hub.location.x = side*(width*.5+.001)
        cap = cylinder_local("Circular axle cap", radius*.19, .003, M["ivory"], node)
        cap.location.x = side*(width*.5+.002)
        # Three raised radial markers make the exported spin visually inspectable.
        for k in range(3):
            a = k*2*math.pi/3
            p = (.0, math.cos(a)*radius*.72, math.sin(a)*radius*.72)
            q = (.0, math.cos(a)*radius*.4, math.sin(a)*radius*.4)
            obj = tube("Wheel rotation marker", [(side*(width/2+.002), p[1], p[2]), (side*(width/2+.002), q[1], q[2])], .0015, M["ivory"], 6, False)
            obj.parent = node
            moving.append(obj)
    node.rotation_euler.x = 0
    node.keyframe_insert(data_path="rotation_euler", frame=1, index=0)
    node.rotation_euler.x = math.pi*2
    node.keyframe_insert(data_path="rotation_euler", frame=25, index=0)
    action = node.animation_data.action
    action.name = name+"_WheelSpinSource"
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"
    track = node.animation_data.nla_tracks.new()
    track.name = "WheelSpin"
    track.strips.new("WheelSpin", 1, action)
    node.animation_data.action = None
    node.rotation_euler.x = 0
    wheel_nodes.append(node)


def reedline():
    prism("Segmented rounded street outsole", outline(), -.057, -.032, M["rubber"])
    prism("Ivory wrapped sidewall", outline(.077), -.032, -.012, M["ivory"])
    shell("Low rounded orange street upper", [(-.16,.034,-.01,.025),(-.14,.063,-.008,.05),(-.08,.071,-.004,.066),(-.01,.064,.006,.084),(.06,.052,.015,.108),(.13,.041,.003,.102)], M["orange"])
    round_cuff(.083, .067, .043, .045, .05, M["navy"])
    for side in [-1, 1]:
        loop("Circler sewn quarter ring", (side*.066,-.007,.051), .039,.025,.0038,M["ivory"],"YZ")
        for i in range(12):
            a=i*math.pi/6
            ellipsoid("Circular stitch inset", (side*.07,-.007+.041*math.cos(a),.051+.027*math.sin(a)),(.0018,.002,.0016),M["navy"],1)
        tube("Orange segmented toe bumper", [(side*.043,-.161,-.012),(side*.07,-.14,-.01),(side*.079,-.09,-.01)],.005,M["orange"])
    laces(-.057,.021,.079,4,M["navy"])
    box("Heel stabilizer tab",(0,.132,.061),(.058,.015,.052),M["ivory"])
    tread()


def inline():
    shell("Streamlined inline boot",[(-.147,.033,.025,.057),(-.12,.062,.028,.088),(-.04,.065,.034,.117),(.03,.054,.04,.13),(.10,.046,.036,.139),(.136,.037,.03,.111)],M["blue"])
    round_cuff(.071,.104,.076,.048,.056,M["navy"])
    for side in [-1,1]:
        box("Long exposed inline fork",(side*.025,0,.008),(.012,.296,.025),M["steel"],.002)
        for j in range(4):
            y=-.117+j*.078
            bar("Fork axle bridge",(-.033,y,.002),(.033,y,.002),.006,M["steel"])
        tube("Airfoil boot spine",[(side*.066,-.105,.055),(side*.067,-.04,.105),(side*.055,.052,.141)],.004,M["ivory"])
        for j in range(3):
            bar("Cuff vent insert",(side*.049,.043+j*.014,.126),(side*.049,.046+j*.014,.157),.0025,M["blue"])
    for y,z in [(-.03,.124),(.051,.163)]:
        box("Ratchet binding strap",(0,y,z),(.107,.019,.012),M["ivory"])
        box("Orange buckle latch",(.045,y,z+.006),(.018,.026,.012),M["orange"])
    for j in range(4):
        wheel(str(j),0,-.117+j*.078,.0365,.031,M["wheel"])


def quads():
    shell("Heelspin high boot",[(-.15,.033,.017,.05),(-.128,.066,.02,.073),(-.05,.068,.023,.098),(.02,.056,.025,.128),(.09,.046,.023,.16),(.134,.038,.02,.141)],M["pink"])
    round_cuff(.078,.12,.075,.05,.055,M["ivory"])
    prism("Quad boot supportive footplate",outline(.067,-.145,.13),.002,.023,M["violet"])
    for y in [-.088,.09]:
        box("Two-wheel truck crossbar",(0,y,-.018),(.147,.021,.02),M["steel"])
        for side in [-1,1]:
            wheel(("L" if side<0 else "R")+("Front" if y<0 else "Rear"),side*.073,y,.034,.026,M["pink"])
    for side in [-1,1]:
        tube("Cream scalloped boot quarter",[(side*.061,-.10,.075),(side*.066,-.063,.09),(side*.058,-.015,.079),(side*.05,.03,.125),(side*.049,.105,.16)],.005,M["ivory"])
    laces(-.065,.022,.106,5,M["violet"])
    ellipsoid("Ground-near front brake",(0,-.144,-.029),(.022,.024,.024),M["rubber"])
    box("Brake mounting stem",(0,-.128,-.002),(.018,.025,.035),M["steel"])


def cloud():
    for side in [-1,1]:
        for j in range(3):
            ellipsoid("Cloud grounded bladder pod",(side*.043,-.095+j*.092,-.043),(.038,.044,.017),M["cloud"])
    prism("Separated upper ceramic deck",outline(.072,-.15,.14),.001,.017,M["ivory"])
    shell("Air gap couture wrap",[(-.15,.032,.02,.041),(-.128,.062,.021,.067),(-.045,.066,.025,.091),(.035,.055,.04,.119),(.116,.043,.031,.111),(.14,.033,.025,.086)],M["cloud"])
    for side in [-1,1]:
        for y in [-.083,.085]:
            bar("Visible cyan air gap support",(side*.043,y,-.03),(side*.043,y,.003),.005,M["cyan"])
        tube("Floating side arc",[(side*.069,-.13,.017),(side*.084,-.078,.038),(side*.083,.022,.047),(side*.065,.125,.025)],.004,M["cyan"])
    for j in range(3):
        y=-.038+j*.031
        box("Cloud wrap band",(0,y,.101+j*.004),(.09,.018,.009),M["navy"])
    loop("Cloud ankle rim",(0,.09,.105),.04,.042,.006,M["cyan"])


def tidefin():
    prism("Wide aquatic gripping paddle",outline(.083,-.164,.14),-.056,-.029,M["teal"])
    shell("Membrane fin runner body",[(-.16,.035,-.02,.017),(-.139,.067,-.02,.043),(-.065,.069,-.01,.058),(.005,.057,.004,.081),(.08,.041,.003,.109),(.137,.027,-.014,.084)],M["aqua"])
    round_cuff(.082,.066,.034,.036,.045,M["teal"])
    for side in [-1,1]:
        v=[(side*.064,-.115,-.012),(side*.096,-.094,-.005),(side*.082,-.048,.033),(side*.098,-.016,.045),(side*.076,.032,.056),(side*.091,.071,.058),(side*.047,.122,.035)]
        fin=mesh("Scalloped flexible side fin",v,[tuple(range(len(v)))],M["aqua"])
        sol=fin.modifiers.new("Flexible fin membrane thickness","SOLIDIFY");sol.thickness=.004
        bevel(fin,.001,1)
        tube("Dark fin edge",v,.0025,M["teal"])
        for j in range(4):
            y=-.09+j*.036
            bar("Raised gill grip rib",(side*.066,y,.015),(side*.061,y+.018,.05),.003,M["ivory"])
    for j in range(4):
        y=-.108+j*.062
        tube("Wave tread ridge",[(-.058,y,-.057),(-.025,y+.008,-.057),(0,y,-.057),(.025,y-.008,-.057),(.058,y,-.057)],.0025,M["ivory"])
    bar("Coral heel grab",(-.02,.13,.073),(.02,.13,.073),.005,M["orange"])


def galosh():
    prism("Deep frost rubber outsole",outline(.081,-.159,.143),-.057,-.027,M["navy"])
    shell("Rounded weatherproof galosh",[(-.158,.034,-.024,.025),(-.132,.066,-.021,.052),(-.05,.073,-.018,.07),(.019,.062,-.012,.099),(.09,.051,-.013,.146),(.139,.038,-.021,.121)],M["frost"])
    round_cuff(.073,.103,.111,.054,.061,M["frost"])
    loop("Folded snow cuff outer",(0,.073,.213),.055,.062,.009,M["snow"])
    loop("Folded cuff inner seam",(0,.073,.205),.047,.054,.003,M["navy"])
    for side in [-1,1]:
        for j in range(5):
            y=.027+j*.021
            bar("Galosh ribbed reinforcement",(side*.054,y,.12),(side*.052,y,.187),.0028,M["ivory"])
        for j in range(4):
            box("Winter block grip",(side*.05,-.12+j*.068,-.054),(.045,.03,.012),M["navy"],.001)
        ellipsoid("Snowglobe heel glazed dome",(side*.052,.099,.076),(.023,.03,.033),M["glass"])
        for a in [0,math.pi/3,math.pi*2/3]:
            dy,dz=.018*math.cos(a),.018*math.sin(a)
            bar("Inset white snowflake spoke",(side*.075,.099-dy,.076-dz),(side*.075,.099+dy,.076+dz),.0017,M["snow"])
    tube("Winter boot front seam",[(-.05,-.108,.048),(0,-.123,.056),(.05,-.108,.048)],.003,M["ivory"])


def oxford():
    out=outline(.071,-.16,.142)
    prism("Stitched slim Oxford welt",out,-.036,-.021,M["ivory"])
    prism("Separate forefoot sole",outline(.071,-.16,.045),-.052,-.035,M["leather"])
    prism("Stacked tap heel",[(-.045,.055),(.045,.055),(.048,.125),(.027,.145),(-.027,.145),(-.048,.125)],-.057,-.026,M["leather"])
    shell("Almond toe polished Oxford",[(-.159,.022,-.022,.002),(-.141,.052,-.017,.032),(-.083,.066,-.013,.052),(-.02,.059,-.005,.07),(.052,.048,.001,.083),(.12,.041,-.013,.074),(.139,.028,-.018,.052)],M["leather"])
    # W-shaped wingtip applique follows the curved toe, with embossed brogue holes.
    wing=[(-.058,-.113,.034),(-.031,-.087,.047),(0,-.112,.05),(.031,-.087,.047),(.058,-.113,.034)]
    tube("Wingtip raised cream seam",wing,.003,M["ivory"])
    for a,b in zip(wing,wing[1:]):
        for j in range(4):
            t=(j+.5)/4;p=tuple(a[k]*(1-t)+b[k]*t for k in range(3))
            ellipsoid("Brogue dark inset",(p[0],p[1]+.006,p[2]+.001),(.0018,.002,.0013),M["rubber"],1)
    for side in [-1,1]:
        tube("Closed Oxford quarter seam",[(side*.037,-.033,.061),(side*.045,.027,.069),(side*.045,.087,.054),(side*.035,.134,.046)],.002,M["ivory"])
        loop("Linked ribbon stage accent",(side*.046,.072,.048),.014,.009,.0017,M["cyan"],"YZ",20)
        loop("Linked ribbon stage accent partner",(side*.047,.089,.048),.014,.009,.0017,M["pink"],"YZ",20)
    laces(-.04,.017,.075,4,M["violet"],.021)
    prism("Metal toe tap plate",[(-.042,-.155),(.042,-.155),(.058,-.13),(.055,-.094),(-.055,-.094),(-.058,-.13)],-.06,-.053,M["tap"],.001)
    prism("Metal heel tap plate",[(-.039,.073),(.039,.073),(.039,.128),(.023,.143),(-.023,.143),(-.039,.128)],-.06,-.057,M["tap"],.001)


def sofa():
    prism("Sofa slipper undersole",outline(.087,-.16,.142),-.033,-.017,M["wood"])
    for side in [-1,1]:
        tube("Curved bentwood surf runner",[(side*.058,-.155,-.036),(side*.058,-.12,-.055),(side*.058,.08,-.055),(side*.058,.14,-.038)],.005,M["wood"])
    box("Rounded upholstered seat cushion",(0,-.038,.025),(.143,.214,.084),M["denim"],.022)
    for side in [-1,1]:
        tube("Rounded sofa armrest",[(side*.074,-.122,.046),(side*.084,-.075,.069),(side*.083,.044,.071),(side*.071,.11,.088)],.015,M["denim"],12)
        tube("Armrest cream piping",[(side*.077,-.125,.057),(side*.09,-.071,.082),(side*.088,.045,.084),(side*.072,.115,.101)],.0022,M["piping"])
    box("High padded sofa backrest",(0,.106,.088),(.143,.044,.133),M["denim"],.018)
    tube("Seat cushion piped perimeter",[(-.061,-.135,.05),(.061,-.135,.05),(.065,.053,.05),(-.065,.053,.05),(-.061,-.135,.05)],.0025,M["piping"])
    tube("Backrest piped top",[(-.062,.082,.13),(-.05,.079,.149),(.05,.079,.149),(.062,.082,.13)],.0022,M["piping"])
    for x in [-.032,.032]:
        for z in [.075,.118]:
            ellipsoid("Tufted upholstery button",(x,.081,z),(.005,.003,.005),M["piping"])
            for side in [-1,1]:
                bar("Tufted diagonal fabric seam",(x,.079,z),(x+side*.015,.079,z+.014),.0009,M["navy"],5)


BUILDERS = {"reedline_circlers": reedline, "slipstream_inlines": inline, "heelspin_quads": quads,
            "cloudsole_striders": cloud, "tidefin_runners": tidefin, "snowglobe_galoshes": galosh,
            "beatlink_tapstep_oxfords": oxford, "sofa_surfers": sofa}


def apply_modifiers(objects):
    for obj in objects:
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    return result


def generate(ident):
    global parts, moving, wheel_nodes, M
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for blocks in [bpy.data.meshes, bpy.data.actions]:
        for data in list(blocks):
            if data.users == 0:
                blocks.remove(data)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    parts, moving, wheel_nodes = [], [], []
    M = palette()
    BUILDERS[ident]()
    name, family, archetype, design = DESIGNS[ident]
    root = bpy.data.objects.new(name+"_AuthoredFootwear", None)
    bpy.context.collection.objects.link(root)
    for obj in parts+wheel_nodes:
        obj.parent = root
    for obj in parts+moving:
        obj["asset_status"] = "original_art_candidate"
        obj["authored_for"] = "Pedestrian Pursuit / "+name
        obj["third_party_source"] = "none"
        if hasattr(obj.data, "use_auto_smooth"):
            obj.data.use_auto_smooth = True
    root["vehicle_id"], root["family_id"] = ident, family
    root["asset_status"] = "original_art_candidate; runtime visual acceptance pending"
    scene = bpy.context.scene
    scene.unit_settings.system, scene.unit_settings.scale_length = "METRIC", 1
    scene.render.fps, scene.frame_start, scene.frame_end = 24, 1, 25
    scene.frame_set(1)
    scene["design_interpretation"] = design
    scene["axis_contract"] = "meters; Blender -Y toe / Z up; glTF/Godot +Z toe / Y up"
    scene["collision_contract"] = "Visual only. Grounded game collision/handling/checkpoints unchanged."
    scene["acceptance"] = "HUMAN=false; RC2=false; V1=false; distinct visual review pending"
    scene["authoring_script_sha256"] = digest(Path(__file__))
    folder = SOURCE / ident
    folder.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    blend = folder / (name+".blend")
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    source_meshes = len(parts)+len(moving)
    # Consolidate static surfaces; preserve the separate rotating wheel-root hierarchy.
    apply_modifiers(parts+moving)
    static = join(parts, name+"_StaticSurfaces")
    for node in wheel_nodes:
        # Joining destroys all but the active mesh. Inspect this live hierarchy
        # rather than stale Python references to meshes joined for earlier wheels.
        wheelparts = [o for o in node.children if o.type == "MESH"]
        if wheelparts:
            join(wheelparts, node.name+"_Mesh")
    bpy.ops.object.select_all(action="SELECT")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.context.view_layer.update()
    triangles = sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)
    corners = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    lower = [min(p[i] for p in corners) for i in range(3)]
    upper = [max(p[i] for p in corners) for i in range(3)]
    bounds = {"min_blender_m": lower, "max_blender_m": upper, "size_m": [upper[i]-lower[i] for i in range(3)]}
    assert .12 <= bounds["size_m"][0] <= .22, (ident, bounds)
    assert .27 <= bounds["size_m"][1] <= .36, (ident, bounds)
    assert -.07 <= lower[2] <= -.048, (ident, bounds)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    glb = RUNTIME / (name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_extras=True,
        export_animations=True, export_animation_mode="NLA_TRACKS",
        export_force_sampling=True, export_frame_range=True)
    receipt = {"id": ident, "name": name, "family_id": family, "movement_archetype": archetype,
        "design": design, "status": "original_art_candidate_exported_not_runtime_assessed",
        "authoring_script_sha256": digest(Path(__file__)),
        "source_blend": str(blend.relative_to(PROJECT)), "source_blend_sha256": digest(blend),
        "asset_path": "res://"+str(glb.relative_to(PROJECT)), "glb_sha256": digest(glb),
        "triangles_per_foot": triangles, "source_mesh_objects": source_meshes,
        "runtime_mesh_objects": len(meshes), "bounds": bounds,
        "wheel_nodes": [o.name for o in wheel_nodes],
        "animation": "WheelSpin illustrative one-second linear clip; no runtime speed binding or autoplay promised" if wheel_nodes else "Existing runner mount/gait only; no new rig or animation",
        "HUMAN": False, "RC2": False, "V1": False}
    (folder / "EXPORT.json").write_text(json.dumps(receipt, indent=2)+"\n")
    return receipt


def main():
    global bpy, Vector
    import sys
    argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("--ids", default="all")
    args = parser.parse_args(argv)
    references = validate_references()
    ids = list(DESIGNS) if args.ids == "all" else args.ids.split(",")
    assert ids and len(ids) == len(set(ids)) and all(i in DESIGNS for i in ids)
    if args.plan:
        print(json.dumps({"registry_count": 50, "source_base_sha": BASE_SHA,
            "status": "editable_authoring_source_ready_no_models_generated",
            "ids": ids, "designs": DESIGNS, "reference_hashes": references}, indent=2))
        return
    import bpy as blender
    from mathutils import Vector as MathVector
    bpy, Vector = blender, MathVector
    manifest_path = RUNTIME / "WAVE1_MANIFEST.json"
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    by_id = {a["id"]: a for a in previous.get("assets", [])}
    manifest = {"wave": "original_kinetic_sole_wave1_20261102", "source_base_sha": BASE_SHA,
        "blender": bpy.app.version_string, "authoring_script_sha256": digest(Path(__file__)),
        "provenance": "Original custom geometry/materials, no external assets, logos, fonts or licensed characters",
        "design_basis": ["data/vehicles/vehicle_registry.json", "data/shoes/<id>.json", "docs/vxp3/VXP3_BRAND_SYSTEM.md", "scripts/player/RacerVisual.gd existing palettes (read-only)"],
        "axis_contract": "meters; Blender -Y toe / Z up; glTF/Godot +Z toe / Y up",
        "reference_hashes": references, "assets": [],
        "runtime_assessment": "pending actual RaceScene and garage evaluation by integration owner",
        "independent_review": "pending distinct reviewer; author measurements are not independent approval",
        "HUMAN": False, "RC2": False, "V1": False}
    results = []
    for ident in ids:
        result = generate(ident)
        by_id[ident] = result
        results.append(result)
        manifest["assets"] = [by_id[i] for i in DESIGNS if i in by_id]
        manifest_path.write_text(json.dumps(manifest, indent=2)+"\n")
    print("KINETIC_SOLE_WAVE1_EXPORT", json.dumps(results))


if __name__ == "__main__":
    main()
