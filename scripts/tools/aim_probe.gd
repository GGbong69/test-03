extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  조준 방식 검사 — 여덟 갈래가 다 살아 있는가
#
#  실행:  godot --path . --headless --script scripts/tools/aim_probe.gd
#  종료 코드 = 실패 개수
#
#  오토플레이로는 이 자리를 못 잰다. _land 가 검증 실행일 때 aim 을 통째로
#  버리고 판 안 아무 데나 꽂기 때문이다 — 조준이 어디를 가리키든 판은
#  똑같이 진행되므로, 조준이 죽어도 소크는 오류 0 으로 통과한다.
#  그래서 여기서는 틱을 직접 몰고 착탄 자리를 직접 읽는다.
#
#  못 박는 것:
#    ① 방식마다 정해진 횟수만 잠근다 (AIM_STAGES). 한 번 잠그는 방식이
#       두 번째 칸으로 새면, 이미 정해진 자리를 두고 빈 칸을 또 눌러야 한다
#    ② 조준점이 실제로 움직인다 — 안 움직이면 아무 때나 눌러도 같은 자리다
#    ③ 조준점이 게이지 봉투를 안 벗어난다. 클릭 반경이 아니다 —
#       기본 게이지도 모서리에서 그 밖으로 나가고 그것이 빗나감이다
#    ④ 원 조준의 2단계가 1단계에서 잠근 원 **위**에 있다
#    ⑤ 놓기는 누른 자리에. 흔들은 커서를 따라다니고, 당김은 **끌고 온
#       거리가 아니라 놓는 순간의 속도**로 던진다 — 참고한 두 웹 게임의
#       방식이고, 처음에 둘 다 틀리게 만들었던 자리다
#    ⑥ 반동은 한 발이 여러 발이 된다 — 자루는 하나만 줄고, 꽂힌 자리가
#       모두 정산된다. 안 잡으면 발이 위로 걸어 올라간다
#    ⑦ 동전이 방식을 쥔다. 봉인되면 안 쥔다
#    ⑦ 여덟 갈래 전부 확인·비행을 지나 착탄까지 간다 (조준이 영영 안
#       잠기면 런이 통째로 막힌다)
# ══════════════════════════════════════════════════════════

const FPS := 1.0 / 60.0

var fails := 0
var lim := 0.0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-34s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	# 흔들 조준(drift)은 randf 로 떠돈다. 시드가 없어 "원을 가장자리까지
	# 쓴다"(worst > span*0.75) 가 다섯 번에 한 번꼴로 그냥 실패했다 —
	# 되는 코드에서 우연히 빨간불이 뜨는 검사는 그 뒤로 아무도 안 믿는다.
	#
	# 시드만으로는 안 됐다. 이 프로브만 Save.path 를 안 옮겨서 **사람의 실제
	# 저장**을 읽고 있었고, 해금 상태가 물건 풀을 바꿔 난수 소비 순서가
	# 달라졌다. 다른 프로브가 전부 지키는 규약이 여기만 빠져 있었다.
	Save.path = "user://_probe_aim.cfg"
	Save.wipe()
	seed(20260902)
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	# 흔들의 난수는 전역이 아니라 game.gd 의 aim_rng 다. RandomNumberGenerator
	# 는 만들 때 스스로 시드를 뽑으므로 전역 seed() 가 안 닿는다 — 여기를
	# 안 박으면 위 두 줄을 다 해도 값이 계속 흔들린다.
	g.aim_rng.seed = 20260902
	g.set_process(false)
	g._new_run()
	g._start_leg()
	# 조준점이 나갈 수 있는 끝. **클릭 반경이 아니다** — 기본 게이지는 두
	# 축이 각각 SWING 까지 가므로 모서리가 SWING*sqrt(2) 다. 그 바깥 띠가
	# 빗나감이고 설계대로다(aim_swing 110 : board_r 98 = 빗나감 37.68%).
	# 클릭 반경은 **잠글 수 있는 자리**를 정할 뿐, 조준선이 갈 수 있는
	# 데를 정하지 않는다. 이 선을 넘으면 조준이 화면 밖을 가리키는 것이다.
	lim = g.SWING * 1.45

	print("\n── 표 ────────────────────────────────────")
	_table()
	for m in GameData.AIM_MODES:
		print("\n── %s ─────────────────────────────────────" % m)
		_mode(g, m)
	print("\n── 누름과 뗌 ─────────────────────────────")
	_place(g)
	_pull(g)
	print("\n── 동전 ────────────────────────────────")
	_items(g)

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "조준 여덟 전부 통과"))
	quit(mini(fails, 125))


