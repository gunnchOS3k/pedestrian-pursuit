extends Node3D
## Original native mesh/material production layer. No collision or racing data edits.
## Hand-composed architecture and silhouettes; runtime candidate, not human final art.
var _surfaces: Dictionary = {}
var _materials: Dictionary = {}
var _data: Dictionary
var _points: Array[Vector3] = []
var _center := Vector3.ZERO
var _radius := 60.0
var _ink := Color("263743")
var _trim := Color("cda775")
var _stone := Color("82918c")
var _leaf := Color("346450")
var _accent := Color("67c8c7")
var _night := false
var _theme := ""
var _frame := Transform3D.IDENTITY

func _ready() -> void:
	get_parent().ready.connect(_install, CONNECT_ONE_SHOT)

func _install() -> void:
	var track := get_parent().get_node_or_null("CourseTrack")
	if track == null: return
	_data = get_parent().get("course_data")
	_theme = str(_data.get("theme", ""))
	_night = _theme in ["prism_void","neon_yard","lantern_corridor","mirror_boulevard","afterglow_overpass","signal_storm_yard","aurora_amphitheater"]
	_accent = Color.from_string(str(_data.get("accent_color", "#67c8c7")),_accent)
	for raw in _data.get("path_points",[]):
		var p := Vector3(raw[0],raw[1],raw[2]);_points.append(p);_center += p
	_center /= maxf(_points.size(),1)
	var minimum_y := _points[0].y
	for point in _points: minimum_y=minf(minimum_y,point.y)
	_center.y=minimum_y
	_radius = 0
	for p in _points: _radius = maxf(_radius, Vector2(p.x-_center.x,p.z-_center.z).length())
	_radius += float(_data.get("lane_width",14))*0.5+13
	# Slate, timber, plaster, foliage, luminous trim: shared draw surfaces, original geometry.
	_materials = {"ink":_mat(_ink),"stone":_mat(_stone),"cream":_mat(Color("d7ccae")),"wood":_mat(Color("835e46")),"trim":_mat(_trim,0.35,0.45),"leaf":_mat(_leaf),"leaflight":_mat(Color("6c8b55")),"glass":_mat(Color("3d8d9b"),0.22,0.25),"signal":_mat(_accent,0.3,0.2,true),"water":_mat(Color("286e83"),0.22,0.35),"rock":_mat(Color("585868"))}
	var name_label := track.get_node_or_null("CourseName")
	if name_label: name_label.visible = false
	_grade_lighting(track)
	_surface_treatment(track)
	_compose_world()
	_flush()
	_hud_readability()
	set_meta("asset_status","runtime_integrated_production_candidate")
	set_meta("course_id",_data.get("id"))
	set_meta("collision_nodes_added",0)

func _mat(color: Color, rough := 0.8, metallic := 0.0, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new();m.albedo_color=color;m.roughness=rough;m.metallic=metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=0.35
	return m

func _grade_lighting(track: Node) -> void:
	for child in track.get_children():
		if child is WorldEnvironment:
			var e: Environment = child.environment.duplicate()
			e.ambient_light_energy = 0.34 if _night else 0.29
			e.ambient_light_color = Color("8699ba") if _night else Color("b2c8cb")
			e.fog_density = 0.0012 if _night else 0.0007
			e.fog_light_color = Color("1c2942") if _night else Color("b7c8c4")
			var sky := Sky.new();var sky_mat := ProceduralSkyMaterial.new()
			sky_mat.sky_top_color = Color("10192e") if _night else Color("4e81a4")
			sky_mat.sky_horizon_color = Color("4d3c68") if _night else Color("c1ccbd")
			sky_mat.ground_bottom_color = Color("1d2737")
			sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
			sky_mat.sun_angle_max=12.0;sky.sky_material=sky_mat
			e.sky=sky;e.background_mode=Environment.BG_SKY
			child.environment=e
		elif child is DirectionalLight3D:
			child.light_energy=0.65 if _night else 0.95
			child.light_color=Color("c4d5f5") if _night else Color("fff0cd")
			child.shadow_enabled=true
		elif child is OmniLight3D:
			child.light_energy=minf(child.light_energy,0.65)

func _surface_treatment(track: Node) -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform vec4 road:source_color; varying vec3 world; void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){vec2 cell=floor(world.xz*26.0);float grain=fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);float joints=smoothstep(0.965,0.99,fract(world.x*0.25))*0.035;ALBEDO=road.rgb*(0.92+grain*0.14)-joints;ROUGHNESS=0.83;}"
	var m := ShaderMaterial.new();m.shader=shader
	var base := Color.from_string(str(_data.get("track_color","#37464c")),Color("37464c"))
	m.set_shader_parameter("road",base.darkened(0.37))
	var surface := track.get_node_or_null("CourseSurface")
	if surface: _dress_surface(surface,m)
	# Retain the exact existing hazard/collision silhouettes; cap washed-out materials.
	var scenery := track.get_node_or_null("Scenery")
	if scenery:
		_cap_scenery(scenery)
		_replace_start_and_cascades(scenery)
		_retire_named_placeholder_cubes(scenery)
		if _theme=="cascade_garden":_skin_garden(scenery)

