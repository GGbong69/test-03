extends SceneTree

# 조준 저울 검사 — 라운드가 오를수록 조준 동전이 잘 뜬다. 2026-09-18 사용자 지시 —
#   "이게 조준 방식이 바뀌는 아이템은 라운드가 올라갈수록 확률이 좀
#    올라간다던가 그런 게 있으면 좋겠는데 어때"
#
# 저울은 rounds.csv 의 aim_w(사다리) · aim_own_w(이미 든 쪽)가 쥐고,
# _stock_items(game.gd)가 그 값을 **최소 가중치**로 얹는다. 배수가 아니라
# 바닥(max)이라 교통카드(common 0.60)는 꼭대기 0.35 에도 안 걸린다.
#
# **왜 qa_shoproll 이 아니라 따로인가.** 붙여 보니 한 판이 414초라 420초
# 예산에 6초 남았다 — 기계가 조금만 느려도 헛되이 죽는다. 그리고 qa_shoproll
# 의 표본 블록은 g.leg_no = 4 = R2 인데 R2 의 바닥이 0.05 = 오늘 그대로라
# 저 검사의 단언 스물넷이 이 변경에 **한 줄도 안 흔들린다.** 둘은 서로를
# 안 본다. 저울을 바꾸면 여기가 운다.
#
#   godot --path . --headless --script scripts/tools/qa_aimroll.gd

const GameData = preload("res://scripts/data.gd")
const Dev = preload("res://scripts/dev.gd")

const AIM_N := 1500         # 라운드당 상점. 여덟이면 12000곳 = 자리 48000칸
const PACK_N := 2500        # 팩에서 뽑는 동전. 갈림이 6배라 이만큼이면 갈린다
const OWN_N := 1000         # 이미 조준 동전을 든 채로 굴리는 표본(⑬)

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _acc() -> Dictionary:
	return {"n": 0, "slots": 0, "item": 0, "aim": 0, "aimrare": 0,
			"r15": 0, "leg": 0, "shop_aim": 0, "shop_rare": 0,
			"nc": 0, "nu": 0, "nr": 0}


# 상점을 한 번 굴리고 **동전 자리를 뜯어** 센다. 공짜 해금 보상은 폭 밖이라 뺀다.
func _tally(a: Dictionary) -> void:
	g._roll_stock()
	a["n"] = int(a["n"]) + 1
	var has_aim := false
	var has_rare := false
	for s in g.stock:
		if bool(s.get("free", false)):
			continue
		a["slots"] = int(a["slots"]) + 1
		var t := String(s.get("type", ""))
		a["k_" + t] = int(a.get("k_" + t, 0)) + 1
		if t != "item":
			continue
		a["item"] = int(a["item"]) + 1
		var d: Dictionary = s.d
		var rar := String(d.get("rarity", ""))
		if rar == "legendary":
			a["leg"] = int(a["leg"]) + 1
		if String(d.get("aim", "")) != "":
			a["aim"] = int(a["aim"]) + 1
			has_aim = true
			if rar == "rare":
				a["aimrare"] = int(a["aimrare"]) + 1
				has_rare = true
			if String(d.get("id", "")) == "r15":
				a["r15"] = int(a["r15"]) + 1
		elif rar == "common":
			a["nc"] = int(a["nc"]) + 1
		elif rar == "uncommon":
			a["nu"] = int(a["nu"]) + 1
		elif rar == "rare":
			a["nr"] = int(a["nr"]) + 1
	if has_aim:
		a["shop_aim"] = int(a["shop_aim"]) + 1
	if has_rare:
		a["shop_rare"] = int(a["shop_rare"]) + 1


func _pct(x: int, d: int) -> float:
	return 0.0 if d <= 0 else 100.0 * float(x) / float(d)