# ── 표: 이름과 잠그는 횟수가 짝이 맞는가 ────────────────
func _table() -> void:
	var bad := []
	for m in GameData.AIM_MODES:
		var st: int = GameData.AIM_STAGES.get(m, 0)
		if st < 1 or st > 2:
			bad.append(m)
	_say(bad.is_empty(), "모든 방식에 잠그는 횟수가 있다",
			"%d가지 · 빠진 것 %s" % [GameData.AIM_MODES.size(), bad])
	# 조준을 쥔 동전이 없는 방식은 런에서 영영 안 나온다 (기본은 빼고)
	var held := {}
	for it in GameData.items():
		var am := String(it.get("aim", ""))
		if am != "":
			held[am] = true
	var orphan := []
	for m in GameData.AIM_MODES:
		if m != "std" and not held.has(m):
			orphan.append(m)
	_say(orphan.is_empty(), "방식마다 그것을 쥔 동전이 있다",
			"쥔 방식 %d · 주인 없음 %s" % [held.size(), orphan])


# ── 방식 하나 ────────────────────────────────────────────
func _mode(g: Node, m: String) -> void:
	var stages: int = GameData.AIM_STAGES.get(m, 2)

	# ① 잠그는 횟수
	g.aim_mode = m
	g.state = g.S.AIM_V
	g._aim_begin()
	g._advance()
	var want: int = g.S.AIM_H if stages >= 2 else g.S.CONFIRM
	_say(g.state == want, "%s 는 %d번 잠근다" % [m, stages],
			"AIM_V 에서 한 번 잠그니 %s" % _sname(g, g.state))

	# ② 움직인다 · ③ 봉투 안에 있다
	# 당김은 여기서 안 잰다 — 쥐기 전에는 다트가 제자리에 가만히 있는
	# 것이 옳다. 움직임은 _pull 이 손을 흔들어 가며 따로 잰다.
	for stg in (range(stages) if m != "pull" and m != "kick" else []):
		var st: int = g.S.AIM_V if stg == 0 else g.S.AIM_H
		g.aim_mode = m
		g.state = g.S.AIM_V
		g._aim_begin()
		if stg == 1:
			_spin(g, m, 37)         # 1단계를 적당히 돌려 잠근 뒤
			g._advance()
		var seen := {}
		var out := 0
		for i in 300:
			_tick(g, m, i)
			seen[Vector2i(g.aim.round())] = true
			if (g.aim - g.BC).length() > lim + 0.5:
				out += 1
		_say(seen.size() >= 8, "%s %d단계가 움직인다" % [m, stg + 1],
				"서로 다른 자리 %d" % seen.size())
		_say(out == 0, "%s %d단계가 봉투 안에 있다" % [m, stg + 1],
				"봉투 %.0f 밖 %d틱" % [lim, out])

	# ④ 원·선은 잠근 원 위에 있다
	if m == "ring":
		g.state = g.S.AIM_V
		g._aim_begin()
		_spin(g, m, 37)
		var rr: float = g.aim_r
		g._advance()
		var worst := 0.0
		var half := [false, false]
		for i in 300:
			g._aim_tick(FPS)
			worst = maxf(worst, absf((g.aim - g.BC).length() - rr))
			half[0 if g.aim.x >= g.BC.x else 1] = true
		_say(rr > 8.0 and worst < 0.6, "%s 2단계가 잠근 원 위에 있다" % m,
				"반지름 %.1f · 최대 어긋남 %.3f" % [rr, worst])
		_say(half[0] and half[1], "%s 가 원의 양쪽을 다 훑는다" % m,
				"오른쪽 %s · 왼쪽 %s" % [half[0], half[1]])

	# 겹조준은 한 줄로 굳으면 아무 때나 눌러도 되는 방식이 된다
	if m == "cross":
		g.state = g.S.AIM_V
		g._aim_begin()
		var quad := {}
		for i in 900:
			g._aim_tick(FPS)
			quad[Vector2i(signi(int(g.aim.x - g.BC.x)), signi(int(g.aim.y - g.BC.y)))] = true
		_say(quad.size() >= 4, "%s 궤적이 한 줄로 안 굳는다" % m,
				"지나간 사분면 %d" % quad.size())

	if m == "drift":
		_drift(g)

	if m == "kick":
		_kick(g)
		return                     # 연발은 _throw 의 한 발 셈과 어긋난다

	# ⑦ 착탄까지 간다
	_throw(g, m, stages)


