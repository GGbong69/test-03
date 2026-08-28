extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  목표 곡선 측정 — 24판이 실제로 어디서 막히는가
#
#  실행:  godot --path . --headless --quit-after 600000 -s scripts/tools/curve_probe.gd -- autoplay
#         (판돈을 재려면)  ... -- autoplay green   ·   ... -- autoplay purple
#
#  8라운드에서 24판으로 늘리며 곡선을 다시 잡았는데, 그 값은 **감으로**
#  고른 것이다. 상점이 7번에서 23번으로 늘면 빌드가 얼마나 세지는지는
#  산수로 안 나온다 — 아이템 87장의 조합이라 시뮬레이션 말고는 길이 없다.
#  그래서 잰다.
#
#  오토플레이는 사람이 아니다. _land 가 판 안(r ≤ 0.95R)에 고르게 꽂으므로
#  **빗나감이 0** 이고, 그래서 이 수치는 조준을 완벽히 한 플레이어의
#  상한이다. 사람은 이보다 아래에 떨어진다. 곡선을 여기에 딱 맞추면 안 되고,
#  "오토플레이가 어디서 막히는가" 를 기준선으로 삼아 사람 몫의 여유를 둔다.
#
#  내는 것
#    · 런마다 도달한 판과 앤티
#    · 판별 통과율 — 어느 판이 벽인가가 여기서 보인다
#    · 완주율
# ══════════════════════════════════════════════════════════

var g: Node = null
var frames := 0
var runs := 0
var reached := []            # 런마다 도달한 판 번호
var wins := 0
var last_round := 1
var last_used := 0
var seen := {}               # 판 번호 → 몇 번 들어섰나
var passed := {}             # 판 번호 → 몇 번 넘겼나
var used := {}               # 판 번호 → 넘길 때 쓴 다트의 합
#  여유를 재는 계기다. 라운드는 목표를 넘긴 순간 끝나므로(_next_step) 점수는
#  언제나 목표 근처에 붙어 있어 headroom 이 안 보인다. 대신 **몇 발 만에
#  넘겼는가**가 그대로 여유다 — 6발 중 2발이면 3배 여유고, 6발을 다 쓰고
#  겨우 넘겼으면 여유가 0 이다.

var RUNS := 16          # -- autoplay runs=N 으로 덮는다
const FRAME_CAP := 400000    # 안전장치. 한 런이 여기 걸리면 무한루프다


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260826)
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if t == "green" or t == "purple":
			GameData.stake = t
		elif t.begins_with("runs="):
			RUNS = maxi(1, int(t.substr(5)))
	print("판돈: %s" % (GameData.stake if GameData.stake != "" else "흰색(기본)"))


func _finish() -> void:
	reached.sort()
	var sum := 0
	for r in reached:
		sum += r
	var med: int = reached[reached.size() / 2] if not reached.is_empty() else 0
	print("\n런 %d회 · 완주 %d회 (%.0f%%)" % [runs, wins, 100.0 * float(wins) / float(maxi(runs, 1))])
	print("도달한 판 — 평균 %.1f · 중앙 %d · 최소 %d · 최대 %d"
			% [float(sum) / float(maxi(reached.size(), 1)), med,
			reached[0] if not reached.is_empty() else 0,
			reached[reached.size() - 1] if not reached.is_empty() else 0])

	print("\n판  앤티 종류      목표     들어섬  넘김   통과율")
	for n in range(1, GameData.rounds_n() + 1):
		var sn := int(seen.get(n, 0))
		var pn := int(passed.get(n, 0))
		if sn == 0:
			continue
		print("%2d   A%d  %-7s %7d   %3d   %3d   %5.0f%%"
				% [n, GameData.ante_of(n), GameData.blind_name(n),
				GameData.target_of(n), sn, pn, 100.0 * float(pn) / float(sn)])
	quit(0)


func _enter(n: int) -> void:
	seen[n] = int(seen.get(n, 0)) + 1


func _process(_d: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		print("!! 프레임 상한 — 런 %d 에서 멈췄다" % runs)
		_finish()
		return true
	if frames == 1:
		_enter(1)

	g.set_process(false)
	g._process(1.0 / 60.0)

	# 판이 바뀌면 앞 판을 넘긴 것이고 새 판에 들어선 것이다.
	if g.round_no != last_round:
		if g.round_no > last_round:
			passed[last_round] = int(passed.get(last_round, 0)) + 1
			used[last_round] = int(used.get(last_round, 0)) + last_used
		_enter(g.round_no)
		last_round = g.round_no
	# 쓴 다트는 라운드가 넘어가기 **전에** 읽어 둔다 — _start_round 가
	# remaining 을 새로 채우면 값이 리셋된다.
	if g.round_darts > 0 and g.darts_left <= g.round_darts:
		last_used = g.round_darts - g.darts_left

	if g.state == g.S.OVER:
		if g.won:
			wins += 1
			passed[g.round_no] = int(passed.get(g.round_no, 0)) + 1
		reached.append(g.round_no)
		runs += 1
		if runs >= RUNS:
			_finish()
			return true
		last_round = 1
		_enter(1)
		g._new_run()
	return false