#  설계값을 **표에서 직접 계산한다.** 상수를 박으면 표를 고쳤을 때 검사가
#  옛날 수를 지키게 된다. g._stock_items 를 그대로 부르므로 상점이 굴리는
#  풀과 같은 것을 본다 — 실측과 견주면 산수와 코드가 같이 검사된다.
func _theory(nxt: int) -> float:
	var sum := 0.0
	var aw := 0.0
	for it in g._stock_items(nxt):
		var w: float = float(it.w) if it.has("w") else GameData.item_weight(it)
		sum += w
		if String(it.get("aim", "")) != "":
			aw += w
	var ks := 0.0
	var iw := 0.0
	for kk in GameData.shop_kinds():
		ks += float(kk.w)
		if String(kk.id) == "item":
			iw = float(kk.w)
	if sum <= 0.0 or ks <= 0.0:
		return 0.0
	return 100.0 * (iw / ks) * (aw / sum)


#  그 라운드의 **첫 상점**이 서는 판 번호. (R-1)*per + 1 을 쓰는 것은 폭
#  (shop_slots(leg_no))과 바닥(round_of(leg_no+1))이 **둘 다 같은 라운드**를
#  보게 하기 위해서다. 한 칸 앞을 쓰면 폭이 앞 라운드 것을 본다 — 오늘은
#  폭이 전 라운드 4 라 안 갈리지만, 폭이 라운드마다 갈리게 되면 그 어긋남이
#  표본에 섞여 경사를 못 읽는다.
func _leg_of_round(r: int) -> int:
	return (r - 1) * GameData.legs_per_round() + 1


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n조준 저울 — 라운드가 오를수록 조준 동전이 잘 뜬다\n")
	var rn := GameData.rounds_n()

	# ① 표 단언 — 게임을 안 굴리고 rounds.csv 만 본다. 공짜고 정확하다.
	#    **인접 단조는 오직 여기서만 단언한다** — 표본에서는 인접 차이가
	#    1.5σ 밖에 안 돼 일곱 쌍이면 돌릴 때마다 약 5% 확률로 헛되이 운다.
	var rare_w := 0.0
	var com_w := 0.0
	for rr in GameData.rows("rarity"):
		if String(rr.get("id", "")) == "rare":
			rare_w = float(String(rr.get("weight", "0")))
		elif String(rr.get("id", "")) == "common":
			com_w = float(String(rr.get("weight", "0")))
	var fl := []
	var ow := []
	for i in rn:
		fl.append(GameData.aim_floor(_leg_of_round(i + 1)))
		ow.append(GameData.aim_floor_own(_leg_of_round(i + 1)))
	_ok("R1·R2 바닥이 레어 저울 그대로",
			is_equal_approx(float(fl[0]), rare_w) and is_equal_approx(float(fl[1]), rare_w),
			"R1 %.2f · R2 %.2f · rarity 의 rare %.2f — 앞은 일부러 평평하다"
			% [fl[0], fl[1], rare_w])
	var mono := true
	var inband := true
	var owok := true
	for i in rn:
		if i > 0 and float(fl[i]) < float(fl[i - 1]) - 0.0001:
			mono = false
		if float(fl[i]) < rare_w - 0.0001 or float(fl[i]) >= com_w:
			inband = false
		if float(ow[i]) > float(fl[i]) + 0.0001 or float(ow[i]) < rare_w - 0.0001:
			owok = false
	_ok("바닥이 라운드를 따라 안 내려간다", mono,
			"R1 %.2f → R%d %.2f" % [fl[0], rn, fl[rn - 1]])
	_ok("R%d 이 R1 보다 높다" % rn, float(fl[rn - 1]) > float(fl[0]) + 0.0001,
			"%.2f → %.2f — 곡선이 통째로 평평해지면 여기서 운다" % [fl[0], fl[rn - 1]])
	_ok("바닥이 레어 이상 일반 미만", inband,
			"레어 %.2f ≤ 바닥 < 일반 %.2f — 일반이 증발하는 자리를 막는다"
			% [rare_w, com_w])
	_ok("든 뒤 바닥이 사다리를 안 넘는다", owok,
			"R1 %.2f … R%d %.2f — 이미 든 쪽이 더 흔하면 겹침 방지가 거꾸로 선다"
			% [ow[0], rn, ow[rn - 1]])

	# ② 후보가 안 비었다 (하데스 함정) — 확률만 재면 「낮다」와 「없다」가
	#    안 갈린다. 표본이 아니라 정확한 수다.
	g.owned = []
	g.mods_own = []
	var aim_n_ok := true
	var aim_cnt := PackedStringArray()
	for r in range(1, rn + 1):
		#  2 로 안 막으면 min_leg(전 등급 2)가 R1 의 후보를 통째로 걸러
		#  없는 사고가 보인다.
		var nxt: int = maxi(2, _leg_of_round(r))
		var c := 0
		for it in g._stock_items(nxt):
			if String(it.get("aim", "")) != "":
				c += 1
		aim_cnt.append(str(c))
		if c != 6:
			aim_n_ok = false
	_ok("조준 후보가 라운드마다 여섯 장", aim_n_ok,
			"R1..R%d — %s (교통카드 + 레어 다섯)" % [rn, ", ".join(aim_cnt)])

	# 표본 — 라운드당 AIM_N 상점. 재는 것은 **자리당** 비율이다.
	# 폭 · 뱃지 「매물」 · 리롤과 값이 안 얽히게 하려는 것이다.
	var A := []
	for r in range(1, rn + 1):
		g.leg_no = _leg_of_round(r)
		g.owned = []
		g.mods_own = []
		g.gold = 999
		var a := _acc()
		a["_th"] = _theory(g.leg_no + 1)
		a["_fw"] = GameData.aim_floor(g.leg_no + 1)
		for i in AIM_N:
			_tally(a)
		A.append(a)

	print("      라운드당 상점 %d곳 · 자리 %d칸씩 (라운드당 %d자리 · 통틀어 %d자리)\n"
			% [AIM_N, GameData.shop_slots(1), AIM_N * GameData.shop_slots(1),
				AIM_N * rn * GameData.shop_slots(1)])
	print("        R   바닥   조준 자리당      설계     레어조준 자리당   조준 상점당  레어조준 상점당")
	for i in rn:
		var a: Dictionary = A[i]
		print("        R%d  %.2f   %6.3f%%      %6.3f%%       %6.3f%%         %6.2f%%       %6.2f%%"
				% [i + 1, a["_fw"],
					_pct(int(a["aim"]), int(a["slots"])), a["_th"],
					_pct(int(a["aimrare"]), int(a["slots"])),
					_pct(int(a["shop_aim"]), int(a["n"])),
					_pct(int(a["shop_rare"]), int(a["n"]))])
	print("")

	# ③ 실측이 설계값과 맞는다. 산수와 코드를 한 줄로 묶는다 — 한 상점
	#    안에서 뽑은 것을 빼므로(pool.erase) 실측이 설계보다 아주 조금
	#    낮게 나오는 것이 정상이다.
	var gapmax := 0.0
	for i in rn:
		var a: Dictionary = A[i]
		gapmax = maxf(gapmax, absf(_pct(int(a["aim"]), int(a["slots"])) - float(a["_th"])))
	_ok("실측이 설계값과 맞는다", gapmax < 1.0,
			"가장 벌어진 라운드가 %.3f%%p — 표와 코드가 같은 수를 말한다" % gapmax)

	# ④ 경사가 실제로 있다. **앞뒤를 묶어** 비교한다(군당 12000자리 · 11σ).
	#    라운드별 실측은 위에 인쇄만 하고 단언은 묶어서 한다.
	var f0 := _pct(int(A[0]["aim"]) + int(A[1]["aim"]),
			int(A[0]["slots"]) + int(A[1]["slots"]))
	var fm := _pct(int(A[3]["aim"]) + int(A[4]["aim"]),
			int(A[3]["slots"]) + int(A[4]["slots"]))
	var f1 := _pct(int(A[rn - 2]["aim"]) + int(A[rn - 1]["aim"]),
			int(A[rn - 2]["slots"]) + int(A[rn - 1]["slots"]))
	_ok("뒤가 앞의 1.8배 이상", f0 > 0.0 and f1 / f0 >= 1.8,
			"R1+R2 %.3f%% → R%d+R%d %.3f%% (%.2f배 · 설계 2.51배)"
			% [f0, rn - 1, rn, f1, f1 / f0])
	_ok("앞 < 가운데 < 뒤", f0 < fm and fm < f1,
			"%.3f%% < %.3f%% < %.3f%%" % [f0, fm, f1])

	# ⑤ 앞이 평평하고 **오늘 그대로**다. 「안 올랐다」가 통과 조건인 유일한
	#    구간이다 — 이 줄이 없으면 R1 을 올려도 ④ 가 그냥 통과한다.
	#    정확한 쪽은 ①이 본다(R1·R2 바닥 == rare_w).
	var p1 := _pct(int(A[0]["aim"]), int(A[0]["slots"]))
	var p2 := _pct(int(A[1]["aim"]), int(A[1]["slots"]))
	_ok("R1 과 R2 가 평평하다", absf(p1 - p2) < 0.8,
			"R1 %.3f%% · R2 %.3f%% (설계 둘 다 %.3f%%)" % [p1, p2, A[0]["_th"]])

	# ⑥ 끝이 실제로 높다. 절대값으로 박아 표가 통째로 지워졌을 때 확실히 운다.
	var p8 := _pct(int(A[rn - 1]["aim"]), int(A[rn - 1]["slots"]))
	_ok("R%d 자리당 3.0%% 이상" % rn, p8 >= 3.0,
			"실측 %.3f%% (설계 %.3f%%)" % [p8, A[rn - 1]["_th"]])

	# ⑦ **이 갈래 밖이 안 흔들린다 — 이 검사의 핵심 줄.**
	#    바닥은 갈래를 고른 **뒤** 동전 안에서만 도는 둘째 저울에 들어가므로
	#    갈래별 자리당 비율은 이론상 R1 과 R8 이 정확히 같아야 한다.
	#    여기가 울면 바닥이 shop.csv 쪽으로 샌 것이다.
	print("        갈래별 자리당 — 바닥은 갈래 저울을 안 만난다")
	var kmax := 0.0
	for k in ["item", "mod", "dart", "cons", "fix", "boost"]:
		var a0 := _pct(int(A[0].get("k_" + k, 0)), int(A[0]["slots"]))
		var a8 := _pct(int(A[rn - 1].get("k_" + k, 0)), int(A[rn - 1]["slots"]))
		kmax = maxf(kmax, absf(a0 - a8))
		print("          %-6s R1 %6.3f%% · R%d %6.3f%% · 차 %+.3f%%p"
				% [k, a0, rn, a8, a8 - a0])
	_ok("갈래 저울이 안 흔들린다", kmax < 3.0,
			"가장 벌어진 갈래가 %.3f%%p — 이론상 정확히 같아야 한다" % kmax)
	var it0 := _pct(int(A[0].get("k_item", 0)), int(A[0]["slots"]))
	_ok("동전 갈래가 표대로 60.9% 언저리", it0 > 58.0 and it0 < 64.0,
			"R1 %.3f%% (shop.csv 여섯 값의 몫) — 사진 0.5%% 도 여기서 안 흔들린다" % it0)

	# ⑧ **등급 사이의 비가 보존된다** — 「한 톨도 안 건드렸다」의 검사.
	#    비조준 동전은 가중치가 전혀 안 움직이고 분모만 커지므로, 비조준
	#    안에서의 비는 정확히 보존되어야 한다(곱하기 하나라 그렇다).
	#    rarity.csv 의 rare 를 노브로 썼다면 불사의 토템·88날어·빌리의
	#    바지 셋이 까닭 없이 같이 올라가 여기가 울었을 자리다.
	var nz0 := int(A[0]["nc"]) + int(A[0]["nu"]) + int(A[0]["nr"])
	var nz8 := int(A[rn - 1]["nc"]) + int(A[rn - 1]["nu"]) + int(A[rn - 1]["nr"])
	var c0 := _pct(int(A[0]["nc"]), nz0)
	var c8 := _pct(int(A[rn - 1]["nc"]), nz8)
	var u0 := _pct(int(A[0]["nu"]), nz0)
	var u8 := _pct(int(A[rn - 1]["nu"]), nz8)
	_ok("비조준 안의 등급 비가 그대로", absf(c0 - c8) < 3.0 and absf(u0 - u8) < 3.0,
			"일반 %.2f%%→%.2f%% · 희귀 %.2f%%→%.2f%%" % [c0, c8, u0, u8])
	_ok("비조준 레어 셋이 R%d 에도 뜬다" % rn, int(A[rn - 1]["nr"]) > 0,
			"%d번 (불사의 토템 · 88날어 · 빌리의 바지)" % int(A[rn - 1]["nr"]))

	# ⑨ 하위 등급이 안 증발한다. Luck be a Landlord 가 상한을 안 걸어
	#    커먼이 통째로 사라진 자리를 수로 막는다.
	var nzp := _pct(nz8, int(A[rn - 1]["item"]))
	_ok("R%d 에도 동전 자리의 90%% 이상이 비조준" % rn, nzp >= 90.0,
			"실측 %.2f%% (설계 92.66%%) — 상한을 0.60 으로 올리면 85%% 로 떨어져 운다" % nzp)

	# ⑩ **교통카드가 안 밀려 올라간다** — 배수 대신 바닥을 고른 이유의 검사.
	#    설계값은 1.198% → 1.142% 로 다른 비조준 58장과 똑같이 −4.69% 준다
	#    (분모가 30.50 → 32.00 으로 커진다). 「전 라운드 상수」가 아니다.
	#    노리는 실패는 따로 있다 — 누가 max 를 곱하기로 바꾸면 3.92% 로
	#    2.7%p 뛰어 바로 운다.
	var t0 := _pct(int(A[0]["r15"]), int(A[0]["slots"]))
	var t8 := _pct(int(A[rn - 1]["r15"]), int(A[rn - 1]["slots"]))
	_ok("교통카드가 사다리에 안 올라탄다", absf(t0 - t8) < 0.6,
			"R1 %.3f%% → R%d %.3f%% (설계 1.198→1.142) — 바닥이 common 0.60 을 못 만난다"
			% [t0, rn, t8])

	# ⑪ 레전더리는 어느 라운드에서도 폭 **안**에 안 뜬다.
	#    바닥을 weight <= 0.0 문 **뒤**에 얹었다는 순서 계약의 검사다.
	#    문 앞에서 박는 실수가 이 한 줄에 걸린다 — 0 x N = 0 이라 안전한
	#    것이 아니라, 레전더리가 바닥을 만나기 전에 빠지기 때문에 안전하다.
	var legs := 0
	for i in rn:
		legs += int(A[i]["leg"])
	_ok("레전더리가 테이블에 안 뜬다", legs == 0,
			"%d번 / 자리 %d칸" % [legs, AIM_N * rn * GameData.shop_slots(1)])

	# ⑫ **팩도 같은 사다리를 탄다.** 동전이 오는 길은 상점 자리와 팩 둘이다
	#    (_boost_one). 한동안 팩이 사다리 밖에 있었는데, 그러면 같은 동전이
	#    R8 에서 상점 5.47% · 팩 0.82% 로 6.7배 갈렸다 — 「라운드가
	#    올라갈수록」이 한 길에서만 참이면 그것은 규칙이 아니라 상점의
	#    버릇이다. 표본이 아니라 갈림이 6배라 적게 굴려도 갈린다. 2026-09-18
	var pk := [0, 0]
	var pk_rare := [0, 0]
	var pk_leg := [0, 0]
	for side in 2:
		g.owned = []
		g.leg_no = _leg_of_round(1 if side == 0 else rn)
		for i in PACK_N:
			var e: Dictionary = g._boost_one("item")
			if e.is_empty():
				continue
			if String(e.d.get("aim", "")) != "":
				pk[side] = int(pk[side]) + 1
				if String(e.d.get("rarity", "")) == "rare":
					pk_rare[side] = int(pk_rare[side]) + 1
			if String(e.d.get("rarity", "")) == "legendary":
				pk_leg[side] = int(pk_leg[side]) + 1
	var kp0 := _pct(int(pk_rare[0]), PACK_N)
	var kp8 := _pct(int(pk_rare[1]), PACK_N)
	print("")
	print("        팩에서 뽑은 동전 %d장씩 — 상점과 같은 바닥을 쓰는가" % PACK_N)
	print("          R1  조준 %5.2f%% · 레어 조준 %5.2f%%" % [_pct(int(pk[0]), PACK_N), kp0])
	print("          R%d  조준 %5.2f%% · 레어 조준 %5.2f%%" % [rn, _pct(int(pk[1]), PACK_N), kp8])
	print("")
	_ok("팩도 라운드를 탄다", kp8 > kp0 * 2.0,
			"레어 조준 R1 %.2f%% → R%d %.2f%%" % [kp0, rn, kp8])
	#  팩의 레전더리는 **바닥이 아니라 legend_pack_w** 로 뜬다. 바닥을 가중치
	#  0 문 앞에서 박으면 l02 정조준이 조준 바닥으로 올라타 기획서 P.16 의
	#  팩 확률이 조용히 깨진다 — 상점의 순서 계약(⑪)과 같은 자리다.
	_ok("팩의 레전더리가 라운드를 안 탄다", int(pk_leg[1]) <= maxi(int(pk_leg[0]) * 3, 3),
			"R1 %d번 · R%d %d번" % [int(pk_leg[0]), rn, int(pk_leg[1])])
	g.owned = []

	# ⑬ **캐시가 안 더러워진다 — 이 사고를 잡는 유일한 줄.**
	#    위 ⑫ 가 팩 길도 굴려 놓았으므로 이 줄은 상점과 팩 **둘 다**를 본다.
	#    GameData.items() 는 _cache["items"] 를 그대로 돌려준다. duplicate()
	#    를 빠뜨려 원본에 w 를 박으면 바닥이 런을 넘어 눌어붙는데, 그것은
	#    max 가 아니라 덮어쓰기라 라운드가 낮아져도 안 내려간다 — 그런데도
	#    「높은 라운드가 더 높다」는 여전히 참이라 위 단언이 전부 통과한다.
	var dirty := PackedStringArray()
	for it in GameData.items():
		if it.has("w"):
			dirty.append(String(it.get("id", "?")))
	_ok("원본 카탈로그에 w 가 안 눌어붙는다", dirty.is_empty(),
			"더러워진 장 %d개%s" % [dirty.size(),
				"" if dirty.is_empty() else ": " + ", ".join(dirty)])

	# ⑭ 감쇠가 일한다 — 이미 조준 동전을 든 플레이어.
	#    _aim_from_items 가 든 동전 첫 장만 읽으므로 둘째 장은 봉인이 걸릴
	#    때만 산다. 사다리를 그대로 두면 **올릴수록 나빠진다** — 후반 상점이
	#    죽은 픽으로 덮인다. aim_own_w 는 곁들이가 아니라 짝이다.
	var card := {}
	for it in GameData.items():
		if String(it.get("id", "")) == "r15":
			card = it.duplicate()
	var own8 := _acc()
	var own1 := _acc()
	for pair in [[rn, own8], [1, own1]]:
		g.leg_no = _leg_of_round(int(pair[0]))
		g.owned = [card.duplicate()]
		g.mods_own = []
		g.gold = 999
		for i in OWN_N:
			_tally(pair[1] as Dictionary)
	g.owned = []                  # 뒷 단언을 안 더럽힌다
	var o8 := _pct(int(own8["aimrare"]), int(own8["slots"]))
	var o1 := _pct(int(own1["aimrare"]), int(own1["slots"]))
	var r8 := _pct(int(A[rn - 1]["aimrare"]), int(A[rn - 1]["slots"]))
	_ok("이미 들면 R%d 사다리가 거의 닫힌다" % rn, o8 < r8,
			"안 들었을 때 %.3f%% → 들었을 때 %.3f%% (설계 3.330 → 1.502)" % [r8, o8])
	_ok("그래도 갈아타는 길은 열려 있다", int(own8["aimrare"]) > 0,
			"레어 조준 %d번 · 상점당 %.2f%% (설계 5.87%%)"
			% [int(own8["aimrare"]), _pct(int(own8["shop_rare"]), int(own8["n"]))])
	#  표본 OWN_N 곳에서 상점당 2.02% 면 σ 가 0.44%p 다. 1.5%p 는 3.4σ —
	#  좁히면 돌릴 때마다 헛되이 운다. 「오늘 아래로 못 내려간다」는 애초에
	#  max 가 구조로 쥔 것이고, 이 줄은 그 구조가 실제로 도는지만 본다.
	var o1s := _pct(int(own1["shop_rare"]), int(own1["n"]))
	_ok("들었어도 R1 은 오늘 그대로", absf(o1s - 2.02) < 1.5,
			"상점당 %.3f%% (설계 2.02%% · 자리당 %.3f%%)" % [o1s, o1])

	# ⑮ **꼬리를 수로 남긴다** — 다음 일감(「조준 예약 칸 — R5 상점, 폭 밖
	#    정가 한 장」)의 출발선이다. 나중에 게이트를 얹을 때 「사다리가 얼마를
	#    줬고 예약이 얼마를 줬나」가 이 줄 하나로 갈린다.
	#
	#    런 하나를 통째로 굴리지 **않는다.** 안 사고 안 리롤하는 런은 상점끼리
	#    독립이라 런 확률이 위에서 잰 **상점당 비율의 곱**이다 — 한 런이 상점
	#    23곳이라 굴리면 표본이 23배로 비싸지는데, 곱하면 공짜인 데다 라운드당
	#    1500곳이라 표본도 훨씬 크다.
	#    단언은 ①만 느슨하게 건다 — 사다리가 통째로 사라지면 79.3% 로 떨어진다.
	var shops := GameData.legs_n() - 1        # 마지막 판은 상점을 안 연다
	var miss := 1.0
	var miss_rare := 1.0
	var miss_pre := 1.0
	var pre_n := 0
	for leg in range(1, shops + 1):
		#  그 상점이 보는 라운드다. 상점은 판 N 을 클리어한 뒤 N+1 을 위해
		#  열리므로 바닥도 nxt = leg + 1 로 본다(_stock_items 와 같은 틀).
		var i: int = GameData.round_of(leg + 1) - 1
		var pa := _pct(int(A[i]["shop_aim"]), int(A[i]["n"])) / 100.0
		var pr := _pct(int(A[i]["shop_rare"]), int(A[i]["n"])) / 100.0
		miss *= 1.0 - pa
		miss_rare *= 1.0 - pr
		#  「R5 상점을 열기 직전까지」다. 판 번호가 아니라 **그 상점이 보는
		#  라운드**로 가른다 — leg_no 12 의 상점은 nxt=13 이라 이미 R5 다.
		if i + 1 < 5:
			miss_pre *= 1.0 - pa
			pre_n += 1
	print("")
	print("        런 하나 — 상점 %d곳 · 안 사고 안 리롤 (위 상점당 비율의 곱)" % shops)
	print("          조준을 한 번이라도 본 런        %6.2f%%  (사다리 전 79.3%%)"
			% (100.0 * (1.0 - miss)))
	print("          레어 조준을 본 런               %6.2f%%  (사다리 전 36.9%%)"
			% (100.0 * (1.0 - miss_rare)))
	print("          R5 상점 직전 %d곳에서 못 본 런   %6.2f%%" % [pre_n, 100.0 * miss_pre])
	print("          → 다음 일감(조준 예약 칸)의 출발선이다")
	print("")
	_ok("런에서 조준을 보는 비율이 85% 이상", 100.0 * (1.0 - miss) >= 85.0,
			"%.2f%% — 빈손 런이 20.7%% 에서 여기까지 줄었다" % (100.0 * (1.0 - miss)))

	# ⑯ 개발자 모드에도 길이 났는가. **dev_probe 는 _rows 까지만 보고
	#    _cur_name 을 안 부른다** — 그 줄의 글은 draw() 안에서만 만들어지고
	#    draw 는 헤드리스에서 안 돈다. 여기가 그 글의 유일한 검사다.
	Dev.page = 1                       # 1쪽 「물건」
	var row := {}
	for e in Dev._rows(g):
		if String(e.get("k", "")) == "aimw":
			row = e
	_ok("개발자 판에 조준 저울 줄이 있다", not row.is_empty(),
			"1쪽 「물건」 · 「테이블 다시 굴리기」 바로 위")
	#  **누르는 줄이 아니다.** "a" 가 없고 _run 의 match k 에도 "aimw" 가
	#  없어야 ◀▶ 로 게임 상태가 안 바뀐다. 다른 list 줄은 「고른 것이 곧
	#  적용」이라 이 줄만 다르다 — 그 다름이 깨지는 것을 여기서 잡는다.
	_ok("그 줄은 읽기 전용이다", not row.has("a") and int(row.get("n", 0)) == rn,
			"a 키 없음 · 칸 %d개 = 라운드 수" % int(row.get("n", 0)))
	_ok("고르개가 안 비었다", Dev._names("aimw").size() == rn,
			"%s" % ", ".join(Dev._names("aimw")))
	if not row.is_empty():
		print("")
		print("        개발자 판 「조준 저울」 줄 — ◀▶ 로 훑는다")
		var seen := {}
		g.owned = []
		for i in rn:
			Dev.pick["aimw"] = i
			var s := Dev._cur_name(g, row)
			seen[s] = true
			print("          %s" % s)
		_ok("라운드마다 다른 글이 선다", seen.size() == rn,
				"서로 다른 줄 %d개 / %d라운드" % [seen.size(), rn])
		#  든 뒤에는 감쇠 쪽을 읽어야 한다. 안 그러면 개발자 판이 상점과
		#  다른 수를 보여 주는 셈이라 거짓말이 된다.
		g.owned = [card.duplicate()]
		Dev.pick["aimw"] = rn - 1
		var so := Dev._cur_name(g, row)
		g.owned = []
		_ok("조준 동전을 들면 감쇠 쪽을 읽는다", so.find("(든 뒤)") >= 0,
				"%s" % so)
	Dev.page = 0

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	#  **판을 손으로 떼고 나간다.** 안 떼면 단언이 다 통과한 뒤 teardown 에서
	#  이따금 죽어(종료 코드 139) 통과한 판을 실패로 읽게 된다 — 이 도구는
	#  상점을 3만 번 넘게 굴려 남는 것이 많다. 여기서는 종료 코드가 곧
	#  검사 결과라 그 한 번이 거짓말이 된다. 2026-09-18
	if g != null:
		root.remove_child(g)
		g.free()
		g = null
	quit(0 if fail == 0 else 1)
