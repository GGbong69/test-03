extends SceneTree
# 히스토리에서 되살린 3D 상인을 들여다본다. 쓸 물건인지 눈으로 먼저 본다.
#   godot --path . --quit-after 1200 --script scripts/tools/peek_dealer.gd
var busy := false

func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false

func _run() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 굽는다"); quit(0); return
	var sc: PackedScene = load("res://assets/dealer.glb")
	if sc == null:
		print("  못 읽었다 — 임포트가 아직 안 됐을 수 있다"); quit(1); return
	var nd := sc.instantiate()
	print("뿌리: %s (%s)" % [nd.name, nd.get_class()])
	var stack := [nd]
	var meshes := 0
	var tris := 0
	var bones := 0
	var anims := PackedStringArray()
	var ab := AABB()
	var first := true
	while not stack.is_empty():
		var n2 = stack.pop_back()
		for c in n2.get_children():
			stack.append(c)
		if n2 is MeshInstance3D:
			meshes += 1
			var m: Mesh = n2.mesh
			if m != null:
				for si in m.get_surface_count():
					tris += m.surface_get_array_len(si) / 3
				if first:
					ab = m.get_aabb()
					first = false
				else:
					ab = ab.merge(m.get_aabb())
		if n2 is Skeleton3D:
			bones += n2.get_bone_count()
		if n2 is AnimationPlayer:
			for a in n2.get_animation_list():
				anims.append(a)
	print("메시 %d · 삼각형 %d · 뼈 %d" % [meshes, tris, bones])
	print("애니메이션: %s" % ("없다" if anims.is_empty() else ", ".join(anims)))
	print("크기: %.2f x %.2f x %.2f" % [ab.size.x, ab.size.y, ab.size.z])

	# 한 장 구워 본다 — 상인 무대와 비슷한 각(−18°)으로
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 360)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(nd)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var big: float = maxf(maxf(ab.size.x, ab.size.y), 0.001)
	cam.size = big * 1.2
	cam.near = 0.01
	cam.far = big * 20.0
	vp.add_child(cam)
	var mid := ab.get_center()
	cam.position = mid + Vector3(0.0, 0.0, big * 3.0)
	cam.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	var lt := DirectionalLight3D.new()
	lt.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	lt.light_energy = 1.3
	vp.add_child(lt)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14111f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.62)
	env.ambient_light_energy = 1.0
	we.environment = env
	vp.add_child(we)
	for i in 20:
		await process_frame
	vp.get_texture().get_image().save_png("res://shots/dealer_peek.png")
	#  ── 손만, **게임 크기로** ──────────────────────────
	#  이 물음의 전부가 이것이다: 30px 짜리 손에서 3D 가 손그림을 이기나.
	#  크게 구워 놓고 "좋다" 하는 것은 답이 아니다 — 화면에 서는 크기로
	#  구워서 견줘야 한다.
	var hand_px := 34
	var hv := SubViewport.new()
	hv.size = Vector2i(hand_px, hand_px)
	hv.own_world_3d = true
	hv.transparent_bg = true
	hv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(hv)
	var nd2 = sc.instantiate()
	hv.add_child(nd2)
	#  왼손 언저리. AABB 로 어림잡는다 — 뼈 이름을 모르므로 자리로 찾는다.
	var hc := mid + Vector3(-ab.size.x * 0.44, ab.size.y * 0.06, 0.0)
	var hcam := Camera3D.new()
	hcam.projection = Camera3D.PROJECTION_ORTHOGONAL
	hcam.size = 0.22
	hcam.near = 0.01
	hcam.far = 20.0
	hv.add_child(hcam)
	hcam.position = hc + Vector3(0.0, 0.10, 0.6)
	hcam.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	var lt2 := DirectionalLight3D.new()
	lt2.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	lt2.light_energy = 1.3
	hv.add_child(lt2)
	var we2 := WorldEnvironment.new()
	we2.environment = env
	hv.add_child(we2)
	for i in 20:
		await process_frame
	hv.get_texture().get_image().save_png("res://shots/dealer_hand.png")
	print("찍었다 — 전신 · 손(%dpx)" % hand_px)
	quit(0)
