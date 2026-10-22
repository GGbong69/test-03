extends SceneTree
#  UI 시안 C — 펠트 · 에나멜 명판 촬영(2026-10-22). 네 장면을 기본 필터 · 날것(CRT · 굴곡 · VHS · 도트 0)으로
#  두 번씩 찍는다. 도트 화판(boot.tscn)으로 연다 — 실제 게임 그림이다.
#    board    판 — 동전 하나 · 20 트리플 착탄 · 합계 카드
#    shop     상점 — 매물 셋 · 동전 슬롯 첫 동전에 툴팁
#    leg      판 고르기 — 보스 판 툴팁
#    collect  컬렉션 — 동전 열 발견 · 첫 칸 툴팁
#   godot --path . --resolution 1280x720 --script scripts/tools/shot_ui_C_felt_enamel.gd
#   → shots/ui_C_felt_enamel_<장면>[_raw].png
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const FPS := 1.0 / 60.0
const PRE := "ui_C_felt_enamel"
var b = null
var g = null
var busy := false
var tip := {}                      # 박아 둘 툴팁 대상. 비면 툴팁을 끈다
var hov_at := Vector2(-50.0, -50.0)


func _initialize() -> void:
	Save.gpath = "user://_shotui_C_g.cfg"
	Save.path = "user://_shotui_C.cfg"
	Save.prof_fmt = "user://_shotui_C_%d.cfg"
	Save.wipe()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	b = load("res://scenes/boot.tscn").instantiate()
	root.add_child(b)


func _process(_d: float) -> bool:
	if g == null:
		g = b.game
		if g == null:
			return false
		g.set_process(false)
	if busy:
		_pin()
		return false
	busy = true
	_run()
	return false


func _quiet() -> void:
	g.swap_live = false
	g.shake = 0.0
	g.hover_live = false
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_pre = 0.0
	g.tutor_out = 0.0
	g.tutor_t = 0.0
	g.idle_act = -1
	g.idle_wait = 99.0


func _pin() -> void:
	_quiet()
	g.mouse_at = hov_at
	if tip.is_empty():
		g.tip_a = 0.0
		g._tip_clear()
	else:
		g._tip_build(tip)
		g.tip_a = 1.0
	g.queue_redraw()


func _tick(n: int) -> void:
	for i in n:
		g._process(FPS)
		g._tutor_close()
		_quiet()


#  필터 넷 — 기본값 · 전부 0.
func _filter(on: bool) -> void:
	g.crt = g.CRT_DEF if on else 0.0
	g.warp = g.WARP_DEF if on else 0.0
	g.vhs = g.VHS_DEF if on else 0.0
	g.dot = g.DOT_DEF if on else 0.0
	g._crt_apply()


func _snap(nm: String) -> void:
	for i in 4:
		_pin()
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://shots/%s_%s.png" % [PRE, nm]
	root.get_texture().get_image().save_png(path)
	print("저장: %s" % path)


#  한 장면을 기본 필터 · 날것으로.
func _shoot(nm: String) -> void:
	_filter(true)
	await _snap(nm)
	_filter(false)
	await _snap(nm + "_raw")
	_filter(true)


func _idx(rows: Array, id: String) -> int:
	for i in rows.size():
		if String(rows[i].get("id", "")) == id:
			return i
	return 0


#  20 트리플 한 발(deck_shots3 의 _hit20) — 자리는 hit_info 에게 묻는다.
func _hit20() -> void:
	if g.remaining.is_empty():
		g._start_leg()
	g.target = 999999
	g.total = 0
	var it: Dictionary = (GameData.items()[0] as Dictionary).duplicate(true)
	it.gs = 0
	it.bought = 1
	g.owned = [it]
	g._panel_reset()
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = "place"
	g._aim_begin()
	_quiet()
	var p: Vector2 = g.BC
	for r in range(int(g.R * 0.30), int(g.R * 0.95)):
		var q: Vector2 = g.BC + Vector2(0.0, -float(r))
		var info: Dictionary = g.hit_info(q)
		if int(info.get("sector", 0)) == 20 and int(info.get("mult", 0)) == 3:
			p = q
			break
	g.mouse_at = p
	g._click(p)
	var t := 0
	while t < 900:
		g._process(FPS)
		t += 1
		if g.state == g.S.RESOLVE and g.card_mode == 1:
			break
	for i in 45:
		g._process(FPS)
	print("   착탄 · 이 발 %d점 · 카드 %d x %d" % [g.last_gain, g.cur_chip, g.cur_mult])


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	_tick(8)

	# ── 판 ──
	g._new_run()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_tick(8)
	_hit20()
	await _shoot("board")

	# ── 상점 ──
	var its: Array = GameData.items()
	var mds: Array = GameData.mods()
	g.leg_no = 4
	g.gold = 99
	g._open_shop()
	g._swap_skip()
	_tick(20)
	g.owned.clear()
	for k in 3:
		var c: Dictionary = (its[k + 1] as Dictionary).duplicate(true)
		c.gs = 0
		c.bought = 1
		g.owned.append(c)
	g._panel_reset()
	g.stock.clear()
	g.stock.append({"type": "item", "d": its[_idx(its, "l05")], "cost": 20, "sold": false})
	g.stock.append({"type": "item", "d": its[_idx(its, "r05")], "cost": 14, "sold": false})
	g.stock.append({"type": "mod", "d": mds[_idx(mds, "jjak")], "cost": 12, "sold": false})
	g._drop_roll()
	g._drop_settle()
	_tick(90)
	g._drop_settle()
	hov_at = g._slot_rect(0).get_center()
	tip = {"k": "rack", "i": 0}
	await _shoot("shop")
	tip = {}
	hov_at = Vector2(-50.0, -50.0)

	# ── 판 고르기 ──
	g.legb_force = true
	g._new_run(true)
	_tick(90)
	var bn: int = g._round_boss()
	g.boss_mods[bn] = PackedStringArray(["dead"])
	g._swap_skip()
	g.leg_skipped = {}
	g.leg_no = 1
	g.state = g.S.LEG
	g._open_leg()
	g._turn_skip()
	_tick(80)
	hov_at = g._row_rect(GameData.leg_idx(bn), GameData.legs_per_round()).get_center()
	tip = {"k": "legboss", "i": bn}
	await _shoot("leg")
	tip = {}
	hov_at = Vector2(-50.0, -50.0)

	# ── 컬렉션 ──
	g.found_all = false
	for k in 10:
		Save.discover("item:" + String(its[k].get("id", "")))
	g.state = g.S.COLLECT
	g.collect_tab = 0
	g.collect_page = 0
	_tick(4)
	hov_at = g._col_cell(0).get_center()
	tip = {"k": "citem", "i": 0}
	await _shoot("collect")
	tip = {}
	print("  찍음")
	quit(0)
