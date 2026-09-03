extends SceneTree

# 줄인 테이블·덮개를 눈으로 본다. 구멍이 살아남았는지 보려는 것뿐이다.
#
#     godot --script scripts/tools/shot_table.gd

const SRC := [
	["res://imported_models/balatro-table-hole-3d/table.obj", "table.png"],
	["res://imported_models/balatro-hole-cap-3d/cap.obj", "cap.png"],
]

var i := 0
var busy := false


func _initialize() -> void:
	pass


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_shots()
	return false


# 임포트를 안 거치고 obj 를 바로 읽는다. 미리보기용이라 이게 빠르다.
func _obj(path: String) -> ArrayMesh:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	while not f.eof_reached():
		var p := f.get_line().split(" ", false)
		if p.size() < 4:
			continue
		if p[0] == "v":
			vs.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif p[0] == "vn":
			ns.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif p[0] == "f":
			for k in 3:
				var t := p[1 + k].split("/")
				ov.append(vs[int(t[0]) - 1])
				if t.size() > 2 and t[2] != "" and ns.size() > 0:
					on.append(ns[int(t[2]) - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in ov.size():
		st.add_vertex(ov[k])
	st.generate_normals()
	return st.commit()


func _shots() -> void:
	for pair in SRC:
		for n in root.get_children():
			n.queue_free()
		await process_frame
		var mesh: Mesh = _obj(pair[0])
		if mesh == null:
			print("못 읽음: ", pair[0])
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.20, 0.42, 0.28)
		mat.roughness = 0.9
		mi.material_override = mat
		root.add_child(mi)

		var ab: AABB = mesh.get_aabb()
		var c := ab.get_center()
		var r: float = maxf(ab.size.length() * 0.62, 0.001)
		var cam := Camera3D.new()
		# 상점과 비슷한 눈높이 — 위에서 비스듬히 내려다본다.
		cam.near = r * 0.01
		cam.far = r * 8.0
		root.add_child(cam)
		# 트리에 붙은 뒤에 겨눈다 — 붙기 전 look_at 은 전역 변환이 없어 헛돈다
		cam.make_current()

		var lt := DirectionalLight3D.new()
		lt.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
		root.add_child(lt)
		var amb := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.07, 0.06, 0.09)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.5, 0.6)
		env.ambient_light_energy = 0.5
		amb.environment = env
		root.add_child(amb)

		var views := {"iso": Vector3(1.0, 1.0, 1.0)}
		for vk in views:
			cam.global_position = c + (views[vk] as Vector3).normalized() * r * 1.6
			cam.look_at(c, Vector3.UP)
			await process_frame
			await process_frame
			var img := root.get_texture().get_image()
			img.save_png("res://shots/%s_%s.png" % [pair[1].get_basename(), vk])
		print("저장: ", pair[1], "  면 ", mesh.get_faces().size() / 3, "  aabb ", ab.size)
	quit()
