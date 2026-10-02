extends SceneTree
#  상인 촬영 (2026-10-02 · 공통 판 R) — 상점 한 장 · 상인 확대 · 자세 넷(쉼 ·
#  두드리기 · 살핌 · 쓸기) · 든 물건 4배. shots/npc_<V>_*.png 로. 창이 있어야 돈다:
#    godot --path . --script scripts/tools/shot_npc3.gd
#  확대는 논리 x[150,490] y[30,230] 을 최근접 3배로 — 보간하면 손가락 골과
#  팔 굵기 단이 흐려져 재는 것이 그림이 아니라 필터가 된다.
#  든 물건(hold)은 물건 중심 ±44 · ±34 를 4배로 — 엄지가 물건 **위**에 서고
#  손끝이 물건 테 밖으로 안 뚫리는지(2026-10-02 「동전에 손가락이 뚫리는데」)를 본다.
const Save = preload("res://scripts/save.gd")
const V := "B"
const CROP := Rect2(150.0, 30.0, 340.0, 200.0)
const K := 3
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_npc3_g.cfg"
	Save.path = "user://_shot_npc3.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261002)


func _process(_d: float) -> bool:
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

	#  살핌 — 매물 하나를 건네 받아 살피는 박자(받기 0.45 뒤). 시계를 손으로 감아
	#  틀 속도와 상관없이 같은 박자를 찍는다(_give_tick 이 몸짓 시계까지 민다).
	await _hold(20, func():
		g.idle_act = -1
		g.idle_wait = 9.0)
	var gi := -1
	for i in g.drop.size():
		if not bool(g.drop[i].get("gone", false)) and String(g.stock[i].type) == "item":
			gi = i
			break
	if gi < 0:
		for i in g.drop.size():
			if not bool(g.drop[i].get("gone", false)):
				gi = i
				break
	var look: Image = rest
	var hold_c := Vector2(320.0, 150.0)
	if gi >= 0:
		g._give_begin(gi, Vector2(400.0, 130.0))
		await _hold(70, func():
			g.mouse_at = Vector2(-50, -50))
		look = root.get_texture().get_image()
		var it: Dictionary = g.drop[gi]
		hold_c = g._p2s(float(it.u), float(it.w), float(it.h))
		print("  살핌 — 물건 %d 화면 (%.1f, %.1f) · give_t %.2f" % [gi, hold_c.x, hold_c.y, g.give_t])
		var hr := Rect2(hold_c - Vector2(56.0, 44.0), Vector2(112.0, 88.0))
		_crop(look, hr, 4).save_png("res://shots/npc_%s_hold.png" % V)
		#  두 화판을 따로 — ① 손 전부 · ③ 앞 층(엄지)만. 앞 층이 무엇을 다시
		#  얹는지가 합친 그림에서는 안 갈린다.
		if g.hand3_fvp != null:
			var r3: Rect2 = g.HAND3.rect
			var hr3 := Rect2(hr.position - r3.position, hr.size)
			#  그림자 화판(시안 B — 그림자를 한 겹으로 따로 굽는다)이 있으면 그것도.
			var vps := [["hand", g.hand3_vp], ["front", g.hand3_fvp]]
			if g.get("hand3_svp") != null:
				vps.append(["shad", g.hand3_svp])
			for pr in vps:
				var im3: Image = (pr[1] as SubViewport).get_texture().get_image()
				var part := im3.get_region(Rect2i(hr3))
				part.resize(int(hr.size.x) * 4, int(hr.size.y) * 4, Image.INTERPOLATE_NEAREST)
				part.save_png("res://shots/npc_%s_hold_%s.png" % [V, pr[0]])
		await _wait(150)
	else:
		print("  살핌 — 건넬 매물이 없다")

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

	#  판 고르기 — 동전 슬롯이 상점보다 16 낮게 선다. 위팔이 그 밑변에서 나오는지.
	g.leg_no = 2
	g._open_leg()
	await _wait(120)
	_quiet()
	await _hold(30, func():
		g.idle_act = -1
		g.idle_wait = 9.0
		g.mouse_at = Vector2(-50, -50))
	root.get_texture().get_image().save_png("res://shots/npc_%s_leg.png" % V)
	print("찍었다 — npc_%s_shop · close · poses · hold · acts · leg" % V)
	quit(0)
