extends SceneTree

# Meshy 모델을 눈으로 본다. **고닷이 임포트한 것을 그대로 쓴다** —
# 손으로 obj 를 파싱하지 않는다. 재질도 텍스처도 고닷이 붙인 그대로다.
#
#     godot --script scripts/tools/shot_table.gd
#
# 임포트가 아직이면 먼저 한 번:  godot --headless --import

const SRC := [
	["res://imported_models/balatro-table-hole-3d/balatro-table-hole-3d.glb", "table_real"],
	["res://imported_models/balatro-hole-cap-3d/balatro-hole-cap-3d.glb", "cap_real"],
	["res://imported_models/Dart/Dart.glb", "dart_real"],
]

const VIEWS := {
	"iso": Vector3(1.0, 0.9, 1.0),
	"top": Vector3(0.0, 1.0, 0.02),
}

var busy := false


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_shots()
	return false


# 인스턴스 전체를 감싸는 상자. 자식 메시들의 AABB 를 합친다.
func _aabb(n: Node, acc: AABB, first: bool) -> Array:
	if n is VisualInstance3D:
		var vi := n as VisualInstance3D
		var a: AABB = vi.global_transform * vi.get_aabb()
		acc = a if first else acc.merge(a)
		first = false
	for c in n.get_children():
		var r := _aabb(c, acc, first)
		acc = r[0]
		first = r[1]
	return [acc, first]


func _shots() -> void:
	for pair in SRC:
		for n in root.get_children():
			n.queue_free()
		await process_frame

		var scn: PackedScene = load(pair[0])
		if scn == null:
			print("못 읽음: ", pair[0])
			continue
		var inst: Node = scn.instantiate()
		root.add_child(inst)
		await process_frame

		var res := _aabb(inst, AABB(), true)
		var ab: AABB = res[0]
		var c := ab.get_center()
		var r: float = maxf(ab.size.length() * 0.62, 0.001)

		var lt := DirectionalLight3D.new()
		lt.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
		lt.light_energy = 1.2
		root.add_child(lt)
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.07, 0.06, 0.09)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.55, 0.62)
		env.ambient_light_energy = 0.6
		we.environment = env
		root.add_child(we)

		var cam := Camera3D.new()
		cam.near = r * 0.01
		cam.far = r * 8.0
		root.add_child(cam)
		cam.make_current()
		for vk in VIEWS:
			# 트리에 붙은 뒤에 겨눈다 — 붙기 전 look_at 은 전역 변환이 없어 헛돈다
			cam.global_position = c + (VIEWS[vk] as Vector3).normalized() * r * 1.7
			cam.look_at(c, Vector3.UP)
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(
					"res://shots/%s_%s.png" % [pair[1], vk])
		print("저장: ", pair[1], "  aabb ", ab.size)
	quit()
