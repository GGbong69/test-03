extends SceneTree
# 팩의 겉 셋(2026-10-06 「3가지 랜덤으로 나오도록 해줄수 있어?」) — 못 박는 것:
#   ① 상점에 깔린 팩은 겉을 하나 입는다(foil · env · tin) — 굴려 보면 셋이 다 나오고
#      한쪽으로 쏠리지 않는다.
#   ② 겉은 판의 뽑기를 안 건드린다 — 같은 씨로 굴린 두 상점이 겉의 난수와 무관하게
#      같은 매물을 낸다(look_rng 는 따로 돈다).
#   ③ 표의 줄(GameData 캐시)에 겉이 안 박힌다 — 사본에만 박는다.
#   ④ 매듭(저장)이 겉을 적고 되살린 상점이 같은 겉을 입는다. 옛 매듭(겉 없음)도 입는다.
#   ⑤ 연 팩(_boost_deal)이 판 위의 그 겉 그대로 열린다.
#   ⑥ 개발자 「팩 겉」이 하나를 고르면 앞으로 깔릴 팩 · 지금 테이블의 팩이 그 겉이고,
#      무작위로 돌리면 다시 굴린다.
#   godot --headless --path . --script scripts/tools/qa_packlook.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_packlook_g.cfg"
	Save.path = "user://_qa_packlook.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _packs() -> Array:
	var out := []
	for s in g.stock:
		if String((s as Dictionary).get("type", "")) == "boost":
			out.append(s)
	return out


func _ids() -> String:
	var a := []
	for s in g.stock:
		a.append("%s:%s" % [String(s.type), String((s.d as Dictionary).get("id", ""))])
	return ",".join(a)


func _run() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g.leg_no = 3
	g._open_shop()
	g.drop_fast = true

	# ① 셋이 다 나오고 고르다
	var cnt := {"foil": 0, "env": 0, "tin": 0}
	var bare := 0
	for r in 400:
		g._roll_stock()
		for s in _packs():
			var lk := String((s.d as Dictionary).get("look", ""))
			if cnt.has(lk):
				cnt[lk] += 1
			else:
				bare += 1
	var tot: int = int(cnt.foil) + int(cnt.env) + int(cnt.tin)
	_ok("① 깔린 팩은 다 겉을 입는다", tot > 60 and bare == 0, "팩 %d · 맨 팩 %d" % [tot, bare])
	var lo: float = minf(float(cnt.foil), minf(float(cnt.env), float(cnt.tin))) / maxf(float(tot), 1.0)
	_ok("① 셋이 다 나오고 한쪽으로 안 쏠린다", lo > 0.22, "포일 %d · 편지봉투 %d · 깡통 %d" % [
			cnt.foil, cnt.env, cnt.tin])

	# ② 판의 뽑기가 그대로
	seed(20261006)
	g.look_rng.seed = 1
	g._roll_stock()
	var a := _ids()
	seed(20261006)
	g.look_rng.seed = 987654321
	g._roll_stock()
	var b := _ids()
	_ok("② 겉의 난수가 매물을 안 바꾼다", a == b, a if a == b else "%s | %s" % [a, b])

	# ③ 표의 줄은 깨끗하다
	var dirty := 0
	for r in GameData.boosters():
		if (r as Dictionary).has("look"):
			dirty += 1
	_ok("③ 표의 줄에 겉이 안 박힌다", dirty == 0, "%d줄" % dirty)

	# ④ 매듭
	var tries := 0
	while _packs().is_empty() and tries < 200:
		g._roll_stock()
		tries += 1
	var before := []
	for s in _packs():
		before.append(String(s.d.look))
	g._knot_shop()
	var st: Array = Save.run_get("stock", [])
	var saved := []
	for e in st:
		if String((e as Dictionary).get("t", "")) == "boost":
			saved.append(String(e.get("look", "")))
	_ok("④ 매듭이 겉을 적는다", not before.is_empty() and saved == before,
			"%s → %s" % [str(before), str(saved)])
	g._stock_restore()
	var after := []
	for s in _packs():
		after.append(String(s.d.get("look", "")))
	_ok("④ 되살린 상점이 같은 겉을 입는다", after == before, "%s → %s" % [str(before), str(after)])
	for e in st:
		(e as Dictionary).erase("look")
	Save.run_set("stock", st)
	g._stock_restore()
	var old_ok := not _packs().is_empty()
	for s in _packs():
		if not g.PACK_LOOKS.has(String(s.d.get("look", ""))):
			old_ok = false
	_ok("④ 옛 매듭(겉 없음)의 팩도 겉을 입는다", old_ok, "")

	# ⑤ 연 팩
	var p0: Dictionary = _packs()[0]
	g._boost_deal(p0.d)
	_ok("⑤ 연 팩이 판 위의 그 겉이다", g._pack_look(g.boost_card) == String(p0.d.look),
			"%s · %s" % [g._pack_look(g.boost_card), String(p0.d.look)])
	for k in 120:
		g._boost_tick(1.0 / 60.0)
		if g.boost_t < 0.0:
			break

	# ⑥ 개발자 「팩 겉」
	var steps: Array = Dev.PACK_LOOK_STEPS
	_ok("⑥ 개발자 줄에 무작위와 겉 셋이 있다", steps.size() == 4 and String(steps[0][1]) == ""
			and Dev._names("packlook").size() == 4, str(Dev._names("packlook")))
	g._roll_stock()
	while _packs().is_empty():
		g._roll_stock()
	Dev.pick["packlook"] = 3
	Dev._run(g, {"t": "list", "k": "packlook", "n": 4})
	var all_tin := true
	for s in _packs():
		if not bool(s.sold) and String(s.d.get("look", "")) != "tin":
			all_tin = false
	_ok("⑥ 「깡통」 — 지금 테이블의 팩이 깡통이다", all_tin and g.pack_look_force == "tin", "")
	var all_tin2 := true
	for r in 30:
		g._roll_stock()
		for s in _packs():
			if String(s.d.get("look", "")) != "tin":
				all_tin2 = false
	_ok("⑥ 「깡통」 — 앞으로 깔릴 팩도 깡통이다", all_tin2, "")
	Dev.pick["packlook"] = 0
	Dev._run(g, {"t": "list", "k": "packlook", "n": 4})
	var seen := {}
	for r in 120:
		g._roll_stock()
		for s in _packs():
			seen[String(s.d.get("look", ""))] = true
	_ok("⑥ 「무작위」 — 다시 셋이 섞인다", g.pack_look_force == "" and seen.size() == 3,
			str(seen.keys()))
