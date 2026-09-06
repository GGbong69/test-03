extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  성장형 걸음 QA — 다트를 **직접 꽂아** 한 걸음씩 확인한다
#
#  실행:  godot --path . --headless --script scripts/tools/qa_grow_step.gd
#  종료 코드 = 실패 개수
#
#  qa_grow 는 오토플레이 소크라 운에 걸린다 — 빗나감이 안 나오면 명중
#  적립기의 하향을 못 보고, 8번 칸이 안 걸리면 88날어가 안 움직인다.
#  여기서는 조준점을 손으로 정해 _land() 를 부른다. 오토플레이를 끄고
#  부르므로(_land 가 켜져 있으면 조준을 덮어쓴다) 꽂는 자리가 정확하다.
#
#  발라트로 어법대로인지 보는 것
#    fire     발동할 때마다 gstep 만큼 오른다
#    hitmiss  명중에 오르고 빗나감에 내린다 · 0 아래로는 안 간다
#    tdec     던질 때마다 한 걸음 · 수량이 gstep 씩 준다
#    rdec     판이 끝날 때마다 한 걸음 · 0 에 닿으면 부서진다
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_grow_step.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail: String) -> void:
	print("  %s %-30s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _find(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it.duplicate()
	return {}


func _by_grow(gw: String) -> Dictionary:
	for it in GameData.items():
		if String(it.get("grow", "")) == gw:
			return it.duplicate()
	return {}


# 판 안에서 그 칸에 꽂히는 자리를 찾는다. 각도 규약을 외우지 않고
# hit_info 에게 물어본다 — 규약이 바뀌어도 이 프로브는 안 깨진다.
func _point_on_sector(sec: int) -> Vector2:
	for i in 2880:
		var a: float = TAU * float(i) / 2880.0
		var p: Vector2 = g.BC + Vector2(cos(a), sin(a)) * g.R * 0.75
		if int(g.hit_info(p).sector) == sec:
			return p
	return Vector2.ZERO


func _miss_point() -> Vector2:
	return g.BC + Vector2(g.R * 4.0, 0.0)      # 판 한참 밖


func _hold(it: Dictionary) -> void:
	var cp: Dictionary = it.duplicate()
	cp.gs = 0
	cp.bought = 1
	g.owned = [cp]
	g.sealed = -1
	g._panel_reset()


func _gs() -> int:
	return int(g.owned[0].get("gs", 0)) if not g.owned.is_empty() else -1


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	g.set_process(false)
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g.leg_no = 1
	g._start_leg()
	g._autoplay = false          # _land 가 조준을 덮어쓰지 않게 한다

	print("성장형 걸음 검사 — 다트를 손으로 꽂는다\n")

	# ── hitmiss — 명중에 오르고 빗나감에 내린다 ──────────────
	var hm := _by_grow("hitmiss")
	if hm.is_empty():
		_ok("hitmiss 동전이 있다", false, "표에 없다")
	else:
		var step := int(hm.gstep)
		_hold(hm)
		var seq := []
		for i in 3:                          # 명중 셋
			g.aim = _point_on_sector(20)
			g._land()
			seq.append(_gs())
		var top: int = _gs()
		_ok("%s — 명중마다 +%d" % [hm.n, step], top == step * 3,
				"0 → %s" % str(seq))
		var dn := []
		for i in 5:                          # 빗나감 다섯 — 바닥을 지나친다
			g.aim = _miss_point()
			g._land()
			dn.append(_gs())
		_ok("%s — 빗나가면 −%d" % [hm.n, step], int(dn[0]) == top - step,
				"%d → %s" % [top, str(dn)])
		_ok("%s — 0 아래로 안 간다" % hm.n, _gs() == 0, "바닥 %d" % _gs())

	# ── fire — 발동할 때마다 gstep ────────────────────────
	# 조건이 sec 인 장으로 본다. 그 칸에만 꽂으면 반드시 발동한다.
	for it in GameData.items():
		if String(it.get("grow", "")) != "fire":
			continue
		var c := String(it.get("c", ""))
		if not c.begins_with("sec:"):
			continue
		var sec := int(c.substr(4).split(",")[0])
		var step2 := int(it.get("gstep", 0))
		_hold(it)
		var seq2 := []
		for i in 4:
			g.aim = _point_on_sector(sec)
			g._land()
			seq2.append(_gs())
		_ok("%s — %d번 칸마다 +%d" % [it.n, sec, step2],
				_gs() == step2 * 4, "0 → %s" % str(seq2))
		# 조건이 안 서면 안 자란다
		var before: int = _gs()
		g.aim = _miss_point()
		g._land()
		_ok("%s — 조건이 안 서면 그대로" % it.n, _gs() == before,
				"%d → %d" % [before, _gs()])

	# ── tdec — 던질 때마다 한 걸음 · 다 쓰면 사라진다 ────────
	var td := _by_grow("tdec")
	if not td.is_empty():
		var v0 := int(td.v)
		var st := int(td.gstep)
		_hold(td)
		var amts := []
		for i in 4:
			g.aim = _point_on_sector(20)
			g._land()
			amts.append(GameData.item_amt(g.owned[0], {"streak": 0}))
		var want := [v0 - st, v0 - st * 2, v0 - st * 3, v0 - st * 4]
		_ok("%s — 던질 때마다 −%d" % [td.n, st], amts == want,
				"%s (바라는 값 %s)" % [str(amts), str(want)])

		# 0 에 닿으면 그 발의 정산이 끝나는 자리에서 사라진다.
		# 판이 안 끝나게 목표를 멀리 두고 다트를 넉넉히 준다 — _next_step 의
		# 빈 큐 갈래가 판 종료로 새면 무엇 때문에 사라졌는지 흐려진다.
		_hold(td)
		g.target = 99999999
		g.total = 0
		g.darts_left = 999
		var throws := int(ceil(float(v0) / float(st)))
		var gone_at := -1
		for i in throws + 1:
			if g.owned.is_empty():
				gone_at = i
				break
			g.aim = _point_on_sector(20)
			g._land()
			while not g.queue.is_empty():
				g._next_step()
			g._next_step()           # 빈 큐 갈래 — 여기서 다 쓴 것을 치운다
		_ok("%s — 다 쓰면 사라진다" % td.n, g.owned.is_empty(),
				"%d발 만에 사라짐 (바라는 값 %d발)" % [gone_at, throws]
				if gone_at >= 0 else "%d발 던졌는데 손에 %d장 남았다"
				% [throws + 1, g.owned.size()])

	# ── rdec — 판마다 한 걸음 · 0 이면 부서진다 ──────────────
	var rd := _by_grow("rdec")
	if not rd.is_empty():
		var v1 := int(rd.v)
		var s1 := int(rd.gstep)
		_hold(rd)
		var legs := int(ceil(float(v1) / float(s1)))
		var amts2 := []
		for i in legs:
			g._leg_end_wear()
			if g.owned.is_empty():
				amts2.append(0)
				break
			amts2.append(GameData.item_amt(g.owned[0], {"streak": 0}))
		_ok("%s — 판마다 −%d" % [rd.n, s1],
				amts2.size() >= 2 and int(amts2[0]) == v1 - s1
				and int(amts2[1]) == v1 - s1 * 2, "%s" % str(amts2))
		_ok("%s — 0 에 닿으면 부서진다" % rd.n, g.owned.is_empty(),
				"%d판 뒤 손에 %d장" % [legs, g.owned.size()])

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
