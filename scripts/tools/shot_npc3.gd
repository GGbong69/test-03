extends SceneTree
#  상인 촬영 (2026-10-02 · 시안 B) — 상점 한 장 · 상인 확대 · 자세 넷(쉼 · 두드리기 ·
#  살핌 · 쓸기) · 테를 집은 손(오른손 · 왼손 · 물건 넷 · 게임 배율) · 몸짓 열둘 · 판 고르기.
#  shots/npc_<V>_*.png 로. 창이 있어야 돈다:
#    godot --path . --script scripts/tools/shot_npc3.gd            # 전부
#    godot --path . --script scripts/tools/shot_npc3.gd -- hold    # 집은 손 · 엄지만(고칠 때)
#    godot --path . --script scripts/tools/shot_npc3.gd -- thumb   # 엄지 8배만
#  확대는 최근접으로만 — 보간하면 손가락 골과 팔 굵기 단이 흐려져 재는 것이 그림이
#  아니라 필터가 된다.
#  집은 손(hold)은 「지금 동전 짚는 손 모양 너무 이상한데」 · 「엄지가 너무 올라가지 않았어?」
#  를 보는 칸이다 — 검지 끝은 동전 윗면 테 안에 · 엄지는 그 밑에 붙은 닫힌 집기인지, 엄지가
#  손등 위로 안 솟는지, 손 나머지가 물건 윤곽 밖(상인 쪽)에 서는지, 등급 빛이 손
#  **밑**에 깔리는지(너클이 안 바래는지)를 본다. 등급 빛이 있는 레어 동전으로 찍는다.
#  엄지(thumb_x8)는 「나이 엄지에 무지내전근이랑 무지대립근이 없잖아」를 보는 칸이다 — 엄지가
#  살 둔덕(엄지 두덩)에서 자라 나오고 물갈퀴로 검지에 이어지는지, 손등에서 본 엄지 쪽
#  윤곽이 손목에서 엄지 끝까지 볼록한 곡선 하나인지(막대 · V 틈 없이) 화소로 본다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const V := "B"
const CROP := Rect2(150.0, 30.0, 340.0, 200.0)
const K := 3
#  살피는 박자 한가운데 — 「살핌」 몸짓의 q 0.5(굴림 · 손각 흔들림 0, 들기 최고).
#  b = 0.20 + 0.52 · 0.5 = 0.46 → 2.30 · 0.46 = 1.06 초. 받기(0.45) 뒤 살피기 안이다.
const LOOK_T := 1.06
var g = null
var busy := false
var only_hold := false
var only_thumb := false


func _initialize() -> void:
	Save.gpath = "user://_shot_npc3_g.cfg"
	Save.path = "user://_shot_npc3.cfg"
	Save.wipe()
	only_hold = OS.get_cmdline_user_args().has("hold")
	only_thumb = OS.get_cmdline_user_args().has("thumb")
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261002)


func _process(_d: float) -> bool:
	#  실제 마우스가 창 위에 있으면 그 자리 물건의 설명이 뜬다(_cursor 는 진짜 커서를 읽는다)
	#  — 찍는 동안은 얹힘을 끈다.
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


func _quiet() -> void:
	g._tutor_close()
	g.tutor_q.clear()
	g.mouse_at = Vector2(-50, -50)


func _hold(n: int, f: Callable) -> void:
	for _i in n:
		f.call()
		await process_frame


func _crop(im: Image, r: Rect2 = CROP, k: int = K) -> Image:
	var s: float = float(im.get_width()) / 640.0
	var part := im.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s),
			int(r.size.x * s), int(r.size.y * s)))
	part.resize(int(r.size.x) * k, int(r.size.y) * k, Image.INTERPOLATE_NEAREST)
	return part


#  몸짓 하나를 그 박자에 붙들어 둔다 — 시계를 매 틀 되돌린다.
func _pose_act(nm: String, t: float, side: int) -> void:
	var ai: int = g._idle_index(nm)
	await _hold(8, func():
		g.idle_act = ai
		g.idle_t = t
		g.idle_side = side
		g.idle_wait = 9.0
		g.mouse_at = Vector2(-50, -50))


#  표에서 한 줄 — 조건(c)을 처음 만족하는 것.
func _row(rows: Array, c: Callable) -> Dictionary:
	for r in rows:
		if c.call(r):
			return r
	return {}


