extends SceneTree

# 첫 손님의 두 장 검사 (2026-09-26 · 2026-09-27 갈아엎음).
#   「튜토리얼을 게임의 매력을 보여 주는 걸로 특화하자 — 개사기 아이템 주는 거」
#   처음엔 런 시작에 손에 넣어 줬는데 「상점에서 자연스럽게 줘야지」로 반려돼
#   사용자와 흐름을 정했다:
#     ① 첫 상점 테이블 네 칸 중 두 칸에 공짜 딱지로 선다(나머지 둘은 평소대로)
#     ② 상인이 「첫 손님이라 둘은 그냥 준다」 한 줄(u_gift)
#     ③ 안 집고 나가면 다음 상점에 다시 선다 · 둘 다 쥐면 그 뒤로 안 선다
#     ④ SAFETY LAST! 가 처음 켜질 때 한 줄(u_last)
#     ⑤ 챌린지·무한 런에는 안 선다 · 점수 표를 한 톨도 안 건드린다
#
#   godot --path . --headless --script scripts/tools/qa_boot.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_boot.cfg"
	Save.gpath = "user://_qa_boot_g.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-40s %s" % ["통과" if c else "실패", n, d])


func _ids() -> Array:
	var out := []
	for o in g.owned:
		out.append(String(o.get("id", "")))
	return out


#  테이블에 선 공짜 선물의 자리들.
func _gift_at() -> Array:
	var out := []
	for i in g.stock.size():
		var s: Dictionary = g.stock[i]
		if s.type == "item" and bool(s.get("free", false)) \
				and (g.BOOT_GIFT as Array).has(String(s.d.id)):
			out.append(i)
	return out


