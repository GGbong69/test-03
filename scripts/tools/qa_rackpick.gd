extends SceneTree

# 상점 밖에서 It's Not About Money · 마릴린 딥틱이 동전 슬롯에서 대상을
# 고르는가. 기획서 s33 이 그 둘을 「상관없음」으로 적었는데 판 위에는
# 테이블이 없어 고를 자리가 없었다.
#
#   godot --path . --headless --script scripts/tools/qa_rackpick.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_rack.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _find(id: String) -> Dictionary:
	for c in GameData.consumables():
		if String(c.id) == id:
			return c
	return {}


func _coin(n := 1) -> void:
	g.owned = []
	for i in n:
		var c: Dictionary = GameData.items()[i].duplicate()
		c.gs = 0
		c.bought = 1
		g.owned.append(c)


func _hold(id: String) -> void:
	g.cons = [_find(id).duplicate()]


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	for i in 20:
		g._process(1.0 / 60.0)

	print("\n판에서 동전 고르기 검사\n")

	# ① 판 위에서 쓰면 고르는 중이 되고 손에 남는다
	g.state = g.S.PICK
	_coin(1)
	_hold("v_moth")
	g._cons_use(0)
	_ok("불나방 — 고르는 중이 된다", g.photo_rack == "burn" and g.cons.size() == 1,
			"photo_rack '%s' · 손 %d장" % [g.photo_rack, g.cons.size()])

	# ② 첫 칸을 고르면 부수고 판매가 2배
	var want: int = GameData.sell_value(g.owned[0]) * 2
	g.gold = 0
	g._photo_rack_click(g._slot_rect(0).get_center())
	_ok("고르면 부수고 판매가 2배",
			g.gold == want and g.owned.is_empty() and g.cons.is_empty(),
			"골드 %d/%d · 동전 %d · 손 %d" % [g.gold, want, g.owned.size(), g.cons.size()])
	_ok("고른 뒤 풀린다", g.photo_rack == "", "'%s'" % g.photo_rack)

	# ③ 마릴린 딥틱 — 복사
	g.state = g.S.PICK
	_coin(1)
	_hold("v_fake")
	g._cons_use(0)
	g._photo_rack_click(g._slot_rect(0).get_center())
	_ok("마릴린 딥틱 — 동전이 하나 는다", g.owned.size() == 2 and g.cons.is_empty(),
			"동전 %d · 손 %d" % [g.owned.size(), g.cons.size()])

	# ④ 슬롯이 꽉 차면 복사가 안 되고 사진이 남는다
	g.state = g.S.PICK
	_coin(GameData.max_items())
	_hold("v_fake")
	g._cons_use(0)
	g._photo_rack_click(g._slot_rect(0).get_center())
	_ok("슬롯이 꽉 차면 복사 안 된다", g.owned.size() == GameData.max_items(),
			"동전 %d/%d" % [g.owned.size(), GameData.max_items()])
	_ok("못 썼으면 사진이 손에 남는다", g.cons.size() == 1, "손 %d장" % g.cons.size())
	g.photo_rack = ""

	# ⑤ 무르기 — 딴 데를 누르면 풀리고 손에 남는다
	g.state = g.S.PICK
	_coin(1)
	_hold("v_moth")
	g._cons_use(0)
	g._photo_rack_click(Vector2(4.0, 330.0))
	_ok("딴 데를 누르면 무른다", g.photo_rack == "" and g.cons.size() == 1
			and g.owned.size() == 1,
			"photo_rack '%s' · 손 %d · 동전 %d" % [g.photo_rack, g.cons.size(), g.owned.size()])

	# ⑥ 빈 칸을 누르면 아무 동전도 안 부서진다
	g.state = g.S.PICK
	_coin(1)
	_hold("v_moth")
	g._cons_use(0)
	g._photo_rack_click(g._slot_rect(GameData.max_items() - 1).get_center())
	_ok("빈 칸을 눌러도 안 부서진다", g.owned.size() == 1,
			"동전 %d" % g.owned.size())
	g.photo_rack = ""

	# ⑦ 동전이 없으면 거절당하고 손에 남는다
	g.state = g.S.PICK
	g.owned = []
	_hold("v_moth")
	g._cons_use(0)
	_ok("동전이 없으면 거절", g.photo_rack == "" and g.cons.size() == 1,
			"%s" % g.pay_msg)

	# ⑧ 상점에서는 옛 길 그대로 테이블이 갈린다
	g.state = g.S.SHOP
	_coin(2)
	_hold("v_moth")
	g._cons_use(0)
	_ok("상점에서는 테이블이 갈린다", g.photo == "burn" and g.stock.size() == 2,
			"photo '%s' · 매물 %d" % [g.photo, g.stock.size()])
	g._photo_close()

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
