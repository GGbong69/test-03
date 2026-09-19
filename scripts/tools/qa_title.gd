extends SceneTree
# 제목 판이 사는가 — 저절로 날아오고, 눌러서 던지고, 여섯이면 걷힌다.
#   godot --headless --path . --script scripts/tools/qa_title.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
const D := 1.0 / 60.0


func _initialize() -> void:
	Save.gpath = "user://_qa_ttl_g.cfg"
	Save.path = "user://_qa_ttl.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


#  제목에 서서 n 프레임 민다.
func _tick(n: int) -> void:
	for i in n:
		g._title_tick(D)


func _title() -> void:
	g.state = g.S.TITLE
	g.pause_from = -1
	g.motion_off = false
	g.ttl_stuck.clear()
	g.ttl_fly.clear()
	g.pops.clear()
	g.mouse_at = Vector2(4.0, 4.0)      # 판에서도 글줄에서도 먼 자리


func _run() -> void:
	g._new_run()
	_title()
	var rim: float = g.R * g.rt_dbl_out

	# ── 자세 ────────────────────────────────────────────
	#  _icon_dart 는 각 없이 부르면 Vector2(6,-10) 쪽으로 눕는다. rot 을
	#  얹은 뒤 그 방향이 u 와 같아야 촉이 가는 쪽을 본다.
	var worst := 0.0
	for i in 32:
		var u := Vector2.from_angle(TAU * float(i) / 32.0)
		var got := Vector2(6.0, -10.0).normalized().rotated(g._ttl_rot(u))
		worst = maxf(worst, got.distance_to(u))
	_ok("촉이 가는 쪽을 본다", worst < 0.001, "최대 어긋남 %.5f" % worst)

	# ── 노리는 자리 ─────────────────────────────────────
	var out := 0
	var bull := 0
	for i in 4000:
		var p: Vector2 = g._ttl_spot()
		if p.distance_to(g.BC) > rim:
			out += 1
		if int(g.hit_info(p).get("sector", 0)) == 50:
			bull += 1
	_ok("저절로 오는 자루는 판을 안 벗어난다", out == 0, "벗어남 %d/4000" % out)
	_ok("안쪽 불이 드물게 난다", bull > 40 and bull < 600,
			"%d/4000 (%.1f%%)" % [bull, 100.0 * float(bull) / 4000.0])

	# ── 손이 없으면 아무 일도 안 난다 ───────────────────
	_title()
	_tick(1800)                         # 30초
	_ok("저절로는 한 자루도 안 난다",
			g.ttl_stuck.is_empty() and g.ttl_fly.is_empty(),
			"꽂힘 %d · 나는 중 %d" % [g.ttl_stuck.size(), g.ttl_fly.size()])

	# ── 누르면 난다 ─────────────────────────────────────
	_title()
	g._ttl_throw(g.BC + Vector2(-40.0, 30.0))
	_ok("누르면 한 자루 난다", g.ttl_fly.size() == 1,
			"나는 중 %d" % g.ttl_fly.size())
	var fx0: float = 999.0
	var fx1: float = -999.0
	for i in 60:
		for f in g.ttl_fly:
			var t: float = clampf(float(f.t) / float(g.TTL.fly), 0.0, 1.0)
			var e: float = t * t * (3.0 - 2.0 * t)
			var p: Vector2 = (f.a as Vector2).lerp(f.b, e)
			fx0 = minf(fx0, p.x)
			fx1 = maxf(fx1, p.x)
		_tick(1)
	#  글줄은 x16~164 다. 나는 길이 거길 지나면 제목 위로 자루가 지나간다.
	_ok("나는 길이 글줄을 안 지난다", fx0 > 170.0, "가장 왼쪽 x=%.1f" % fx0)
	_ok("날아간 자루가 꽂힌다", g.ttl_stuck.size() == 1 and g.ttl_fly.is_empty(),
			"꽂힘 %d · 나는 중 %d" % [g.ttl_stuck.size(), g.ttl_fly.size()])
	_ok("꽂힌 자리는 판 안이다",
			(g.ttl_stuck[0].p as Vector2).distance_to(g.BC) <= rim)

	# ── 자루마다 제 시계로 진다 ─────────────────────────
	var life: float = float(g.TTL.life)
	var gone: float = float(g.TTL.gone)
	_title()
	g._ttl_throw(g.BC)
	_tick(int(g.TTL.fly / D) + 2)
	_ok("꽂히고 바로는 안 진다", g.ttl_stuck.size() == 1)
	_tick(int((life - 0.3) / D))
	_ok("사는 동안은 그대로 있다", g.ttl_stuck.size() == 1,
			"%.1f초 뒤" % float(g.ttl_stuck[0].t))
	_tick(int((gone + 0.6) / D))
	_ok("제 시간이 지나면 혼자 사라진다", g.ttl_stuck.is_empty())

	# ── 한꺼번에 비지 않는다 ────────────────────────────
	#  여섯이 차면 통째로 걷던 방식이 남긴 자국이 여기 있으면 잡힌다 —
	#  그 방식은 한 프레임에 여섯이 같이 없어진다.
	_title()
	var top := 0
	var sum := 0
	var frames := 0
	var empty := 0
	var drop_max := 0
	var seen := false
	var prev: int = 0
	var beat := 0
	for i in 5400:                      # 90초 — 2.1초마다 한 자루씩 놓는다
		beat += 1
		if beat >= 126:
			beat = 0
			g._ttl_throw(g._ttl_spot())
		_tick(1)
		var now: int = g.ttl_stuck.size()
		if now > 0:
			seen = true
		if seen:
			frames += 1
			sum += now
			top = maxi(top, now)
			if now == 0:
				empty += 1
			drop_max = maxi(drop_max, prev - now)
		prev = now
	_ok("한 프레임에 하나씩만 진다", drop_max <= 1,
			"가장 많이 준 수 %d" % drop_max)
	_ok("판이 오래 비지 않는다", float(empty) / float(maxi(frames, 1)) < 0.12,
			"빈 프레임 %.1f%%" % (100.0 * float(empty) / float(maxi(frames, 1))))
	var avg := float(sum) / float(maxi(frames, 1))
	_ok("화면에 평균 두셋 넷쯤", avg >= 2.0 and avg <= 6.0, "평균 %.2f장" % avg)
	_ok("여섯 언저리에서 논다", top <= int(g.TTL.max), "가장 많이 %d장" % top)

	# ── 눌러서 던진다 ───────────────────────────────────
	_title()
	var aim: Vector2 = g.BC + Vector2(0.0, -40.0)
	g._click(aim)
	_ok("판을 누르면 난다", g.ttl_fly.size() == 1,
			"나는 중 %d" % g.ttl_fly.size())
	_ok("누른 자리로 간다", g.ttl_fly.size() == 1
			and (g.ttl_fly[0].b as Vector2).is_equal_approx(aim))
	_tick(30)
	_ok("누른 자루가 꽂힌다", g.ttl_stuck.size() == 1)

	_title()
	g._click(Vector2(600.0, 340.0))     # 판 밖 · 줄 밖
	_ok("판 밖을 누르면 안 난다", g.ttl_fly.is_empty() and g.ttl_stuck.is_empty())

	_title()
	#  ⚠ 여기는 _menu_rect(1) 이 「컬렉션」이라고 **번호로** 박혀 있었다.
	#  2026-09-20 에 줄이 다섯이 되면서(「계속하기」가 둘째) 그 번호가
	#  딴 줄을 가리켰다 — 줄을 하나 늘릴 때마다 깨지는 단언이다.
	#  표에서 **이름으로** 찾는다. 밑에서 names 를 모으는 그 어법이다.
	var ci := -1
	for i in g.TITLE_ROWS.size():
		if String(g.TITLE_ROWS[i].n) == "컬렉션":
			ci = i
	_ok("글줄에 컬렉션이 있다", ci >= 0)
	g._click(g._menu_rect(ci).get_center())
	_ok("글줄은 여전히 글줄이다", g.state == g.S.COLLECT and g.ttl_fly.is_empty(),
			"state=%d" % g.state)

	# ── 프로필은 글줄 밖의 따로 선 패다 ─────────────────
	#  시작·컬렉션·설정·종료는 「무엇을 한다」 이고 프로필은 「누구로 하는가」 라
	#  발라트로처럼 패로 따로 선다(2026-09-17 사용자).
	var names := []
	for row in g.TITLE_ROWS:
		names.append(String(row.n))
	_ok("글줄에 프로필이 없다", not names.has("프로필"), " · ".join(names))
	var pb: Rect2 = g._prof_badge_rect()
	var rows_box: Rect2 = g._menu_rect(0).merge(g._menu_rect(g.TITLE_ROWS.size() - 1))
	_ok("프로필 패가 글줄과 안 겹친다", not pb.intersects(rows_box), "%s · %s" % [pb, rows_box])
	_ok("프로필 패가 판과 안 겹친다",
			pb.end.x < g.BC.x - g.R * g.rt_dbl_out - 20.0, "%s" % pb)
	_ok("프로필 패가 화면 안이다", pb.end.y <= 360.0 and pb.position.x >= 0.0)
	_ok("프로필 패가 손가락 크기다", pb.size.y >= 26.0 and pb.size.x >= 100.0, "%s" % pb.size)
	_title()
	g._click(pb.get_center())
	_ok("프로필 패를 누르면 프로필 화면", g.state == g.S.PROFILE, "state=%d" % g.state)
	_title()
	g._click(pb.get_center())
	_ok("패를 눌러도 자루가 안 난다", g.ttl_fly.is_empty())

	# ── 화면을 뜨면 비운다 ──────────────────────────────
	_title()
	g._click(aim)
	_tick(30)
	var had: int = g.ttl_stuck.size()
	g.state = g.S.NEWRUN
	_tick(1)
	_ok("제목을 뜨면 판을 비운다", had > 0 and g.ttl_stuck.is_empty(),
			"뜨기 전 %d장" % had)

	# ── 설정이 위에 떠도 판은 산다 ──────────────────────
	_title()
	g._ttl_throw(g.BC + Vector2(20.0, 20.0))
	g.state = g.S.SETTINGS
	g.pause_from = -1
	_tick(30)
	_ok("설정 밑에서도 나던 자루는 꽂힌다",
			g.ttl_stuck.size() == 1 and g.ttl_fly.is_empty(),
			"꽂힘 %d" % g.ttl_stuck.size())
	#  **수가 는 적이 있는가**를 본다. 제 시간에 지는 것은 「새로 왔다」
	#  가 아니다.
	var n0: int = g.ttl_stuck.size()
	var grew := false
	var pn: int = n0
	for i in 600:                       # 10초
		_tick(1)
		if g.ttl_stuck.size() > pn or not g.ttl_fly.is_empty():
			grew = true
		pn = g.ttl_stuck.size()
	_ok("설정 밑에서는 새 자루를 안 보낸다", not grew,
			"%d → %d장" % [n0, g.ttl_stuck.size()])
	#  판을 판 중에 열었으면(pause_from >= 0) 뒤에 있는 것은 제목이 아니다.
	g.state = g.S.SETTINGS
	g.pause_from = g.S.AIM_V
	_tick(1)
	_ok("판 중에 연 설정은 제목 판을 비운다", g.ttl_stuck.is_empty())

	# ── 움직임 끄기 ─────────────────────────────────────
	_title()
	g.motion_off = true
	_tick(600)
	_ok("움직임을 끄면 저절로 안 온다", g.ttl_stuck.is_empty() and g.ttl_fly.is_empty(),
			"꽂힘 %d" % g.ttl_stuck.size())
	g._click(aim)
	_ok("움직임을 꺼도 누르면 곧장 꽂힌다",
			g.ttl_stuck.size() == 1 and g.ttl_fly.is_empty())
	_tick(int((life + gone + 0.6) / D))
	_ok("움직임을 꺼도 제 시간에 진다", g.ttl_stuck.is_empty())
	g.motion_off = false

	# ── 마구 눌러도 안 넘친다 ───────────────────────────
	_title()
	#  _click 이 아니라 _ttl_throw 로 쌓는다. 같은 자리를 다시 누르면
	#  이제 **뽑히므로**, 클릭으로는 한도까지 못 쌓는다 — 여기서 재려는
	#  것은 손이 아니라 「자루가 많을 때」 다.
	for i in 40:
		g._ttl_throw(g._ttl_spot())
		_tick(int(g.TTL.fly / D) + 2)
	_ok("마구 눌러도 한도를 크게 안 넘는다",
			g.ttl_stuck.size() <= int(g.TTL.max) + 2,
			"%d장 (한도 %d)" % [g.ttl_stuck.size(), int(g.TTL.max)])
	#  넘친 것도 **하나씩** 진다 — 한도를 넘었다고 통째로 걷으면 그게
	#  걷어 낸 그 방식이다.
	var w2 := 0
	var pv: int = g.ttl_stuck.size()
	for i in 900:
		_tick(1)
		w2 = maxi(w2, pv - g.ttl_stuck.size())
		pv = g.ttl_stuck.size()
	#  빨리 재우는 자루와 제 시간에 지는 자루가 **같은 프레임**에 만날
	#  수는 있다. 둘까지는 「한꺼번에」 가 아니다 — 여섯이 한 번에 비던
	#  것이 걷어 낸 그 방식이다.
	_ok("넘친 것도 하나씩 진다", w2 <= 2, "가장 많이 준 수 %d" % w2)

	# ── 꽂힌 자루를 집는다 ──────────────────────────────
	_title()
	g._click(aim)
	_tick(30)
	_ok("한 자루 꽂혀 있다", g.ttl_stuck.size() == 1)
	#  자루 한가운데를 누른다. 촉이 아니라 몸통이 잡히는 자리다.
	var body: Vector2 = (g.ttl_stuck[0].p as Vector2) 			- (g.ttl_stuck[0].u as Vector2) * float(g.TTL.dl1)
	g._click(body)
	_ok("자루를 누르면 뽑힌다", g.ttl_stuck.is_empty() and g.ttl_fly.is_empty(),
			"꽂힘 %d · 나는 중 %d" % [g.ttl_stuck.size(), g.ttl_fly.size()])
	#  뽑는 손이 꽂는 손을 겸하면 안 된다 — 누른 자리에 또 하나가 꽂히면
	#  자루가 안 없어진 것으로 보인다.
	_title()
	g._click(aim)
	_tick(30)
	var b2: Vector2 = (g.ttl_stuck[0].p as Vector2) 			- (g.ttl_stuck[0].u as Vector2) * float(g.TTL.dl1)
	g._click(b2)
	_tick(30)
	_ok("뽑은 자리에 새로 안 꽂힌다", g.ttl_stuck.is_empty())
	#  겹친 자리는 **위엣것**이 잡힌다. 나중에 꽂힌 것이 위에 그려진다.
	_title()
	g._ttl_throw(aim)
	_tick(int(g.TTL.fly / D) + 2)
	g._ttl_throw(aim + Vector2(2.0, 2.0))
	_tick(int(g.TTL.fly / D) + 2)
	_ok("겹쳐도 둘이다", g.ttl_stuck.size() == 2)
	var keep_p: Vector2 = g.ttl_stuck[0].p
	g._click((g.ttl_stuck[1].p as Vector2)
			- (g.ttl_stuck[1].u as Vector2) * float(g.TTL.dl1))
	_ok("겹친 자리는 위엣것이 잡힌다",
			g.ttl_stuck.size() == 1
			and (g.ttl_stuck[0].p as Vector2).is_equal_approx(keep_p),
			"남은 자리 %s" % g.ttl_stuck[0].p)

	# ── 문 값이 뜬다 ────────────────────────────────────
	_title()
	var spots := {"안쪽 불": g.BC, "바깥 칸": g.BC + Vector2(0.0, -g.R * 0.55)}
	for nm in spots:
		var sp: Vector2 = spots[nm]
		g.pops.clear()
		g.ttl_stuck.clear()
		g._ttl_throw(sp)
		_tick(int(g.TTL.fly / D) + 2)
		var inf: Dictionary = g.hit_info(sp)
		var want := str(int(inf.base) * maxi(int(inf.mult), 0))
		var got := ""
		for q in g.pops:
			got = String(q.txt)
		_ok("문 값이 뜬다 — %s" % nm, got == want,
				"「%s」 (바란 것 %s)" % [got, want])

	# ── 이스터에그 — 불 서른 번 잇달아 ───────────────────
	var need: int = int(g.EGG.need)
	var land := int(g.TTL.fly / D) + 2
	var outer: Vector2 = g.BC + Vector2(0.0, -g.R * (g.rt_bull_i + g.rt_bull_o) * 0.5)
	var single: Vector2 = g.BC + Vector2(0.0, -g.R * 0.55)
	_title()
	g._egg_reset()
	g._ttl_throw(g.BC)
	_tick(land)
	_ok("안쪽 불 → 하나 는다", g.egg_streak == 1, "%d" % g.egg_streak)
	g._ttl_throw(outer)
	_tick(land)
	_ok("바깥 불도 센다", g.egg_streak == 2, "%d" % g.egg_streak)
	var from: int = int(g.EGG.from)
	var ns: int = g._egg_stages()
	g.egg_streak = from - 2
	g._ttl_throw(g.BC)
	_tick(land + 30)
	_ok("일곱 번째 앞까지는 금이 안 간다", g.egg_streak == from - 1 and g.egg_stage == 0,
			"잇단 %d · 단 %d" % [g.egg_streak, g.egg_stage])
	g.egg_bits.clear()
	g._ttl_throw(g.BC)
	_tick(land)
	_ok("일곱 번째에 금이 간다", g.egg_stage == 1, "단 %d" % g.egg_stage)
	var n1 := 0
	var last := 0.0
	for sg in g.egg_segs:
		if int(sg.s) == 1:
			n1 += 1
			last = maxf(last, float(sg.o) + float(g.EGG.snap))
	_ok("첫 금은 한 번에 튄다", n1 >= int(g.EGG.first) and last <= 0.3,
			"마디 %d · 끝까지 %.2f초" % [n1, last])
	_ok("금이 날 때 부스러기가 튄다", g.egg_bits.size() > 0, "%d" % g.egg_bits.size())
	#  바깥 불로 문다 — 안쪽 불은 제 등급만으로도 판을 흔든다
	g.shake = 0.0
	g._ttl_throw(outer)
	_tick(land)
	_ok("한 발에 한 단", g.egg_stage == 2, "단 %d" % g.egg_stage)
	_ok("금이 나면 판이 움찔한다", g.shake > 3.0, "흔들림 %.1f" % g.shake)
	g._ttl_throw(single)
	_tick(land)
	_ok("불이 아니면 처음부터", g.egg_streak == 0, "%d" % g.egg_streak)
	_tick(3)
	_ok("금은 한 번에 안 지워지고 걷힌다",
			g.egg_stage > 0 and g.egg_fade > 0.0 and g.egg_fade < 1.0,
			"단 %d · 짙기 %.3f" % [g.egg_stage, g.egg_fade])
	_tick(int(float(g.EGG.heal) / D) + 5)
	_ok("다 걷힌다", g.egg_stage == 0, "단 %d" % g.egg_stage)

	#  금 무늬 — 같은 씨면 같고, 판 밖으로 안 나가고, 이어져 있다
	g._egg_make_web()
	var pa: Array = g.egg_segs.duplicate(true)
	g._egg_make_web()
	var same: bool = pa.size() == g.egg_segs.size()
	var far := 0.0
	for i in pa.size():
		if not same:
			break
		var x: Dictionary = pa[i]
		var y: Dictionary = g.egg_segs[i]
		if not ((x.a as Vector2).is_equal_approx(y.a) and (x.b as Vector2).is_equal_approx(y.b)
				and int(x.s) == int(y.s)):
			same = false
		far = maxf(far, maxf((x.a as Vector2).length(), (x.b as Vector2).length()))
	_ok("같은 씨면 같은 금 무늬", same, "%d마디" % pa.size())
	_ok("금이 판 밖으로 안 나간다", far <= g.R * g.rt_dbl_out + 0.01,
			"가장 먼 %.1f · 판 %.1f" % [far, g.R * g.rt_dbl_out])
	var per := []
	per.resize(ns + 1)
	per.fill(0)
	for sg in g.egg_segs:
		per[int(sg.s)] = int(per[int(sg.s)]) + 1
	var hollow := 0
	for st in range(1, ns + 1):
		if int(per[st]) == 0:
			hollow += 1
	_ok("단마다 새 금이 난다 — 헛발이 없다", hollow == 0 and int(per[0]) == 0,
			"단 %d · 빈 단 %d" % [ns, hollow])
	#  허공에서 시작하는 금이 없다 — 시작점이 맞은 자리거나, 같은 단 이하의
	#  다른 금이 끝나는 자리다.
	var orphan := 0
	var order_bad := 0
	for k in g.egg_segs.size():
		var sg: Dictionary = g.egg_segs[k]
		var a: Vector2 = sg.a
		if a.length() > 3.0:
			var hit := false
			for x in g.egg_segs.size():
				var o: Dictionary = g.egg_segs[x]
				if x != k and int(o.s) <= int(sg.s) and (o.b as Vector2).distance_to(a) < 0.01:
					hit = true
					break
			if not hit:
				orphan += 1
		for x in sg.after:
			var pseg: Dictionary = g.egg_segs[x]
			if int(pseg.s) > int(sg.s) or (int(pseg.s) == int(sg.s) and float(pseg.o) >= float(sg.o)):
				order_bad += 1
	_ok("허공에서 시작하는 금이 없다", orphan == 0, "%d" % orphan)
	_ok("이어진 마디는 차례로 난다(지직)", order_bad == 0, "%d" % order_bad)
	_ok("금이 가른 유리 면이 있다", g.egg_facets.size() >= 10, "%d면" % g.egg_facets.size())

	#  서른 번째에 깨진다
	_title()
	g._egg_reset()
	var seed0: int = g.egg_seed
	#  판에 자루 하나 — 깨질 때 같이 날아가야 한다. 불이 아닌 자리라 잇단 수를
	#  지우므로 **먼저** 꽂고 나서 잇단 수를 세운다.
	g._ttl_throw(g.BC + Vector2(20.0, 20.0))
	_tick(land)
	g.egg_streak = need - 2
	g._ttl_throw(g.BC)
	_tick(land)
	_ok("스물아홉 — 아직 안 깨진다", g.egg_t < 0.0 and g.egg_streak == need - 1)
	g._ttl_throw(g.BC)
	_tick(land)
	_ok("서른 — 깨진다", g.egg_t >= 0.0, "t %.2f" % g.egg_t)
	_ok("조각이 난다", g.egg_shards.size() == 61, "%d" % g.egg_shards.size())
	_ok("꽂혀 있던 자루도 날아간다", g.ttl_stuck.is_empty())
	_ok("깨진 동안 판은 안 그린다", is_inf(g._egg_board_dy()))
	g._click(g.BC)
	_ok("판이 없으면 눌러도 안 던진다", g.ttl_fly.is_empty())
	_tick(int((float(g.EGG.fly) + float(g.EGG.hold) + 0.05) / D))
	var dy_rise: float = g._egg_board_dy()
	_ok("새 판이 밑에서 오른다", not is_inf(dy_rise) and dy_rise > 100.0, "%.0f" % dy_rise)
	_tick(int((float(g.EGG.rise) + 0.1) / D))
	_ok("다 오르면 제자리", g._egg_board_dy() == 0.0 and g.egg_t < 0.0)
	_ok("다 오르면 잇단 수가 처음부터", g.egg_streak == 0 and g.egg_stage == 0)
	_ok("새 판은 다른 금 무늬(씨 +1)", g.egg_seed == seed0 + 1, "%d → %d" % [seed0, g.egg_seed])
	g._click(g.BC)
	_ok("새 판에 다시 던질 수 있다", g.ttl_fly.size() == 1)

	#  제목을 뜨면 처음부터
	_title()
	g._egg_reset()
	g.egg_streak = 12
	g.state = g.S.COLLECT
	_tick(1)
	_ok("제목을 뜨면 잇단 수가 처음부터", g.egg_streak == 0)

	#  움직임 끄기 — 날리지 않고 바로 새 판
	_title()
	g._egg_reset()
	g.motion_off = true
	var seed1: int = g.egg_seed
	g.egg_streak = need - 1
	g._ttl_throw(g.BC)
	_ok("움직임을 끄면 바로 새 판", g.egg_t < 0.0 and g.egg_seed == seed1 + 1
			and g.egg_streak == 0, "t %.2f · 씨 %d" % [g.egg_t, g.egg_seed])
	g.motion_off = false

	# ── 소리 사다리 ─────────────────────────────────────
	#  제목과 판이 **같은 사다리**를 본다. 갈라지면 같은 자리를 물고
	#  다른 소리가 난다.
	var want := {"안쪽 불": [g.BC, 5],
			"바깥 불": [g.BC + Vector2(0.0,
					-g.R * (g.rt_bull_i + g.rt_bull_o) * 0.5) as Vector2, 4],
			"판 밖": [g.BC + Vector2(0.0, -g.R * 1.4) as Vector2, 0]}
	for nm in want:
		var p: Vector2 = want[nm][0]
		var info: Dictionary = g.hit_info(p)
		var got: int = g._hit_grade(info, int(info.mult))
		_ok("사다리 — %s" % nm, got == int(want[nm][1]),
				"등급 %d (바란 것 %d)" % [got, int(want[nm][1])])
	_ok("등급마다 소리가 있다", g.HIT_SFX.size() == 6,
			"%d개" % g.HIT_SFX.size())
