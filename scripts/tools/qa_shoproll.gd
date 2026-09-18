extends SceneTree

# 상점 배정 검사. 2026-09-13 사용자 지시 —
#   "아이템 종류대로 하나씩 떨어트리지 말고 그냥 랜덤으로 해"
#   "사진은 기획서에서 봤듯이 확률 낮게"
#
# 기획서 P.17 「동전 · 골드 · 다트 · 사탕 · 사진 · 팩 랜덤 등장」
# 기획서 P.30 「상점에서 등장할 확률은 0.5%」
#
# **동전 갈래 안의 저울은 여기가 안 본다.** 조준 동전의 라운드별 바닥
# (rounds.csv 의 aim_w)은 qa_aimroll.gd 가 본다 — 이 파일의 표본은
# g.leg_no = 4 = R2 한 라운드뿐이고 R2 의 바닥은 오늘 그대로라, 저울을
# 바꿔도 아래 단언은 한 줄도 안 운다. 그쪽을 같이 돌려라. 2026-09-18
#
#   godot --path . --headless --script scripts/tools/qa_shoproll.gd

const GameData = preload("res://scripts/data.gd")

const N := 12000            # 표본. 0.5% 를 넉넉한 오차로 재기에 충분하다

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
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


# 상점을 한 번 굴리고 갈래별 개수를 돌려준다. 공짜 해금 보상은 폭 밖이라 뺀다.
func _roll() -> Dictionary:
	g._roll_stock()
	var c := {"item": 0, "mod": 0, "dart": 0, "cons": 0, "fix": 0, "boost": 0}
	var ids := {}
	var dup := false
	var slots := 0
	for s in g.stock:
		if bool(s.get("free", false)):
			continue
		slots += 1
		var t := String(s.get("type", ""))
		c[t] = int(c.get(t, 0)) + 1
		var key := t + ":" + String(s.d.get("id", ""))
		if ids.has(key):
			dup = true
		ids[key] = true
	c["_slots"] = slots
	c["_dup"] = dup
	return c


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n상점 배정 검사 — 갈래를 자리마다 굴린다\n")

	# ① 표가 여섯 갈래를 다 들고 있다
	var kinds := GameData.shop_kinds()
	var have := PackedStringArray()
	for k in kinds:
		have.append(String(k.id))
	var want := ["item", "mod", "dart", "cons", "fix", "boost"]
	var miss := PackedStringArray()
	for w in want:
		if not have.has(w):
			miss.append(w)
	_ok("shop.csv 가 여섯 갈래", miss.is_empty(),
			"%d갈래: %s" % [kinds.size(), ", ".join(have)])

	# ② 판 표가 갈래별 칸을 더는 안 쥔다
	var cols_gone := true
	for r in GameData.rows("rounds"):
		if r.has("shop_items") or r.has("shop_mods") or r.has("shop_darts"):
			cols_gone = false
	_ok("rounds.csv 에 갈래별 칸이 없다", cols_gone,
			"폭은 shop_slots 한 열이 쥔다 (R1 %d칸)" % GameData.shop_slots(1))

	# ③ 표본을 돌린다
	g.leg_no = 4
	g.owned = []
	g.mods_own = []
	g.gold = 999
	var tot := {"item": 0, "mod": 0, "dart": 0, "cons": 0, "fix": 0, "boost": 0}
	var shops_with := {"item": 0, "mod": 0, "dart": 0, "cons": 0, "fix": 0, "boost": 0}
	var dup := 0
	var badw := 0
	var want_w := GameData.shop_slots(g.leg_no)
	for i in N:
		var c := _roll()
		if bool(c["_dup"]):
			dup += 1
		if int(c["_slots"]) != want_w:
			badw += 1
		for k in tot:
			tot[k] = int(tot[k]) + int(c[k])
			if int(c[k]) > 0:
				shops_with[k] = int(shops_with[k]) + 1

	print("")
	print("      상점 %d곳 · 자리 %d칸씩 — 뜬 횟수" % [N, want_w])
	for k in want:
		var nm := ""
		for kk in kinds:
			if String(kk.id) == k:
				nm = String(kk.n)
		print("        %-4s %-8s 자리 %6.2f%% · 상점당 %6.2f%%"
				% [k, nm, 100.0 * float(tot[k]) / float(N * want_w),
					100.0 * float(shops_with[k]) / float(N)])
	print("")

	_ok("폭이 늘 표대로다", badw == 0, "어긋난 상점 %d곳" % badw)
	_ok("한 상점에 같은 물건이 두 번 안 온다", dup == 0, "겹친 상점 %d곳" % dup)

	# ④ 갈래마다 칸을 못 박지 않는다 — 없는 상점이 실제로 있어야 한다
	for k in ["item", "mod", "dart", "cons", "boost"]:
		var without := N - int(shops_with[k])
		_ok("「%s」 없는 상점이 있다" % k, without > 0,
				"%d곳 (%.1f%%)" % [without, 100.0 * float(without) / float(N)])

	# ⑤ 여섯 갈래가 다 뜬다 — 저울이 0 인 갈래는 영영 안 온다
	for k in want:
		_ok("「%s」 가 실제로 뜬다" % k, int(tot[k]) > 0, "%d번" % int(tot[k]))

	# ⑥ 사진 — 기획서 P.30 의 0.5%
	var fix_pct := 100.0 * float(shops_with["fix"]) / float(N)
	_ok("사진이 상점당 0.5% 언저리", fix_pct >= 0.25 and fix_pct <= 0.85,
			"실측 %.3f%% (%d/%d) · 기획서 0.5%%" % [fix_pct, int(shops_with["fix"]), N])
	_ok("사진이 동전보다 훨씬 드물다", int(tot["fix"]) * 50 < int(tot["item"]),
			"사진 %d · 동전 %d" % [int(tot["fix"]), int(tot["item"])])

	# ⑦ 보드 확장이 바닥나도 자리가 안 빈다
	print("")
	g.mods_own = []
	var all_mods := []
	for m in GameData.mods():
		all_mods.append(String(m.id))
	# 한 장만 끼지만 _mod_room 은 "이미 가진 것" 을 보므로, 다 채운 척해 본다
	g.mods_own = all_mods
	var empty_mod: bool = (g._stock_mods() as Array).is_empty()
	var w2 := 0
	for i in 200:
		var c2 := _roll()
		w2 = maxi(w2, int(c2["_slots"]))
		if int(c2["_slots"]) != want_w:
			w2 = -1
			break
	_ok("보드 확장이 바닥나도 폭이 그대로", empty_mod and w2 == want_w,
			"살 수 있는 보드 확장 %d장 · 폭 %d" % [g._stock_mods().size(), w2])
	g.mods_own = []

	# ⑧ 등급 번짐 — 테이블 동전 둘레의 빛이 등급 색이다 (2026-09-13 지시)
	print("")
	_ok("일반은 안 빛난다", g._glow_of("common").a == 0.0,
			"알파 %.2f" % g._glow_of("common").a)
	_ok("빈 등급도 안 빛난다", g._glow_of("").a == 0.0, "")
	for rr in ["uncommon", "rare", "legendary"]:
		var rc: Color = GameData.rarity_color(rr)
		var gc: Color = g._glow_of(rr)
		_ok("%s 는 등급 색으로 빛난다" % rr,
				gc.a > 0.0 and is_equal_approx(gc.r, rc.r)
				and is_equal_approx(gc.g, rc.g)
				and is_equal_approx(gc.b, rc.b),
				"#%s 알파 %.2f (rarity.csv #%s)"
				% [gc.to_html(false), gc.a, rc.to_html(false)])

	# ⑨ 팩의 「사탕」 갈래가 사진을 안 뱉는다
	var leak := 0
	for i in 2000:
		var e: Dictionary = g._boost_one("cons")
		if e.is_empty():
			continue
		if String(e.d.get("cat", "")) != "area":
			leak += 1
	_ok("팩의 사탕 갈래가 사진을 안 뱉는다", leak == 0, "샌 것 %d개 / 2000" % leak)

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
