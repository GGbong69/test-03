extends SceneTree

# 정산 연출 검사. docs/UI개편_설계.md C12·C13.
#   줄이 차례로 들고 · 합계선은 그 뒤에 · 총액이 굴러 오르고 ·
#   누르면 즉시 끝나고 · 모션을 끄면 곧장 최종값
#
#   godot --path . --headless --script scripts/tools/qa_clear.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var busy := false
var okn := 0
var fail := 0
var enter_fr := -1    # 확인에서 CLEAR 까지 걸린 프레임


func _initialize() -> void:
	Save.path = "user://_qa_clear.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _enter() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g._click(g._leg_go().get_center())
	for k in 60:
		g._process(1.0 / 60.0)
	g.target = 1
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC
	#  확인에서 CLEAR 까지 696프레임이다 — 배움 말상자가 게임 시간을 0.30배로 묶고,
	#  합계 걸음이 4.4박 · 모음 걸음 0.7박으로 길어졌다(2026-10-06). 600 이면 돌파
	#  걸음 안에서 끊겨 state 5(RESOLVE)로 운다.
	for k in 1500:
		g._process(1.0 / 60.0)
		if g.state == g.S.CLEAR:
			enter_fr = k + 1
			return


#  정산을 처음부터 다시 굴리며 난 소리를 [이름, 피치] 로 걷는다 — 풀을 넓혀 깔고(넷이면 돈다)
#  sfx_next 까지 읽는다(qa_land 의 수법). skip 이면 첫 틀 전에 눌러 건너뛴다.
func _clear_sounds(frames: int, skip: bool) -> Array:
	for sp in g.sfx_pool:
		sp.queue_free()
	g.sfx_pool.clear()
	for i in 64:
		var sp := AudioStreamPlayer.new()
		g.add_child(sp)
		g.sfx_pool.append(sp)
	g.sfx_next = 0
	g.clear_t = 0.0
	g.clear_snd_i = 0
	if skip:
		g._click(Vector2(320.0, 300.0))
	for k in frames:
		g._process(1.0 / 60.0)
	var out := []
	for i in g.sfx_next:
		var pl: AudioStreamPlayer = g.sfx_pool[i]
		if pl.stream != null:
			out.append([String(pl.stream.resource_path).get_file().get_basename(), pl.pitch_scale])
	return out


