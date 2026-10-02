extends SceneTree
#  상인 촬영 (2026-10-02) — 손가락 · 소매 · 램프 빛. 상점 한 장 · 상인 확대 ·
#  자세 넷(쉼 · 두드리기 한가운데 · 살핌으로 물건을 든 때 · 쓸기 한가운데).
#  shots/<머리>_shop.png · _close.png · _poses.png 로. 창이 있어야 돈다:
#    godot --path . --script scripts/tools/shot_npc3.gd            (머리 npc_B)
#    godot --path . --script scripts/tools/shot_npc3.gd -- npc_X   (머리 바꾸기)
const Save = preload("res://scripts/save.gd")
#  상인 칸(논리 px). 세 배 최근접으로 키운다.
const CROP := Rect2(150.0, 30.0, 340.0, 200.0)
const UP := 3
var g = null
var busy := false
var tag := "npc_B"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		tag = a[0]
	#  진짜 저장을 안 건드린다 — 버리는 이름부터 세우고 비운다.
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


#  툴팁 · 배움 · 커서를 걷는다. 커서는 한가운데 — 상인이 커서를 따라 돌기 때문이다.
func _quiet() -> void:
	g._tutor_close()
	g.tutor_q.clear()
	g.mouse_at = Vector2(320.0, 300.0)
	g.tip_a = 0.0
	g.tip_title = ""


#  저절로 나는 몸짓을 막는다 — 자세는 우리가 고른다.
func _still() -> void:
	_quiet()
	g.idle_wait = 99.0


func _crop(im: Image) -> Image:
	var k: float = float(im.get_width()) / 640.0
	var part := im.get_region(Rect2i(int(CROP.position.x * k), int(CROP.position.y * k),
			int(CROP.size.x * k), int(CROP.size.y * k)))
	part.resize(int(CROP.size.x) * UP, int(CROP.size.y) * UP, Image.INTERPOLATE_NEAREST)
	return part


func _grab() -> Image:
	return root.get_texture().get_image()


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
	g.gold = 24
	g._open_shop()
	for _i in 200:
		_still()
		g.idle_act = -1
		await process_frame
	_still()
	await _wait(20)
	var poses: Array[Image] = []
	#  ① 쉼
	g.idle_act = -1
	g.idle_t = 0.0
	await _wait(4)
	var full := _grab()
	full.save_png("res://shots/%s_shop.png" % tag)
	_crop(full).save_png("res://shots/%s_close.png" % tag)
	poses.append(_crop(full))
	#  ② 두드리기 한가운데 — 오른손(화면)이 들려 검지 · 가운뎃손가락이 물결을 탄다.
	var di: int = g._idle_index("두드리기")
	for _i in 3:
		_still()
		g.idle_act = di
		g.idle_side = 1
		g.idle_t = g._idle_len() * 0.527
		await process_frame
	poses.append(_crop(_grab()))
	g.idle_act = -1
	g.idle_t = 0.0
	await _wait(30)
	#  ③ 살핌 — 판 위 물건 하나를 오른손에 건넨다. 살피는 박자 한가운데에서 찍는다.
	var gi := -1
	for i in g.drop.size():
		if i < g.stock.size() and not bool(g.drop[i].get("held", false)):
			gi = i
			break
	if gi >= 0:
		_still()
		g._give_begin(gi, Vector2(420.0, 120.0))
		var want: float = float(g.GIVE.take) + float(g.GIVE.look) * 0.42
		var guard := 0
		while g._give_live() and g.give_t < want and guard < 600:
			_still()
			guard += 1
			await process_frame
		poses.append(_crop(_grab()))
		while g._give_live() and guard < 1200:
			_still()
			guard += 1
			await process_frame
	else:
		print("  건넬 물건이 없다")
		poses.append(_crop(_grab()))
	await _wait(60)
	#  ④ 쓸기 한가운데
	_still()
	g._sweep_begin()
	var sw: float = float(g.SWEEP.reach) + float(g.SWEEP.rake) * 0.30
	var guard2 := 0
	while g.sweep_live and g.sweep_t < sw and guard2 < 600:
		_still()
		guard2 += 1
		await process_frame
	poses.append(_crop(_grab()))
	#  2×2 — 사이 8px 검정.
	var cw: int = int(CROP.size.x) * UP
	var ch: int = int(CROP.size.y) * UP
	var grid := Image.create(cw * 2 + 8, ch * 2 + 8, false, poses[0].get_format())
	grid.fill(Color.BLACK)
	for i in poses.size():
		var p: Image = poses[i]
		if p.get_format() != grid.get_format():
			p.convert(grid.get_format())
		grid.blit_rect(p, Rect2i(0, 0, cw, ch), Vector2i((i % 2) * (cw + 8), (i / 2) * (ch + 8)))
	grid.save_png("res://shots/%s_poses.png" % tag)
	print("찍었다 — %s_shop / _close / _poses" % tag)
	quit(0)