# 이 방식이 손을 읽는가 — 놓기·당김만 마우스를 본다
func _tick(g: Node, m: String, i: int) -> void:
	if m == "place" or m == "pull":
		var a := float(i) * 0.11
		g.mouse_at = g.BC + Vector2(cos(a), sin(a)) * (30.0 + float(i % 40))
	g._aim_tick(FPS)


func _spin(g: Node, m: String, n: int) -> void:
	for i in n:
		_tick(g, m, i)


func _sname(g: Node, s: int) -> String:
	for k in g.S.keys():
		if int(g.S[k]) == s:
			return String(k)
	return str(s)


# 다트를 집어 확인·비행을 지나 착탄까지. 조준이 영영 안 잠기는 방식이
# 있으면 여기서 걸린다 — 그 방식을 쥔 런은 통째로 못 넘어간다.
func _throw(g: Node, m: String, stages: int) -> void:
	# 앞선 방식이 자루를 다 썼으면 새 판을 연다 — 집을 다트가
	# 없으면 _pick_dart 가 조용히 돌아가고 상태가 PICK 에 굳는다.
	if g.remaining.is_empty():
		g._start_leg()
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = m                 # _pick_dart 는 방식을 안 건드린다. 못 박아 둔다
	g._aim_begin()
	var seen := {}
	var locks := 0
	var n := 0
	while n < 900 and not seen.has(g.S.RESOLVE):
		if (g.state == g.S.AIM_V or g.state == g.S.AIM_H) and n % 30 == 29:
			g._advance()
			locks += 1
		else:
			_tick(g, m, n) if (g.state == g.S.AIM_V or g.state == g.S.AIM_H) else g._process(FPS)
		seen[g.state] = true
		n += 1
	_say(seen.has(g.S.FLY) and seen.has(g.S.RESOLVE), "%s 가 착탄까지 간다" % m,
			"%d틱 · 잠금 %d회 · 지나온 칸 %d" % [n, locks, seen.size()])
	_say(locks == stages, "%s 는 잠금이 %d회로 끝난다" % [m, stages], "실제 %d회" % locks)