#  집을 매물 — 종류별로 표에서 한 줄을 골라 판 위 매물 자리 하나에 갈아 끼운다
#  (물리 자리 · 그림자는 그대로, 그리는 것만 바뀐다). 손님이 건넨 것과 같은 길이다.
func _stock_of(kind: String) -> Dictionary:
	match kind:
		"rare":
			return {"type": "item", "cost": 9, "sold": false, "d": _row(GameData.items(),
					func(r): return String(r.get("rarity", "")) == "rare")}
		"plaque":
			return {"type": "item", "cost": 9, "sold": false, "d": _row(GameData.items(),
					func(r): return String(r.get("rarity", "")) == "legendary")}
		"dart":
			var ds: Array = GameData.darts()
			return {"type": "dart", "cost": 6, "sold": false, "d": ds[mini(1, ds.size() - 1)]}
		"candy":
			return {"type": "cons", "cost": 4, "sold": false, "d": GameData.candies()[0]}
		"pack":
			return {"type": "boost", "cost": 6, "sold": false, "d": GameData.boosters()[0]}
		"photo":
			return {"type": "fix", "cost": 6, "sold": false, "d": GameData.fixtures()[0]}
	return {}


#  매물 하나를 kind 로 갈아 끼우고 side 손에 건네 살피는 박자에 붙든다. 물건 화면 자리를 돌려준다.
func _give_hold(kind: String, side: int) -> Vector2:
	if g._give_live():
		g._give_end()
	await _wait(2)
	var gi := -1
	for i in g.drop.size():
		if not bool(g.drop[i].get("gone", false)) and float(g.drop[i].get("sold", 0.0)) <= 0.0:
			gi = i
			break
	if gi < 0:
		print("  집기 — 판 위에 매물이 없다")
		return Vector2(320.0, 170.0)
	var st: Dictionary = _stock_of(kind)
	if st.is_empty() or (st.d as Dictionary).is_empty():
		print("  집기 — %s 표 줄이 없다" % kind)
		return Vector2(320.0, 170.0)
	g.stock[gi] = st
	g._give_begin(gi, Vector2(200.0 if side == 0 else 440.0, 130.0))
	await _hold(80, func():
		g.give_t = minf(g.give_t, LOOK_T)
		g.mouse_at = Vector2(-50, -50)
		g.tip_pin = {}
		g.tip_a = 0.0)
	var it: Dictionary = g.drop[gi]
	var c: Vector2 = g._p2s(float(it.u), float(it.w), float(it.h))
	print("  집기 %-6s %s손 — 물건 %d 화면 (%.1f, %.1f) · give_t %.2f · 쥠 %.2f"
			% [kind, "왼" if side == 0 else "오른", gi, c.x, c.y, g.give_t, g._give_grip(side)])
	return c


#  집은 손 확대 칸 — 물건 한가운데에서 위(상인 쪽)로 조금 올려 손까지 든다.
func _hold_rect(c: Vector2, w: float, h: float) -> Rect2:
	return Rect2(c.x - w * 0.5, c.y - h * 0.62, w, h)


