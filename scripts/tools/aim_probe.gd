extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  조준 방식 검사 — 여덟 갈래가 다 살아 있는가
#
#  실행:  godot --path . --headless --script scripts/tools/aim_probe.gd
#  종료 코드 = 실패 개수
#
#  오토플레이로는 이 자리를 못 잰다. _land 가 검증 실행일 때 aim 을 통째로
#  버리고 판 안 아무 데나 꽂기 때문이다 — 조준이 어디를 가리키든 라운드는
#  똑같이 진행되므로, 조준이 죽어도 소크는 오류 0 으로 통과한다.
#  그래서 여기서는 틱을 직접 몰고 착탄 자리를 직접 읽는다.
#
#  못 박는 것:
#    ① 방식마다 정해진 횟수만 잠근다 (AIM_STAGES). 한 번 잠그는 방식이
#       두 번째 칸으로 새면, 이미 정해진 자리를 두고 빈 칸을 또 눌러야 한다
#    ② 조준점이 실제로 움직인다 — 안 움직이면 아무 때나 눌러도 같은 자리다
#    ③ 조준점이 게이지 봉투를 안 벗어난다. 클릭 반경이 아니다 —
#       기본 게이지도 모서리에서 그 밖으로 나가고 그것이 빗나감이다
#    ④ 원·선 조준의 2단계가 1단계에서 잠근 원 **위**에 있다
#    ⑤ 놓기는 누른 자리에, 당김은 뗀 순간에 — 누름과 뗌의 뜻이 방식마다 다르다
#    ⑥ 스티커가 방식을 쥔다. 봉인되면 안 쥔다
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
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g._new_run()
	g._start_round()
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
	print("\n── 스티커 ────────────────────────────────")
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
	# 조준을 쥔 스티커가 없는 방식은 런에서 영영 안 나온다 (기본은 빼고)
	var held := {}
	for it in GameData.items():
		var am := String(it.get("aim", ""))
		if am != "":
			held[am] = true
	var orphan := []
	for m in GameData.AIM_MODES:
		if m != "std" and not held.has(m):
			orphan.append(m)
	_say(orphan.is_empty(), "방식마다 그것을 쥔 스티커가 있다",
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

	# ② 움직인다 · ③ 판 안에 있다
	for stg in range(stages):
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
	if m == "ring" or m == "ray":
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

	# 겹조준·흔들은 한 줄로 굳으면 아무 때나 눌러도 되는 방식이 된다
	if m == "cross" or m == "drift":
		g.state = g.S.AIM_V
		g._aim_begin()
		var quad := {}
		for i in 900:
			g._aim_tick(FPS)
			quad[Vector2i(signi(int(g.aim.x - g.BC.x)), signi(int(g.aim.y - g.BC.y)))] = true
		_say(quad.size() >= 4, "%s 궤적이 한 줄로 안 굳는다" % m,
				"지나간 사분면 %d" % quad.size())

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
	# 앞선 방식이 자루를 다 썼으면 새 라운드를 연다 — 집을 다트가
	# 없으면 _pick_dart 가 조용히 돌아가고 상태가 PICK 에 굳는다.
	if g.remaining.is_empty():
		g._start_round()
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


# ── 당김: 누름은 쥐는 것, 뗌이 던지는 것 ──────────────────
func _pull(g: Node) -> void:
	g.aim_mode = "pull"
	g.state = g.S.AIM_V
	g._aim_begin()
	var p: Vector2 = g.BC + Vector2(20.0, 10.0)
	g._click(p)
	_say(g.state == g.S.AIM_V, "당김은 누를 때 안 잠긴다", _sname(g, g.state))
	_say(g.pull_at.distance_to(p) < 0.6, "당김이 쥔 자리를 기억한다", str(g.pull_at))

	# 헤드리스는 버튼이 눌린 적이 없다 — 다음 틱이 곧 "놓는 순간" 이다
	g.mouse_at = p + Vector2(0.0, g.PULL.ideal)
	g._aim_tick(FPS)
	_say(g.aim.distance_to(p) < 1.0, "알맞게 당기면 짚은 자리에 꽂힌다",
			"짚은 %s · 조준 %s" % [p, g.aim])
	_say(g.state == g.S.CONFIRM, "놓는 순간 던진다", _sname(g, g.state))

	g.state = g.S.AIM_V
	g._aim_begin()
	g.pull_at = p
	g.mouse_at = p + Vector2(0.0, g.PULL.ideal + 40.0)
	var far: Vector2 = g._pull_point()
	g.mouse_at = p + Vector2(0.0, g.PULL.ideal - 40.0)
	var near: Vector2 = g._pull_point()
	_say(far.y < p.y - 1.0 and near.y > p.y + 1.0,
			"더 당기면 지나가고 덜 당기면 못 미친다",
			"과 %.1f · 짚은 %.1f · 부족 %.1f" % [far.y, p.y, near.y])


# ── 스티커가 방식을 쥔다 ─────────────────────────────────
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
	_say(n > 0, "조준을 쥔 스티커가 있다", "%d장" % n)

	# 봉인된 장은 이번 판에 일을 안 한다 — 조준도 마찬가지다
	for it in GameData.items():
		if String(it.get("aim", "")) != "":
			g.owned = [it.duplicate()]
			g.sealed = 0
			_say(g._aim_from_items() == "std", "봉인된 조준 스티커는 안 쥔다",
					g._aim_from_items())
			break
	g.owned = []
	g.sealed = -1
