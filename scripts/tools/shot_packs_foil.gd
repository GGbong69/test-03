extends SceneTree
#  포일 봉투 팩 촬영(2026-10-06 「일단 지금 다른 아이템에 비해 팩의 퀄리티가 그대로 잖아?」).
#  shot_packs 의 판을 그대로 깔고 겉이 바뀐 팩을 모든 자리에서 찍는다. shots/ 에:
#    packs_foil_shop.png     상점 테이블 — 작은 팩 · 큰 팩 · 동전 · 사진(1280x720 · 기본 필터)
#    packs_foil_shop2.png    작은 팩 · 사탕 · 큰 팩 · 다트
#    packs_foil_zoom.png     위 둘의 테이블 띠를 2배로
#    packs_foil_rot.png      돌린 팩(psi 70° · 160°) — 사진과 실루엣이 어느 각에서도 갈리는가
#    packs_foil_sheen.png    얹었을 때 박 위로 미끄러지는 빛 — 네 박자
#    packs_foil_hold.png     상인이 든 팩(개발자 「살핌 · 팩」 · 「살핌 · 큰 팩」 길) — 확대
#    packs_foil_hold_full.png  큰 팩을 든 상점 한 장(1280x720)
#    packs_foil_open.png     큰 팩 열기 여덟 장(다가옴 · 빛 · 찢김 · 쏟음)
#    packs_foil_smash.png    쓸기에 처박혀 깨지는 팩 — 조각이 겉 그림째
#    packs_foil_legend.png   레전더리가 든 팩 — 봉투가 뜯기는 원이 등급색으로
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_packs_foil.gd
#  히트가 새 실루엣을 덮는지도 같이 잰다(「히트 ·」 줄) — 큰 팩이 커졌으므로.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const Dev = preload("res://scripts/dev.gd")
const DT := 1.0 / 120.0
const BAND := Rect2i(160, 300, 960, 260)
var g = null
var busy := false
var fails := 0


func _initialize() -> void:
	Save.gpath = "user://_shot_packs_foil_g.cfg"
	Save.path = "user://_shot_packs_foil.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	#  겉 셋 가운데 이것만 찍는다(2026-10-06 — 상점의 팩은 겉을 무작위로 입는다).
	g.pack_look_force = "foil"
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
		var cost: int = int((g.stock[i] as Dictionary).get("cost", 4))
		cost = int(d.get("cost", cost))
		g.stock[i] = {"type": String(k[0]), "d": d, "sold": false, "cost": cost}
	_step(0.3)


#  지난 칸이 쏟은 것(팩에서 나온 고르기 매물)을 걷어 판을 넷으로 되돌린다 — 안 걷으면
#  다음 칸의 판이 쏟은 것으로 어수선해 팩이 묻힌다.
func _clean() -> void:
	g.boost_pick = 0
	while g.stock.size() > 4 and g.drop.size() > 4:
		g.stock.pop_back()
		g.drop.pop_back()
	for it in g.drop:
		it.gone = false
		it.sold = 0.0
		it.held = false
	_step(0.2)


func _ok(n: String, c: bool, d: String) -> void:
	if not c:
		fails += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


#  확대 — 최근접만. 보간하면 재는 것이 그림이 아니라 필터가 된다.
func _crop(im: Image, r: Rect2i, k: int) -> Image:
	var part := im.get_region(r)
	part.resize(r.size.x * k, r.size.y * k, Image.INTERPOLATE_NEAREST)
	return part


func _grid(tiles: Array, cols: int, gap: int) -> Image:
	var tw: int = (tiles[0] as Image).get_width()
	var th: int = (tiles[0] as Image).get_height()
	var rows: int = int(ceil(float(tiles.size()) / float(cols)))
	var out := Image.create(cols * tw + (cols - 1) * gap, rows * th + (rows - 1) * gap,
			false, (tiles[0] as Image).get_format())
	out.fill(Color(0.06, 0.05, 0.08))
	for i in tiles.size():
		var t: Image = tiles[i]
		out.blit_rect(t, Rect2i(0, 0, t.get_width(), t.get_height()),
				Vector2i((i % cols) * (tw + gap), (i / cols) * (th + gap)))
	return out


#  판 위 물건 하나의 화면 자리(물리 · 들림 그대로)를 화면 픽셀로.
func _px(i: int, sp: float) -> Vector2i:
	var it: Dictionary = g.drop[i]
	var c: Vector2 = g._p2s(float(it.u), float(it.w), float(it.h) + float(it.lift))
	return Vector2i(int(c.x * sp), int(c.y * sp))