# ── 흔들: 커서 둘레를 떠돈다 ─────────────────────────────
#  참고한 게임(Darts: skill issue)은 "your cursor moves unpredictably
#  within a small circular area" 다. 판 한가운데를 도는 것이 아니라
#  **손을 따라다니는** 것이 이 방식의 전부다 — 처음에 그것을 놓쳤다.
func _drift(g: Node) -> void:
	var span: float = g.R * float(g.DRIFT.span)
	var worst := 0.0
	var seen := {}
	for spot in [g.BC + Vector2(-52.0, -30.0), g.BC + Vector2(44.0, 38.0)]:
		g.state = g.S.AIM_V
		g._aim_begin()
		g.mouse_at = spot
		var near := 0
		var path := 0.0
		var prev: Vector2 = g.aim
		for i in 600:
			g._aim_tick(FPS)
			path += prev.distance_to(g.aim)
			prev = g.aim
			worst = maxf(worst, g.aim.distance_to(spot))
			seen[Vector2i(g.aim.round())] = true
			if g.aim.distance_to(spot) <= span + 0.5:
				near += 1
		_say(near == 600, "흔들이 커서 %s 를 안 벗어난다" % spot,
				"반경 %.1f 안 %d/600" % [span, near])
		# **빠르기는 위아래 양쪽이 다 틀릴 수 있다.** 감쇠 랜덤워크는 가운데서
		# 속도가 죽어 멎어 보였고, 그 다음에는 초당 300px 로 파르르 떨었다.
		# 참고한 게임은 눈으로 따라갈 수 있게 어슬렁거린다 — 10초에 원
		# 지름의 서너 배에서 열 배 사이다.
		var laps := path / (span * 2.0)
		_say(laps > 3.0 and laps < 10.0, "흔들이 눈으로 따라갈 빠르기다",
				"10초에 %.0fpx = 지름의 %.1f배 (3~10 사이여야 한다)"
				% [path, laps])
	_say(seen.size() >= 60, "흔들이 실제로 떠돈다", "서로 다른 자리 %d" % seen.size())
	_say(worst > span * 0.75, "흔들이 원을 가장자리까지 쓴다",
			"가장 멀리 %.1f / %.1f" % [worst, span])


# ── 당김: 끌고 온 거리가 아니라 놓는 순간의 속도 ─────────
#  참고한 게임(Dartlatro)의 주석이 그대로 말한다 — "the dart flies in the
#  direction your hand is moving at the moment you let go, not the net
#  drag distance." 처음에는 당긴 **거리**로 만들었고 그것이 틀렸다.
func _flick(g: Node, from: Vector2, to: Vector2, secs: float, steps: int) -> void:
	g.mouse_down = true
	g.mouse_at = from
	g._pull_grab(from)
	var d := secs / float(steps)
	for i in steps:
		g.mouse_at = from.lerp(to, float(i + 1) / float(steps))
		g._aim_tick(d)


func _let_go(g: Node) -> void:
	g.mouse_down = false
	g._aim_tick(FPS)