func _shop() -> void:
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 4
	g._open_shop()


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	print("\n== 첫 손님의 두 장 ==")
	var want: Array = (g.BOOT_GIFT as Array).duplicate()

	# ── ① 손에는 안 준다 · 첫 상점에 선다 ─────────────
	print("① 첫 런 첫 상점")
	Save.wipe()
	g.state = g.S.TITLE
	g._new_run()
	_ok("런 시작에 손에 넣어 주지 않는다", _ids().is_empty(), str(_ids()))
	_shop()
	var at := _gift_at()
	_ok("두 장이 테이블에 선다", at.size() == want.size(), "%d장" % at.size())
	var free0 := true
	for i in at:
		if int(g.stock[i].cost) != 0:
			free0 = false
	_ok("둘 다 값이 0 이다", free0, "")
	_ok("테이블 폭은 그대로다(둘은 평소 매물)",
			g.stock.size() == GameData.shop_slots(1), "%d / %d"
			% [g.stock.size(), GameData.shop_slots(1)])
	var dup := false
	for i in g.stock.size():
		if at.has(i):
			continue
		var s: Dictionary = g.stock[i]
		if s.type == "item" and want.has(String(s.d.id)):
			dup = true
	_ok("같은 장이 평소 매물로 또 안 선다", not dup, "")
	_ok("상인 한 줄이 줄에 선다",
			g.tutor_q.has("u_gift") or String(g.tutor_id) == "u_gift",
			str(g.tutor_q))
	#  낙하가 앉은 뒤 과녁이 두 장을 감싼다
	g.drop_fast = true
	for k in 200:
		g._drop_step(1.0 / 60.0)
	var mr: Rect2 = g._mark_rect("gift")
	var inside := true
	for i in at:
		if not mr.encloses(g._obj_box(i)):
			inside = false
	_ok("과녁이 두 장을 감싼다", mr.size.x > 2.0 and inside,
			"%.0fx%.0f" % [mr.size.x, mr.size.y])
	_ok("과녁 이름이 표에 있다", GameData.TUTOR_MARKS.has("gift"), "")

	# ── ② 한 장만 집고 나가면 다음 상점에 남은 한 장 ──
	print("② 안 집고 나가면")
	var g0: int = g.gold
	g._buy(at[0])
	var got1 := _ids()
	_ok("공짜로 집힌다 — 골드가 그대로다", g.gold == g0 and got1.size() == 1,
			"%s · 골드 %d" % [got1, g.gold])
	_ok("한 장만으로는 배움 표에 안 적힌다", not Save.taught("u_boot"), "")
	_shop()
	var at2 := _gift_at()
	_ok("다음 상점에 남은 한 장이 다시 선다", at2.size() == 1
			and not got1.has(String(g.stock[at2[0]].d.id)), "%d장" % at2.size())
	g._buy(at2[0])
	var all := true
	for w in want:
		if not _ids().has(String(w)):
			all = false
	_ok("둘 다 손에 들어왔다", all, str(_ids()))
	_ok("둘 다 쥐면 배움 표에 적힌다", Save.taught("u_boot"), "")
	_shop()
	_ok("그 뒤 상점에는 안 선다", _gift_at().is_empty(), "")

	# ── ③ 두 번째 런 ─────────────────────────────────
	print("③ 두 번째 런")
	g.state = g.S.TITLE
	g._new_run()
	_shop()
	_ok("두 번째 런 첫 상점에도 안 선다", _gift_at().is_empty(), "")

	# ── ④ 아예 안 집은 사람 ───────────────────────────
	print("④ 하나도 안 집고 나간 사람")
	Save.wipe()
	g.state = g.S.TITLE
	g._new_run()
	_shop()
	_shop()
	_ok("다음 상점에 두 장 다 다시 선다", _gift_at().size() == want.size(), "")

	# ── ⑤ 챌린지·무한 ────────────────────────────────
	print("⑤ 제약을 걸고 도는 런")
	Save.wipe()
	GameData.challenge = "solo"
	g.state = g.S.TITLE
	g._new_run()
	_shop()
	_ok("챌린지 런에는 안 선다", _gift_at().is_empty(), "")
	GameData.challenge = ""
	Save.wipe()
	g.state = g.S.TITLE
	g._new_run()
	GameData.endless = true
	_ok("무한 런에는 안 선다", g._boot_stock().is_empty(), "")
	GameData.endless = false

	# ── ⑥ SAFETY LAST! 가 처음 켜질 때 ─────────────────
	print("⑥ 끝이 절정인 장")
	Save.wipe()
	g.state = g.S.TITLE
	g._new_run()
	for it in GameData.items():
		if String(it.id) == "u26":
			var cp: Dictionary = it.duplicate()
			cp.gs = 0
			cp.bought = 0
			g.owned.append(cp)
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.RESOLVE
	g.cur_chip = 40
	g.cur_mult = 4
	g.queue.clear()
	g.queue.append({"k": "item", "i": 0, "kind": "xmult", "v": 3, "lbl": "배수 ×3"})
	g._next_step()
	_ok("처음 켜질 때 한 줄이 선다", g.tutor_q.has("u_last"), str(g.tutor_q))
	g.tutor_q.clear()
	g.queue.append({"k": "item", "i": 0, "kind": "xmult", "v": 3, "lbl": "배수 ×3"})
	g._next_step()
	_ok("두 번째부터는 안 선다", not g.tutor_q.has("u_last"), "")

	# ── ⑦ 표를 안 건드린다 · 글 ───────────────────────
	print("⑦ 밸런스 · 글")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var i0: int = src.find("func _boot_due")
	var i1: int = src.find("\nconst BOOT_GIFT", i0)
	var body: String = src.substr(i0, i1 - i0)
	_ok("주는 자가 값을 한 개도 안 고친다",
			body.find("score") < 0 and body.find("target") < 0
			and body.find("gold") < 0, "")
	_ok("값표가 「공짜」를 적는다", src.find("\"공짜\"") >= 0, "")
	var tut := FileAccess.get_file_as_string("res://data/tutor.csv")
	_ok("상인 한 줄이 표에 있다", tut.find("u_gift,1,첫 손님이라 둘은 그냥 준다") >= 0, "")
	_ok("끝 한 줄이 표에 있다", tut.find("u_last,1,마지막 다트에서 배수가 세 배가 된다") >= 0, "")

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(fail)
