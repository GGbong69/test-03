extends SceneTree

# 팩 고르기 검사. 2026-09-13 사용자 제보 —
#   "지금 팩을 까면 하나만 선택이 아니라 아이템 다 주거든?"
#
# 기획서 P.17 「작은 팩 아이템 2개 중 1 / 큰 팩 아이템 4개 중 1 선택 획득」
#
#   godot --path . --headless --script scripts/tools/qa_pack.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_pack.cfg"
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


# 팩 하나를 사서 다 뜯는다. 쏟은 것의 stock 인덱스를 돌려준다.
func _open(bd: Dictionary) -> Array:
	g.gold = 99
	g.owned = []
	g.cons = []
	g._roll_stock()
	var before: int = (g.stock as Array).size()
	g._boost_deal(bd)
	for k in 400:
		g._boost_tick(1.0 / 60.0)
		if g.boost_t < 0.0:
			break
	var out := []
	for i in range(before, g.stock.size()):
		if bool(g.stock[i].get("pack", false)):
			out.append(i)
	return out


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n팩 고르기 검사 — 여럿 중 하나\n")

	var bs := GameData.boosters()
	_ok("팩이 두 종류다", bs.size() == 2,
			", ".join(PackedStringArray([String(bs[0].n), String(bs[1].n)]))
			if bs.size() == 2 else "%d종" % bs.size())

	for bd in bs:
		print("")
		var nm := String(bd.n)
		var size := int(bd.get("size", 2))
		var pick := int(bd.get("pick", 1))
		var idx := _open(bd)
		_ok("%s — %d장이 쏟아진다" % [nm, size], idx.size() == size,
				"%d장" % idx.size())
		_ok("%s — 몫이 %d 이다" % [nm, pick], g.boost_pick == pick,
				"boost_pick %d (표 pick %d)" % [g.boost_pick, pick])
		if idx.is_empty():
			continue

		# 값이 0 이라도 몫이 없으면 못 집는다
		var got := 0
		for i in idx:
			if g._buy_block(i) == "":
				g._buy(i)
				got += 1
		_ok("%s — %d장만 집힌다" % [nm, pick], got == pick,
				"집은 것 %d장 / 쏟은 것 %d장" % [got, idx.size()])

		var left := 0
		var swept := 0
		for i in idx:
			if bool(g.stock[i].sold):
				swept += 1
			else:
				left += 1
		_ok("%s — 나머지는 쓸려 나간다" % nm, left == 0,
				"남은 것 %d · 쓸린 것 %d" % [left, swept])
		_ok("%s — 몫을 다 쓰면 0" % nm, g.boost_pick == 0,
				"boost_pick %d" % g.boost_pick)
		var why: String = String(g._buy_block(idx[0]))
		_ok("%s — 다 쓴 뒤에는 거절한다" % nm, why != "", "사유 '%s'" % why)

	# 리롤하면 몫도 같이 사라진다 — 안 지우면 다음 매물을 공짜로 집는다
	print("")
	var idx2 := _open(bs[0])
	_ok("팩을 열면 몫이 선다", g.boost_pick > 0, "%d" % g.boost_pick)
	g._roll_stock()
	_ok("리롤하면 몫이 접힌다", g.boost_pick == 0, "%d" % g.boost_pick)
	var packs_left := 0
	for st in g.stock:
		if bool(st.get("pack", false)):
			packs_left += 1
	_ok("리롤하면 쏟은 것도 없어진다", packs_left == 0, "%d장" % packs_left)

	# 사탕 칸이 꽉 찬 채로 사진을 사면 값만 잃던 자리 (2026-09-13)
	print("")
	g.gold = 99
	g.cons = []
	var fx := GameData.fixtures()
	for k in GameData.cons_slots():
		g.cons.append(fx[0])
	g.stock = [{"type": "fix", "d": fx[1], "cost": 15, "sold": false}]
	var g0: int = g.gold
	var why2: String = String(g._buy_block(0))
	_ok("칸이 차면 사진을 미리 막는다", why2 != "", "사유 '%s'" % why2)
	g._buy(0)
	_ok("막힌 사진은 값을 안 먹는다", g.gold == g0, "%d → %d" % [g0, g.gold])
	_ok("막힌 사진은 안 사라진다", not bool(g.stock[0].sold),
			"sold %s" % g.stock[0].sold)

	# 해금 보상(free)과 안 헷갈린다 — 둘 다 0골드다
	print("")
	var free_is_pack := false
	for st in g.stock:
		if bool(st.get("free", false)) and bool(st.get("pack", false)):
			free_is_pack = true
	_ok("공짜 보상은 팩 물건이 아니다", not free_is_pack, "")

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
