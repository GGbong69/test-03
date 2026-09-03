extends SceneTree

const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  판에 꽂힌 다트(3D) 검사
#
#  실행:  godot --path . --quit-after 4000 --script scripts/tools/bdart_probe.gd
#  종료 코드 = 실패 개수
#
#  통(cup_probe)과 같은 이유로 있다 — 뷰포트는 화면에 안 보이므로
#  뒤에 남아 돌아도 눈으로는 영영 못 잡는다. 판은 통보다 나가는 길이
#  더 많다(상점 · 제목 · 런 끝 · 다음 판).
#
#  헤드리스로는 못 돈다. 3D 렌더러가 있어야 뷰포트가 선다.
#
#  재는 것
#    ① 촉이 착탄점에 **정확히** 온다 — 3D 가 2D 판정과 어긋나면 안 된다
#    ② 꽁지는 눈 쪽으로 서고, 축에서 멀수록 화면에 길게 비친다
#    ③ 던질수록 자루가 늘고 판이 바뀌면 0 으로 돌아간다
#    ④ 판이 아닌 화면으로 나가면 뷰포트가 지워진다
#    ⑤ 판 갈이가 도는 동안은 안 지워진다 — 판이 아직 화면에 있다
#    ⑥ 원근의 세기가 2D 받침과 같은 수에서 나온다
# ══════════════════════════════════════════════════════════

var g = null
var busy := false
var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-34s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	Save.path = "user://_probe_bdart.cfg"
	Save.wipe()
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


# 3D 자세에서 촉이 화면 어디에 오는가. z=0 이므로 월드 1 = 화면 1px 이고
# 부호만 뒤집으면 된다 — 이 환산이 곧 무대의 규약이다.
func _tip_screen(t: Transform3D) -> Vector2:
	var tip: Vector3 = t * Vector3(0.0, -float(g.BD3.len) * 0.5, 0.0)
	return g.BC + Vector2(tip.x, -tip.y)


func _run() -> void:
	await _wait(4)
	g._new_run()
	g._start_leg()
	g._swap_skip()

	# ① 촉이 착탄점에 온다
	var pts := [g.BC, g.BC + Vector2(0.0, -88.0), g.BC + Vector2(62.0, 40.0),
			g.BC + Vector2(-130.0, 96.0)]
	var worst := 0.0
	for p in pts:
		var e := {"p": p, "id": "std", "rot": 0.17}
		worst = maxf(worst, (_tip_screen(g._bd3_pose(e)) - p).length())
	_say(worst < 0.01, "촉이 착탄점에 정확히 온다", "최대 어긋남 %.5f px" % worst)

	# ② 꽁지는 눈 쪽이고, 멀수록 길게 비친다
	var lens := []
	for r in [0.0, 30.0, 60.0, 98.0]:
		var e := {"p": g.BC + Vector2(0.0, -r), "id": "std", "rot": 0.0}
		var t: Transform3D = g._bd3_pose(e)
		var tail: Vector3 = t * Vector3(0.0, float(g.BD3.len) * 0.5, 0.0)
		# 원근 투영 — 꽁지가 눈에 가까우니 축에서 더 멀리 찍힌다
		var d: float = g._bd3_eye()
		var s: float = d / (d - tail.z)
		lens.append((g.BC + Vector2(tail.x, -tail.y) * s - (g.BC + Vector2(0.0, -r))).length())
	var grows := true
	for i in range(1, lens.size()):
		if lens[i] <= lens[i - 1]:
			grows = false
	_say(grows, "축에서 멀수록 길게 비친다",
			"r 0·30·60·98 → %.1f · %.1f · %.1f · %.1f px"
			% [lens[0], lens[1], lens[2], lens[3]])
	# 정확히 0 은 아니다 — BD3.rise 만큼 꽁지가 들려 있다. 그 기울기가
	# 원근보다 작아야 "불은 점" 이 성립하므로, 판 끝 길이의 1/4 로 잡는다.
	_say(lens[0] < lens[3] * 0.25, "불에 꽂힌 발은 정면으로 뭉친다",
			"불 %.2f px · 판 끝 %.1f px" % [lens[0], lens[3]])

	# ⑥ 원근의 세기가 2D 받침과 같은 수에서 나온다
	#    길이를 통째로 견주면 안 된다 — 거기에는 꽁지 기울기(BD3.rise)
	#    몫이 상수로 얹혀 있다. 12시 선에서 그 몫은 반지름과 무관하므로
	#    끝에서 불을 빼면 순수한 원근만 남는다.
	var want: float = float(g.DART_PERSP) * 98.0
	var got: float = lens[3] - lens[0]
	_say(absf(got - want) < 1.5, "2D 받침과 같은 세기다",
			"3D %.1f px vs 2D %.1f px (기울기 몫 %.1f 제외)"
			% [got, want, lens[0]])

	# ③ 던질수록 늘고 판마다 0 이다
	g.darts.append({"p": g.BC, "id": "std", "rot": 0.0})
	g.darts.append({"p": g.BC + Vector2(40.0, 0.0), "id": "hvy", "rot": 0.1})
	g.queue_redraw()
	await _wait(3)
	_say(g._bd3_live(), "판이 서면 무대가 열린다")
	_say(g.bd_nodes.size() == g.darts.size(), "자루 수가 꽂힌 수와 같다",
			"%d벌 vs %d발" % [g.bd_nodes.size(), g.darts.size()])
	g.darts.append({"p": g.BC + Vector2(-40.0, 20.0), "id": "lgt", "rot": -0.1})
	g.queue_redraw()
	await _wait(3)
	_say(g.bd_nodes.size() == 3, "던지면 는다", "%d벌" % g.bd_nodes.size())

	g._start_leg()
	g._swap_skip()
	g.queue_redraw()
	await _wait(3)
	_say(g.darts.is_empty() and g.bd_nodes.is_empty(),
			"판이 바뀌면 0 으로 돌아간다", "%d벌" % g.bd_nodes.size())

	# ⑤ 판 갈이 도중에는 안 지운다
	g.darts.append({"p": g.BC, "id": "std", "rot": 0.0})
	g.queue_redraw()
	await _wait(2)
	# _swap_begin(false) 는 돌아갈 곳이 상점일 때만 켠다 — 정산 화면에서
	# 부르면 아무 일도 안 일어난다. 게임도 상점을 먼저 세우고 부른다.
	g.state = g.S.SHOP
	g._swap_begin(false)
	g._process(1.0 / 60.0)
	_say(g.swap_live and g._bd3_live(), "판 갈이 도중에는 안 지운다",
			"갈이=%s · 무대=%s" % [g.swap_live, g._bd3_live()])
	g._swap_skip()

	# ④ 판이 아닌 화면으로 나가면 지운다
	g.state = g.S.SHOP
	g._process(1.0 / 60.0)
	_say(not g._bd3_live(), "상점으로 나가면 지운다")
	_say(g.bd_nodes.is_empty(), "자루 목록도 빈다", "%d벌" % g.bd_nodes.size())

	# 다시 열린다
	g.leg_no = 1
	g._start_leg()
	g._swap_skip()
	g.darts.append({"p": g.BC + Vector2(20.0, -20.0), "id": "std", "rot": 0.0})
	g.queue_redraw()
	await _wait(3)
	_say(g._bd3_live() and g.bd_nodes.size() == 1, "다시 들어서면 다시 선다")

	g.state = g.S.TITLE
	g._process(1.0 / 60.0)
	_say(not g._bd3_live(), "제목으로 나가도 지운다")

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "열두 검사 전부 통과"))
	quit(mini(fails, 125))
