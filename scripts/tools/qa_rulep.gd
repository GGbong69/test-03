extends SceneTree
# 판 규칙 명판(2026-10-08 · game.gd RULEP) — 못 박는 것:
#   ① 걸린 것이 없으면 명판도 없다. 보스 제약은 한 장마다 이름 · 효과가 modifiers.csv 그대로다.
#   ② 명판은 오른쪽 벽 — 판(x441) 오른쪽 · HUD 밑 · 오른쪽 점수 카드(bot) 위 · 화면 안 · 서로 안
#      겹치고 폭이 같다. 표의 제약 열 종이 다 두 줄 안에 든다.
#   ③ 새 명판은 차례로 들고(뒤엣것이 stagger 만큼 늦다) 드는 동안은 안 잡힌다.
#   ④ 칠판 주문 — 걸린 동안 「조건 보상」 한 줄 · 남은 발이 눈금. 받으면(또는 X) 빠지고 다 빠지면 지운다.
#   ⑤ 단골 — 자루가 꽂힌 뒤에만(나는 동안은 아니다) · 막은 칸 이름과 값 · 남은 발.
#   ⑥ 불씨 — 핀 동안만 · 맞힐 때 골드.
#   ⑦ 툴팁 — 이름 · 효과 줄 · 태그([제약] · [사건] · [남은 n발]). 칠판에 올려도 주문 툴팁이다.
#   ⑧ 넷이 다 안 들어가면 효과 줄을 접는다 — 그래도 bot 위다.
#   ⑨ 판이 안 서 있으면(판 갈이 · 상점) 비운다 · 움직임 끄기면 빠지는 명판이 곧장 지워진다.
#   ⑩ events.csv 의 사건 세 갈래에 desc 가 있다.
#   godot --headless --path . --script scripts/tools/qa_rulep.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_rulep_g.cfg"
	Save.path = "user://_qa_rulep.cfg"
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
	print("  %s %-50s %s" % ["통과" if cond else "실패", nm, note])


func _tick(sec: float) -> void:
	var n := int(ceil(sec / (1.0 / 60.0)))
	for i in n:
		g._rulep_tick(1.0 / 60.0)


func _row(key: String) -> Dictionary:
	for rw in g._rulep_rows():
		if String(rw.key) == key:
			return rw
	return {}