func _pull(g: Node) -> void:
	# 던지는 자리는 **고른 자루가 꽂힌 데**다 — 자루가 있어야 한다
	if g.remaining.is_empty():
		g._start_leg()
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = "pull"
	var org: Vector2 = g._pull_org()
	_say(org.x < g.BC.x - g.R, "다트가 왼쪽 벽에서 떠난다",
			"출발 %s · 판 왼쪽 끝 %.0f" % [org, g.BC.x - g.R])

	# 벽을 눌러도 쥐어진다 — 판 위를 눌러야 한다는 규칙 밖이다
	g.state = g.S.AIM_V
	g._aim_begin()
	g._click(org)
	_say(g.pull_at.distance_to(org) < 0.6 and g.state == g.S.AIM_V,
			"벽에서 다트를 쥔다", "쥔 자리 %s · %s" % [g.pull_at, _sname(g, g.state)])

	# 쥐었다 가만히 놓으면 안 던진다. 착탄점으로 재면 벽에서 판까지의
	# 거리가 끼어들어 이것이 통과해 버린다 — 던지는 벡터로 재야 한다.
	g.state = g.S.AIM_V
	g._aim_begin()
	_flick(g, org, org, 0.30, 18)
	_let_go(g)
	_say(g.state == g.S.AIM_V and g.pull_at.x < 0.0,
			"가만히 놓으면 안 던지고 다시 쥐게 한다",
			"%s · 쥔 자리 %s" % [_sname(g, g.state), g.pull_at])

	# **같은 거리라도 느리면 안 나가고 빠르면 나간다** — 이 한 쌍이
	# "거리가 아니라 속도" 를 못 박는다
	var far := Vector2(120.0, 0.0)
	g.state = g.S.AIM_V
	g._aim_begin()
	_flick(g, org, org + far, 1.20, 72)
	_let_go(g)
	var slow_st: int = g.state
	g.state = g.S.AIM_V
	g._aim_begin()
	_flick(g, org, org + far, 0.08, 6)
	_let_go(g)
	var fast_st: int = g.state
	var fast_hit: Vector2 = g.aim
	_say(slow_st == g.S.AIM_V and fast_st == g.S.CONFIRM,
			"같은 거리라도 느리면 안 나가고 빠르면 나간다",
			"느리게 %s · 빠르게 %s" % [_sname(g, slow_st), _sname(g, fast_st)])
	_say(fast_st == g.S.CONFIRM, "빠르게 튕기면 던져진다", "착탄 %s" % fast_hit)

	# 눈금이 맞는가. 판 한가운데를 노리는 세기를 **상수에서 거꾸로 뽑아**
	# 던져 본다 — 손으로 적은 수를 두면 vs 를 만질 때마다 검사가 같이
	# 거짓말을 한다. 놓는 틱까지 창에 들어오므로 그만큼 더 끌어야 한다.
	var dt := 0.08 + FPS
	var aimed: Vector2 = (g.BC - org) / float(g.PULL.vs) * dt
	g.state = g.S.AIM_V
	g._aim_begin()
	_flick(g, org, org + aimed, 0.08, 6)
	_let_go(g)
	_say(g.aim.distance_to(g.BC) < g.R * 0.2, "한가운데를 노린 세기는 한가운데다",
			"착탄 %s · 중심에서 %.1f" % [g.aim, g.aim.distance_to(g.BC)])

	# 사람 손 눈금. 세기를 달리해도 흔한 손놀림이면 판에 얹혀야 한다 —
	# 이것이 깨지면 vs 가 사람이 못 내는 속도를 요구하고 있는 것이다.
	var on := 0
	for px in [70.0, 90.0, 110.0, 130.0]:
		g.state = g.S.AIM_V
		g._aim_begin()
		_flick(g, org, org + Vector2(px, 0.0), 0.08, 6)
		_let_go(g)
		if g.aim.distance_to(g.BC) <= g.R:
			on += 1
	_say(on >= 3, "흔한 세기로 튕기면 판에 얹힌다", "0.08초에 70~130px 중 %d/4" % on)

	# 튕기는 방향이 곧 겨냥이다
	g.state = g.S.AIM_V
	g._aim_begin()
	_flick(g, org, org + Vector2(120.0, -80.0), 0.08, 6)
	_let_go(g)
	var up: Vector2 = g.aim
	g.state = g.S.AIM_V
	g._aim_begin()
	_flick(g, org, org + Vector2(120.0, 80.0), 0.08, 6)
	_let_go(g)
	_say(up.y < g.aim.y - 20.0, "위로 튕기면 위에, 아래로 튕기면 아래에 꽂힌다",
			"위 %.0f · 아래 %.0f" % [up.y, g.aim.y])

	# 세게 튕길수록 멀리 간다
	g.state = g.S.AIM_V
	g._aim_begin()
	_flick(g, org, org + Vector2(70.0, 0.0), 0.08, 6)
	_let_go(g)
	var soft: float = g.aim.distance_to(org)
	g.state = g.S.AIM_V
	g._aim_begin()
	_flick(g, org, org + Vector2(150.0, 0.0), 0.08, 6)
	_let_go(g)
	_say(g.aim.distance_to(org) > soft + 8.0, "세게 튕길수록 멀리 간다",
			"약하게 %.0f · 세게 %.0f" % [soft, g.aim.distance_to(org)])


