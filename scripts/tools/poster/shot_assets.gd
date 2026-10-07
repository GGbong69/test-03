extends SceneTree
#  게임 그림 낱장 — 「게임 내에 상점 주인의 그 달라는 손 동작 이미지랑 동전들 이미지 좀 줘볼래?」
#  (2026-10-07). 게임을 SubViewport 에 달아 인쇄 해상도 · 투명 바탕으로 찍는다.
#    mode=hand  상점에서 물건을 들고 창구에 오면 상인이 그쪽 손바닥을 펴 위로 돌려 내미는
#               「내미는 예고」(game.gd npc_reach — 「여기 놓아라」는 손바닥이 말한다). 양쪽 손 다.
#                 reach_hand_<side>.png   팔 · 손만(투명) — side 0 왼손(화면 왼쪽) · 1 오른손
#                 reach_scene_<side>.png  HUD 없는 상점 한 장(빈 테이블)
#    mode=coin  게임에서 쓰는 동전(GameData.items()) 전부를 동전 슬롯 그림 그대로 칸마다 —
#                 coins_sheet.png + coins.json(칸 자리 · id · 이름 · 등급)
#  필터(브라운관 · VHS · 도트)는 끈다. 게임 파일은 안 고친다(손은 shop_poster_game.gd,
#  동전은 coin_sheet_game.gd 가 그리기만 가른다).
#  창이 있어야 돈다:
#    godot --path . --script scripts/tools/poster/shot_assets.gd -- mode=hand
#    godot --path . --script scripts/tools/poster/shot_assets.gd -- mode=coin
#  결과: outputs/poster/assets/raw/  →  python scripts/tools/poster/cut_assets.py 가 낱장으로 자른다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const SHOP_SUB := "res://scripts/tools/poster/shop_poster_game.gd"
const COIN_SUB := "res://scripts/tools/poster/coin_sheet_game.gd"
const DT := 1.0 / 120.0
const OUT := "res://outputs/poster/assets/raw"
var A := {
	"mode": "coin",
	"k": 16,          # 2D 배율(논리 640x360 → 기기 px)
	"k3": 12,         # 손 3D 화판 배율
	"r": 18.0,        # 동전 반지름(논리 px) — 동전 슬롯 크기 언저리
	"cell": 44.0,     # 동전 한 칸(논리 px)
}
var g = null
var vp: SubViewport = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_poster_assets_g.cfg"
	Save.path = "user://_poster_assets.cfg"
	Save.wipe()
	for s in OS.get_cmdline_user_args():
		var kv := String(s).split("=", false, 1)
		if kv.size() != 2 or not A.has(kv[0]):
			push_warning("모르는 인자 " + String(s))
			continue
		match typeof(A[kv[0]]):
			TYPE_INT:
				A[kv[0]] = int(kv[1])
			TYPE_FLOAT:
				A[kv[0]] = float(kv[1])
			_:
				A[kv[0]] = String(kv[1])
	print("args ", A)
	var K: int = A.k
	vp = SubViewport.new()
	vp.size = Vector2i(640 * K, 360 * K)
	vp.size_2d_override = Vector2i(640, 360)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = true
	root.add_child(vp)
	g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load(SHOP_SUB if String(A.mode) == "hand" else COIN_SUB))
	vp.add_child(g)
	seed(20261007)


func _process(_d: float) -> bool:
	if g != null:
		g.hover_live = false
		g.tip_pin = {}
		g.tip_a = 0.0
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _step(sec: float) -> void:
	for k in int(ceil(sec / DT)):
		g.idle_act = -1
		g.idle_wait = 99.0
		g.mouse_at = Vector2(-50.0, -50.0)
		g._process(DT)


func _grab() -> Image:
	g.queue_redraw()
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _save(img: Image, nm: String) -> void:
	var p := "%s/%s.png" % [OUT, nm]
	img.save_png(p)
	print("saved ", p, " ", img.get_size())


