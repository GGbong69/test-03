extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  레전더리를 얻는 길 — 기획서 P.16 의 3단이 실제로 도는가
#
#   실행:  godot --path . --headless --quit-after 900 #              --script scripts/tools/legend_probe.gd
#   종료 코드 = 어긋난 검사의 수
#
#  ① 조건을 채우면 열린다
#  ② **바로 다음 상점**에 0골드로 온다
#  ③ 한 번 받은 뒤로는 팩에서 온다 (그전에는 안 온다)
#
#  왜 있는가
#    레전더리는 상점 테이블에 안 뜨는 유일한 등급이라(가중치 0.00) 손으로
#    돌려서는 길이 막혔는지 알 수가 없다. 처음 돌렸을 때 실제로 막혀 있었다 —
#    공짜로 놓은 그 한 장을 **사탕 바꿔치기가 덮어써서** 조용히 사라졌다.
#    재고 0번 자리를 건드리는 코드가 늘 때마다 여기서 걸린다.

var g: Node = null
var bad := 0


func _initialize() -> void:
	Save.path = "user://_tmp_legend.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260909)


func _ok(c: bool, what: String, detail := "") -> void:
	if c:
		print("  OK   %-42s %s" % [what, detail])
	else:
		bad += 1
		print("  실패 %-42s %s" % [what, detail])


# 팩의 동전 갈래를 여러 번 뽑아 그 장이 나오는지 본다.
func _in_pack(id: String, tries := 4000) -> bool:
	for i in tries:
		var e: Dictionary = g._boost_one("item")
		if not e.is_empty() and String(e.d.id) == id:
			return true
	return false


func _process(_d: float) -> bool:
	g.set_process(false)
	print("\n── 레전더리를 얻는 길 ──\n")

	var leg := []
	for it in GameData.items():
		if String(it.rarity) == "legendary":
			leg.append(it)
	_ok(leg.size() >= 2, "레전더리가 표에 있다",
			" · ".join(PackedStringArray(leg.map(func(x): return "%s(%s)" % [x.n, x.id]))))

	# 조건을 쥔 장을 고른다 (정조준)
	var tgt := {}
	for it in leg:
		if String(it.get("ustat", "")) != "":
			tgt = it
	if tgt.is_empty():
		_ok(false, "조건을 쥔 레전더리가 없다")
		quit(1)
		return false
	var st := String(tgt.ustat)
	var need := int(tgt.uv)
	print("  대상: %s — %s %d 필요\n" % [tgt.n, st, need])

	GameData.pack = "base"
	g._new_run()

	# ── ① 조건 미달이면 안 열린다 ────────────────────
	g._item_unlock_check()
	_ok(not Save.unlocked("item:" + String(tgt.id)), "조건 미달이면 안 열린다",
			"%s %d/%d" % [st, Save.stat(st), need])
	_ok(g._item_free_pick().is_empty(), "공짜로 줄 것도 없다")

	# ── ② 팩에도 아직 안 온다 ────────────────────────
	_ok(not _in_pack(String(tgt.id)), "받아 보기 전에는 팩에 안 든다",
			"4000번 뽑아 한 번도 안 나옴")

	# ── ③ 조건을 채우면 열린다 ───────────────────────
	if Save.PEAKS.has(st):
		Save.peak(st, need)
	else:
		Save.bump(st, need)
	g._item_unlock_check()
	_ok(Save.unlocked("item:" + String(tgt.id)), "조건을 채우면 열린다",
			"%s %d/%d" % [st, Save.stat(st), need])

	# ── ④ 바로 다음 상점에 0골드로 온다 ──────────────
	var pick: Dictionary = g._item_free_pick()
	_ok(not pick.is_empty() and String(pick.id) == String(tgt.id),
			"열린 장이 공짜 후보로 잡힌다", String(pick.get("id", "없음")))
	g.leg_no = 1
	g._roll_stock()
	var free_i := -1
	for i in g.stock.size():
		var e: Dictionary = g.stock[i]
		if String(e.type) == "item" and String(e.d.id) == String(tgt.id):
			free_i = i
	_ok(free_i >= 0, "상점 재고에 실린다", "자리 %d / %d칸" % [free_i, g.stock.size()])
	if free_i >= 0:
		_ok(int(g.stock[free_i].cost) == 0, "값이 0골드다",
				"%d골드" % int(g.stock[free_i].cost))

	# ── ⑤ 받기 전에는 팩에 아직 안 온다 ──────────────
	_ok(not _in_pack(String(tgt.id)), "열리기만 해서는 팩에 안 든다")

	# ── ⑥ 사면 「받아 봤다」가 서고 팩에 든다 ─────────
	if free_i >= 0:
		g.gold = 99
		g._buy(free_i)
	_ok(Save.unlocked("itemgot:" + String(tgt.id)), "사면 「받아 봤다」가 선다")
	_ok(g._has_item(String(tgt.id)), "손에 들어왔다")

	# 손에 든 장은 팩에서 빠지므로(중복 금지) 비운 뒤에 본다
	g.owned = []
	_ok(_in_pack(String(tgt.id)), "그 뒤로는 팩에서 온다",
			"가중치 %.3f" % GameData.tune("legend_pack_w"))

	# ── ⑦ 두 번째로는 공짜가 안 온다 ─────────────────
	_ok(g._item_free_pick().is_empty(), "공짜는 한 번뿐이다")

	# ── ⑧ 다트통이 쥐여 준 것도 「받아 봤다」다 ───────
	Save.wipe()
	GameData.pack = "p_x1"
	g._new_run()
	_ok(Save.unlocked("itemgot:l01"), "다트통이 쥐여 준 장도 받아 본 것이다",
			"저울 다트통 → 데칼코마니")
	g.owned = []
	_ok(_in_pack("l01"), "그래서 데칼코마니도 팩에서 온다")

	print("")
	print("전부 통과" if bad == 0 else "실패 %d건" % bad)
	quit(bad)
	return false
