extends SceneTree
# 16:9 가 아닌 화면(2026-10-08 · game.gd _ui_pad · _ui_top · _bar_y · _room3d_rect) — 못 박는 것:
#   ① 16:9(여백 0)에서는 HUD 가 한 픽셀도 안 움직인다 — 옛 표(LAY)의 자리 그대로다.
#   ② 21:9 에서 왼쪽 무리(자금판 · 사탕·사진 칸)는 왼끝, 오른쪽 무리(정보 · 일시정지)는 오른끝을
#      따라간다 — 화면 끝에서 떨어진 거리가 16:9 와 같다. 동전 슬롯은 가운데다.
#   ③ 리롤 · 다음 판(= 던진다)은 양끝으로 가고, 건너뛴다는 던진다의 거울 자리 그대로다.
#   ④ 32:9 처럼 아주 넓은 화면은 UIW 에서 멈춘다(24:9 자리).
#   ⑤ 4:3 은 다트판 화면에서 첫 줄 · 상단 띠가 위끝에 붙고, 상인이 서는 화면(상점 · 판 고르기)은
#      첫 줄이 제자리(상인 머리를 가린다) · 상단 띠만 위끝이다.
#   ⑥ 툴팁은 화면 전체(여백까지) 안에 선다 — 끝에 붙은 단추의 툴팁이 640 안으로 밀려 떨어지지 않는다.
#   ⑦ 상점 테이블 화판은 화면 끝 · 밑까지 덮는다.
#   ⑧ HUD 사각들이 서로 안 겹치고 화면 안이다(모든 비율).
#   godot --headless --path . --script scripts/tools/qa_aspect.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_aspect_g.cfg"
	Save.path = "user://_qa_aspect.cfg"
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
	print("  %s %-48s %s" % ["통과" if cond else "실패", nm, note])


func _pad(p: Vector2) -> void:
	#  헤드리스는 여백을 안 따라가는 것이 규약이다(_fill_pad) — 이 검사만 켠다.
	g.ui_pad_force = true
	g.view_pad = p


func _hud() -> Dictionary:
	return {"bank": g._bank_rect(), "cons0": g._cons_rect(0), "cons1": g._cons_rect(1),
			"panel": g._panel_rect(), "info": g._hud_btn_rect(0), "pause": g._hud_btn_rect(1)}


func _inside(r: Rect2) -> bool:
	return (g._full() as Rect2).grow(0.5).encloses(r)


