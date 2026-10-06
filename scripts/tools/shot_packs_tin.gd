extends SceneTree
#  팩 깡통 촬영(2026-10-06 「일단 지금 다른 아이템에 비해 팩의 퀄리티가 그대로 잖아?」).
#  shot_packs.gd(옛 봉투의 그 자리)를 그대로 밟고, 깡통이 서는 자리를 다 찍는다.
#  shots/ 에 packs_tin_*.png (1280x720 · 기본 필터):
#    shop     상점 테이블 — 작은 팩 · 큰 팩 · 동전(피자) · 사진
#    shop2    작은 팩 · 큰 팩 · 사탕 · 다트
#    zoom     위 둘의 테이블 띠를 2배로
#    rot      psi 70° · 160° 로 누운 두 팩(사진 곁) — 3배. 두 장을 바꿔 돌린 것까지
#    sheet    그림 표본 ②(개발자 「그림 표본 · 팩」) — 판 위 일곱 각 · 사진 · 여는 넷
#    hold     상인이 든 팩(개발자 「살핌 · 팩」 길) — 작은 팩 · 큰 팩, 게임 배율 2배
#    hold_x4  그 둘의 손끝 · 깡통 4배 — 검지가 뚜껑 위 테에 얹히고 엄지가 벽 밑을 받치는가
#    open     큰 팩을 여는 여덟 박자 — 오기 · 흔들 · 뜸 · 젖힘 · 빛 · 쏟음
#    open_s   작은 팩을 여는 여덟 박자 — 끼우는 뚜껑이 톡 떠서 뒤로 넘어간다
#    smash    리롤 쓸기에 깡통이 턱에 처박혀 깨지는 박자 넷
#    leg      레전더리가 든 팩(개발자 「팩에서 레전더리」) — 여느 팩과 같은 박자 견주기
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_packs_tin.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const Dev = preload("res://scripts/dev.gd")
const DT := 1.0 / 120.0
#  살피는 박자 한가운데 — shot_npc3 의 LOOK_T 와 같은 수(굴림 · 손각 흔들림 0, 들기 최고).
const LOOK_T := 1.06
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_packs_tin_g.cfg"
	Save.path = "user://_shot_packs_tin.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	#  겉 셋 가운데 이것만 찍는다(2026-10-06 — 상점의 팩은 겉을 무작위로 입는다).
	g.pack_look_force = "tin"
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


func _step(sec: float, hold_t := -1.0) -> void:
	for k in int(ceil(sec / DT)):
		g.idle_act = -1
		g.idle_wait = 99.0
		g.mouse_at = Vector2(-50.0, -50.0)
		if hold_t >= 0.0:
			g.give_t = minf(g.give_t, hold_t)
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
		var cost := 4
		match String(k[0]):
			"boost":
				d = _row(GameData.boosters(), String(k[1]))
				cost = int(d.get("cost", 4))
			"item": d = GameData.items()[3]
			"cons": d = GameData.candies()[0]
			"fix":
				d = GameData.fixtures()[0]
				cost = 12
			"dart":
				d = GameData.darts()[1]
				cost = 12
		g.stock[i] = {"type": String(k[0]), "d": d, "sold": false, "cost": cost}
	_step(0.3)


#  논리 좌표(640x360)의 칸을 잘라 k 배로 — 최근접. 보간하면 도트가 흐려져 재는 것이
#  그림이 아니라 필터가 된다(shot_npc3 의 _crop 과 같은 자).
func _crop(im: Image, r: Rect2, k: float) -> Image:
	var s: float = float(im.get_width()) / 640.0
	var part := im.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s),
			int(r.size.x * s), int(r.size.y * s)))
	part.resize(int(r.size.x * k), int(r.size.y * k), Image.INTERPOLATE_NEAREST)
	return part


