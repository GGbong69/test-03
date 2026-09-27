extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  튜토리얼 런에서 판마다 한 발이 얼마나 나는지 재는 자 (2026-09-27)
#
#  실행:  godot --path . --headless --script scripts/tools/tut_probe.gd -- autoplay [n=40]
#
#  튜토리얼 런은 상점마다 공짜 선물을 받아 빌드가 판마다 불어난다. 판마다
#  **그 판에 들고 있을 빌드로** 여섯 발을 다 던지게 하고(목표를 무한대로 둔다)
#  발마다 점수를 적는다. 한때 이 수로 튜토리얼 목표를 올렸다가 되돌렸다
#  (목표는 본편 그대로 — 넘치는 점수가 목적이다). 지금은 「얼마나 넘치는가」를 본다.
#
#  빌드는 game.gd 의 TUT.pages 를 **그대로** 읽는다 — 판 n 에는 상점 n−1 까지의
#  선물이 다 들어 있다고 본다(곱하기는 오른쪽 끝, _tut_slot 과 같은 규칙).
# ══════════════════════════════════════════════════════════

var g: Node = null
var N := 40
var frames := 0
var leg := 1
var trial := 0
var armed := false
var prev_total := 0
var gains := []            # 이 판 발마다
var rows := {}             # leg -> [[g1..g6], ...]


func _initialize() -> void:
	Save.path = "user://_tut_probe.cfg"
	Save.gpath = "user://_tut_probe_g.cfg"
	Save.wipe()
	Save.teach("u_boot")      # 이 자는 튜토리얼 런 문을 안 연다 — 빌드를 손으로 끼운다
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260927)
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if t.begins_with("n="):
			N = maxi(1, int(t.substr(2)))


func _build(n: int) -> void:
	g.owned.clear()
	var mods := []
	var ids := []
	#  판 n 에는 상점 n−1 까지의 쪽이 다 들어 있다(리롤 쪽 포함 — 튜토리얼
	#  안내가 리롤을 시킨다). 팩·사탕·사진은 사람이 쓸지 모르므로 안 센다.
	for pg in g.TUT.pages:
		if int(pg.shop) < n:
			for gid in pg.ids:
				ids.append(String(gid))
	for gid in ids:
		if gid.begins_with("m:"):
			mods.append(gid.substr(2))
			continue
		if gid.find(":") == 1:
			continue
		for it in GameData.items():
			if String(it.id) == gid:
				var c: Dictionary = it.duplicate()
				c.gs = 0
				c.bought = 0
				g.owned.insert(g._tut_slot(c), c)
				break
	g._panel_reset()
	g.mods_own = mods
	g._board_bake()


func _begin() -> void:
	g._new_run()
	g.leg_no = leg
	_build(leg)
	g._open_leg()
	armed = false
	gains = []


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		g.beat = 0.015
		g.gauge_speed = 8.0
		g.confirm_hold = 0.0
		_begin()
		return false
	if frames < 2:
		return false
	g.set_process(false)
	g._process(1.0 / 60.0)
	#  판이 서고 첫 조준에 들어서면 목표를 무한대로 — 여섯 발을 다 던지게 한다.
	if not armed and g.leg_no == leg and (g.state == g.S.PICK or g._is_aim_stage()):
		g.target = 1000000000000
		prev_total = int(g.total)
		armed = true
	if armed and int(g.total) != prev_total:
		gains.append(int(g.total) - prev_total)
		prev_total = int(g.total)
	if armed and (g.state == g.S.OVER or g.leg_no != leg or frames > 3000000):
		if not rows.has(leg):
			rows[leg] = []
		rows[leg].append(gains.duplicate())
		print("  판 %d · %d회 · %s" % [leg, trial + 1, str(gains)])
		trial += 1
		if trial >= N:
			trial = 0
			leg += 1
			if leg > int(g.TUT.legs):
				_finish()
				return true
		_begin()
	return false


func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[clampi(int(p * float(s.size() - 1)), 0, s.size() - 1)])


func _finish() -> void:
	print("\n판  본편목표  발1~6 평균                                   다섯발합 p50   여섯발합 p10 · p25 · p50")
	for n in range(1, int(g.TUT.legs) + 1):
		var rs: Array = rows.get(n, [])
		var per := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		var s5 := []
		var s6 := []
		for r in rs:
			var a: Array = r
			var t5 := 0
			var t6 := 0
			for i in mini(a.size(), 6):
				per[i] += float(a[i])
				t6 += int(a[i])
				if i < 5:
					t5 += int(a[i])
			s5.append(t5)
			s6.append(t6)
		var nn := maxf(float(rs.size()), 1.0)
		var line := ""
		for i in 6:
			line += "%8.0f" % (per[i] / nn)
		print("%2d %8d %s   %9.0f   %9.0f %9.0f %9.0f" % [n, GameData.target_of(n), line,
				_pct(s5, 0.5), _pct(s6, 0.1), _pct(s6, 0.25), _pct(s6, 0.5)])
	quit(0)
