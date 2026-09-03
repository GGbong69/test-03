extends SceneTree

# 사탕 모델 다섯을 나란히 찍는다. 아이콘으로 쓸 각도를 고르려는 것이다.
#     godot --script scripts/tools/shot_candy3.gd

const NAMES := ["gummy", "twist", "cane", "pop", "bar"]
var busy := false

func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_go()
	return false

func _go() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.11, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.60, 0.70)
	env.ambient_light_energy = 0.8
	we.environment = env
	root.add_child(we)
	var lt := DirectionalLight3D.new()
	lt.rotation_degrees = Vector3(-46.0, -28.0, 0.0)
	lt.light_energy = 1.4
	root.add_child(lt)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 12.0
	cam.near = 0.05
	cam.far = 60.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 1.6, 8.0)
	cam.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)

	for i in NAMES.size():
		var mesh: Mesh = load("res://assets/candy/%s.obj" % NAMES[i])
		if mesh == null:
			print("못 읽음: ", NAMES[i])
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		# obj 의 mtl 은 pymeshlab 이 자기 것으로 덮어 쓴다(텍스처가 없다).
		# 그림은 코드에서 물린다 — 게임도 같은 길로 간다.
		var mat := StandardMaterial3D.new()
		var tex: Texture2D = load("res://assets/candy/%s.jpg" % NAMES[i])
		if tex != null:
			mat.albedo_texture = tex
		mat.roughness = 0.55
		mi.material_override = mat
		root.add_child(mi)
		var ab := mesh.get_aabb()
		var k := 2.0 / maxf(ab.size.y, 0.001)      # 키를 2 로 맞춘다
		mi.scale = Vector3.ONE * k
		mi.position = Vector3((float(i) - 2.0) * 2.4, -ab.get_center().y * k, 0.0)
		mi.rotation_degrees = Vector3(0.0, -24.0, 0.0)
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("res://shots/candy3d.png")
	print("저장: candy3d.png ", img.get_width(), "x", img.get_height())
	quit()