func _no_overlap(d: Dictionary) -> String:
	var ks := d.keys()
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			var a: Rect2 = d[ks[i]]
			var b: Rect2 = d[ks[j]]
			if a.size.x > 0.0 and b.size.x > 0.0 and a.intersects(b):
				return "%s · %s" % [ks[i], ks[j]]
	return ""


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g._open_leg()
	g._begin_leg()
	g.state = g.S.PICK
	var LAY: Dictionary = g.LAY
	var VIEW: Vector2 = g.VIEW

	# ① 16:9
	_pad(Vector2.ZERO)
	var h0 := _hud()
	_ok("① 16:9 — 자금판이 표 자리 그대로", (h0.bank as Rect2).position == (LAY.bank as Rect2).position,
			str(h0.bank))
	_ok("① 16:9 — 정보 단추가 표 자리 그대로", (h0.info as Rect2).position == (LAY.menu as Rect2).position,
			str(h0.info))
	_ok("① 16:9 — 리롤 · 다음 판 그대로", g._reroll_rect().position == Vector2(32.0, 288.0)
			and g._next_rect().position == Vector2(432.0, 288.0))
	_ok("① 16:9 — 상단 띠 · 첫 줄이 안 오른다", g._bar_y() == 0.0 and g._hud_dy() == 0.0)
	_ok("① 16:9 — 테이블 화판이 640 폭", g._room3d_rect().size.x == VIEW.x
			and g._room3d_rect().position.x == 0.0)

	# ② 21:9 (1720x720 → 860x360)
	_pad(Vector2(110.0, 0.0))
	var h1 := _hud()
	var f: Rect2 = g._full()
	_ok("② 21:9 — 자금판이 왼끝에서 4", absf((h1.bank as Rect2).position.x - (f.position.x + 4.0)) < 0.01,
			"x %.1f · 화면 왼끝 %.1f" % [(h1.bank as Rect2).position.x, f.position.x])
	_ok("② 21:9 — 사탕·사진 칸이 자금판을 따라간다",
			(h1.cons0 as Rect2).position.x - (h1.bank as Rect2).position.x
			== (h0.cons0 as Rect2).position.x - (h0.bank as Rect2).position.x)
	_ok("② 21:9 — 일시정지가 오른끝에서 4", absf(f.end.x - (h1.pause as Rect2).end.x - 4.0) < 0.01,
			"끝 %.1f · 화면 오른끝 %.1f" % [(h1.pause as Rect2).end.x, f.end.x])
	_ok("② 21:9 — 동전 슬롯은 가운데", (h1.panel as Rect2) == (h0.panel as Rect2))
	_ok("② 21:9 — 상단 띠 제약 칸이 오른끝을 따라간다",
			g._bar_mod_rect().position.x == float(LAY.bar_mod) - 4.0 + 110.0)
	var hh := ""
	var nov := _no_overlap(h1)
	for k in h1:
		if not _inside(h1[k]):
			hh = k
	_ok("⑧ 21:9 — HUD 가 화면 안 · 안 겹친다", hh == "" and nov == "", "%s %s" % [hh, nov])

	# ③ 단추
	_ok("③ 21:9 — 리롤이 왼끝 · 다음 판이 오른끝을 따라간다",
			g._reroll_rect().position.x == 32.0 - 110.0 and g._next_rect().position.x == 432.0 + 110.0)
	var go: Rect2 = g._leg_go()
	var sk: Rect2 = g._leg_skip()
	_ok("③ 건너뛴다는 던진다의 거울 자리", absf((sk.position.x - f.position.x) - (f.end.x - go.end.x)) < 0.01
			and _inside(sk) and _inside(go), "%s · %s" % [sk, go])

	# ⑦ 테이블 화판
	var rr: Rect2 = g._room3d_rect()
	_ok("⑦ 21:9 — 테이블 화판이 화면 양끝까지", absf(rr.position.x - f.position.x) < 0.01
			and absf(rr.end.x - f.end.x) < 0.01, str(rr))

	# ⑥ 툴팁
	g.tip_slot = -1
	g.tip_spot = -1
	g.tip_mark = h1.pause
	var tp: Vector2 = g._tip_pos(Vector2(160.0, 60.0))
	_ok("⑥ 오른끝 단추의 툴팁이 단추 곁에 선다(640 안으로 안 밀린다)",
			tp.x + 160.0 <= f.end.x - 4.0 + 0.01 and tp.x + 160.0 > VIEW.x,
			"툴팁 x %.1f ~ %.1f" % [tp.x, tp.x + 160.0])
	g.tip_mark = Rect2()

	# ④ 32:9 (2560x720 → 1280x360) — UIW 에서 멈춘다
	_pad(Vector2(320.0, 0.0))
	var cap: float = float(g.UIW.x)
	_ok("④ 32:9 — 자금판이 UIW 에서 멈춘다", (g._bank_rect() as Rect2).position.x == 4.0 - cap,
			"x %.1f" % (g._bank_rect() as Rect2).position.x)
	_ok("④ 32:9 — 일시정지도 UIW 에서 멈춘다", (g._hud_btn_rect(1) as Rect2).position.x
			== (LAY.menu as Rect2).position.x + cap)
	var h2 := _hud()
	hh = ""
	for k in h2:
		if not _inside(h2[k]):
			hh = k
	_ok("⑧ 32:9 — HUD 가 화면 안 · 안 겹친다", hh == "" and _no_overlap(h2) == "", hh)

	# ⑤ 4:3 (960x720 → 640x480)
	_pad(Vector2(0.0, 60.0))
	g.state = g.S.PICK
	_ok("⑤ 4:3 다트판 — 상단 띠가 위끝", g._bar_y() == -60.0, "%.1f" % g._bar_y())
	_ok("⑤ 4:3 다트판 — 첫 줄이 위끝을 따라간다", (g._bank_rect() as Rect2).position.y
			== (LAY.bank as Rect2).position.y - 60.0)
	var h3 := _hud()
	hh = ""
	for k in h3:
		if not _inside(h3[k]):
			hh = k
	_ok("⑧ 4:3 다트판 — HUD 가 화면 안 · 안 겹친다", hh == "" and _no_overlap(h3) == "", hh)
	g.state = g.S.SHOP
	_ok("⑤ 4:3 상점 — 첫 줄은 제자리(상인 머리를 가린다)", (g._panel_rect() as Rect2).position.y
			== float(g.PANEL.y) + float(g.HUD_UP), "%.1f" % (g._panel_rect() as Rect2).position.y)
	g.state = g.S.LEG
	_ok("⑤ 4:3 판 고르기 — 첫 줄 제자리 · 상단 띠만 위끝", g._hud_dy() == 0.0 and g._bar_y() == -60.0)
	var r43: Rect2 = g._room3d_rect()
	_ok("⑦ 4:3 — 테이블 화판이 화면 밑까지", absf(r43.end.y - (g._full() as Rect2).end.y) < 0.01, str(r43))
	_pad(Vector2.ZERO)
	g.state = g.S.PICK
