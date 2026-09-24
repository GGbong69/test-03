extends SceneTree

#  한 발의 결 — 꽂힌 각 · 확인/비행 넘기기 · 착탄에 뜨는 값 · 타격 사다리.
#    godot --path . --headless --script scripts/tools/qa_throw.gd
#
#  2026-09-24 에 고친 넷을 못 박는다. 넷 다 **눈으로만 보이던 것**이라
#  자가 없었고, 그래서 두 줄이 서로 자리를 바꿔 박힌 채로 오래 살았다.
#    ① 꽂힌 자루의 각 — 보통 발은 나는 동안의 각을 잇고, 연발은 발마다 구른다
#    ② 확인·비행 — 누르면 다음 프레임에 **원래 길로** 끝난다(건너뛰기가 아니다)
#    ③ 착탄 글자 — 갈래 이름이 아니라 **수**이고, 그 수가 칸 값 × 자리 배수다
#    ④ 타격 사다리 — 판펀치 여섯이 단조로 오르고 이웃끼리 화면에서 갈린다
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0
const DT := 1.0 / 60.0


func _initialize() -> void:
	Save.gpath = "user://_qa_throw_g.cfg"
	Save.path = "user://_qa_throw.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c:
		okn += 1
	else:
		fail += 1
	print("  %s %-40s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _fresh() -> void:
	g._new_run()
	g._start_leg()
	g.swap_live = false
	g.state = g.S.PICK
	g._pick_dart(0)


#  판 꼭대기 칸으로 반지름 f*R 인 점
func _at(f: float) -> Vector2:
	return g.BC + Vector2(0.0, -g.R * f)


#  i 번 칸 한가운데로 반지름 f*R 인 점. hit_info 의 각 셈을 거꾸로 푼다 —
#  ang = idx * _sec_w() 가 그 칸의 중심이고, v = (sin, -cos) * r 이다.
func _at_sec(i: int, f: float) -> Vector2:
	var a: float = float(i) * g._sec_w()
	return g.BC + Vector2(sin(a), -cos(a)) * (g.R * f)


func _run() -> void:
	for i in 8:
		g._process(DT)
	print("\n한 발의 결 검사\n")

	# ── ① 꽂힌 자루의 각 ────────────────────────────────
	#  보통 발은 **나는 동안 쓴 각을 그대로** 잇는다. 여기서 다시 구르면
	#  던지는 12프레임을 다 보고 마지막에 자루가 홱 돈다.
	_fresh()
	var same := true
	var seen := []
	for k in 6:
		g.darts.clear()
		g.aim = _at(0.35 + 0.06 * float(k))
		g.state = g.S.FLY
		g.fly_rot = randf_range(-0.26, 0.26)
		var want: float = g.fly_rot
		g._land()
		if g.darts.is_empty() or absf(float(g.darts[0].rot) - want) > 0.0001:
			same = false
		seen.append(want)
	_ok("보통 발은 나는 동안의 각을 잇는다", same, "여섯 발")
	#  연발은 S.FLY 를 안 지나 fly_rot 이 한 번도 안 갱신된다 — 여기서
	#  fly_rot 을 쓰면 **여섯 발이 각 하나를 돌려 써서** 자로 잰 듯 나란해진다.
	_fresh()
	g.darts.clear()
	g.fly_rot = 0.11                       # 안 갱신된 채 남은 값
	g.burst_left = 6
	g.burst_n = 6
	var rots := []
	for k2 in 6:
		g.aim = _at(0.30 + 0.07 * float(k2))
		g.burst_left = 6 - k2              # 마지막 발이 _advance 를 부르지 않게
		g._kick_fire()
	for e in g.darts:
		rots.append(float(e.rot))
	var uniq := {}
	for r in rots:
		uniq["%.6f" % r] = true
	_ok("연발은 발마다 각이 새로 구른다", uniq.size() == rots.size(),
			"%d발 · 서로 다른 각 %d" % [rots.size(), uniq.size()])
	var in_range := true
	for r in rots:
		if absf(r) > 0.26:
			in_range = false
	_ok("연발의 각이 ±0.26 안이다", in_range and not rots.is_empty(), str(rots.size()) + "발")

	# ── ② 확인 · 비행을 눌러 넘긴다 ─────────────────────
	#  **건너뛰기가 아니다** — 시계를 끝까지 밀 뿐이라 다음 프레임에 원래
	#  길이 그대로 끝난다. again_aim(덤 한 발이 읽는 자리)이 그 증거다.
	_fresh()
	g.aim = _at(0.61)
	g.state = g.S.CONFIRM
	g.confirm_t = 0.0
	g.again_aim = Vector2(-1.0, -1.0)
	g._click(Vector2(-1.0, -1.0))
	_ok("누르면 확인 시계가 창 끝에 선다", absf(g.confirm_t - g.ch()) < 0.0001,
			"%.3f / %.3f" % [g.confirm_t, g.ch()])
	g._process(DT)
	_ok("다음 프레임에 비행으로 넘어간다", g.state == g.S.FLY, "state %d" % g.state)
	_ok("원래 길을 지났다 — 덤 한 발 자리가 섰다", g.again_aim.x >= 0.0,
			str(g.again_aim))
	g.fly_t = 0.0
	g._click(Vector2(-1.0, -1.0))
	_ok("누르면 비행 시계가 창 끝에 선다",
			absf(g.fly_t - GameData.tune("fly_time")) < 0.0001,
			"%.3f / %.3f" % [g.fly_t, GameData.tune("fly_time")])
	var n0: int = g.darts.size()
	g._process(DT)
	_ok("다음 프레임에 꽂힌다", g.darts.size() > n0 and g.state == g.S.RESOLVE,
			"자루 %d → %d · state %d" % [n0, g.darts.size(), g.state])

	# ── ③ 착탄에 뜨는 값 ────────────────────────────────
	#  글자가 **수**여야 한다. 갈래 이름(「트리플」)은 칸이 이미 말한다.
	_fresh()
	var zones := {
		"싱글": (g.rt_bull_o + g.rt_trp_in) * 0.5,
		"트리플": (g.rt_trp_in + g.rt_trp_out) * 0.5,
		"더블": (g.rt_dbl_in + g.rt_dbl_out) * 0.5,
		"이너 불": g.rt_bull_i * 0.3,
	}
	for z in zones:
		g.pops.clear()
		var p := _at(float(zones[z]))
		var hi: Dictionary = g.hit_info(p)
		g.aim = p
		g._impact(hi, int(hi.mult))
		var got := "" if g.pops.is_empty() else String(g.pops[g.pops.size() - 1].txt)
		var want2 := "%d" % (int(hi.sector) * maxi(int(hi.mult), 1))
		_ok("%s 에 값이 뜬다" % z, got == want2, "「%s」 (칸 %d × 배수 %d)"
				% [got, int(hi.sector), int(hi.mult)])
	#  빗나감만 글자가 없다 — 대신 물결이 하나 인다(등급 1~5 는 전부 있는데
	#  0 만 없어서 화면에 아무 일도 안 일어났다).
	g.pops.clear()
	g.waves.clear()
	var pm := _at(g.rt_dbl_out + 0.10)
	var him: Dictionary = g.hit_info(pm)
	g.aim = pm
	g._impact(him, int(him.mult))
	_ok("빗나감에는 글자가 없다", g.pops.is_empty(), "%d장" % g.pops.size())
	_ok("빗나감에도 물결이 하나 인다", g.waves.size() >= 1, "%d개" % g.waves.size())

	# ── ④ 타격 사다리 ──────────────────────────────────
	#  여섯 등급이 네 값에 앉아 있었다(3·4·5 가 전부 1.0). push 는
	#  1 + board_punch × 0.028 이라 테 108px 에서 화면 px 로 환산해 잰다.
	var pts := []
	var probe := {
		0: pm,
		1: _at((g.rt_bull_o + g.rt_trp_in) * 0.5),
		2: _at((g.rt_dbl_in + g.rt_dbl_out) * 0.5),
		3: _at((g.rt_trp_in + g.rt_trp_out) * 0.5),
		4: _at((g.rt_bull_i + g.rt_bull_o) * 0.5),
		5: _at(g.rt_bull_i * 0.3),
	}
	for gr in probe:
		var pp: Vector2 = probe[gr]
		var hh: Dictionary = g.hit_info(pp)
		g.aim = pp
		g.board_punch = 0.0
		g._impact(hh, int(hh.mult))
		pts.append(g.board_punch * 0.028 * 108.0)
	var rise := true
	var gap_ok := true
	var worst := 99.0
	for i2 in range(1, pts.size()):
		if float(pts[i2]) <= float(pts[i2 - 1]):
			rise = false
		var d2: float = float(pts[i2]) - float(pts[i2 - 1])
		worst = minf(worst, d2)
		if d2 < 0.40:
			gap_ok = false
	var shown := []
	for v in pts:
		shown.append("%.2f" % float(v))
	_ok("판펀치가 등급마다 오른다", rise, str(shown) + "px")
	#  0.40px 은 640×360 을 정수 두 배로 키운 화면에서 **한 픽셀**이 갈리는 선이다.
	_ok("이웃 등급이 화면에서 갈린다", gap_ok, "가장 좁은 걸음 %.2fpx" % worst)

	# ── ⑤ 착탄 값이 죽이는 축을 지난다 ──────────────────
	#  ⚠ **한 번 크게 틀렸던 자리다.** 값을 info.sector 에서 떴는데 그것은
	#  hit_info 가 낸 날것이라, _land 가 그 뒤에 지나는 금줄 · 색 · 홀짝 ·
	#  「목표물」 · 칠을 한 번도 안 탔다. 「목표물」 런에서는 카드가 0 인데
	#  판 위에 「60」이 떴다 — 판 위 가장 큰 글자가 발마다 거짓이었다.
	#  갈래 이름(「트리플」)은 틀릴 수가 없어서 이 병이 안 보였다.
	#  아래 둘은 **글자와 카드가 같은 수를 말하는가**만 묻는다. 2026-09-25

	#  ⓐ 금줄이 죽인 칸 — 0점이면 글자가 아예 없다(0 을 적으면 빗나감과
	#     같은 말이 되는데, 빗나감은 글자가 없다).
	_fresh()
	var ptr := _at((g.rt_trp_in + g.rt_trp_out) * 0.5)
	var hit0: Dictionary = g.hit_info(ptr)
	g.pops.clear()
	g.dead_idx = int(hit0.idx)
	g.aim = ptr
	g.state = g.S.FLY
	g._land()
	_ok("금줄이 죽인 칸에는 값이 안 뜬다", g.pops.is_empty(),
			"칸 %d · %d장" % [int(hit0.sector), g.pops.size()])

	#  ⓑ 홀짝 보정이 곱한 칸 — 글자도 같이 곱해져야 한다. 날것을 적으면
	#     여기서 옛 수가 그대로 나온다.
	var odd_i := -1
	for si in g.sectors.size():
		if int(g.sectors[si]) % 2 == 1:
			odd_i = si
			break
	if odd_i < 0:
		_ok("홀수 칸이 판에 있다", false, "못 찾음")
	else:
		_fresh()
		var pod := _at_sec(odd_i, (g.rt_trp_in + g.rt_trp_out) * 0.5)
		var hod: Dictionary = g.hit_info(pod)
		g.pops.clear()
		g.odd_mul = 3.0
		g.aim = pod
		g.state = g.S.FLY
		g._land()
		var got3 := "" if g.pops.is_empty() else String(g.pops[g.pops.size() - 1].txt)
		var want3 := "%d" % (int(hod.sector) * 3 * maxi(int(hod.mult), 1))
		var raw3 := "%d" % (int(hod.sector) * maxi(int(hod.mult), 1))
		_ok("홀짝이 곱한 칸은 곱해진 값이 뜬다", got3 == want3,
				"「%s」 want %s · 날것이면 %s" % [got3, want3, raw3])

	print("\n%s" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