func _clear() -> void:
	g._ev_clear()
	g.active_mods = []
	g.rulep.clear()


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g._open_leg()
	g._begin_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g.motion_off = false
	var RP: Dictionary = g.RULEP
	var mf: Array = GameData.modifiers()
	_ok("판이 서 있다(판 갈이 끝)", g._rulep_on(), "swap_live=%s" % g.swap_live)

	# ①
	_clear()
	_tick(0.5)
	_ok("① 걸린 것이 없으면 줄도 명판도 없다", g._rulep_rows().is_empty() and g.rulep.is_empty())
	g.active_mods = [mf[0], mf[3]]
	var rows: Array = g._rulep_rows()
	_ok("① 보스 제약 둘이면 줄 둘", rows.size() == 2)
	_ok("① 이름 · 효과가 표 그대로", rows.size() == 2
			and String(rows[0].n) == String(mf[0].n) and String(rows[0].d[0]) == String(mf[0].d)
			and String(rows[1].n) == String(mf[3].n) and String(rows[1].d[0]) == String(mf[3].d),
			"%s / %s" % [rows[0].d, rows[1].d] if rows.size() == 2 else "")
	_ok("① 제약에는 남은 발 눈금이 없다", rows.size() == 2 and int(rows[0].left) < 0 and int(rows[0].max) == 0)

	# ③
	g._rulep_tick(1.0 / 60.0)
	var t0: float = float(g.rulep["m:" + String(mf[0].id)].t)
	var t1: float = float(g.rulep["m:" + String(mf[3].id)].t)
	_ok("③ 둘째 명판은 stagger 만큼 늦게 든다",
			absf((t0 - t1) - float(RP.stagger)) < 0.001, "%.3f %.3f" % [t0, t1])
	var lay0: Array = g._rulep_layout()
	var c0: Vector2 = g._rulep_at(lay0[0]).get_center()
	_ok("③ 드는 동안은 안 잡힌다", g._rulep_hit(c0).is_empty())
	_tick(1.0)

	# ②
	var lay: Array = g._rulep_layout()
	var inside := true
	var nolap := true
	var samew := true
	var top: float = float(RP.y) + g._hud_dy()
	var bot: float = float(RP.bot) + g._hud_dy()
	var scr_r: float = g.VIEW.x + g._ui_pad().x
	for j in lay.size():
		var r: Rect2 = g._rulep_at(lay[j])
		if r.position.x < 448.0 or r.end.x > scr_r or r.position.y < top - 0.5 or r.end.y > bot + 0.5:
			inside = false
		if absf(r.size.x - (g._rulep_at(lay[0]) as Rect2).size.x) > 0.5:
			samew = false
		for k in j:
			if r.intersects(g._rulep_at(lay[k])):
				nolap = false
	_ok("② 오른쪽 벽 안(판 밖 · HUD 밑 · 점수 카드 위 · 화면 안)", inside,
			str(lay.map(func(it): return g._rulep_at(it))))
	_ok("② 서로 안 겹친다", nolap)
	_ok("② 폭이 다 같다", samew)
	var hit: Dictionary = g._tip_hit(g._rulep_at(lay[1]).get_center())
	_ok("② 둘째 명판에 올리면 rulep · 둘째 줄", String(hit.get("k", "")) == "rulep" and int(hit.get("i", -1)) == 1,
			str(hit))
	var fit := true
	var worst := ""
	for mo in mf:
		g.active_mods = [mo]
		g.rulep.clear()
		_tick(0.1)
		var l1: Array = g._rulep_layout()
		if l1.size() != 1 or (l1[0].lines as Array).size() > 2 or (l1[0].lines as Array).is_empty():
			fit = false
			worst = String(mo.id)
	_ok("② 표의 제약이 다 효과 두 줄 안에 든다", fit, worst)

	# ⑦ 제약 툴팁
	g.active_mods = [mf[0], mf[3]]
	g.rulep.clear()
	_tick(1.0)
	g._tip_build({"k": "rulep", "i": 1, "src": ""})
	var tags: Array = g.tip_tags.map(func(t): return String(t.t))
	_ok("⑦ 제약 툴팁 — 이름 · 효과 · [제약]", g.tip_title == String(mf[3].n)
			and g.tip_lines.size() == 1 and String(g.tip_lines[0].s) == String(mf[3].d)
			and tags.has("제약"), "%s %s" % [g.tip_title, tags])
	_ok("⑦ 툴팁 자리는 그 명판", g.tip_mark == g._rulep_rect("m:" + String(mf[3].id)))

	# ⑧
	g.active_mods = [mf[0], mf[1], mf[5], mf[9]]
	g.rulep.clear()
	_tick(1.0)
	var l4: Array = g._rulep_layout()
	var folded := l4.size() == 4
	for it in l4:
		if not (it.lines as Array).is_empty():
			folded = false
	_ok("⑧ 넷이면 효과 줄을 접는다", folded)
	_ok("⑧ 접어도 bot 위", l4.size() == 4 and (g._rulep_at(l4[3]) as Rect2).end.y <= bot + 0.5,
			str((g._rulep_at(l4[3]) as Rect2)) if l4.size() == 4 else "")

	# ④ 칠판 주문
	_clear()
	var tg_gold := {}
	for t in GameData.tags():
		if String(t.get("id", "")) == "t_gold":
			tg_gold = t
	g._order_open("triple", 3, tg_gold, 777)
	var orw := _row("ev:order")
	var want: String = GameData.cond_text("triple") + " " + g._tag_text(tg_gold)
	_ok("④ 주문 줄 — 조건 · 보상 한 줄", not orw.is_empty() and orw.d.size() == 1
			and String(orw.d[0]) == want, "%s / %s" % [orw.get("d", []), want])
	_ok("④ 이름은 표(events.csv)의 것", String(orw.get("n", "")) == String(GameData.event_of("order").name))
	_ok("④ 남은 발 3 · 눈금 3", int(orw.get("left", -1)) == 3 and int(orw.get("max", 0)) == 3)
	_tick(1.0)
	g.order_left = 2
	_ok("④ 발을 쓰면 남은 발이 준다", int(_row("ev:order").get("left", -1)) == 2)
	var bc: Vector2 = (g.ORDER.box as Rect2).get_center()
	var bh: Dictionary = g._tip_hit(bc)
	_ok("⑦ 칠판에 올리면 주문 툴팁(src board)", String(bh.get("k", "")) == "rulep"
			and String(bh.get("src", "")) == "board", str(bh))
	g._tip_build(bh)
	tags = g.tip_tags.map(func(t): return String(t.t))
	_ok("⑦ 주문 툴팁 — [사건] · [남은 2발] · 칠판 자리", tags.has("사건") and tags.has("남은 2발")
			and g.tip_mark == g._order_foot(), str(tags))
	g.order_st = "done"
	_ok("④ 받으면 줄이 없다", _row("ev:order").is_empty())
	g._rulep_tick(1.0 / 60.0)
	_ok("④ 명판은 빠지는 중", g.rulep.has("ev:order") and float(g.rulep["ev:order"].o) >= 0.0)
	_tick(float(RP.out_t) + 0.05)
	_ok("④ 다 빠지면 지운다", not g.rulep.has("ev:order"))
	g.order_st = "open"
	g.order_left = 3
	g._rulep_tick(1.0 / 60.0)
	g.order_st = "miss"
	_tick(1.0)
	_ok("④ X(못 채움)에도 빠진다", not g.rulep.has("ev:order"))

	# ⑤ 단골
	_clear()
	var tg: Dictionary = g._rgl_at(g._ember_at(3, "t"))
	g._rgl_open(tg, 4242)
	_ok("⑤ 들어오기 전(in)에는 줄이 없다", _row("ev:regular").is_empty())
	g._rgl_in(0.5)
	var flying: bool = String(g.rgl_ph) == "in"
	_ok("⑤ 나는 동안은 줄이 없다", not flying or _row("ev:regular").is_empty())
	g._rgl_stick()
	var rr := _row("ev:regular")
	_ok("⑤ 꽂히면 줄이 선다", not rr.is_empty())
	var cell: String = g._rgl_cell()
	_ok("⑤ 막은 칸 이름 「4 트리플」", cell == "%d 트리플" % int(g.sectors[3]), cell)
	_ok("⑤ 효과 두 줄 — 막은 칸 0점 · 맞히면 그 값", rr.get("d", []).size() == 2
			and String(rr.d[0]).begins_with(cell) and String(rr.d[1]).ends_with("+%d" % g.rgl_val),
			str(rr.get("d", [])))
	_ok("⑤ 남은 발 = 뽑아 가기까지", int(rr.get("left", -1)) == g.rgl_left
			and int(rr.get("max", 0)) == int(GameData.event_v(g.leg_ev_row, "v2", 2.0)))
	g.rgl_r = Vector2(0.0, g.R * g.rt_bull_i)
	g.rgl_idx = -1
	_ok("⑤ 불이면 「이너 불」", g._rgl_cell() == "이너 불", g._rgl_cell())
	g.rgl_r = Vector2(g.R * g.rt_bull_i, g.R * g.rt_bull_o)
	_ok("⑤ 바깥 불이면 「아우터 불」", g._rgl_cell() == "아우터 불", g._rgl_cell())
	g.rgl_st = "done"
	_ok("⑤ 뽑아 가면 줄이 없다", _row("ev:regular").is_empty())

	# ⑥ 불씨
	_clear()
	_ok("⑥ 피기 전에는 줄이 없다", _row("ev:ember").is_empty())
	g._ember_light(5, "d")
	var er := _row("ev:ember")
	_ok("⑥ 피면 줄 — 맞힐 때 골드", not er.is_empty() and String(er.d[0]).ends_with("+%d" % g._ember_gold()),
			str(er.get("d", [])))
	g._ember_douse()
	_ok("⑥ 꺼지면 줄이 없다", _row("ev:ember").is_empty())

	# ⑨
	_clear()
	g.active_mods = [mf[2]]
	_tick(1.0)
	_ok("⑨ 서 있다", g.rulep.size() == 1)
	g.swap_live = true
	g._rulep_tick(1.0 / 60.0)
	_ok("⑨ 판 갈이 동안은 비운다", g.rulep.is_empty())
	g.swap_live = false
	_tick(1.0)
	g.state = g.S.SHOP
	g._rulep_tick(1.0 / 60.0)
	_ok("⑨ 상점에서는 비운다", g.rulep.is_empty())
	g.state = g.S.PICK
	_tick(1.0)
	g.motion_off = true
	g.active_mods = []
	g._rulep_tick(1.0 / 60.0)
	_ok("⑨ 움직임 끄기면 빠지는 명판이 곧장 지워진다", g.rulep.is_empty())
	g.motion_off = false

	# ⑩
	var desc_ok := true
	for k in ["ember", "order", "regular"]:
		if String(GameData.event_of(k).get("desc", "")).strip_edges() == "":
			desc_ok = false
	_ok("⑩ 사건 세 갈래에 desc", desc_ok)
	var errs := []
	for e in GameData.errors():
		if String(e).begins_with("events"):
			errs.append(e)
	_ok("⑩ events 표 오류 없음", errs.is_empty(), str(errs))
