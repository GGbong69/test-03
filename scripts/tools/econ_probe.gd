extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  경제 측정 — 라운드 2 까지 손에 쥐는 골드와 그 돈이 산 것
#
#  실행:  godot --path . --headless --quit-after 600000 \
#           -s scripts/tools/econ_probe.gd -- autoplay runs=24
#
#  curve_probe 는 "어디서 죽는가" 만 낸다. 이 프로브는 그 자리에서
#  플레이어가 **무엇을 살 돈이 있었는가** 를 낸다.
#    · 상점마다 들어설 때 가진 골드 · 나올 때 남은 골드
#    · 산 것의 종류와 값
#    · 그 판에 든 동전 수
#  곡선 탓인지 돈 탓인지를 가르는 데 쓴다.
# ══════════════════════════════════════════════════════════

var g: Node = null
var frames := 0
var runs := 0
var RUNS := 24
const FRAME_CAP := 400000

var prev_state := -1
var shop_no := 0
var gold_in := 0
var gold_track := 0
var own_in := 0
var buys := []

# 판 번호 → 통계
var g_in := {}      # 상점 진입 골드의 합
var g_out := {}     # 상점 퇴장 골드의 합
var g_n := {}       # 표본 수
var own_at := {}    # 그 판을 시작할 때 든 동전 수의 합
var own_n := {}
var spend_kind := {}   # 종류 → [횟수, 합계]
var rerolls := 0
var fixtures := 0
var reached := []
var wins := 0
var last_round := 1
var last_used := 0
var used := {}
var passed := {}
var seen := {}
var broke_shop := 0   # 상점에서 아무것도 못 산 횟수(제일 싼 매물보다 돈이 적었다)
var shop_visits := 0
var cheapest_gap := {}  # 판 → 못 산 상점 수


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260826)
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if String(GameData.league_row(t).get("id", "")) == t:
			GameData.league = t
		elif t.begins_with("runs="):
			RUNS = maxi(1, int(t.substr(5)))
	print("리그: %s" % (GameData.league if GameData.league != "" else "흰색(기본)"))


func _add(d: Dictionary, k, v) -> void:
	d[k] = d.get(k, 0) + v


func _finish() -> void:
	print("\n런 %d회 · 완주 %d회" % [runs, wins])
	print("\n판별 — 그 판을 넘긴 뒤 열린 상점")
	print("판  A  종류     목표   판시작든동전  상점진입골드  상점퇴장골드  표본")
	for n in range(1, GameData.legs_n() + 1):
		var c: int = int(g_n.get(n, 0))
		if c == 0:
			continue
		var oc: int = int(own_n.get(n, 0))
		print("%2d  A%d %-7s %6d      %4.2f          %5.1f         %5.1f      %3d"
				% [n, GameData.round_of(n), GameData.leg_name(n),
				GameData.target_of(n),
				float(own_at.get(n, 0)) / float(maxi(oc, 1)),
				float(g_in.get(n, 0)) / float(c),
				float(g_out.get(n, 0)) / float(c), c])

	print("\n산 것 — 종류별 (횟수 · 골드합 · 평균가)")
	for k in spend_kind.keys():
		var a: Array = spend_kind[k]
		print("  %-8s %4d회  %5d골드  평균 %.1f" % [k, a[0], a[1], float(a[1]) / float(maxi(a[0], 1))])
	print("  리롤     %4d회" % rerolls)
	print("\n상점 방문 %d회 · 그중 한 푼도 못 쓴 방문 %d회 (%.0f%%)"
			% [shop_visits, broke_shop, 100.0 * float(broke_shop) / float(maxi(shop_visits, 1))])
	print("판별 '한 푼도 못 씀' 횟수:")
	for n in range(1, GameData.legs_n() + 1):
		if int(cheapest_gap.get(n, 0)) > 0:
			print("   판 %2d — %d회 / %d" % [n, int(cheapest_gap[n]), int(g_n.get(n, 0))])

	print("\n판별 통과율 · 평균 다트")
	for n in range(1, GameData.legs_n() + 1):
		var sn := int(seen.get(n, 0))
		if sn == 0:
			continue
		var pn := int(passed.get(n, 0))
		var du := float(used.get(n, 0)) / float(maxi(pn, 1))
		print("%2d  A%d %-7s %6d  들어섬 %3d  넘김 %3d  %5.0f%%  다트 %.1f"
				% [n, GameData.round_of(n), GameData.leg_name(n),
				GameData.target_of(n), sn, pn, 100.0 * float(pn) / float(sn), du])
	quit(0)


func _process(_d: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		print("!! 프레임 상한")
		_finish()
		return true
	if frames == 1:
		seen[1] = int(seen.get(1, 0)) + 1

	# 판을 시작할 때 든 동전 수
	g.set_process(false)
	var st_before: int = g.state
	g._process(1.0 / 60.0)

	if g.leg_no != last_round:
		if g.leg_no > last_round:
			_add(passed, last_round, 1)
			_add(used, last_round, last_used)
		seen[g.leg_no] = int(seen.get(g.leg_no, 0)) + 1
		_add(own_at, g.leg_no, g.owned.size())
		_add(own_n, g.leg_no, 1)
		last_round = g.leg_no
	if g.leg_darts > 0 and g.darts_left <= g.leg_darts:
		last_used = g.leg_darts - g.darts_left

	# 상점 진입 / 퇴장
	if st_before != g.S.SHOP and g.state == g.S.SHOP:
		shop_no = g.leg_no
		gold_in = int(g.gold)
		gold_track = int(g.gold)
		own_in = g.owned.size()
		buys = []
		shop_visits += 1
	elif st_before == g.S.SHOP and g.state != g.S.SHOP:
		_add(g_in, shop_no, gold_in)
		_add(g_out, shop_no, g.gold)
		_add(g_n, shop_no, 1)
		if gold_in == g.gold:
			broke_shop += 1
			_add(cheapest_gap, shop_no, 1)

	# 구매 감시 — 상점 안에서 골드가 줄면 무엇에 썼는지 stock 에서 읽는다
	if st_before == g.S.SHOP and g.state == g.S.SHOP and int(g.gold) < gold_track:
		var spent: int = gold_track - int(g.gold)
		gold_track = int(g.gold)
		var kind := "리롤"
		if g.owned.size() > own_in:
			kind = "동전"
			own_in = g.owned.size()
		elif spent >= 5:
			kind = "사진/보드 확장/다트"
		if not spend_kind.has(kind):
			spend_kind[kind] = [0, 0]
		spend_kind[kind][0] += 1
		spend_kind[kind][1] += spent
		if kind == "리롤":
			rerolls += 1

	if g.state == g.S.OVER:
		if g.won:
			wins += 1
			_add(passed, g.leg_no, 1)
		reached.append(g.leg_no)
		runs += 1
		if runs >= RUNS:
			_finish()
			return true
		last_round = 1
		seen[1] = int(seen.get(1, 0)) + 1
		g._new_run()
	return false
