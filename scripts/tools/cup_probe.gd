extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  팩 통(3D) 수명 검사
#
#  실행:  godot --path . --quit-after 3000 --script scripts/tools/cup_probe.gd
#  종료 코드 = 실패 개수
#
#  통은 이 게임에서 유일한 3D 다. 새 런 화면에만 살고 나가면 지워지는데,
#  나가는 길이 셋(ESC · 뒤로 · 시작)이라 하나만 빠뜨려도 뷰포트와 강체가
#  런 내내 뒤에 남아 돈다 — 화면에는 안 보이므로 눈으로는 영영 못 잡는다.
#
#  헤드리스로는 못 돈다. 3D 렌더러가 있어야 뷰포트가 서고, 물리도 그 안
#  World3D 에서 돈다.
#
#  재는 것
#    ① 화면을 열면 통이 서고 자루 수가 그 팩의 탄창과 같다
#    ② 넘기는 동안만 두 벌이고, 다 넘기면 나간 통이 사라진다
#    ③ 연타해도 통이 쌓이지 않는다
#    ④ 화면을 뜨면(제목 · 런 시작) 뷰포트가 지워진다
#    ⑤ 팩별 통 겉(CUP_SKIN) 표에 없는 팩·없는 벽·없는 속성이 없다
# ══════════════════════════════════════════════════════════
var g = null
var busy := false
var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-34s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	Save.path = "user://_probe_cup.cfg"
	Save.wipe()
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _wait(4)
	g._open_newrun()
	await _wait(60)
	_say(g.cup_vp != null, "화면을 열면 통이 선다",
			"자루 %d개" % (g.cup_rigs[0].darts.size() if g.cup_rigs.size() > 0 else -1))
	_say(g.cup_rigs.size() == 1, "통은 한 벌", "%d벌" % g.cup_rigs.size())

	g._pack_step(1)
	await _wait(6)
	_say(g.cup_rigs.size() == 2, "넘기는 동안 두 벌", "%d벌" % g.cup_rigs.size())
	await _wait(220)
	_say(g.cup_rigs.size() == 1, "다 넘기면 나간 통이 사라진다", "%d벌" % g.cup_rigs.size())
	_say(g.cup_rigs[0].darts.size() == 7, "새 팩의 자루 수로 선다",
			"%d개" % g.cup_rigs[0].darts.size())

	# 연달아 눌러도 줄이 안 밀린다
	for k in 4:
		g._pack_step(1)
		await _wait(3)
	await _wait(240)
	_say(g.cup_rigs.size() == 1, "연타해도 한 벌만 남는다", "%d벌" % g.cup_rigs.size())

	# ESC 로 나가면 지워진다
	g.state = g.S.TITLE
	await _wait(4)
	_say(g.cup_vp == null, "화면을 뜨면 통이 지워진다", "")
	_say(g.cup_rigs.is_empty(), "통 목록도 빈다", "%d벌" % g.cup_rigs.size())

	# 다시 열면 다시 선다
	g._open_newrun()
	await _wait(30)
	_say(g.cup_vp != null and g.cup_rigs.size() == 1, "다시 열면 다시 선다", "")

	# 시작 → 런으로. 3D 는 따라 들어가면 안 된다
	g._new_run()
	await _wait(6)
	_say(g.cup_vp == null, "런을 시작하면 통이 지워진다",
			"state %d" % g.state)
	# 팩별 통 겉 표. 오타는 잠자코 기본 통으로 떨어지므로 여기서 잡는다 —
	# 없는 팩 · 없는 벽 이름 · CUP_SKIN0 에 없는 속성 셋 다 본다.
	var ids := []
	for r in GameData.packs():
		ids.append(String(r.get("id", "")))
	var bad := []
	for k in g.CUP_SKIN:
		if not ids.has(String(k)):
			bad.append("팩 없음 " + String(k))
			continue
		var sk: Dictionary = g.CUP_SKIN[k]
		for f in sk:
			if not g.CUP_SKIN0.has(String(f)):
				bad.append("속성 없음 %s.%s" % [k, f])
		if sk.has("wall") and not g.CUP_WALLS.has(String(sk["wall"])):
			bad.append("벽 없음 %s=%s" % [k, sk["wall"]])
	_say(bad.is_empty(), "통 겉 표가 팩·벽·속성 이름과 맞는다",
			", ".join(bad) if not bad.is_empty() else "%d줄" % g.CUP_SKIN.size())

	print("아홉 검사 · 실패 %d" % fails)
	quit(fails)