#  여러 장을 한 줄(또는 cols 칸 격자)로 — 사이 6px 검은 틈.
func _grid(ims: Array, cols: int) -> Image:
	var w: int = (ims[0] as Image).get_width()
	var h: int = (ims[0] as Image).get_height()
	var rows: int = int(ceil(float(ims.size()) / float(cols)))
	var out := Image.create(w * cols + 6 * (cols - 1), h * rows + 6 * (rows - 1), false,
			(ims[0] as Image).get_format())
	out.fill(Color.BLACK)
	for i in ims.size():
		out.blit_rect(ims[i], Rect2i(0, 0, w, h),
				Vector2i((i % cols) * (w + 6), (i / cols) * (h + 6)))
	return out


func _boost_idx() -> Array:
	var out := []
	for i in g.stock.size():
		if String(g.stock[i].type) == "boost":
			out.append(i)
	return out


func _run() -> void:
	await _wait(10)
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

	#  ── 테이블 ──
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	var a: Image = await _shot()
	a.save_png("res://shots/packs_tin_shop.png")
	#  psi 70° · 160° — 두 팩을 돌려 눕힌다(사진은 그대로). 둘을 바꿔 한 번 더.
	var bi := _boost_idx()
	var rots: Array = []
	for pass_i in 2:
		for j in bi.size():
			var deg: float = [70.0, 160.0][(j + pass_i) % 2]
			g.drop[bi[j]].psi = deg_to_rad(deg)
		var im: Image = await _shot()
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for j in bi.size():
			var it: Dictionary = g.drop[bi[j]]
			var cc: Vector2 = g._p2s(float(it.u), float(it.w), float(it.h))
			lo = Vector2(minf(lo.x, cc.x), minf(lo.y, cc.y))
			hi = Vector2(maxf(hi.x, cc.x), maxf(hi.y, cc.y))
		var ctr := (lo + hi) * 0.5
		rots.append(_crop(im, Rect2(ctr.x - 80.0, ctr.y - 42.0, 160.0, 84.0), 3.0))
		print("돌린 팩 — 작은 %.0f° · 큰 %.0f°" % [rad_to_deg(g.drop[bi[0]].psi),
				rad_to_deg(g.drop[bi[1]].psi)])
	_grid(rots, 1).save_png("res://shots/packs_tin_rot.png")

	_put([["boost", "b_small"], ["boost", "b_big"], ["cons", ""], ["dart", ""]])
	var b: Image = await _shot()
	b.save_png("res://shots/packs_tin_shop2.png")
	var za := a.get_region(Rect2i(160, 300, 960, 260))
	var zb := b.get_region(Rect2i(160, 300, 960, 260))
	var z := Image.create(960, 526, false, za.get_format())
	z.blit_rect(za, Rect2i(0, 0, 960, 260), Vector2i(0, 0))
	z.blit_rect(zb, Rect2i(0, 0, 960, 260), Vector2i(0, 266))
	z.resize(1920, 1052, Image.INTERPOLATE_NEAREST)
	z.save_png("res://shots/packs_tin_zoom.png")

	#  ── 그림 표본 ② ──
	Dev.on = false
	g.art_guide = false
	Dev.pick["artsheet"] = 2
	var sh: Image = await _shot()
	sh.save_png("res://shots/packs_tin_sheet.png")
	Dev.pick["artsheet"] = 0
	g.art_guide = true

	#  ── 상인이 든 팩 — 개발자 「살핌 · 팩」(작은 팩이 먼저 잡힌다) · 큰 팩 ──
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	var holds: Array = []
	var close: Array = []
	for pass_i in 2:
		if pass_i == 0:
			Dev._npc_hold_kind(g, ["팩", "boost", ""])
		else:
			g._give_begin(_boost_idx()[1], Vector2(200.0, float(g.TBL.fy)))
		_step(1.0, LOOK_T)
		var hi2: Image = await _shot()
		holds.append(_crop(hi2, Rect2(150.0, 30.0, 340.0, 220.0), 2.0))
		if g.give_i >= 0:
			var hit: Dictionary = g.drop[g.give_i]
			var hc: Vector2 = g._p2s(float(hit.u), float(hit.w), float(hit.h))
			close.append(_crop(hi2, Rect2(hc.x - 60.0, hc.y - 60.0, 120.0, 96.0), 4.0))
		print("살핌 — 든 물건 %d (%s) · give_t %.2f" % [g.give_i,
				String(g.stock[g.give_i].d.get("n", "?")) if g.give_i >= 0 else "-", g.give_t])
		if g._give_live():
			g._give_end()
		_step(1.2)
	_grid(holds, 2).save_png("res://shots/packs_tin_hold.png")
	if close.size() == 2:
		_grid(close, 2).save_png("res://shots/packs_tin_hold_x4.png")

	#  ── 쓸기에 깨지는 깡통 ──
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	_step(0.6)
	g._sweep_begin()
	var sm: Array = []
	var t2 := 0.0
	var at := [0.33, 0.36, 0.39, 0.42, 0.45, 0.48]
	var ai := 0
	while ai < at.size() and t2 < 1.0:
		_step(1.0 / 60.0)
		t2 += 1.0 / 60.0
		if t2 >= float(at[ai]):
			sm.append(_crop(await _shot(), Rect2(10.0, 110.0, 330.0, 170.0), 2.0))
			print("쓸기 %.3f초 — 조각 %d" % [t2, g.shards.size()])
			ai += 1
	_grid(sm, 3).save_png("res://shots/packs_tin_smash.png")
	_step(2.0)
	#  ── 큰 팩 열기 — 여덟 박자 ──
	#  오기(0.04 · 0.20) · 흔들(0.33) · 뜸(0.37) · 젖힘(0.42 · 0.48) · 다 열림(0.58) ·
	#  쏟음(0.64 뒤 0.12초 — 테이블로 떨어지는 중)
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	g._boost_deal(_row(GameData.boosters(), "b_big"))
	var frames: Array = []
	for t in [0.04, 0.20, 0.33, 0.37, 0.42, 0.48, 0.58]:
		g.boost_t = float(t)
		var fi: Image = await _shot()
		frames.append(_crop(fi, Rect2(200.0, 26.0, 240.0, 280.0), 2.0))
	g.boost_t = 0.63
	_step(0.12)
	var fl: Image = await _shot()
	frames.append(_crop(fl, Rect2(200.0, 26.0, 240.0, 280.0), 2.0))
	_grid(frames, 4).save_png("res://shots/packs_tin_open.png")
	_step(1.2)
	var fo: Image = await _shot()
	fo.save_png("res://shots/packs_tin_open_full.png")
	print("열린 뒤 state %d · 몫 %d" % [g.state, g.boost_pick])

	#  ── 작은 팩 열기 — 끼우는 뚜껑이 톡 뜨고 뒤로 넘어간다(같은 박자) ──
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	g._boost_deal(_row(GameData.boosters(), "b_small"))
	var fs: Array = []
	for t in [0.20, 0.33, 0.37, 0.40, 0.44, 0.48, 0.53, 0.60]:
		g.boost_t = float(t)
		fs.append(_crop(await _shot(), Rect2(200.0, 26.0, 240.0, 280.0), 2.0))
	_grid(fs, 4).save_png("res://shots/packs_tin_open_s.png")
	g.boost_t = 0.63
	_step(1.2)

	#  ── 레전더리가 든 팩 — 여느 팩(뜸 한가운데)과 견준다 ──
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	g._boost_deal(_row(GameData.boosters(), "b_big"))
	var legs: Array = []
	g.boost_t = 0.49
	legs.append(_crop(await _shot(), Rect2(200.0, 26.0, 240.0, 280.0), 2.0))
	g.boost_t = -1.0
	g.boost_card = {}
	g.boost_spill.clear()
	Dev._run(g, {"a": "land_pack"})
	for t in [0.40, 0.49, 0.56]:
		g.boost_t = float(t)
		legs.append(_crop(await _shot(), Rect2(200.0, 26.0, 240.0, 280.0), 2.0))
	_grid(legs, 4).save_png("res://shots/packs_tin_leg.png")
	g.boost_t = 0.63
	_step(1.0)

	print("찍었다 — packs_tin_*")
	quit(0)