func _run() -> void:
	for i in 20:
		g._process(1.0 / 60.0)
	print("\n정산 연출 검사\n")

	_enter()
	_ok("정산으로 들어왔다", g.state == g.S.CLEAR,
			"state %d · %d프레임" % [g.state, enter_fr])
	_ok("내역이 섰다", (g.clear_gold_detail as Array).size() >= 3,
			"%d줄" % (g.clear_gold_detail as Array).size())
	#  ⚠ **화면 글을 여기 다시 적지 않는다.** 전에는 "클리어 보상" 을 글자로
	#  박아 뒀다가 game.gd 가 「넘김 보상」으로 갈리자 자가 거짓으로 울었다
	#  (2026-09-25). 재는 것은 **판 이름이 첫 줄에 또 서지 않는다**는 그 한 가지다.
	var nm0 := String(g.clear_gold_detail[0].n)
	_ok("첫 줄이 판 이름이 아니다",
			nm0 != "" and not nm0.contains(GameData.leg_name(g.leg_no)),
			"'%s' — 판 이름은 제목이 이미 말한다" % nm0)

	# ① 판 위 팝업은 판 위에서 끝난다
	_ok("판 위 팝업을 안 끌고 온다", (g.pops as Array).is_empty(),
			"%d개" % (g.pops as Array).size())

	# ② 총액이 0 에서 오른다
	g.clear_t = 0.0
	var at0: int = g._clear_roll()
	for k in 8:
		g._process(1.0 / 60.0)
	var at1: int = g._clear_roll()
	for k in 200:
		g._process(1.0 / 60.0)
	var at2: int = g._clear_roll()
	_ok("총액이 0 에서 시작한다", at0 == 0, "%d" % at0)
	_ok("총액이 굴러 오른다", at2 > at1 or at1 > at0,
			"%d → %d → %d (골드 %d)" % [at0, at1, at2, g.gold])
	#  큰 수는 이번 판 몫 — 줄들의 합이다(2026-10-21). 지갑 전체는 자금판이 말한다.
	var sum := 0
	for r in g.clear_gold_detail:
		sum += int(r.v)
	_ok("다 구르면 이번 판 몫(줄들의 합)", at2 == sum and g._clear_sum() == sum and sum > 0,
			"%d / 합 %d · 지갑 %d" % [at2, sum, g.gold])
	_ok("멎으면 자금판이 새 지갑", g._bank_shown() == g.gold, "%d / %d" % [g._bank_shown(), g.gold])
	_ok("다 구르면 끝났다고 말한다", g._clear_done(), "")
	#  큰 수가 제값에 닿는 그 틀에 끝난다 — 등록기 · 자금판이 수가 멎는 틀과 같다.
	var stop_ok := true
	g.clear_t = 0.0
	for k in 120:
		g.clear_t += 1.0 / 60.0
		if (g._clear_roll() == sum) != g._clear_done():
			stop_ok = false
	_ok("수가 멎는 틀에 끝난다(등록기 · 자금판)", stop_ok, "")

	# ③ 누르면 즉시 끝난다 — 연출이 입력을 삼키면 안 된다
	g.clear_t = 0.0
	g._process(1.0 / 60.0)
	_ok("구르는 중에는 안 끝났다", not g._clear_done(),
			"보이는 값 %d / %d" % [g._clear_roll(), sum])
	_ok("구르는 동안 자금판은 옛 지갑", g._bank_shown() == g.gold - sum,
			"%d / %d" % [g._bank_shown(), g.gold - sum])
	var st0: int = g.state
	g._click(Vector2(320.0, 300.0))
	_ok("누르면 굴림만 끝내고 화면은 그대로",
			g.state == st0 and g._clear_done(),
			"state %d · 보이는 값 %d" % [g.state, g._clear_roll()])

	# ④ 모션을 끄면 곧장 최종값
	g.motion_off = true
	g.clear_t = 0.0
	_ok("모션 끄면 곧장 제값", g._clear_roll() == sum and g._clear_done() and g._bank_shown() == g.gold,
			"%d / %d" % [g._clear_roll(), sum])
	var di := -1
	for i in g.clear_gold_detail.size():
		if int(g.clear_gold_detail[i].get("d", 0)) > 0:
			di = i
	var dn: int = int(g.clear_gold_detail[di].d) if di >= 0 else 0
	_ok("모션 끄면 다트가 다 금화", di >= 0 and g._clear_flip(di, 0, dn) >= 1.0
			and g._clear_flip(di, dn - 1, dn) >= 1.0, "줄 %d · 다트 %d" % [di, dn])
	g.motion_off = false

	# ⑦ 「남은 다트」 줄 — 줄이 드는 틀부터 다트가 한 자루씩 금화로 뒤집힌다(2026-10-21)
	var st7: float = g._mo("fast")
	g.clear_t = float(di) * st7 - 0.001
	var f0: float = g._clear_flip(di, 0, dn)
	g.clear_t = float(di) * st7 + st7 * 0.5
	var fa: float = g._clear_flip(di, 0, dn)
	var fz: float = g._clear_flip(di, dn - 1, dn)
	g.clear_t = 99.0
	var f9: float = g._clear_flip(di, dn - 1, dn)
	_ok("줄이 들기 전엔 다트 · 들며 하나씩 · 건너뛰면 다 금화",
			f0 == 0.0 and fa > 0.0 and (dn < 2 or fz < fa) and f9 >= 1.0,
			"다트 %d · %.2f %.2f %.2f %.2f" % [dn, f0, fa, fz, f9])

	# ⑥ 소리 — 받은 줄마다 짤랑(한 온음씩 오른다) · 합계에 등록기 한 번 · 건너뛰면 · 모션 끄면 합계만
	var got := 0
	for r in g.clear_gold_detail:
		if int(r.v) > 0:
			got += 1
	var sn: Array = _clear_sounds(200, false)
	var lands: Array = sn.filter(func(e): return e[0] == "coin_land")
	var steps_ok := true
	for i in lands.size():
		if not is_equal_approx(float(lands[i][1]), pow(2.0, 2.0 * float(i) / 12.0)):
			steps_ok = false
	var nm: Array = sn.map(func(e): return e[0])
	_ok("받은 줄마다 짤랑 · 한 온음씩", got > 0 and lands.size() == got and steps_ok,
			"받은 줄 %d · 짤랑 %d · %s" % [got, lands.size(), lands])
	_ok("합계에 등록기 한 번 · 짤랑 뒤", nm.count("buy") == 1 and nm.find("buy") > nm.rfind("coin_land"),
			"%s" % [nm])
	sn = _clear_sounds(30, true)
	_ok("건너뛰면 등록기만", sn.filter(func(e): return e[0] == "coin_land").is_empty()
			and sn.filter(func(e): return e[0] == "buy").size() == 1, "%s" % [sn])
	g.motion_off = true
	sn = _clear_sounds(30, false)
	g.motion_off = false
	_ok("모션 끄면 등록기만", sn.filter(func(e): return e[0] == "coin_land").is_empty()
			and sn.filter(func(e): return e[0] == "buy").size() == 1, "%s" % [sn])
	Dev._run(g, {"a": "replay"})
	_ok("개발자 「정산 다시 재생」은 소리도 처음부터", g.clear_snd_i == 0 and g.clear_t == 0.0,
			"%d" % g.clear_snd_i)

	# ⑤ 표가 화면 한가운데 축에 선다
	var mid: float = float(g.CLR.x) + float(g.CLR.w) * 0.5
	_ok("표가 화면 한가운데 축", is_equal_approx(mid, g.VIEW.x * 0.5),
			"표 중심 %.0f · 화면 중심 %.0f" % [mid, g.VIEW.x * 0.5])

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
