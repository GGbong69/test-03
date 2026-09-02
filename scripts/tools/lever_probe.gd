extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  지렛대 비교 — 목표 곡선 말고 무엇을 밀면 난이도가 오르는가
#
#  실행:  godot --path . --headless --quit-after 900000 \
#             -s scripts/tools/lever_probe.gd -- autoplay runs=12
#
#  같은 시드로 손잡이 하나씩만 바꿔 완주율과 벽을 잰다. 곡선을 미는 것과
#  랙을 좁히는 것, 어느 쪽이 같은 힘으로 더 미는가가 답이다.
# ══════════════════════════════════════════════════════════

var g: Node = null
var frames := 0
var runs := 0
var RUNS := 12
const FRAME_CAP := 400000

# 시험할 손잡이. {이름: {tuning 키: 값}}
var CASES := [
	{"n": "랙 5→3", "t": {"max_items": 3.0}},
	{"n": "곡선 4000→16000", "t": {"curve_last": 16000.0}},
	{"n": "다트 6→4", "t": {"darts_base": 4.0}},
]
var ci := 0
var saved := {}
var reached := []
var wins := 0
var out := []


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if t.begins_with("runs="):
			RUNS = maxi(1, int(t.substr(5)))
	_apply(0)


func _apply(i: int) -> void:
	# 앞 사례를 되돌리고 이번 사례를 얹는다.
	for k in saved:
		GameData._tune[k] = saved[k]
	saved.clear()
	var t: Dictionary = CASES[i].t
	for k in t:
		saved[k] = GameData._tune[k]
		GameData._tune[k] = t[k]
	GameData._cache.clear()
	seed(20260826)
	runs = 0
	reached.clear()
	wins = 0
	g._new_run()
	print("── %s ──" % CASES[i].n)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		g.beat = 0.015
		g.gauge_speed = 8.0
		g.confirm_hold = 0.0
	if frames > FRAME_CAP:
		print("!! 프레임 상한")
		_report()
		return true

	g.set_process(false)
	g._process(1.0 / 60.0)

	if g.state == g.S.OVER:
		if g.won:
			wins += 1
		reached.append(g.round_no)
		runs += 1
		if runs >= RUNS:
			var s := 0
			for r in reached:
				s += r
			reached.sort()
			out.append("%-26s 완주 %2d/%2d (%3.0f%%) · 도달 평균 %5.1f · 중앙 %2d · 최종 목표 %d"
					% [CASES[ci].n, wins, RUNS, 100.0 * float(wins) / float(RUNS),
					float(s) / float(RUNS), reached[reached.size() / 2],
					GameData.target_of(GameData.rounds_n())])
			print("   " + out[out.size() - 1])
			ci += 1
			if ci >= CASES.size():
				_report()
				return true
			_apply(ci)
			return false
		g._new_run()
	return false


func _report() -> void:
	print("\n═══ 지렛대 비교 ═══")
	for l in out:
		print(l)
	quit(0)
