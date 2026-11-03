extends MeshInstance3D
## Original open relay core. Cosmetic mesh/pose only; the Area and grant logic remain unchanged.
var _phase := 0.0
var _motion := true
func _ready() -> void:
	var access:=get_tree().root.get_node_or_null("AccessibilitySettings")
	if access and access.has_method("camera_shake_allowed"):_motion=access.camera_shake_allowed()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cyan:=Color("6ed6de");var gold:=Color("e5b95e");var ivory:=Color("e4e9da")
	for ring in range(2):
		var pts:Array[Vector3]=[]
		for i in range(25):
			var a:=TAU*i/24.0
			pts.append(Vector3(cos(a)*.65,sin(a)*.65+.75,(ring-.5)*.38))
		for i in range(24):_bar(st,pts[i],pts[i+1],.055,cyan if ring==0 else gold)
	for side in [-1,1]:
		for y in [0.15,1.35]:_bar(st,Vector3(side*.45,y,-.19),Vector3(side*.45,y,.19),.045,ivory)
	for z in [-.23,.23]:
		_bar(st,Vector3(-.28,.55,z),Vector3(.08,.95,z),.065,ivory)
		_bar(st,Vector3(.08,.95,z),Vector3(.36,.65,z),.065,ivory)
	mesh=st.commit()
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.metallic=.45;material.roughness=.35
	material.emission_enabled=true;material.emission=Color(.08,.2,.21);material.emission_energy_multiplier=.3
	material_override=material
	set_meta("art_status","original_runtime_candidate")
func _process(delta:float)->void:
	var access:=get_tree().root.get_node_or_null("AccessibilitySettings")
	if access and access.has_method("camera_shake_allowed"):_motion=access.camera_shake_allowed()
	if not _motion:
		rotation.y=0.0;position.y=0.0
		return
	_phase+=delta;rotation.y=_phase*.65;position.y=sin(_phase*1.8)*.08
func _bar(st:SurfaceTool,a:Vector3,b:Vector3,r:float,color:Color)->void:
	var tangent:Vector3=(b-a).normalized();var u:=tangent.cross(Vector3.UP).normalized()
	if u.length()<.1:u=Vector3.RIGHT
	var v:=tangent.cross(u).normalized()
	for i in range(6):
		var x:=TAU*i/6;var y:=TAU*(i+1)/6
		var p:=a+(u*cos(x)+v*sin(x))*r;var q:=a+(u*cos(y)+v*sin(y))*r
		var s:=b+(u*cos(y)+v*sin(y))*r;var t:=b+(u*cos(x)+v*sin(x))*r
		var n:Vector3=(q-p).cross(s-p).normalized()
		for point in [p,q,s,p,s,t]:st.set_color(color);st.set_normal(n);st.add_vertex(point)