# ── 반동: 한 발이 여러 발 ────────────────────────────────
#  FPS 의 스프레이다. 쏠 때마다 조준이 위로 밀리고 손이 눌러 잡는다.
#  이 게임의 정산은 발마다 카드가 뜨는 애니메이션이라 연발 중에는 못
#  돌린다 — 다 쏜 뒤에 꽂힌 자리를 하나씩 판다. 그 두 토막이 다
#  이어지는지가 여기서 걸린다.
func _kick(g: Node) -> void:
	if g.remaining.is_empty():
		g._start_leg()
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = "kick"
	g._aim_begin()
	var n: int = GameData.tune_i("kick_n")
	var spot: Vector2 = g.BC + Vector2(0.0, 30.0)
	g.mouse_at = spot

	# 누름은 방아쇠다 — 그 자리에서 잠기면 안 된다
	g._click(spot)
	_say(g.state == g.S.AIM_V and g.burst_left == n,
			"누르면 연발이 시작되고 그 자리에서 안 잠긴다",
			"%s · 남은 발 %d/%d" % [_sname(g, g.state), g.burst_left, n])

	# 손을 안 움직이면 발이 위로 걸어 올라간다
	var guard := 0
	while g.burst_left > 0 and guard < 600:
		g._aim_tick(FPS)
		guard += 1
	_say(g.burst_hits.size() == n, "연발이 %d발을 꽂는다" % n,
			"%d발 · %d틱" % [g.burst_hits.size(), guard])
	_say(g.state == g.S.CONFIRM, "마지막 발이 나가면 잠긴다", _sname(g, g.state))
	var climb: float = float(g.burst_hits[0].y) - float(g.burst_hits[n - 1].y)
	_say(climb > float(g.KICK.up) * float(n - 1) * 0.6,
			"안 잡으면 발이 위로 걸어 올라간다",
			"첫 발 y %.0f → 끝 발 y %.0f (%.0fpx 위로)"
			% [g.burst_hits[0].y, g.burst_hits[n - 1].y, climb])

	# 손을 내리면 잡힌다 — 반동만큼 따라 내린다
	g.state = g.S.AIM_V
	g._aim_begin()
	g.mouse_at = spot
	g._click(spot)
	guard = 0
	while g.burst_left > 0 and guard < 600:
		g.mouse_at = spot + Vector2(0.0, -g.kick_o.y)   # 밀린 만큼 눌러 잡는다
		g._aim_tick(FPS)
		guard += 1
	var held := 0.0
	for h in g.burst_hits:
		held = maxf(held, absf(float(h.y) - spot.y))
	_say(held < 6.0, "손으로 누르면 발이 한자리에 모인다",
			"가장 벗어난 발 %.1fpx" % held)

	# 다 쏜 뒤 꽂힌 자리가 하나씩 정산된다. 자루는 하나만 준다.
	var before: int = g.remaining.size()
	var marks: int = g.darts.size()
	var seen := {}
	var tick := 0
	while tick < 3000 and not seen.has(g.S.RESOLVE):
		g._process(FPS)
		seen[g.state] = true
		tick += 1
	while tick < 3000 and not g.burst_hits.is_empty():
		g._process(FPS)
		tick += 1
	_say(g.burst_hits.is_empty(), "꽂힌 자리를 하나도 안 남기고 다 판다",
			"남은 자리 %d · %d틱" % [g.burst_hits.size(), tick])
	_say(g.remaining.size() == before - 1, "연발이어도 자루는 하나만 쓴다",
			"%d → %d" % [before, g.remaining.size()])
	_say(g.darts.size() == marks, "정산이 다트를 두 번 안 꽂는다",
			"쏠 때 %d개 · 정산 뒤 %d개" % [marks, g.darts.size()])

	# 연발을 잇달아 세 번. 발과 발 사이에 남는 상태가 있으면 여기서
	# 걸린다 — **오토플레이는 이 길을 못 걷는다.** 반동 동전을 안 들고,
	# _auto_step 은 조준 칸에서 그냥 _advance 를 부르기 때문이다.
	g._start_leg()
	g.target = 999999          # 판이 중간에 끝나면 셈이 어긋난다
	var d0: int = g.remaining.size()
	var m0: int = g.darts.size()
	var shots := 0
	var t2 := 0
	while shots < 3 and t2 < 9000:
		var idle: bool = g.burst_left <= 0 and g.burst_hits.is_empty()
		if idle and (g.state == g.S.PICK or g.state == g.S.AIM_V):
			if g.state == g.S.PICK:
				g._pick_dart(0)
			g.aim_mode = "kick"
			g.mouse_at = spot
			g._click(spot)
			shots += 1
		g._process(FPS)
		t2 += 1
	while t2 < 9000 and not g.burst_hits.is_empty():
		g._process(FPS)
		t2 += 1
	_say(g.remaining.size() == d0 - 3, "연발 셋이 자루 셋만 쓴다",
			"%d → %d" % [d0, g.remaining.size()])
	_say(g.darts.size() == m0 + n * 3, "연발 셋이 작은 다트 %d개를 꽂는다" % (n * 3),
			"%d → %d" % [m0, g.darts.size()])
	# 발마다 정산 애니메이션이 한 번씩 돈다. 한 발이 다섯 발이 되면
	# 기다리는 시간도 다섯 배다 — 점수를 어떻게 셀지 정할 때 같이 볼 수
	# 있게 재어 둔다. 실패로 안 만드는 것은 아직 정한 값이 없어서다.
	# 걸음 빠르기. **짧은 정산은 안 건드린다** — 맨 다트 한 발이 갑자기
	# 빨라지면 게임 전체의 박자가 바뀐 것이고, 그건 부탁받은 일이 아니다.
	g.burst_n = 0
	g.settle_n = 3
	var p_bare: float = g._pace()
	g.settle_n = 14
	var p_many: float = g._pace()
	g.settle_n = 3
	g.burst_n = GameData.tune_i("kick_n")
	var p_kick: float = g._pace()
	g.burst_n = 0
	_say(is_equal_approx(p_bare, 1.0), "맨 다트 한 발은 박자가 그대로다",
			"걸음 셋 → 배수 %.2f" % p_bare)
	_say(p_many < 0.7 and p_many > p_kick, "동전이 줄줄이면 걸음이 재진다",
			"걸음 열넷 → 배수 %.2f" % p_many)
	_say(p_kick <= float(g.PACE.min) + 0.001, "연발은 가장 재게 돈다",
			"배수 %.2f (바닥 %.2f)" % [p_kick, g.PACE.min])

	_say(true, "연발 한 번을 정산하는 데 걸리는 시간",
			"%.1f초 (한 발당 %.1f초 · 발마다 카드가 뜬다)"
			% [float(t2) * FPS / 3.0, float(t2) * FPS / float(n * 3)])

	# 작은 다트는 점수를 **조금씩만** 받는다. 동전을 다 뺀 맨 판에서
	# 같은 자리(불)에 보통 한 발과 연발 다섯 발을 꽂아 견준다 — 이 비가
	# 반동의 세기다. 기본 점수만 깎고 동전을 안 깎으면 여기서 안 걸리므로
	# 동전 슬롯을 비우고 재는 것이 아니라, 동전 슬롯을 채워서도 한 번 더 잰다.
	var one := _score_at(g, "std", g.BC)
	var five := _score_at(g, "kick", g.BC)
	var want := float(GameData.tune("kick_share")) * float(n)
	_say(one > 0 and five > 0, "맨 판에서 둘 다 점수가 난다",
			"보통 %d점 · 연발 다섯 %d점" % [one, five])
	_say(absf(float(five) / maxf(float(one), 1.0) - want) < want * 0.35,
			"연발 다섯이 보통 한 발의 %.2f배쯤이다" % want,
			"실제 %.2f배 (한 발당 %d%%)"
			% [float(five) / maxf(float(one), 1.0),
				int(round(GameData.tune("kick_share") * 100.0))])

	# 점수 동전을 한 장 얹어도 몫이 지켜지는가 — 기본 점수만 깎았다면 여기서
	# 연발 쪽이 훌쩍 커진다(동전이 발마다 온전히 얹히기 때문이다).
	var chip := _item(g, "chip")
	if not chip.is_empty():
		g.owned = [chip]
		var one2 := _score_at(g, "std", g.BC, false)
		var five2 := _score_at(g, "kick", g.BC, false)
		g.owned = []
		_say(absf(float(five2) / maxf(float(one2), 1.0) - want) < want * 0.35,
				"동전을 얹어도 몫이 지켜진다",
				"%s 얹고 — 보통 %d점 · 연발 %d점 (%.2f배)"
				% [chip.n, one2, five2, float(five2) / maxf(float(one2), 1.0)])