func _dress_surface(node: Node, mat: Material) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			# Only the deck: rails/feature signals retain their distinct original materials.
			if str(child.name)=="TrackVisual":child.material_override=mat
		_dress_surface(child,mat)

func _cap_scenery(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var m: StandardMaterial3D=child.material_override.duplicate()
			m.albedo_color=m.albedo_color.darkened(0.24)
			m.emission_energy_multiplier=0.18
			child.material_override=m
		_cap_scenery(child)

func _compose_world() -> void:
	var id := str(_data.get("id"))
	# Continuous stepped terrain closes the floating board; no collision added.
	_loft(_center+Vector3(0,-3.5,0),[[0,_radius*1.25],[2,_radius*1.17],[3,_radius*1.08]],24,"rock",0.16)
	var ground_mat := "ink"
	if _theme in ["cascade_garden","windy_ranch","origami_orchard","cascade_colossus"]:ground_mat="leaflight"
	elif _theme in ["mesa_mirage","ember_fortress","ridge_cloud","cliffside_draft"]:ground_mat="rock"
	elif "harbor" in _theme or "tidal" in _theme or "saltline" in _theme or "seaglass" in _theme:ground_mat="water"
	elif "foyer" in _theme or "gallery" in _theme or "stack" in _theme or "vault" in _theme:ground_mat="cream"
	_loft(_center+Vector3(0,-0.7,0),[[0,_radius*1.1],[0.4,_radius*1.08]],32,ground_mat,0.03)
	# Curated skyline placements are outside the complete lane envelope.
	for i in range(12):
		var a:=TAU*float(i)/12.0;var p:=_center+Vector3(cos(a)*(_radius+7),0,sin(a)*(_radius+7))
		match _theme:
			"cascade_garden","cascade_colossus","windy_ranch","origami_orchard": _tree(p,7.0+float(i%3)*2.2,i)
			"ridge_cloud","mesa_mirage","cliffside_draft","ember_fortress","seaglass_switchback": _rock_spire(p,9.0+float(i%4)*4.0,i)
			_: _building(p,4.2,10.0+float(i%4)*4.0,4.5,i)
	var front := _points[1]-_points[0];front.y=0;front=front.normalized()
	var right:=front.cross(Vector3.UP)
	var hero := _center + front*(_radius+5)
	# Every championship course gets a distinct constructed landmark, not a palette swap.
	match id:
		"verdant_cascade_circuit": _aqueduct(hero,3);_garden(_center-right*(_radius+3))
		"cloverwind_ranch": _barn(hero);_windmill(_center-right*(_radius+4))
		"prism_apex": _orbit(hero,14);_prism(hero+right*15,11)
		"emberkeep_gauntlet": _keep(hero);_furnace(hero+right*18)
		"tideglass_harbor": _lighthouse(hero);_canopy(hero-right*16,3)
		"neon_switchyard": _gantry(hero,3);_freight(hero-right*20)
		"cloudstep_ridge": _windmill(hero);_rope_shelter(hero+right*15)
		"mirage_mesa": _rock_arch(hero);_mesa(hero-right*20)
		"sneaker_city_sprintway": _retail(hero);_sculpture(hero-right*17)
		"metro_pulse_loop": _station(hero);_clock(hero+right*15)
		"crosswalk_canyon": _clock(hero);_retail(hero-right*18)
		"transit_spiral": _spiral(hero);_station(hero-right*19)
		"saltline_boardwalk": _pier(hero);_canopy(hero-right*18,4)
		"cliffside_draft": _cliff_observatory(hero);_windmill(hero-right*17)
		"tidal_bridge_run": _cable_tower(hero);_lighthouse(hero-right*18)
		"seaglass_switchback": _glass_shards(hero);_rock_arch(hero-right*18)
		"lantern_corridor": _lantern_market(hero);_canopy(hero-right*17,4)
		"mirror_boulevard": _mirror_palace(hero);_sculpture(hero-right*18)
		"afterglow_overpass": _flyover(hero);_clock(hero-right*17)
		"signal_storm_yard": _signal_array(hero);_freight(hero-right*18)
		"rooftop_ribbon": _roof_garden(hero);_canopy(hero-right*17,2)
		"skybridge_sprint": _cable_tower(hero);_flyover(hero-right*22)
		"antenna_ascent": _antenna(hero);_signal_array(hero-right*18)
		"cloud_deck_circuit": _observatory(hero);_rope_shelter(hero-right*18)
		"marble_foyer_loop": _colonnade(hero);_sculpture(hero-right*17)
		"stack_corridor": _library(hero);_clock(hero-right*18)
		"gallery_grand_oval": _gallery(hero);_sculpture(hero-right*18)
		"vault_gate_gauntlet": _vault(hero);_colonnade(hero-right*20)
		"cascade_colossus": _aqueduct(hero,5);_cliff_observatory(hero-right*24)
		"aurora_amphitheater": _amphitheater(hero);_orbit(hero-right*23,9)
		"origami_orchard": _paper_grove(hero);_canopy(hero-right*20,4)
		"horizon_crown_finale": _crown(hero);_amphitheater(hero-right*25)
	# Grounded trackside direction fins sit beyond rail clearance, never obscure checkpoints.
	for i in range(_points.size()):
		var p:=_points[i];var t:=(_points[(i+1)%_points.size()]-p).normalized();var r:=t.cross(Vector3.UP).normalized()
		var edge:=p+r*(float(_data.get("lane_width",14))*0.5+3.4)
		# A fin must clear every segment, including an adjacent returning chord.
		if not _clear_of_lanes(edge,0.9):continue
		_loft(edge,[[0,0.35],[1.5,0.28],[1.8,0.12]],6,"ink")
		_block(edge+Vector3(0,1.45,0),Vector3(0.18,0.28,0.8),"signal")

func _tree(p: Vector3,h: float,i: int) -> void:
	_loft(p,[[0,0.65],[h*.55,0.28]],7,"wood",0.05)
	for layer in range(3):
		_loft(p+Vector3(0,h*.32+layer*h*.19,0),[[0,h*.22],[h*.16,h*.25],[h*.28,0.15]],7,"leaf" if (i+layer)%2==0 else "leaflight",0.17)
	_tube([p+Vector3(0,h*.25,0),p+Vector3(1,h*.38,0),p+Vector3(2,h*.5,0)],0.2,"wood")
func _rock_spire(p:Vector3,h:float,i:int)->void:
	_loft(p,[[0,3.8],[h*.25,3.3],[h*.7,2.0],[h,0.6]],7,"rock" if i%2==0 else "stone",0.25)
func _building(p:Vector3,w:float,h:float,d:float,i:int)->void:
	_block(p+Vector3(0,h*.5,0),Vector3(w,h,d),"ink" if i%2 else "stone")
	_block(p+Vector3(0,h,0),Vector3(w+0.4,0.35,d+0.4),"cream")
	for floor_i in range(int(h/2.3)):
		for col in [-1,1]:
			_block(p+Vector3(col*w*.25,2+floor_i*2.3,d*.505),Vector3(w*.24,1.1,0.04),"signal" if _night and floor_i%3==0 else "glass")
		_block(p+Vector3(-w*.505,2+floor_i*2.3,0),Vector3(.04,1.0,d*.55),"glass")
func _arch(p:Vector3,w:float,h:float,depth:float,mat:String="cream")->void:
	var path:Array[Vector3]=[]
	for i in range(19):
		var a:=PI*float(i)/18.0
		path.append(p+Vector3(cos(a)*w*.5,h*.42+sin(a)*h*.58,0))
	_tube(path,depth,mat)
	for side in [-1,1]:_block(p+Vector3(side*w*.5,h*.21,0),Vector3(depth*2,h*.42,depth*2),mat)
func _roof(p:Vector3,w:float,d:float,h:float,mat:String="wood")->void:
	_quad(p+Vector3(-w/2,0,-d/2),p+Vector3(0,h,-d/2),p+Vector3(0,h,d/2),p+Vector3(-w/2,0,d/2),mat)
	_quad(p+Vector3(0,h,-d/2),p+Vector3(w/2,0,-d/2),p+Vector3(w/2,0,d/2),p+Vector3(0,h,d/2),mat)
func _aqueduct(p:Vector3,count:int)->void:
	for i in range(count):
		var q:=p+Vector3((i-(count-1)*.5)*8,0,0);_arch(q,6.5,12,0.7,"stone");_block(q+Vector3(0,12.2,0),Vector3(8.2,.65,3),"cream")
		_quad(q+Vector3(-2.6,11,-.5),q+Vector3(2.6,11,-.5),q+Vector3(2.6,0,-.5),q+Vector3(-2.6,0,-.5),"water")
func _garden(p:Vector3)->void:
	for i in range(3):
		var q:=p+Vector3(i*6,0,0);_loft(q,[[0,3],[1,3],[1.3,2.7]],16,"cream");_tree(q+Vector3(0,1.3,0),5,i)
func _barn(p:Vector3)->void:
	_block(p+Vector3(0,4,0),Vector3(14,8,10),"wood");_roof(p+Vector3(0,8,0),16,12,5,"ink")
	_arch(p+Vector3(0,0,5.1),5,6,.35);_block(p+Vector3(0,4,5.15),Vector3(3,4,.1),"ink")
	for x in [-5.5,5.5]:_block(p+Vector3(x,4,5.2),Vector3(.18,8,.2),"cream")
func _windmill(p:Vector3)->void:
	_loft(p,[[0,2.4],[11,1.3],[14,.9]],12,"cream");_roof(p+Vector3(0,14,0),4,4,2,"ink")
	var hub:=p+Vector3(0,12,1.6)
	for i in range(4):
		var a:=i*PI*.5+.35;var direction:=Vector3(cos(a),sin(a),0)
		_tube([hub,hub+direction*6],.17,"wood")
		var side:=Vector3(-sin(a),cos(a),0)
		_quad(hub+direction*2,hub+direction*6,hub+direction*6+side*1.4,hub+direction*2+side*1.4,"cream")
func _orbit(p:Vector3,r:float)->void:
	for tilt in [0.0,0.9]:
		var path:Array[Vector3]=[]
		for i in range(49):
			var a:=TAU*i/48.0;path.append(p+Vector3(cos(a)*r,sin(a)*r+16,sin(a)*r*tilt))
		_tube(path,.4,"signal")
	_loft(p,[[0,3],[10,1.4],[19,0.6]],8,"ink")
func _prism(p:Vector3,h:float)->void:
	_loft(p,[[0,2.8],[h*.65,3.5],[h,0]],5,"glass")
func _keep(p:Vector3)->void:
	for x in [-8,8]:
		_loft(p+Vector3(x,0,0),[[0,3.5],[15,2.9],[16,3.4]],10,"rock")
		for i in range(8):_block(p+Vector3(x+cos(i*TAU/8)*3,16.5,sin(i*TAU/8)*3),Vector3(1,1.5,1),"ink")
	_arch(p,10,12,.9,"stone");_block(p+Vector3(0,13,0),Vector3(14,3,4),"rock")
func _furnace(p:Vector3)->void:
	_loft(p,[[0,4],[6,3.4],[10,2],[18,1.4]],10,"ink")
	for y in [3,6,9]:_loft(p+Vector3(0,y,0),[[0,3.5],[.3,3.5]],12,"signal")
func _lighthouse(p:Vector3)->void:
	_loft(p,[[0,3],[14,1.8],[15,2.6],[18,2.6]],14,"cream")
	_loft(p+Vector3(0,15.1,0),[[0,2.65],[2.4,2.65]],14,"glass")
	_roof(p+Vector3(0,18,0),7,7,2,"ink")
	for y in [5,10,14]:_loft(p+Vector3(0,y,0),[[0,2.6-y*.04],[.5,2.6-y*.04]],14,"trim")
func _canopy(p:Vector3,count:int)->void:
	for i in range(count):
		var q:=p+Vector3(i*5,0,0);_roof(q+Vector3(0,5,0),6,9,2.8,"cream")
		for z in [-3.8,3.8]:_loft(q+Vector3(0,0,z),[[0,.15],[5,.15]],6,"wood")
func _gantry(p:Vector3,count:int)->void:
	for i in range(count):
		var q:=p+Vector3(0,0,i*5);_arch(q,18,14,.3,"trim")
		for x in [-6,-3,0,3,6]:_block(q+Vector3(x,12,0),Vector3(.75,1.1,.5),"signal")
func _freight(p:Vector3)->void:
	for i in range(4):
		var q:=p+Vector3(i*5,2,0);_block(q,Vector3(4.5,4,10),"wood" if i%2==0 else "ink")
		for x in [-1.5,-.75,0,.75,1.5]:_block(q+Vector3(x,0,5.02),Vector3(.08,3.5,.08),"trim")
func _rope_shelter(p:Vector3)->void:
	_canopy(p,2)
	for i in range(5):_tube([p+Vector3(i*2-4,0,-4),p+Vector3(i*2-4,6,0),p+Vector3(i*2-4,0,4)],.08,"trim")
func _rock_arch(p:Vector3)->void:
	_arch(p,18,12,2.0,"rock")
	for side in [-1,1]:_rock_spire(p+Vector3(side*11,0,2),13,int(side))
func _mesa(p:Vector3)->void:
	_loft(p,[[0,12],[4,11.5],[4.5,13],[8,12],[9,8]],9,"stone",.13)
func _retail(p:Vector3)->void:
	for i in range(4):
		var q:=p+Vector3((i-1.5)*7,0,0);_building(q,6,6+i%2*2,8,i);_roof(q+Vector3(0,4,4.5),7,3,1,"trim")
func _sculpture(p:Vector3)->void:
	_loft(p,[[0,3],[1.5,3],[1.7,2.6]],12,"cream")
	var path:Array[Vector3]=[]
	for i in range(33):
		var t:=i/32.0;path.append(p+Vector3(sin(t*TAU)*3,2+t*10,cos(t*TAU)*3))
	_tube(path,.7,"trim")
func _station(p:Vector3)->void:
	_building(p,18,7,10,1);_arch(p+Vector3(0,0,5.1),10,7,.45,"trim");_roof(p+Vector3(0,7,0),22,14,4,"ink")
func _clock(p:Vector3)->void:
	_block(p+Vector3(0,9,0),Vector3(5,18,5),"cream");_roof(p+Vector3(0,18,0),7,7,4,"ink")
	_loft(p+Vector3(0,14,2.6),[[0,2.2],[.15,2.2]],16,"ink")
	_tube([p+Vector3(-1,14,2.8),p+Vector3(0,14,2.8),p+Vector3(0,15.5,2.8)],.13,"trim")
func _spiral(p:Vector3)->void:
	var path:Array[Vector3]=[]
	for i in range(65):
		var t:=i/64.0;path.append(p+Vector3(cos(t*TAU*2)*7,t*24,sin(t*TAU*2)*7))
	_tube(path,1.0,"cream");_loft(p,[[0,2],[25,1.2]],10,"glass")
func _pier(p:Vector3)->void:
	_block(p+Vector3(0,4,0),Vector3(27,.6,12),"wood");_canopy(p+Vector3(-8,4,0),4)
	for x in [-12,-6,0,6,12]:
		for z in [-5,5]:_loft(p+Vector3(x,-1,z),[[0,.35],[5,.35]],8,"wood")
func _cliff_observatory(p:Vector3)->void:
	_rock_spire(p,12,0);_observatory(p+Vector3(0,12,0))
func _cable_tower(p:Vector3)->void:
	for x in [-8,8]:_block(p+Vector3(x,10,0),Vector3(1.6,20,1.6),"cream")
	_arch(p+Vector3(0,15,0),16,6,.4,"trim")
	for x in [-7,-4,0,4,7]:_tube([p+Vector3(-8,19,0),p+Vector3(x,6,12)],.08,"trim")
func _glass_shards(p:Vector3)->void:
	for i in range(7):_prism(p+Vector3((i-3)*4,0,sin(i)*4),7+float(i%3)*4)
func _lantern_market(p:Vector3)->void:
	_retail(p)
	_tube([p+Vector3(-16,9,0),p+Vector3(0,7,0),p+Vector3(16,9,0)],.05,"ink")
	for i in range(9):_loft(p+Vector3((i-4)*3.5,6.5+absf(i-4)*.3,0),[[0,.7],[1.6,.9],[2.1,.55]],8,"signal")
func _mirror_palace(p:Vector3)->void:
	for x in [-10,10]:
		_building(p+Vector3(x,0,0),7,22,10,0)
		for j in range(4):_block(p+Vector3(x,3+j*5,5.02),Vector3(6,3.8,.1),"glass")
	_arch(p+Vector3(0,16,0),20,7,.5,"trim")
func _flyover(p:Vector3)->void:
	_arch(p,30,11,.8,"stone");_block(p+Vector3(0,12,0),Vector3(36,1,7),"ink")
	for x in [-16,-8,0,8,16]:_block(p+Vector3(x,13,3.3),Vector3(.2,1,.2),"signal")
func _signal_array(p:Vector3)->void:
	for i in range(4):
		var q:=p+Vector3((i-1.5)*5,0,0);_loft(q,[[0,.35],[15,.25]],8,"ink")
		for j in range(3):_loft(q+Vector3(0,10+j*2,0),[[0,.8],[.6,.8]],8,"signal")
func _roof_garden(p:Vector3)->void:
	_building(p,24,13,18,0);_garden(p+Vector3(-6,13,0));_canopy(p+Vector3(-7,14,3),3)
func _antenna(p:Vector3)->void:
	for y in range(0,24,4):
		for side in [-1,1]:_tube([p+Vector3(side*2,y,0),p+Vector3(-side*2,y+4,0)],.12,"trim")
	_loft(p,[[0,.35],[33,.2]],8,"ink");_orbit(p+Vector3(0,9,0),5)
func _observatory(p:Vector3)->void:
	_loft(p,[[0,7],[6,7],[8,6.6],[11,5],[13,2],[13.5,0]],24,"glass")
	_block(p+Vector3(0,6,0),Vector3(16,.5,16),"cream");_arch(p+Vector3(0,0,7),4,5,.3,"trim")
func _colonnade(p:Vector3)->void:
	for i in range(5):_arch(p+Vector3((i-2)*7,0,0),6,12,.65,"cream")
	_block(p+Vector3(0,12.7,0),Vector3(36,1,6),"stone")
func _library(p:Vector3)->void:
	for i in range(5):
		var q:=p+Vector3((i-2)*6,0,0);_block(q+Vector3(0,7,0),Vector3(5,14,7),"wood")
		for y in range(2,14,2):
			_block(q+Vector3(0,y,3.6),Vector3(4.6,.2,.3),"cream")
			for j in range(6):_block(q+Vector3((j-2.5)*.65,y+.65,3.6),Vector3(.4,1.1,.5),"ink" if j%2 else "trim")
func _gallery(p:Vector3)->void:
	_colonnade(p);_roof(p+Vector3(0,14,0),38,16,4,"glass")
	for i in [-1,0,1]:_sculpture(p+Vector3(i*9,0,5))
func _vault(p:Vector3)->void:
	_block(p+Vector3(0,7,0),Vector3(18,14,8),"stone");_arch(p+Vector3(0,0,4.2),10,11,.65,"trim")
	for i in range(8):
		var a:=TAU*i/8;_block(p+Vector3(cos(a)*4.1,6+sin(a)*4.1,4.3),Vector3(.55,.55,.4),"ink")
func _amphitheater(p:Vector3)->void:
	for row in range(4):
		var path:Array[Vector3]=[]
		for i in range(25):
			var a:=PI+PI*i/24;path.append(p+Vector3(cos(a)*(10+row*2),row*1.3,sin(a)*(10+row*2)))
		_tube(path,.7,"cream")
	_arch(p+Vector3(0,0,2),18,12,.4,"signal")
func _paper_grove(p:Vector3)->void:
	for i in range(7):
		var q:=p+Vector3((i-3)*5,0,sin(i)*4);_loft(q,[[0,.4],[6,.2]],5,"wood")
		for j in range(3):_loft(q+Vector3(0,4+j*2,0),[[0,4-j*.7],[3,0]],4,"cream" if i%2 else "leaflight")
func _crown(p:Vector3)->void:
	for side in [-1,1]:
		var q:=p+Vector3(side*10,0,0);_arch(q,16,18,.8,"trim")
		for i in range(5):_prism(q+Vector3((i-2)*3,16+absf(i-2),0),4)

func _tri(a:Vector3,b:Vector3,c:Vector3,mat:String)->void:
	if not _surfaces.has(mat):_surfaces[mat]=SurfaceTool.new();_surfaces[mat].begin(Mesh.PRIMITIVE_TRIANGLES)
	a=_frame*a;b=_frame*b;c=_frame*c
	var st:SurfaceTool=_surfaces[mat];var n:Vector3=(b-a).cross(c-a).normalized()
	for v in [a,b,c]:st.set_normal(n);st.add_vertex(v)
func _quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,mat:String)->void:
	_tri(a,b,c,mat);_tri(a,c,d,mat)
