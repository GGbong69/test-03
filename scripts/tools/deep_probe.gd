extends SceneTree

#  오버 배율 분포 조사 — 「목표를 넘긴 그 걸음의 total / target」이
#  실제로 어디에 앉는지 잰다. 깊이 단 문턱(BRKDEEP.step)을 실측 버킷
#  경계에 앉히려고 판 자다. **연출도 값도 한 톨 안 만진다 — 읽기만.**
#
#  실행:  godot --headless --path . --script scripts/tools/deep_probe.gd -- autoplay

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g: Node = null
var frames := 0
var ks := []                 # 판마다 넘긴 배율
var by_round := {}           # 라운드 → 배율들
var last_leg := -1
var armed := false


func _initialize() -> void:
	Save.path = "user://_probe_deep.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260925)


func _report() -> void:
	ks.sort()
	var n := ks.size()
	print("\n── 오버 배율(total/target) 실측 ── 판 %d\n" % n)
	if n == 0:
		quit(1)
		return
	var edges := [1.0, 1.1, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 1e9]
	var lo := 1.0
	for e in edges:
		var c := 0
		for k in ks:
			if k >= lo and k < float(e):
				c += 1
		if c > 0:
			print("  x%.2f ~ x%.2f : %4d  (%5.1f%%)" % [lo, e, c, 100.0 * float(c) / float(n)])
		lo = float(e)
	print("\n  중앙 x%.3f · 최소 x%.3f · 최대 x%.3f" % [ks[n / 2], ks[0], ks[n - 1]])
	#  설계서가 고른 문턱 1.25 / 2.00 / 3.00 으로 나눈 단 분포
	var t := [0, 0, 0, 0]
	for k in ks:
		var s := 0
		for e2 in [1.25, 2.0, 3.0]:
			if k >= float(e2):
				s += 1
		t[s] += 1
	print("\n  문턱 1.25 / 2.00 / 3.00 로 가른 단:")
	for i in 4:
		print("    %d단 %4d  (%5.1f%%)  24판 런에 %.1f회" % [i, t[i],
				100.0 * float(t[i]) / float(n), 24.0 * float(t[i]) / float(n)])
	var rk := by_round.keys()
	rk.sort()
	print("\n  라운드별 중앙값:")
	for r in rk:
		var a: Array = by_round[r]
		a.sort()
		print("    R%-3s n=%-4d 중앙 x%.2f" % [str(r), a.size(), a[a.size() / 2]])
	quit(0)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		g.beat = 0.015
		g.gauge_speed = 8.0
		g.confirm_hold = 0.0
	g.set_process(false)
	for _i in 800:
		g._process(1.0 / 60.0)
		if int(g.leg_no) != last_leg:
			last_leg = int(g.leg_no)
			armed = false
		if not armed and int(g.target) > 0 and int(g.total) >= int(g.target):
			armed = true
			var k := float(g.total) / maxf(float(g.target), 1.0)
			ks.append(k)
			var r := int(GameData.round_of(int(g.leg_no)))
			if not by_round.has(r):
				by_round[r] = []
			by_round[r].append(k)
	if ks.size() >= 600 or frames > 900:
		_report()
		return true
	return false