func _box(c: Vector2i, w: int, h: int, im: Image) -> Rect2i:
	var x: int = clampi(c.x - w / 2, 0, im.get_width() - w)
	var y: int = clampi(c.y - h / 2, 0, im.get_height() - h)
	return Rect2i(x, y, w, h)


#  히트가 그림을 덮는가 — 그림의 네 귀(배율 탄 면)를 안으로 0.5px 물려 _obj_shape 에
#  넣는다. 사진보다 커진 큰 팩에서 귀퉁이가 안 잡히면 여기서 걸린다.
func _hit_check(i: int, tag: String) -> void:
	var it: Dictionary = g.drop[i]
	var s: float = g._pack_s(g.stock[i].d)
	var c: Vector2 = g._p2s(float(it.u), float(it.w), float(it.h))
	var worst := 0
	var box_out := 0
	var psi0: float = float(it.psi)
	#  한 바퀴를 2° 걸음으로 — 귀퉁이가 가로로 눕는 좁은 각을 안 놓친다.
	for k in 180:
		it.psi = deg_to_rad(float(k) * 2.0)
		var q: PackedVector2Array = g._quad_at(c, it.psi,
				float(g.PACK.w) * g.GOODS_K * s - 0.5, float(g.PACK.h) * g.GOODS_K * s - 0.5)
		for p in q:
			if not g._obj_shape(i, p):
				worst += 1
			#  광역 덮개는 _hit_obj 가 2px 키워 쓴다 — 같은 자로 잰다
			if not g._obj_box(i).grow(2.0).has_point(p):
				box_out += 1
	it.psi = psi0
	_ok("히트 · %s 귀 720개가 모양에 잡힌다" % tag, worst == 0,
			"빠진 귀 %d · 배율 %.2f" % [worst, s])
	_ok("히트 · %s 광역 덮개가 귀를 싼다" % tag, box_out == 0, "빠진 귀 %d" % box_out)