# 조건 없는 점수 동전 한 장. 연발이 발마다 이걸 온전히 받으면 몫이 깨진다.
func _item(g: Node, kind: String) -> Dictionary:
	for it in GameData.items():
		if String(it.get("k", "")) == kind and String(it.get("c", "")) == "always" \
				and String(it.get("grow", "")) == "" and String(it.get("per", "")) == "":
			return it.duplicate()
	return {}


# 한 자리에 꽂고 정산이 끝날 때까지 돌린 뒤 그 판의 점수를 낸다.
func _score_at(g: Node, mode: String, p: Vector2, wipe := true) -> int:
	if wipe:
		g.owned = []
		g.sealed = -1
	if g.remaining.size() < 2:
		g._start_leg()
	g.target = 999999          # 판이 중간에 끝나면 정산이 잘린다
	g.total = 0
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = mode
	g._aim_begin()
	g.mouse_at = p
	var t := 0
	if mode == "kick":
		g._click(p)
		while g.burst_left > 0 and t < 900:
			g.mouse_at = p + Vector2(0.0, -g.kick_o.y)   # 반동을 눌러 잡는다
			g._aim_tick(FPS)
			t += 1
	else:
		g._advance()
		if int(GameData.AIM_STAGES.get(mode, 2)) >= 2:
			g._advance()
		g.aim = p
	while t < 6000 and (g.state == g.S.CONFIRM or g.state == g.S.FLY
			or g.state == g.S.RESOLVE or not g.burst_hits.is_empty()):
		g._process(FPS)
		t += 1
	return int(g.total)


