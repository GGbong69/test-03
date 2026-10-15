extends SceneTree
#  상점 고르기 · 다트통 다트 · 칠판 수(2026-10-15) — 못 박는 것:
#    ① 무쇠 다트통(여섯 발 무거운) — 상점 다트를 산다 · 무거운 하나가 그 다트로 바뀐다
#    ② 다트통의 기본 다트는 상점에 안 뜬다(무쇠 통에 무거운 · 기본 통에 표준)
#    ③ 기본 다트를 다 갈면 막는 말이 그 다트 이름을 말한다
#    ④ 고른 매물은 떠오른다(lift_sel 둘레) · 흔들림(sway)이 선다 · 맨 위에 그린다
#    ⑤ 살 수 있게 고르면 등록기가 켜지고(chute_rk) · 못 사면 꺼진다 · 판매 고르기면 저울
#    ⑥ 칠판 목표 · 점수 — 여섯 · 일곱 자리가 칠판 폭 안
#   godot --headless --path . --script scripts/tools/qa_shopsel.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_shopsel_g.cfg"
	Save.path = "user://_qa_shopsel.cfg"
	Save.prof_fmt = "user://_qa_shopsel_%d.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-52s %s" % ["통과" if cond else "실패", nm, note])


func _dart(id: String) -> Dictionary:
	for dd in GameData.darts():
		if String(dd.id) == id:
			return dd
	return {}


func _tick(sec: float) -> void:
	for i in int(ceil(sec * 60.0)):
		g._drop_extras(1.0 / 60.0)
		g._prop_tick(1.0 / 60.0)


func _run() -> void:
	GameData.pack = "p_iron"
	g._new_run()
	g.tut_run = false
	g.gold = 999
	g.leg_no = 4
	g._open_shop()
	g._drop_settle()
	# ①
	g.stock.append({"type": "dart", "d": _dart("lgt"), "cost": 6, "sold": false})
	var di: int = g.stock.size() - 1
	_ok("① 무쇠 통 — 상점 다트를 살 수 있다", g._buy_block(di) == "", g._buy_block(di))
	g._buy(di)
	var ids: Array = g._ids_of(g.magazine)
	_ok("① 무거운 하나가 가벼운으로", ids.count("lgt") == 1 and ids.count("hvy") == ids.size() - 1, str(ids))
	# ②
	var seen := {}
	for r in 60:
		g._roll_stock()
		for s in g.stock:
			if String(s.type) == "dart":
				seen[String(s.d.id)] = true
	_ok("② 무쇠 통 상점에 무거운 · 표준이 안 뜬다", not seen.has("hvy") and not seen.has("std") and not seen.is_empty(),
			str(seen.keys()))
	# ③
	for i in g.magazine.size():
		g.magazine[i] = _dart("mag")
	g.stock.append({"type": "dart", "d": _dart("lgt"), "cost": 6, "sold": false})
	var blk: String = g._buy_block(g.stock.size() - 1)
	_ok("③ 다 갈면 막는다 · 그 다트 이름", blk.contains(GameData.dart_name("hvy")), blk)
	# ④ ⑤ — 새 상점에서 동전 하나를 고른다
	g._roll_stock()
	g._drop_settle()
	var ii := -1
	for k in g.stock.size():
		if String(g.stock[k].type) == "item":
			ii = k
	if ii < 0:
		g.stock.append({"type": "item", "d": GameData.items()[0], "cost": 3, "sold": false})
		g._drop_settle()
		ii = g.stock.size() - 1
	g.motion_off = false
	g.buy_sel = ii
	_tick(1.2)
	var lf: float = float(g.drop[ii].lift)
	_ok("④ 고른 매물이 떠오른다", absf(lf - float(g.DROP.lift_sel)) <= float(g.DROP.bob_h) + 1.0,
			"%.1f" % lf)
	var sw := []
	for k in 40:
		_tick(1.0 / 60.0)
		sw.append(float(g.drop[ii].get("sway", 0.0)))
	_ok("④ 흔들린다", sw.max() - sw.min() > 0.02, "%.3f" % (sw.max() - sw.min()))
	var z: Array = g._z_order()
	_ok("④ 맨 위에 그린다", not z.is_empty() and int(z[z.size() - 1]) == ii)
	_ok("⑤ 살 수 있게 고르면 등록기가 켜진다", float(g.chute_rk[g.Z_BUY]) >= 1.0 and float(g.chute_rk[g.Z_SELL]) == 0.0,
			str(g.chute_rk))
	g.gold = 0
	g.stock[ii].cost = 5
	_tick(0.6)
	_ok("⑤ 골드가 모자라면 꺼진다", float(g.chute_rk[g.Z_BUY]) == 0.0, str(g.chute_rk))
	g.buy_sel = -1
	_tick(0.6)
	_ok("④ 고르기를 풀면 내려앉는다", float(g.drop[ii].lift) < float(g.DROP.lift_hov) + 0.5
			and float(g.drop[ii].get("sway", 0.0)) == 0.0, "%.1f" % float(g.drop[ii].lift))
	g.owned.append(GameData.items()[0].duplicate())
	g.sell_sel = 0
	_tick(0.6)
	_ok("⑤ 판매 고르기면 저울이 켜진다", float(g.chute_rk[g.Z_SELL]) >= 1.0, str(g.chute_rk))
	# ⑥
	var w: float = (g.SCOREB.box as Rect2).size.x - 16.0
	var fit := true
	var note := []
	for v in [123456, 999999, 999999999]:
		var s: String = GameData.big(v)
		var sz: int = g._fit_sz(s, w, 36)
		var tw: float = g.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		if tw > w:
			fit = false
		note.append("%s→%d(%.0f)" % [s, sz, tw])
	_ok("⑥ 칠판 목표가 폭(%.0f) 안" % w, fit, str(note))
