extends SceneTree
#  봉인 편지봉투 촬영(2026-10-06 「일단 지금 다른 아이템에 비해 팩의 퀄리티가 그대로 잖아?」).
#  shot_packs.gd 의 판을 그대로 깔고 봉투가 서는 자리를 전부 찍는다. shots/ 에:
#    packs_envelope_shop.png     작은 팩 · 큰 팩 · 동전 · 사진(1280x720 · 기본 필터)
#    packs_envelope_shop2.png    작은 팩 · 사탕 · 큰 팩 · 다트
#    packs_envelope_zoom.png     위 둘의 테이블 띠를 2배로
#    packs_envelope_rot.png      psi 70° · 160° 로 돈 두 봉투와 사진(테이블 띠 2배)
#    packs_envelope_hold.png     상인이 든 작은 팩(개발자 모드 「살핌 · 팩」 길)
#    packs_envelope_hold_strip.png  받기 · 들기 · 살피기 세 박자
#    packs_envelope_hold_big.png 상인이 든 큰 팩
#    packs_envelope_open.png     큰 팩 여는 여덟 박자(다가옴 · 찢김 · 쏟음)
#    packs_envelope_smash.png    리롤에 턱으로 쓸려 깨지는 봉투 세 박자
#    packs_envelope_legend.png   레전더리가 든 큰 팩이 찢기는 순간(등급색 원)
#    packs_envelope_legend_zoom.png  그 가운데 2배
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_packs_envelope.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const Dev = preload("res://scripts/dev.gd")
const DT := 1.0 / 120.0
const BAND := Rect2i(160, 300, 960, 260)
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_packs_env_g.cfg"
	Save.path = "user://_shot_packs_env.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	#  겉 셋 가운데 이것만 찍는다(2026-10-06 — 상점의 팩은 겉을 무작위로 입는다).
	g.pack_look_force = "env"
	seed(20261006)


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


func _shot() -> Image:
	g.queue_redraw()
	for k in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if String(r.id) == id:
			return r
	return rows[0]


func _put(kinds: Array) -> void:
	for i in mini(kinds.size(), g.stock.size()):
		var k: Array = kinds[i]
		var d: Dictionary = {}
		match String(k[0]):
			"boost": d = _row(GameData.boosters(), String(k[1]))
			"item": d = GameData.items()[3]
			"cons": d = GameData.candies()[0]
			"fix": d = GameData.fixtures()[0]
			"dart": d = GameData.darts()[1]
		#  팩 값은 표(boosters.csv)의 것 — 작은 팩 4 · 큰 팩 7. 나머지는 자리 값 그대로.
		var cost: int = int((g.stock[i] as Dictionary).get("cost", 4))
		if String(k[0]) == "boost":
			cost = int(d.get("cost", cost))
		g.stock[i] = {"type": String(k[0]), "d": d, "sold": false, "cost": cost}
	_step(0.3)


#  여러 장을 한 판에. 칸마다 같은 크기여야 한다.
func _grid(ims: Array, cols: int) -> Image:
	var w: int = (ims[0] as Image).get_width()
	var h: int = (ims[0] as Image).get_height()
	var rows: int = (ims.size() + cols - 1) / cols
	var out := Image.create(w * cols + 6 * (cols - 1), h * rows + 6 * (rows - 1), false,
			(ims[0] as Image).get_format())
	out.fill(Color(0.08, 0.07, 0.12))
	for i in ims.size():
		var im: Image = ims[i]
		out.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * (w + 6), (i / cols) * (h + 6)))
	return out


func _band2(a: Image) -> Image:
	var z := a.get_region(BAND)
	z.resize(BAND.size.x * 2, BAND.size.y * 2, Image.INTERPOLATE_NEAREST)
	return z