# ── 놓기: 누른 자리가 곧 꽂히는 자리 ─────────────────────
func _place(g: Node) -> void:
	g.aim_mode = "place"
	g.state = g.S.AIM_V
	g._aim_begin()
	var p: Vector2 = g.BC + Vector2(40.0, -25.0)
	g._click(p)
	_say(g.aim.distance_to(p) < 0.6, "놓기는 누른 자리에 꽂힌다",
			"누른 %s · 조준 %s" % [p, g.aim])
	_say(g.state == g.S.CONFIRM, "놓기는 한 번에 잠긴다", _sname(g, g.state))

	g.state = g.S.AIM_V
	var before: Vector2 = g.aim
	g._click(g.BC + Vector2(0.0, -lim - 30.0))
	_say(g.state == g.S.AIM_V and g.aim == before, "판 밖을 누르면 안 잠긴다",
			"%s · 조준 그대로 %s" % [_sname(g, g.state), g.aim == before])


# ── 동전이 방식을 쥔다 ─────────────────────────────────
func _items(g: Node) -> void:
	var n := 0
	for it in GameData.items():
		var am := String(it.get("aim", ""))
		if am == "":
			continue
		n += 1
		g.owned = [it.duplicate()]
		g.sealed = -1
		_say(g._aim_from_items() == am, "%s 가 %s 를 쥔다" % [it.n, am],
				g._aim_from_items())
	_say(n > 0, "조준을 쥔 동전이 있다", "%d장" % n)

	# 봉인된 장은 이번 판에 일을 안 한다 — 조준도 마찬가지다
	for it in GameData.items():
		if String(it.get("aim", "")) != "":
			g.owned = [it.duplicate()]
			g.sealed = 0
			_say(g._aim_from_items() == "std", "봉인된 조준 동전은 안 쥔다",
					g._aim_from_items())
			break
	g.owned = []
	g.sealed = -1
