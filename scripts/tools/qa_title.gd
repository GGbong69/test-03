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
	g.ttl_wait = 99.0
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

	# ── 저절로 온다 ─────────────────────────────────────
	_title()
	g.ttl_wait = 0.005
	_tick(1)
	_ok("때가 되면 한 자루 난다", g.ttl_fly.size() == 1,
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
	g.ttl_wait = 999.0                  # _ttl_throw 가 다음 자루를 예약한다
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
	g.ttl_wait = 0.1                    # 첫 자루만 당긴다. 뒤는 제 간격대로
	for i in 5400:                      # 90초
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
	g._click(g._menu_rect(1).get_center())   # 「컬렉션」
	_ok("글줄은 여전히 글줄이다", g.state == g.S.COLLECT and g.ttl_fly.is_empty(),
			"state=%d" % g.state)

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
	g.ttl_wait = 0.005
	_tick(1)
	g.state = g.S.SETTINGS
	g.pause_from = -1
	_tick(30)
	_ok("설정 밑에서도 나던 자루는 꽂힌다",
			g.ttl_stuck.size() == 1 and g.ttl_fly.is_empty(),
			"꽂힘 %d" % g.ttl_stuck.size())
	#  **수가 는 적이 있는가**를 본다. 사는 시간이 7.2초라 10초를 밀면
	#  있던 자루가 제 시간에 지는데, 그것은 「새로 왔다」 가 아니다.
	var n0: int = g.ttl_stuck.size()
	var grew := false
	var pn: int = n0
	for i in 600:                       # 10초 — 저절로 오는 사이보다 길다
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
	g.ttl_wait = 0.005
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
	for i in 40:
		g._click(g.BC + Vector2(float(i % 7) * 9.0 - 27.0, float(i % 5) * 11.0 - 22.0))
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