func _holds() -> void:
	#  오른손 · 레어 동전 — 등급 빛이 손 밑에 깔리는지 본다.
	var c: Vector2 = await _give_hold("rare", 1)
	var im: Image = root.get_texture().get_image()
	_crop(im, _hold_rect(c, 120.0, 96.0), 4).save_png("res://shots/npc_%s_hold.png" % V)
	#  오른손만 8배 — 검지 끝 둘레 64 × 52. 엄지가 검지 밑에 붙어 닫힌 집기인지, 손등
	#  윤곽 위로 안 솟는지를 화소로 본다(「엄지가 너무 올라가지 않았어?」).
	var rg1: Dictionary = g.hand3_rig[1]
	var tip3: Vector3 = (rg1.tips[0] as Node3D).global_transform.origin
	var tps := Vector2(tip3.x, float(g.TBL.fy) + tip3.z * float(g.TBL.flat) - tip3.y * float(g.TBL.tall))
	_crop(im, Rect2(tps - Vector2(34.0, 30.0), Vector2(64.0, 52.0)), 8).save_png(
			"res://shots/npc_%s_hold_x8.png" % V)
	#  게임 배율(2배) 그대로 — 상인 둘레를 자르지 않고. 화면에서 읽히는지가 이 칸의 일이다.
	_crop(im, Rect2(150.0, 30.0, 340.0, 220.0), 2).save_png("res://shots/npc_%s_hold_game.png" % V)
	#  ① 손 화판 · ③ 앞 화판을 따로 — 앞 층에 무엇이 섰는지(검지)가 합친 그림에서는 안 갈린다.
	if g.hand3_fvp != null:
		var hr := _hold_rect(c, 120.0, 96.0)
		var r3: Rect2 = g.HAND3.rect
		var hr3 := Rect2i(Rect2(hr.position - r3.position, hr.size))
		for pr in [["hand", g.hand3_vp], ["front", g.hand3_fvp]]:
			var im3: Image = (pr[1] as SubViewport).get_texture().get_image()
			var part := im3.get_region(hr3)
			part.resize(int(hr.size.x) * 4, int(hr.size.y) * 4, Image.INTERPOLATE_NEAREST)
			part.save_png("res://shots/npc_%s_hold_%s.png" % [V, pr[0]])
	#  받기 · 내리기 여덟 박자 — 손끝이 테로 건너가고 풀리는 동안 면 위로 지나가지
	#  않는지(앞 층은 쥠 GIVE.front_k 부터 선다 · 내리는 동안은 집은 채다). 한 줄 넷 · 두 줄, 3배.
	var seq := [0.26, 0.32, 0.38, 0.44, 1.77, 1.83, 1.89, 1.95]
	var sq: Image = null
	for k in seq.size():
		var tq: float = seq[k]
		await _hold(4, func():
			g.give_t = tq - 1.0 / 60.0
			g.mouse_at = Vector2(-50, -50))
		var itq: Dictionary = g.drop[g.give_i] if g._give_live() else {}
		var cq: Vector2 = c if itq.is_empty() else g._p2s(float(itq.u), float(itq.w), float(itq.h))
		var qi: Image = _crop(root.get_texture().get_image(), _hold_rect(Vector2(c.x, (c.y + cq.y) * 0.5), 120.0, 96.0), 3)
		if sq == null:
			sq = Image.create(360 * 4 + 6 * 3, 288 * 2 + 6, false, qi.get_format())
			sq.fill(Color.BLACK)
		sq.blit_rect(qi, Rect2i(0, 0, 360, 288), Vector2i((k % 4) * 366, (k / 4) * 294))
	sq.save_png("res://shots/npc_%s_hold_seq.png" % V)
	#  왼손 · 레어 동전.
	c = await _give_hold("rare", 0)
	_crop(root.get_texture().get_image(), _hold_rect(c, 120.0, 96.0), 4).save_png(
			"res://shots/npc_%s_hold_L.png" % V)
	#  물건 넷 — 플라크 · 다트 · 사탕 · 팩. 손을 번갈아 둘 다 본다. 3배 2 × 2.
	var kinds := [["plaque", 1], ["dart", 0], ["candy", 1], ["pack", 0]]
	var cw := 120 * 3
	var ch := 96 * 3
	var gap := 6
	var sheet: Image = null
	for k in kinds.size():
		var kc: Vector2 = await _give_hold(String(kinds[k][0]), int(kinds[k][1]))
		var ki: Image = _crop(root.get_texture().get_image(), _hold_rect(kc, 120.0, 96.0), 3)
		if sheet == null:
			sheet = Image.create(cw * 2 + gap, ch * 2 + gap, false, ki.get_format())
			sheet.fill(Color.BLACK)
		sheet.blit_rect(ki, Rect2i(0, 0, cw, ch), Vector2i((k % 2) * (cw + gap), (k / 2) * (ch + gap)))
	sheet.save_png("res://shots/npc_%s_hold_kinds.png" % V)
	#  마지막 것은 끝까지 — 내려놓고 뿌린다(바로 놓으면 상인 손 밑에 떨어져, 다음 칸의
	#  쉬는 손이 그 물건을 덮은 그림이 된다).
	var guard := 0
	while g._give_live() and guard < 300:
		guard += 1
		await process_frame
	await _wait(60)


#  엄지 칸 하나 — 손 i 의 CMC 와 엄지 끝 한가운데를 가운데로 56 × 44 를 8 배.
func _thumb_cell(im: Image, i: int) -> Image:
	var hj: Dictionary = (g.hand3_rig[i] as Dictionary).hj
	var a: Vector3 = (hj.thumb as Node3D).global_transform.origin
	var b: Vector3 = (hj.ttip as Node3D).global_transform.origin
	var m := (a + b) * 0.5
	var ms := Vector2(m.x, float(g.TBL.fy) + m.z * float(g.TBL.flat) - m.y * float(g.TBL.tall))
	return _crop(im, Rect2(ms - Vector2(28.0, 22.0), Vector2(56.0, 44.0)), 8)