func _block(p:Vector3,s:Vector3,mat:String)->void:
	var a:=p-s*.5;var b:=p+s*.5
	_quad(Vector3(a.x,a.y,a.z),Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,a.y,a.z),mat)
	_quad(Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,a.y,b.z),mat)
	_quad(Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,b.y,a.z),Vector3(a.x,a.y,a.z),mat)
	_quad(Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(b.x,a.y,b.z),mat)
	_quad(Vector3(a.x,b.y,a.z),Vector3(a.x,b.y,b.z),Vector3(b.x,b.y,b.z),Vector3(b.x,b.y,a.z),mat)
	_quad(Vector3(a.x,a.y,b.z),Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),mat)
func _loft(p:Vector3,rings:Array,sides:int,mat:String,irregular:=0.0)->void:
	for j in range(rings.size()-1):
		for i in range(sides):
			var a:=TAU*i/sides;var b:=TAU*(i+1)/sides
			var r0:float=rings[j][1];var r1:float=rings[j+1][1]
			var ia:=1+sin(i*5.7)*irregular;var ib:=1+sin((i+1)*5.7)*irregular
			_quad(p+Vector3(cos(a)*r0*ia,rings[j][0],sin(a)*r0*ia),p+Vector3(cos(b)*r0*ib,rings[j][0],sin(b)*r0*ib),p+Vector3(cos(b)*r1*ib,rings[j+1][0],sin(b)*r1*ib),p+Vector3(cos(a)*r1*ia,rings[j+1][0],sin(a)*r1*ia),mat)
	for i in range(sides):
		var a:=TAU*i/sides;var b:=TAU*(i+1)/sides;var last:Array=rings[-1]
		_tri(p+Vector3(0,last[0],0),p+Vector3(cos(a)*last[1],last[0],sin(a)*last[1]),p+Vector3(cos(b)*last[1],last[0],sin(b)*last[1]),mat)
