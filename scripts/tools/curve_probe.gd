extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  목표 곡선 측정 — 24판이 실제로 어디서 막히는가
#
#  실행:  godot --path . --headless --quit-after 600000 -s scripts/tools/curve_probe.gd -- autoplay
#         (리그을 재려면)  ... -- autoplay blue   ·   ... -- autoplay yellow
#
#  8판에서 24판으로 늘리며 곡선을 다시 잡았는데, 그 값은 **감으로**
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
#    · 런마다 도달한 판과 판
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
#  여유를 재는 계기다. 판은 목표를 넘긴 순간 끝나므로(_next_step) 점수는
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
		# 표에 있는 리그 id 면 그것으로 잰다. 색 순서가 바뀌어도 안 깨지도록
		# id 를 박지 않고 표에 물어본다 — 모르는 말이면 league_row 가 첫 단을
		# 돌려주므로 id 가 안 맞고, 그대로 지나간다.
		if String(GameData.league_row(t).get("id", "")) == t:
			GameData.league = t
		elif t.begins_with("runs="):
			RUNS = maxi(1, int(t.substr(5)))
	print("리그: %s" % (GameData.league if GameData.league != "" else "흰색(기본)"))


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

	print("\n판  판 종류      목표     들어섬  넘김   통과율   평균다트   여유")
	for n in range(1, GameData.legs_n() + 1):
		var sn := int(seen.get(n, 0))
		var pn := int(passed.get(n, 0))
		if sn == 0:
			continue
		# 여유 = 6발을 다 썼을 때 낼 수 있는 점수 / 목표. 쓴 발이 적을수록 크다.
		# 2발에 넘겼으면 x3.0 이고, 6발을 다 쓰고 겨우 넘겼으면 x1.0 이다.
		var du := float(used.get(n, 0)) / float(maxi(pn, 1))
		var head := float(GameData.darts_of(n)) / maxf(du, 0.5)
		print("%2d   A%d  %-7s %7d   %3d   %3d   %5.0f%%   %6.1f   x%.1f"
				% [n, GameData.round_of(n), GameData.leg_name(n),
				GameData.target_of(n), sn, pn, 100.0 * float(pn) / float(sn),
				du, head])
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
	if g.leg_no != last_round:
		if g.leg_no > last_round:
			passed[last_round] = int(passed.get(last_round, 0)) + 1
			used[last_round] = int(used.get(last_round, 0)) + last_used
		_enter(g.leg_no)
		last_round = g.leg_no
	# 쓴 다트는 판이 넘어가기 **전에** 읽어 둔다 — _start_leg 가
	# remaining 을 새로 채우면 값이 리셋된다.
	if g.leg_darts > 0 and g.darts_left <= g.leg_darts:
		last_used = g.leg_darts - g.darts_left

	if g.state == g.S.OVER:
		if g.won:
			wins += 1
			passed[g.leg_no] = int(passed.get(g.leg_no, 0)) + 1
		reached.append(g.leg_no)
		runs += 1
		if runs >= RUNS:
			_finish()
			return true
		last_round = 1
		_enter(1)
		g._new_run()
	return false