#  엄지 길이 8배 — 쉬는 화면 오른손, 엄지 MCP 와 검지 PIP 사이를 가운데로 56 × 44. 검지 PIP
#  자리에 검지 첫마디를 가로지르는 1px 눈금 하나를 **이 그림에만** 긋는다(게임에는 없다) —
#  「지금 엄지가 너무 길지 않아?」: 모은 엄지 끝이 그 눈금 못 미쳐(검지 첫마디의 0.69 —
#  PMC12309929) 서는지 본다.
func _thumb_len_shot(im: Image) -> void:
	var hj: Dictionary = (g.hand3_rig[1] as Dictionary).hj
	var k: Vector3 = (hj.j1[0] as Node3D).global_transform.origin
	var p: Vector3 = (hj.j2[0] as Node3D).global_transform.origin
	var m: Vector3 = (hj.t1 as Node3D).global_transform.origin
	var ks := Vector2(k.x, float(g.TBL.fy) + k.z * float(g.TBL.flat) - k.y * float(g.TBL.tall))
	var ps := Vector2(p.x, float(g.TBL.fy) + p.z * float(g.TBL.flat) - p.y * float(g.TBL.tall))
	var ms := Vector2(m.x, float(g.TBL.fy) + m.z * float(g.TBL.flat) - m.y * float(g.TBL.tall))
	var o: Vector2 = (ps + ms) * 0.5 - Vector2(28.0, 22.0)
	var cut := _crop(im, Rect2(o, Vector2(56.0, 44.0)), 8)
	var d := (ps - ks).normalized()
	var n := Vector2(-d.y, d.x)
	var c8 := (ps - o) * 8.0
	for t in range(-28, 29):
		var q := c8 + n * float(t)
		if q.x >= 0.0 and q.y >= 0.0 and q.x < float(cut.get_width()) and q.y < float(cut.get_height()):
			cut.set_pixel(int(q.x), int(q.y), Color(0.2, 1.0, 1.0))
	cut.save_png("res://shots/npc_%s_thumb_len.png" % V)