func _tube(path:Array[Vector3],r:float,mat:String)->void:
	for j in range(path.size()-1):
		var tangent:Vector3=(path[j+1]-path[j]).normalized();var u:=tangent.cross(Vector3.UP).normalized()
		if u.length()<.01:u=Vector3.RIGHT
		var v:=tangent.cross(u).normalized()
		for i in range(6):
			var a:=TAU*i/6.0;var b:=TAU*(i+1)/6.0
			_quad(path[j]+(u*cos(a)+v*sin(a))*r,path[j]+(u*cos(b)+v*sin(b))*r,path[j+1]+(u*cos(b)+v*sin(b))*r,path[j+1]+(u*cos(a)+v*sin(a))*r,mat)
func _flush()->void:
	var mesh:=ArrayMesh.new()
	for key in _surfaces:
		var st:SurfaceTool=_surfaces[key];st.index();st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count()-1,_materials[key])
	var asset_path := "res://assets/art/course_worlds/%s.res" % str(_data.get("id"))
	mesh.set_meta("production_status","runtime_integrated_candidate")
	mesh.set_meta("source_course",_data.get("id"))
	mesh.set_meta("human_approved",false)
	if OS.get_cmdline_user_args().has("--bake-course-art"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/art/course_worlds"))
		var error := ResourceSaver.save(mesh,asset_path)
		if error != OK:push_error("Course art save failed: %s (%d)" % [asset_path,error])
	elif FileAccess.file_exists(asset_path):
		var authored := load(asset_path) as ArrayMesh
		if authored != null:mesh=authored
	var instance:=MeshInstance3D.new();instance.name="AuthoredCourseWorld";instance.mesh=mesh
	instance.set_meta("source_asset",asset_path)
	add_child(instance)

func _replace_start_and_cascades(scenery:Node3D)->void:
	var start:=_points[0]
	for child in scenery.get_children():
		if not child is MeshInstance3D:continue
		if child.mesh is BoxMesh:
			var size:Vector3=child.mesh.size;var pos:Vector3=child.position-start
			var beam:=size.x>=8.0 and size.y<1.0 and absf(pos.z)<3.0 and absf(pos.x)<2.0 and pos.y>4.0
			var pier:=size.y>=5.0 and size.x<=2.0 and absf(pos.z)<3.0 and absf(pos.x)<=14.0
			if beam or pier:child.hide()
		if child.mesh is CylinderMesh and _theme=="cascade_garden":
			var h:float=child.mesh.height;var r:float=child.mesh.top_radius
			if h>6 and r>2 and r<3:
				child.hide()
				var base:Vector3=_safe_scenery_position(child.position-Vector3(0,h*.5,0),r*1.5)
				_loft(base,[[0,r*1.05],[h*.25,r],[h*.7,r*.85],[h,r*.9]],9,"rock",.13)
				_quad(base+Vector3(-r*.55,h,r*.95),base+Vector3(r*.55,h,r*.95),base+Vector3(r*.68,0,r*.95),base+Vector3(-r*.68,0,r*.95),"water")
	var direction:=_points[1]-start;direction.y=0;direction=direction.normalized()
	var right:=direction.cross(Vector3.UP).normalized()
	var half_span:=float(_data.get("lane_width",14))*.5+2
	var gate_origin:=start
	var gate_clear:=false
	for shift in [0.0,3.0,6.0]:
		for extra in [0.0,2.0,4.0,6.0,9.0,12.0,16.0]:
			var span:=float(_data.get("lane_width",14))*.5+2+float(extra)
			var origin:=start+direction*float(shift)
			if _clear_of_lanes(origin-right*span,1.5) and _clear_of_lanes(origin+right*span,1.5):
				half_span=span;gate_origin=origin;gate_clear=true;break
		if gate_clear:break
	# The physical start/checkpoint stays unchanged. A decorative welcome arch
	# may move down the opening straight to keep every return chord unobstructed.
	if gate_clear:
		_frame=Transform3D(Basis.looking_at(direction,Vector3.UP),gate_origin)
		_arch(Vector3.ZERO,half_span*2,7.5,.35,"cream")
		for side in [-1,1]:
			_block(Vector3(side*half_span,3.2,0),Vector3(.9,6.4,.9),"ink")
			_quad(Vector3(side*5,7.2,0),Vector3(side*5,5.6,0),Vector3(side*6,6.2,0),Vector3(side*6,7.2,0),"signal")
	_frame=Transform3D.IDENTITY

func _skin_garden(node:Node)->void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			var h:float=child.mesh.height;var r:float=child.mesh.top_radius
			if h>=5 and r>.3 and r<3 and child.visible:
				child.hide();var base:Vector3=_safe_scenery_position(to_local(child.global_position)-Vector3(0,h*.5,0),r*1.5)
				_loft(base,[[0,r*1.2],[h*.3,r*1.1],[h*.65,r*.9],[h,r]],9,"rock",.13)
				_quad(base+Vector3(r*.98,h,-r*.6),base+Vector3(r*.98,h,r*.6),base+Vector3(r*.98,0,r*.6),base+Vector3(r*.98,0,-r*.6),"water")
		if child is MeshInstance3D and child.mesh is SphereMesh:
			var r:float=child.mesh.radius
			if r>1.4:
				child.hide();var base:Vector3=_safe_scenery_position(to_local(child.global_position)-Vector3(0,r*.7,0),r*1.15)
				_loft(base,[[0,r*.4],[r*.35,r],[r*1.1,r*.85],[r*1.6,0.12]],9,"leaflight",.13)
		_skin_garden(child)

func _retire_named_placeholder_cubes(node:Node)->void:
	# The old named-prop helper uses a bare2.4m cube as a marker, without a collider.
	# Actual course-specific architecture is composed above; retire only that exact marker.
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and not child.get_parent() is CollisionObject3D:
			var size:Vector3=child.mesh.size
			var p:Vector3=child.position
			if size.is_equal_approx(Vector3(2.4,2.4,2.4)) and p.is_equal_approx(Vector3(0,1.2,0)):
				var has_collision:=false
				for sibling in child.get_parent().get_children():
					if sibling is CollisionObject3D or sibling is CollisionShape3D:has_collision=true
				if not has_collision:
					child.hide()
					child.set_meta("replaced_placeholder",true)
		_retire_named_placeholder_cubes(child)

func _hud_readability()->void:
	# A noninteractive scrim keeps existing race labels readable across day/night worlds.
	var layer:=CanvasLayer.new();layer.name="RaceLabelContrast";layer.layer=0
	var plate:=ColorRect.new();plate.name="HeaderScrim"
	plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	plate.offset_bottom=205.0
	plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; void fragment(){COLOR=vec4(0.015,0.025,0.045,0.82*(1.0-smoothstep(0.25,1.0,UV.y)));}"
	var mat:=ShaderMaterial.new();mat.shader=shader;plate.material=mat
	layer.add_child(plate);add_child(layer)

func _nearest_lane_flat(point:Vector3)->Dictionary:
	var distance:=INF
	var near:=Vector3.ZERO
	for i in range(_points.size()):
		var a:=_points[i];var b:=_points[(i+1)%_points.size()]
		var ab:=Vector2(b.x-a.x,b.z-a.z)
		var t:=clampf(Vector2(point.x-a.x,point.z-a.z).dot(ab)/maxf(ab.length_squared(),.001),0,1)
		var candidate:=a.lerp(b,t)
		var d:=Vector2(point.x-candidate.x,point.z-candidate.z).length()
		if d<distance:distance=d;near=candidate
	return {"distance":distance,"point":near}

func _clear_of_lanes(point:Vector3,radius:float)->bool:
	return float(_nearest_lane_flat(point).distance)>=float(_data.get("lane_width",14))*.5+radius+.5

func _safe_scenery_position(point:Vector3,radius:float)->Vector3:
	var result:=point
	var required:=float(_data.get("lane_width",14))*.5+radius+.5
	for attempt in range(16):
		var lane:=_nearest_lane_flat(result)
		if float(lane.distance)>=required:return result
		var away:Vector3=result-lane.point;away.y=0
		if away.length_squared()<.001:away=result-_center;away.y=0
		if away.length_squared()<.001:away=Vector3.RIGHT
		result+=away.normalized()*(required-float(lane.distance)+.6)
	# Dense switchbacks can leave no infield pocket; move the whole decoration
	# outside the complete circuit instead of clipping its mesh or hiding a failure.
	var radial:=point-_center;radial.y=0
	if radial.length_squared()<.001:radial=Vector3.RIGHT
	result=_center+radial.normalized()*(_radius+radius+8)
	result.y=point.y
	return result