func _filters_off() -> void:
	g.crt = 0.0
	g.warp = 0.0
	g.vhs = 0.0
	g.dot = 0.0
	g._crt_apply()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await _wait(10)
	DisplayServer.window_set_size(Vector2i(640, 360))
	DirAccess.make_dir_recursive_absolute(OUT)
	if String(A.mode) == "hand":
		await _hand()
	else:
		await _coins()
	print("done ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	quit(0)


# ─────────────────────────────────────────────────────────────
#  동전 — 칸마다 하나씩, 한 장에
# ─────────────────────────────────────────────────────────────
func _coins() -> void:
	g.set_process(false)
	_filters_off()
	var items: Array = GameData.items()
	var cell: float = float(A.cell)
	var cols: int = int(floor(640.0 / cell))
	var rows: int = int(ceil(float(items.size()) / float(cols)))
	if float(rows) * cell > 360.0:
		push_error("칸이 모자란다 — cell 을 줄여라")
		return
	var x0: float = (640.0 - float(cols) * cell) * 0.5
	var y0: float = (360.0 - float(rows) * cell) * 0.5
	var sheet := []
	var meta := []
	for i in items.size():
		var it: Dictionary = items[i]
		var c := Vector2(x0 + (float(i % cols) + 0.5) * cell, y0 + (float(i / cols) + 0.5) * cell)
		sheet.append({"c": c, "r": float(A.r), "it": it})
		meta.append({"i": i, "id": String(it.get("id", "")), "name": String(it.get("name", "")),
				"rarity": String(it.get("rarity", "")), "x": c.x, "y": c.y})
	g.sheet = sheet
	await _wait(4)
	var img: Image = await _grab()
	_save(img, "coins_sheet")
	var f := FileAccess.open(OUT + "/coins.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"k": A.k, "cell": cell, "r": A.r, "coins": meta}, "\t"))
	f.close()
	print("coins ", items.size(), " grid ", cols, "x", rows)


# ─────────────────────────────────────────────────────────────
#  손 — 빈 상점에서 「내미는 예고」
# ─────────────────────────────────────────────────────────────
func _grow_vps() -> int:
	var n := 0
	var K3: int = A.k3
	for c in g.get_children():
		if c is SubViewport and not c.has_meta("poster_k3") and c != g.room_vp:
			var sv := c as SubViewport
			sv.set_meta("poster_k3", K3)
			sv.size = sv.size * K3
			if sv.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
				sv.render_target_update_mode = SubViewport.UPDATE_ONCE
			n += 1
	return n


#  내밀기를 세운다 — 게임은 _give_tick 이 매 틀 0 쪽으로 걷으므로 찍기 직전마다 다시 세운다.
func _reach(side: int) -> void:
	g.npc_reach_side = side
	g.npc_reach = 1.0


func _settle(side: int) -> void:
	for k in 5:
		_reach(side)
		g.queue_redraw()
		await _wait(3)
		g._process(0.00001)
	_reach(side)
	g.queue_redraw()
	await _wait(3)


func _hand() -> void:
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	g.set_process(false)
	g._new_run(true)
	g._tutor_close()
	g.tutor_q.clear()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_step(0.5)
	g.total = g.target
	g.darts_left = 0
	g.remaining.clear()
	g._finish_leg()
	for k in 600:
		if g.state == g.S.CLEAR:
			break
		_step(DT)
		g._swap_skip()
	g.clear_t = 99.0
	_step(0.2)
	g._clear_go()
	_step(2.5)
	g._tutor_close()
	g.tutor_q.clear()
	_filters_off()
	#  빈 테이블 — 손만 보이게 물건을 걷는다(stock 과 drop 은 색인을 나눠 쓰므로 같이).
	g.stock.clear()
	g.drop.clear()
	_step(1.0)
	print("shop state ", g.state == g.S.SHOP)
	g.poster_on = true
	g.pp = {"bg": true, "room": true, "body": true, "table": true, "goods": true,
			"shadow": true, "hands": true}
	await _settle(1)
	print("grew ", _grow_vps())
	await _settle(1)
	_grow_vps()
	var all_on := {"bg": true, "room": true, "body": true, "table": true, "goods": true,
			"shadow": true, "hands": true}
	for side in [0, 1]:
		await _settle(side)
		g.pp = {"harm": true}
		_save(await _grab(), "reach_hand_%d" % side)
		g.pp = all_on
		await _settle(side)
		_save(await _grab(), "reach_scene_%d" % side)