#  엄지 8배 — 두 줄(화면 오른손 · 왼손) × 세 칸(쉼 · 집기 · 편 손). 편 손은 오른손이
#  쓸기 한가운데, 왼손은 쓸지 않으므로(쓰는 동안 HUD 뒤로 물러난다) 「기대기」 한가운데 —
#  두 손이 다 편 손(FPOSE.open)이다.
func _thumbs() -> void:
	if g._give_live():
		g._give_end()
	await _hold(40, func():
		g.idle_act = -1
		g.idle_wait = 9.0
		g.mouse_at = Vector2(-50, -50))
	var cw := 56 * 8
	var ch := 44 * 8
	var gap := 6
	var sheet: Image = null
	var im: Image = root.get_texture().get_image()
	var cells: Array = [[_thumb_cell(im, 1), _thumb_cell(im, 0)]]
	_thumb_len_shot(im)
	await _give_hold("rare", 1)
	var gr: Image = _thumb_cell(root.get_texture().get_image(), 1)
	await _give_hold("rare", 0)
	cells.append([gr, _thumb_cell(root.get_texture().get_image(), 0)])
	if g._give_live():
		g._give_end()
	await _hold(40, func():
		g.idle_act = -1
		g.idle_wait = 9.0)
	g._sweep_begin()
	await _hold(6, func():
		g.sweep_t = 0.43)
	var sw: Image = _thumb_cell(root.get_texture().get_image(), 1)
	while g.sweep_live:
		await _wait(4)
	await _wait(10)
	var li: int = g._idle_index("기대기")
	await _pose_act("기대기", 0.5 * float((g.IDLE.acts[li] as Dictionary).t), 0)
	cells.append([sw, _thumb_cell(root.get_texture().get_image(), 0)])
	await _hold(20, func():
		g.idle_act = -1
		g.idle_wait = 9.0)
	for c in 3:
		for r in 2:
			var ci: Image = cells[c][r]
			if sheet == null:
				sheet = Image.create(cw * 3 + gap * 2, ch * 2 + gap, false, ci.get_format())
				sheet.fill(Color.BLACK)
			sheet.blit_rect(ci, Rect2i(0, 0, cw, ch), Vector2i(c * (cw + gap), r * (ch + gap)))
	sheet.save_png("res://shots/npc_%s_thumb_x8.png" % V)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	g._new_run()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give"]:
		Save.teach(id)
	_quiet()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 99
	g._open_shop()
	await _wait(200)
	_quiet()
	if only_thumb:
		await _thumbs()
		print("찍었다 — npc_%s_thumb_x8 · thumb_len" % V)
		quit(0)
		return
	if only_hold:
		await _holds()
		await _thumbs()
		print("찍었다 — npc_%s_hold · hold_L · hold_kinds · hold_game · thumb_x8 · thumb_len" % V)
		quit(0)
		return
	#  쉼 — 몸짓을 걷고 쉼을 길게 잡는다.
	await _hold(30, func():
		g.idle_act = -1
		g.idle_wait = 9.0
		g.mouse_at = Vector2(-50, -50))
	var rest: Image = root.get_texture().get_image()
	rest.save_png("res://shots/npc_%s_shop.png" % V)
	_crop(rest).save_png("res://shots/npc_%s_close.png" % V)

	#  두드리기 — 화면 왼손. 셋 치는 박자 가운데.
	await _pose_act("두드리기", 0.76, 0)
	var tap: Image = root.get_texture().get_image()

	#  살핌 — 레어 동전을 오른손에 건네 살피는 박자에 붙든다.
	await _hold(20, func():
		g.idle_act = -1
		g.idle_wait = 9.0)
	await _give_hold("rare", 1)
	var look: Image = root.get_texture().get_image()
	if g._give_live():
		g._give_end()
	await _wait(60)
	await _holds()

	#  쓸기 — 훑기 한가운데. 시계를 붙들어 둔다.
	await _hold(20, func():
		g.idle_act = -1
		g.idle_wait = 9.0)
	g._sweep_begin()
	await _hold(6, func():
		g.sweep_t = 0.43)
	var swp: Image = root.get_texture().get_image()

	var cw: int = int(CROP.size.x) * K
	var ch: int = int(CROP.size.y) * K
	var gap := 8
	var grid := Image.create(cw * 2 + gap, ch * 2 + gap, false, rest.get_format())
	grid.fill(Color.BLACK)
	var shots := [rest, tap, look, swp]
	for i in 4:
		var c := _crop(shots[i])
		grid.blit_rect(c, Rect2i(0, 0, cw, ch),
				Vector2i((i % 2) * (cw + gap), (i / 2) * (ch + gap)))
	grid.save_png("res://shots/npc_%s_poses.png" % V)
	while g.sweep_live:
		await _wait(4)
	await _wait(10)
	await _thumbs()

	#  몸짓 열둘 — 한가운데 박자. 새 팔(위팔 · 팔꿈치 · 큰 손)이 몸짓마다 안
	#  끊기는지(팔꿈치 이음매 · 손목 · 어깨) 한 장에서 본다.
	var acts := [["털기", 0.5, 0], ["두드리기", 0.42, 0], ["기대기", 0.5, 1],
			["뒤집기", 0.5, 1], ["내리치기", 0.5, 0], ["기지개", 0.5, 1],
			["어깨돌리기", 0.25, 1], ["훑기", 0.5, 0], ["손짓", 0.5, 1],
			["짚기", 0.5, 0], ["손사래", 0.3, 1], ["빼기", 0.5, 0]]
	var aw: int = int(CROP.size.x) * 2
	var ah: int = int(CROP.size.y) * 2
	var sheet := Image.create(aw * 4 + 6 * 3, ah * 3 + 6 * 2, false, rest.get_format())
	sheet.fill(Color.BLACK)
	for k in acts.size():
		var ac: Array = acts[k]
		var ai: int = g._idle_index(String(ac[0]))
		var tt: float = float(ac[1]) * float((g.IDLE.acts[ai] as Dictionary).t)
		await _pose_act(String(ac[0]), tt, int(ac[2]))
		var im: Image = root.get_texture().get_image()
		sheet.blit_rect(_crop(im, CROP, 2), Rect2i(0, 0, aw, ah),
				Vector2i((k % 4) * (aw + 6), (k / 4) * (ah + 6)))
	sheet.save_png("res://shots/npc_%s_acts.png" % V)
	g.idle_act = -1

	#  판 고르기 — 동전 슬롯이 상점보다 16 낮게 서고 가운데 카드가 손 사이에 선다.
	g.leg_no = 2
	g._open_leg()
	await _wait(120)
	_quiet()
	await _hold(30, func():
		g.idle_act = -1
		g.idle_wait = 9.0
		g.mouse_at = Vector2(-50, -50))
	root.get_texture().get_image().save_png("res://shots/npc_%s_leg.png" % V)
	print("찍었다 — npc_%s_shop · close · poses · hold · hold_L · hold_kinds · hold_game · thumb_x8 · thumb_len · acts · leg" % V)
	quit(0)
