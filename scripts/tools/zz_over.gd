extends SceneTree
const GameData = preload("res://scripts/data.gd")

var g: Node = null
var frames := 0
var runs := 0
var wins := 0
var last_round := 1
var last_used := 0
var recorded := {}                # 이번 판 CLEAR 를 이미 적었나
var over := {}                    # 판 → [초과배율…]
var used := {}                    # 판 → [쓴 다트…]
var seen := {}
var passed := {}
var RUNS := 24

func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260826)
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if t.begins_with("runs="):
			RUNS = maxi(1, int(t.substr(5)))
		elif String(GameData.league_row(t).get("id","")) == t:
			GameData.league = t

func _rec(n: int, o: float, u: int) -> void:
	if not over.has(n):
		over[n] = []
		used[n] = []
	over[n].append(o)
	used[n].append(u)

func _finish() -> void:
	print("\n런 %d · 완주 %d (%.0f%%)  리그=%s" % [runs, wins,
			100.0*float(wins)/float(maxi(runs,1)),
			GameData.league if GameData.league != "" else "white"])
	print("\n판  라운드 목표     들어섬 넘김 통과%%  쓴다트 |  초과배율(총점/목표)")
	print("                                            중앙   평균   최소   최대")
	for n in range(1, GameData.legs_n()+1):
		var sn := int(seen.get(n,0))
		if sn == 0: continue
		var pn := int(passed.get(n,0))
		var o: Array = over.get(n, [])
		var u: Array = used.get(n, [])
		var line := "%2d   A%d %7d   %3d   %3d  %4.0f%%" % [n, GameData.round_of(n),
				GameData.target_of(n), sn, pn, 100.0*float(pn)/float(sn)]
		if o.is_empty():
			print(line + "     -   |   (기록 없음)")
			continue
		var so := o.duplicate(); so.sort()
		var su := 0.0
		for x in u: su += float(x)
		var sm := 0.0
		for x in o: sm += float(x)
		print(line + "   %4.1f  |  x%-6.2f x%-6.2f x%-6.2f x%.2f" % [
				su/float(u.size()), so[so.size()/2], sm/float(so.size()), so[0], so[so.size()-1]])
	quit(0)

func _process(_d: float) -> bool:
	frames += 1
	if frames > 3000000:
		print("!! 프레임 상한")
		_finish(); return true
	if frames == 1: seen[1] = 1
	g.set_process(false)
	g._process(1.0/60.0)

	# 클리어 화면에 들어선 순간의 총점/목표 = 진짜 여유다
	if g.state == g.S.CLEAR and not recorded.get(g.leg_no, false):
		recorded[g.leg_no] = true
		var t := float(g.target)
		if t > 0.0:
			_rec(g.leg_no, float(g.total)/t, last_used)

	if g.leg_no != last_round:
		if g.leg_no > last_round:
			passed[last_round] = int(passed.get(last_round,0)) + 1
		seen[g.leg_no] = int(seen.get(g.leg_no,0)) + 1
		last_round = g.leg_no
	if g.leg_darts > 0 and g.darts_left <= g.leg_darts:
		last_used = g.leg_darts - g.darts_left

	if g.state == g.S.OVER:
		if g.won:
			wins += 1
			passed[g.leg_no] = int(passed.get(g.leg_no,0)) + 1
		runs += 1
		print("  run %d/%d  도달 %d  프레임 %d" % [runs, RUNS, g.leg_no, frames])
		if runs >= RUNS:
			_finish(); return true
		last_round = 1
		recorded.clear()
		seen[1] = int(seen.get(1,0)) + 1
		g._new_run()
	return false