func _run() -> void:
	await _wait(10)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift", "u_pack"]:
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
	var sp: float = 2.0

	#  ── 판 위 ─────────────────────────────────────────
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	var a: Image = await _shot()
	sp = float(a.get_width()) / 640.0
	a.save_png("res://shots/packs_foil_shop.png")
	print("팩 화면 자리  작은 %s · 큰 %s" % [_px(0, sp), _px(1, sp)])
	_hit_check(0, "작은 팩")
	_hit_check(1, "큰 팩")
	_put([["boost", "b_small"], ["cons", ""], ["boost", "b_big"], ["dart", ""]])
	var b: Image = await _shot()
	b.save_png("res://shots/packs_foil_shop2.png")
	var za := a.get_region(BAND)
	var zb := b.get_region(BAND)
	var z := Image.create(960, 526, false, za.get_format())
	z.blit_rect(za, Rect2i(0, 0, 960, 260), Vector2i(0, 0))
	z.blit_rect(zb, Rect2i(0, 0, 960, 260), Vector2i(0, 266))
	z.resize(1920, 1052, Image.INTERPOLATE_NEAREST)
	z.save_png("res://shots/packs_foil_zoom.png")

	#  ── 돌린 팩 — 70° · 160°. 사진을 곁에 두고 같은 각으로 돌린다 ──
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	var rots := []
	for deg in [70.0, 160.0]:
		for i in [0, 1, 3]:
			g.drop[i].psi = deg_to_rad(deg)
		var r: Image = await _shot()
		rots.append(r.get_region(BAND))
	var zr := _grid(rots, 1, 6)
	zr.resize(zr.get_width() * 2, zr.get_height() * 2, Image.INTERPOLATE_NEAREST)
	zr.save_png("res://shots/packs_foil_rot.png")

	#  ── 얹었을 때의 빛 — 네 박자 ────────────────────────
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	g.drop[0].psi = deg_to_rad(8.0)
	g.drop[1].psi = deg_to_rad(-6.0)
	var shs := []
	var both := Rect2i()
	for t in [0.0, 0.2, 0.42, 0.66]:
		g.drop[0].gl = t
		g.drop[1].gl = t
		var im: Image = await _shot()
		var p0 := _px(0, sp)
		var p1 := _px(1, sp)
		var mid := Vector2i((p0.x + p1.x) / 2, (p0.y + p1.y) / 2)
		both = _box(mid, 300, 140, im)
		shs.append(_crop(im, both, 2))
	g.drop[0].gl = 0.0
	g.drop[1].gl = 0.0
	_grid(shs, 2, 8).save_png("res://shots/packs_foil_sheen.png")

	#  ── 상인이 든 팩 — 개발자 「살핌 · 팩」 길 그대로(작은 팩) · 큰 팩 ──
	var holds := []
	for big in [false, true]:
		_put([["boost", "b_small"], ["item", ""], ["fix", ""], ["cons", ""]])
		Dev._npc_side = 1
		#  개발자 판 「살핌 · 팩」 · 「살핌 · 큰 팩」 줄이 부르는 그 함수 그대로
		var hk: Array = Dev.NPC_HOLDS[0]
		for h in Dev.NPC_HOLDS:
			if String(h[1]) == "boost" and (String(h[2]) == "b_big") == big:
				hk = h
		Dev._npc_hold_kind(g, hk)
		for k in 130:
			g.give_t = minf(g.give_t, 1.06)
			_step(DT)
		var gi: int = g.give_i
		#  쥔 동안 박 위로 빛이 지나간다 — 그 박자 한가운데(쓸기 0.9초 중 0.45)를 찍는다
		if gi >= 0:
			g.drop[gi].gl = 0.45
		var hi: Image = await _shot()
		print("상인 손  %s 팩 · give_i %d · 쥔 자리 %s" % ["큰" if big else "작은", gi,
				_px(maxi(gi, 0), sp)])
		holds.append(_crop(hi, _box(_px(maxi(gi, 0), sp) + Vector2i(0, -60), 360, 300, hi), 2))
		if big:
			hi.save_png("res://shots/packs_foil_hold_full.png")
		g._give_end()
		_step(0.6)
	_grid(holds, 2, 8).save_png("res://shots/packs_foil_hold.png")

	#  ── 큰 팩 열기 — 여덟 장 ─────────────────────────────
	_clean()
	_put([["boost", "b_small"], ["item", ""], ["fix", ""], ["cons", ""]])
	var bd: Dictionary = _row(GameData.boosters(), "b_big")
	g._boost_deal(bd)
	var opens := []
	var orect := Rect2i(300, 60, 680, 560)
	for bt in [0.04, 0.15, 0.26, 0.335, 0.40, 0.47, 0.55, 0.63]:
		g.boost_t = bt
		var oi: Image = await _shot()
		opens.append(oi.get_region(orect))
	#  쏟은 뒤 — 시계를 돌려 실제로 쏟고(_boost_spill) 떨어지는 것을 본다
	g.boost_t = 0.63
	_step(0.05)
	_step(0.55)
	var si: Image = await _shot()
	opens[7] = si.get_region(orect)
	_grid(opens, 4, 8).save_png("res://shots/packs_foil_open.png")
	_step(1.5)

	#  ── 레전더리가 든 큰 팩 — 봉투가 뜯기는 원 ───────────────
	var leg: Dictionary = {}
	for it in GameData.items():
		if String(it.get("rarity", "")) == "legendary":
			leg = it
			break
	_clean()
	_put([["boost", "b_small"], ["item", ""], ["fix", ""], ["cons", ""]])
	g._boost_deal(bd)
	if not leg.is_empty() and not g.boost_spill.is_empty():
		g.boost_spill[0] = {"type": "item", "d": leg}
	var legs := []
	for bt in [0.40, 0.49, 0.56]:
		g.boost_t = bt
		var li: Image = await _shot()
		legs.append(li.get_region(orect))
	g.boost_t = 0.63
	_step(0.05)
	_step(0.7)
	var lj: Image = await _shot()
	legs.append(lj.get_region(orect))
	_grid(legs, 4, 8).save_png("res://shots/packs_foil_legend.png")
	_step(1.5)

	#  ── 쓸기 — 판 위 팩이 벽에 처박혀 깨진다 ───────────────
	_clean()
	_put([["boost", "b_big"], ["boost", "b_small"], ["boost", "b_big"], ["boost", "b_small"]])
	_step(0.4)
	g._sweep_begin()
	var smash := []
	var seen := 0
	for k in 900:
		_step(DT)
		var fly := 0
		var froze := 0
		for s in g.shards:
			if float(s.t) < 0.0:
				froze += 1
			elif s.get("tex") != null:
				fly += 1
		if (froze > 0 and seen == 0) or (fly > 0 and seen in [1, 2, 3] and k % 5 == 0):
			var mi: Image = await _shot()
			smash.append(mi.get_region(Rect2i(0, 240, 720, 380)))
			seen += 1
		if seen >= 4:
			break
	print("깨짐  찍은 장 %d · 조각 %d" % [smash.size(), g.shards.size()])
	if not smash.is_empty():
		_grid(smash, 2, 8).save_png("res://shots/packs_foil_smash.png")
	_step(2.0)

	print("state ", g.state, " · 실패 ", fails)
	quit(fails)