func _save(im: Image, nm: String) -> void:
	im.save_png("res://shots/packs_envelope_%s.png" % nm)
	print("  shots/packs_envelope_%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창을 달고 돌려라")
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
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
	g.gold = 99
	g.crt = g.CRT_DEF
	g.warp = g.WARP_DEF
	g.vhs = g.VHS_DEF
	g.dot = g.DOT_DEF
	g._crt_apply()

	#  ① 테이블 — 동전 · 사진 곁
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	var a: Image = await _shot()
	_save(a, "shop")
	#  ② 사탕 · 다트 곁
	_put([["boost", "b_small"], ["cons", ""], ["boost", "b_big"], ["dart", ""]])
	var b: Image = await _shot()
	_save(b, "shop2")
	_save(_grid([_band2(a), _band2(b)], 1), "zoom")

	#  ③ 돌린 봉투 — 70° · 160°. 사진과 어느 각에서도 갈리는가.
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	g.drop[0].psi = deg_to_rad(70.0)
	g.drop[1].psi = deg_to_rad(160.0)
	g.drop[3].psi = deg_to_rad(70.0)
	var r1: Image = await _shot()
	g.drop[0].psi = deg_to_rad(160.0)
	g.drop[1].psi = deg_to_rad(70.0)
	g.drop[3].psi = deg_to_rad(160.0)
	var r2: Image = await _shot()
	_save(_grid([_band2(r1), _band2(r2)], 1), "rot")

	#  ④ 상인이 든 팩 — 개발자 모드 「상인 몸짓 · 살핌 · 팩」과 같은 길
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	Dev._npc_hold_kind(g, ["팩", "boost", ""])
	var hs: Array = []
	var prev := 0.0
	for t in [0.30, 0.55, 0.95]:
		_step(float(t) - prev)
		prev = float(t)
		hs.append(await _shot())
	_save(hs[2], "hold")
	_save(_grid([(hs[0] as Image).get_region(Rect2i(160, 60, 960, 500)),
			(hs[1] as Image).get_region(Rect2i(160, 60, 960, 500)),
			(hs[2] as Image).get_region(Rect2i(160, 60, 960, 500))], 3), "hold_strip")
	_step(2.5)
	#  큰 팩 — 판 위 첫 팩을 쥐므로 큰 팩을 앞에 둔다
	_put([["boost", "b_big"], ["item", ""], ["fix", ""], ["cons", ""]])
	Dev._npc_hold_kind(g, ["팩", "boost", ""])
	_step(0.95)
	_save(await _shot(), "hold_big")
	_step(2.5)

	#  ⑤ 큰 팩 열기 — 다가옴 셋 · 찢김 넷 · 쏟음 하나
	_put([["item", ""], ["fix", ""], ["cons", ""], ["dart", ""]])
	g._boost_deal(_row(GameData.boosters(), "b_big"))
	var marks := [0.0, 0.17, 0.33, 0.40, 0.46, 0.52, 0.60, 1.20]
	var fr: Array = []
	var at := 0.0
	for m in marks:
		_step(float(m) - at)
		at = float(m)
		var im: Image = await _shot()
		fr.append(im.get_region(Rect2i(320, 60, 640, 520)))
		print("  열기 t %.2f  boost_t %.3f" % [at, float(g.boost_t)])
	_save(_grid(fr, 4), "open")
	_step(1.0)
	#  쏟은 것을 걷는다 — 다음 판(레전더리)이 깨끗한 테이블에서 열리게.
	g.stock.resize(4)
	g.drop.resize(4)
	g.boost_pick = 0
	_put([["item", ""], ["fix", ""], ["cons", ""], ["dart", ""]])

	#  ⑥ 레전더리가 든 큰 팩 — 찢기는 원이 등급색으로 터진다
	var leg := {}
	for it in GameData.items():
		if String(it.get("rarity", "")) == "legendary":
			leg = it
			break
	g._boost_deal(_row(GameData.boosters(), "b_big"))
	if not leg.is_empty() and not g.boost_spill.is_empty():
		g.boost_spill[0] = {"type": "item", "d": leg}
	_step(float(g.BOOST.rise) + float(g.BOOST.tear) * 0.45)
	var lg: Image = await _shot()
	_save(lg, "legend")
	var lz := lg.get_region(Rect2i(400, 120, 480, 400))
	lz.resize(960, 800, Image.INTERPOLATE_NEAREST)
	_save(lz, "legend_zoom")
	_step(1.5)

	#  ⑦ 리롤 — 쓸려 턱에 처박혀 깨지는 봉투
	g.stock.resize(4)
	g.drop.resize(4)
	g.boost_pick = 0
	_put([["boost", "b_small"], ["boost", "b_big"], ["boost", "b_small"], ["boost", "b_big"]])
	g._sweep_begin()
	var sm: Array = []
	var guard := 0
	while sm.size() < 3 and guard < 400:
		guard += 1
		_step(1.0 / 60.0)
		if g.shards.size() > 0 and (sm.is_empty() or guard % 4 == 0):
			sm.append((await _shot()).get_region(Rect2i(0, 200, 760, 400)))
	if not sm.is_empty():
		_save(_grid(sm, 3), "smash")
	print("  조각 %d" % g.shards.size())
	print("state ", g.state)
	quit(0)
