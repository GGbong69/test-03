extends SceneTree
#  Blender 자루(assets/models/darts.glb · 2026-10-16 「다트들의 외형을 새로 디자인」) — 못 박는 것:
#    ① 네 종류(표준 · 무거운 쿠나이 · 가벼운 종이비행기 · 자석)마다 메시가 든다
#    ② 재질 이름이 다 칠로 읽힌다(body · fin · print · ART_PAL 램프 · 단은 수 · 꼬리는 m 뿐)
#    ③ 온 길이 1 그대로 — 촉 끝 −0.5 · 꽁지 0.5 안(통 벽 뚫림 · DART3_SHAPE 의 ⚠)
#    ④ 세운 벌 — 표준 밖은 낯 축(face) 밑 · 표준은 안 돈다(십자 날개) · 메시마다 칠 표(dk3)
#    ⑤ 표준 날개는 인쇄(테 · 띠) 질감을 받는다
#    ⑥ 2D 그림 — 쥘 때 쓰는 배럴 반폭(_dart_barrel)이 넷 다 선다
#   godot --headless --path . --script scripts/tools/qa_darts3.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false
const IDS := ["std", "hvy", "lgt", "mag"]


func _initialize() -> void:
	Save.gpath = "user://_qa_darts3_g.cfg"
	Save.path = "user://_qa_darts3.cfg"
	Save.prof_fmt = "user://_qa_darts3_%d.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-52s %s" % ["통과" if cond else "실패", nm, note])


func _mis(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_mis(c))
	return out


func _run() -> void:
	_ok("① glb 가 있다", ResourceLoader.exists(g.DART3_GLB), g.DART3_GLB)
	var names_bad := []
	var len_bad := []
	for id in IDS:
		var parts: Array = g._dart3_glb_parts(id)
		_ok("① %s 메시" % id, parts.size() >= 3, str(parts.size()))
		var lo := 9.0
		var hi := -9.0
		for p in parts:
			var q: PackedStringArray = String(p[1]).split("_")
			var r := q[0]
			if not (r in ["body", "fin", "print"] or g.ART_PAL.has(r)) or q.size() < 2 \
					or not q[1].is_valid_int() or (q.size() > 2 and q[2] != "m") or q.size() > 3:
				names_bad.append("%s:%s" % [id, p[1]])
			var bb: AABB = (p[0] as Mesh).get_aabb()
			lo = minf(lo, bb.position.y)
			hi = maxf(hi, bb.end.y)
		if absf(lo + 0.5) > 0.01 or hi > 0.505:
			len_bad.append("%s %.3f~%.3f" % [id, lo, hi])
	_ok("② 재질 이름이 다 칠로 읽힌다", names_bad.is_empty(), str(names_bad))
	_ok("③ 온 길이 1 — 촉 −0.5 · 꽁지 0.5 안", len_bad.is_empty(), str(len_bad))
	for id in IDS:
		var b := Node3D.new()
		g._dart3_meshes(b, 10.0, 1.0, 1.0, g._dart3_col(id), id, 0.3)
		var face := b.get_node_or_null("face") as Node3D
		var mis := _mis(b)
		var dk_ok := true
		for mi in mis:
			if not mi.has_meta("dk3") or not (mi.material_override is ShaderMaterial):
				dk_ok = false
		if id == "std":
			_ok("④ 표준은 낯 축 없이 선다(십자 날개)", face == null, "%d" % b.get_child_count())
			var pr := 0
			for mi in mis:
				if mi.get_meta("dk3")[3] != null:
					pr += 1
			_ok("⑤ 표준 날개 둘이 인쇄를 받는다", pr == 2, str(pr))
		else:
			_ok("④ %s 는 온 몸이 낯 축 밑 · u_yaw 를 받는다" % id, face != null
					and face.get_child_count() == mis.size() and is_equal_approx(face.rotation.y, 0.3),
					"%d/%d" % [face.get_child_count() if face != null else 0, mis.size()])
		_ok("④ %s 메시마다 칠 표" % id, dk_ok and mis.size() >= 3, str(mis.size()))
		b.free()
	var bw := []
	for id in IDS:
		bw.append("%s %.1f" % [id, g._dart_barrel(id)])
	_ok("⑥ 2D 배럴 반폭이 넷 다 선다", IDS.all(func(i): return g._dart_barrel(i) > 0.5), str(bw))
